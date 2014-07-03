function [U,CSM,SS,R] = arap(varargin)
  % ARAP Solve for the as-rigid-as-possible deformation according to various
  % manifestations including:
  %   (1) "As-rigid-as-possible Surface Modeling" by [Sorkine and Alexa 2007]
  %   (2) "A local-global approach to mesh parameterization" by [Liu et al.
  %     2010] or "A simple geometric model for elastic deformation" by [Chao et
  %     al.  2010]
  %   (3) Adapted version of "As-rigid-as-possible Surface Modeling" by
  %     [Sorkine and Alexa 2007] presented in section 4.2 of or "A simple
  %     geometric model for elastic deformation" by [Chao et al.  2010]
  %
  % U = arap(V,F,b,bc) given a rest mesh (V,F) and list of constraint vertex
  % indices (b) and their new postions (bc) solve for pose mesh positions (U),
  % using default choice for 'Energy'
  %
  % U = arap(V,F,b,bc,'ParameterName','ParameterValue',...)
  %
  % Inputs:
  %   V  #V by dim list of rest domain positions
  %   F  #F by {3|4} list of {triangle|tetrahedra} indices into V
  %   b  #b list of indices of constraint (boundary) vertices
  %   bc  #b by dim list of constraint positions for b
  %   Optional:
  %     'Energy'
  %       followed by a string specifying which arap energy definition to use.
  %       One of the following:
  %         'spokes'  "As-rigid-as-possible Surface Modeling" by [Sorkine and
  %           Alexa 2007], rotations defined at vertices affecting incident
  %           edges
  %         'elements'  "A local-global approach to mesh parameterization" by
  %           [Liu et al.  2010] or "A simple geometric model for elastic
  %           deformation" by [Chao et al.  2010], rotations defined at
  %           elements (triangles or tets) 
  %         'spokes-and-rims'  Adapted version of "As-rigid-as-possible Surface
  %           Modeling" by [Sorkine and Alexa 2007] presented in section 4.2 of
  %           or "A simple geometric model for elastic deformation" by [Chao et
  %           al.  2010], rotations defined at vertices affecting incident
  %           edges and opposite edges
  %     'V0' #V by dim list of initial guess positions
  %       dim by dim by #C list of linear transformations initial guesses,
  %       optional (default is to use identity transformations)
  %     'CovarianceScatterMatrix'
  %       followed by CSM a dim*n by dim*n sparse matrix, see Outputs
  %     'Groups'
  %       followed by #V list of group indices (1 to k) for each vertex, such 
  %       that vertex i is assigned to group G(i)
  %     'Tol'
  %       stopping critera parameter. If variables (linear transformation matrix
  %       entries) change by less than 'tol' the optimization terminates,
  %       default is 0.75 (weak tolerance)
  %     'MaxIter'
  %       max number of local-global iterations, default is 10
  %     'Dynamic' 
  %        #V by dim list of external forces
  %     'TimeStep'
  %        scalar time step value
  %     'Vm1' 
  %        #V by dim positions at time t-1
  %     'Tikhonov' followed by constant Tikhonov regularization parameter
  %       alpha:
  %       http://en.wikipedia.org/wiki/Tikhonov_regularization#Relation_to_probabilistic_formulation
  %     'Flat' followed by whether to add the constraint that Z=0 {false}
  %     'RemoveRigid' followed by whether to add a constraint that places an
  %       arbitrary point at the origin and another along the x-axis {false}
  % Outputs:
  %   U  #V by dim list of new positions
  %   CSM dim*n by dim*n sparse matrix containing special laplacians along the
  %     diagonal so that when multiplied by repmat(U,dim,1) gives covariance 
  %     matrix elements, can be used to speed up next time this function is
  %     called, see function definitions
  %
  % Known issues: 'Flat',true + 'Energy','elements' should only need a 2D
  % rotation fit, but this does 3D to stay general (e.g. if one were to use
  % 'spokes' then the edge-set cannot be pre-mapped to a common plane)
  %
  % See also: takeo_arap
  %

  % parse input
  V = varargin{1};
  F = varargin{2};
  b = varargin{3};
  bc = varargin{4};
  G = [];

  % number of vertices
  n = size(V,1);
  assert(isempty(b) || max(b) <= n);
  assert(isempty(b) || min(b) >= 1);

  % default is Sorkine and Alexa style local rigidity energy
  energy = 'spokes';
  % default is no dynamics
  dynamic = false;
  % default is no external forces
  fext = zeros(size(V));
  % defaults is unit time step
  h = 1;
  % Tikhonov regularization alpha
  alpha_tik = 0;
  % flatten/parameterization
  flat = false;
  % remove rigid transformation invariance
  remove_rigid = false;

  ii = 5;
  while(ii <= nargin)
    switch varargin{ii}
    case 'Energy'
      ii = ii + 1;
      assert(ii<=nargin);
      energy = varargin{ii};
    case 'V0'
      ii = ii + 1;
      assert(ii<=nargin);
      U = varargin{ii};
    case 'CovarianceScatterMatrix'
      ii = ii + 1;
      assert(ii<=nargin);
      if ~isempty(varargin{ii})
        CSM = varargin{ii};
      end
    case 'Tikhonov'
      ii = ii + 1;
      assert(ii<=nargin);
      alpha_tik = varargin{ii};
    case 'Groups'
      ii = ii + 1;
      assert(ii<=nargin);
      G = varargin{ii};
      if isempty(G)
        k = n;
      else
        k = max(G);
      end
    case 'Tol'
      ii = ii + 1;
      assert(ii<=nargin);
      tol = varargin{ii};
    case 'MaxIter'
      ii = ii + 1;
      assert(ii<=nargin);
      max_iterations = varargin{ii};
    case 'Dynamic'
      ii = ii + 1;
      dynamic = true;
      assert(ii<=nargin);
      fext = varargin{ii};
    case 'TimeStep'
      ii = ii + 1;
      assert(ii<=nargin);
      h = varargin{ii};
    case 'Vm1'
      ii = ii + 1;
      assert(ii<=nargin);
      Vm1 = varargin{ii};
    case 'Flat'
      ii = ii + 1;
      assert(ii<=nargin);
      flat = varargin{ii};
    case 'RemoveRigid'
      ii = ii + 1;
      assert(ii<=nargin);
      remove_rigid = varargin{ii};
    otherwise
      error(['Unsupported parameter: ' varargin{ii}]);
    end
    ii = ii + 1;
  end

  if flat
    [ref_V,ref_F,ref_map] = plane_project(V,F);
    assert(strcmp(energy,'elements'),'flat only makes sense with elements');
  else
    ref_map = 1;
    ref_V = V;
    ref_F = F;
  end
  dim = size(ref_V,2);

  if isempty(bc)
    bc = sparse(0,dim);
  end
  assert(dim == size(bc,2));

  if(~exist('U','var') || isempty(U))
    if(dim == 2) 
      U = laplacian_mesh_editing(V,F,b,bc);
    else
      U = V;
    end
    U = U(:,1:dim);
  end
  assert(n == size(U,1));
  assert(dim == size(U,2));

  if dynamic
    V0 = U(:,1:dim);
    if ~exist('Vm1','var')
      Vm1 = V0;
    end
    M = massmatrix(V,F,'voronoi');
    DQ = 0.5*1/h^2*M;
    vel = (V0-Vm1)/h;
    Dl = 1/(h^2)*M*(-V0 - h*vel) - fext;
    %Dl = 1/h^3*M*(-2*V0 + Vm1) - fext;
  else
    DQ = sparse(size(V,1),size(V,1));
    Dl = sparse(size(V,1),dim);
  end

  if(~exist('L','var'))
    if(size(F,2) == 3)
      L = cotmatrix(V,F);
    elseif(size(F,2) == 4)
      L = cotmatrix3(V,F);
    else
      error('Invalid face list');
    end
  end

  rr.b = cell(dim,1);
  rr.bc = cell(dim,1);
  rr.preF = cell(dim,1);
  if remove_rigid
    if ~isempty(b)
      warning('RemoveRigid`s constraints are not typically wanted if |b|>0');
    end
    % the only danger is picking two points which end up mapped very close to
    % each other
    [~,f] = farthest_points(V,dim);
    for c = 1:dim
      rr.b{c} = f([1:dim-(c-1)])';
      rr.bc{c} = zeros(numel(rr.b{c}),1);
    end
    % Immediately remove rigid transformation from initial guess
    U = bsxfun(@minus,U,U(f(1),:));
    % We know that f(1) is at origin
    switch dim
    case 3
      % rotate about y-axis so that f(2) has (x=0)
      theta = atan2(U(f(2),1),U(f(2),3));
      R = axisangle2matrix([0 1 0],theta);
      U = U*R;
      % rotate about x-axis so that f(2) has (y=0)
      theta = atan2(U(f(2),3),U(f(2),2))+pi/2;
      R = axisangle2matrix([1 0 0],theta);
      U = U*R;
      % rotate about z-axis so that f(3) has (x=0)
      theta = atan2(U(f(3),2),U(f(3),1))+pi/2;
      R = axisangle2matrix([0 0 1],theta);
      U = U*R;
    case 2
      % rotate so that f(2) is on y-axis (x=0)
      theta = atan2(U(f(2),2),U(f(2),1))+pi/2;
      R = [cos(theta) -sin(theta);sin(theta) cos(theta)];
      U = U*R;
    otherwise
      error('Unsupported dimension');
    end
  end

  if(~exist('interior','var'))
    indices = 1:n;
    interior = indices(~ismember(indices,b));
  end
  all = [interior b];

  % cholesky factorization
  %cholL = chol(-L(interior,interior),'lower');
  % Why lu and not cholesky?
  %[luL,luU,luP,luQ,luR] = lu(-L(interior,interior));

  %R = repmat(eye(dim,dim),[1 1 n]);
  if(~exist('max_iterations','var'))
    max_iterations = 100;
  end

  ae = avgedge(V,F);
  if(~exist('tol','var'))
    tol = 0.001;
  end


  % build covariance scatter matrix used to build covariance matrices we'll
  % later fit rotations to
  if(~exist('CSM','var'))
    assert(size(ref_V,2) == dim);
    CSM = covariance_scatter_matrix(ref_V,ref_F,'Energy',energy);
    if flat
      CSM = CSM * repdiag(ref_map',dim);
    end
    
    % if there are groups then condense scatter matrix to only build
    % covariance matrices for each group
    if ~isempty(G)
      if strcmp(energy,'elements') && numel(G) ~= size(F,1) && numel(G) == n
        % groups are defined per vertex, convert to per face using mode
        G = mode(G(F),2);
      end
      G_sum = group_sum_matrix(G,k);
      %CSM = [G_sum sparse(k,n); sparse(k,n) G_sum] * CSM;
      CSM = repdiag(G_sum,dim) * CSM;
    end
  end

  % precompute rhs premultiplier
  [~,K] = arap_rhs(ref_V,ref_F,[],'Energy',energy);
  if flat
    K = repdiag(ref_map,dim) * K;
  end

  % initialize rotations with identies (not necessary)
  R = repmat(eye(dim,dim),[1 1 size(CSM,1)/dim]);

  iteration = 0;
  U_prev = V;
  preF = [];
  while( iteration < max_iterations && (iteration == 0 || max(abs(U(:)-U_prev(:)))>tol*ae))
    U_prev = U;

    % energy after last global step
    U(b,:) = bc;
    %E = arap_energy(V,F,U,R);
    %[1 E]

    % compute covariance matrix elements
    S = zeros(size(CSM,1),dim);
    S(:,1:dim) = CSM*repmat(U,dim,1);
    % dim by dim by n list of covariance matrices
    SS = permute(reshape(S,[size(CSM,1)/dim dim dim]),[2 3 1]);
    % fit rotations to each deformed vertex
    R = fit_rotations(SS);

    % energy after last local step
    U(b,:) = bc;
    %E = arap_energy(V,F,U,R);
    %[2 E]


    % This is still the SLOW way of building the right hand side, the entire
    % step of building the right hand side should collapse into a
    % #handles*dim*dim+1 by #groups matrix times the rotations at for group
    
    % distribute group rotations to vertices in each group
    if ~isempty(G)
      R = R(:,:,G);
    end

    U(b,:) = bc;

    %B = arap_rhs(V,F,R);
    Rcol = reshape(permute(R,[3 1 2]),size(K,2),1);
    Bcol = K * Rcol;
    B = reshape(Bcol,[size(Bcol,1)/dim dim]);

    % RemoveRigid requires to solve each indepently
    if remove_rigid
      for c = 1:dim
        eff_b = [b rr.b{c}];
        eff_bc = [bc(:,c);rr.bc{c}];
        [U(:,c),rr.preF{c}] = min_quad_with_fixed( ...
          -0.5*L+DQ+alpha_tik*speye(size(L)), ...
          -B(:,c)+Dl(:,c),eff_b,eff_bc,[],[],rr.preF{c});
      end
    else 
      [U,preF] = min_quad_with_fixed( ...
        -0.5*L+DQ+alpha_tik*speye(size(L)),-B+Dl,b,bc,[],[],preF);
    end
    energy = trace(U'*(-0.5*L)*U+U'*(-B))
    %U(interior,:) = -L(interior,interior) \ (B(interior,:) + L(interior,b)*bc);
    %U(interior,:) = -L(interior,all)*L(all,interior) \ (L(interior,all)*B(all,:) + L(interior,all)*L(all,b)*bc);
    %U(interior,:) = luQ*(luU\(luL\(luP*(luR\(B(interior,:)+L(interior,b)*bc)))));
    %U(interior,:)=cholL\((B(interior,:)+L(interior,b)*bc)'/cholL)';
    iteration = iteration + 1;
  end
  U = U(:,1:dim);
end
