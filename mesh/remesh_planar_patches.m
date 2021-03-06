function [W,G,IM,C] = remesh_planar_patchs(V,F,varargin)
  % REMESH_PLANAR_PATCHS  Find nearly planar patches and retriangulate them.
  %   (V,F) should probably not be self-intersecting, at least not near the
  %   planar patches. This will attempt to maintain non-manifold edges
  %   (untested).
  %
  % [W,G] = remesh_planar_patchs(V,F)
  % [W,G,IM,C] = remesh_planar_patchs(V,F,'ParameterName',ParameterValue,...)
  %
  % Inputs:
  %   V  #V by 3 list of vertices
  %   F  #F by 3 list of triangle indices
  %   Optional:
  %     'Force' followed by whether to remesh even if it will not improve
  %        the number of vertices {false}.
  %     'MinSize' followed by minimum number of facets in group to consider for
  %       remeshing {4}
  %
  % Outputs:
  %   W  #W by 3 list of output mesh positions
  %   G  #G by 3 list of output triangle indices
  %   IM  indices from final remove_unreferenced
  %   C  #F list of patch indices
  %

  % force remesh even if there are no internal vertices to remove
  force_remesh = false;
  % Minmimum angle for two neighboring facets to be considered coplanar
  % in radians
  %min_delta_angle = pi-1e-5;
  min_delta_angle = pi-1e-3;
  min_size = 4;
  % Map of parameter names to variable names
  params_to_variables = containers.Map( ...
    {'Force','MinSize'}, ...
    {'force_remesh','min_size'});
  v = 1;
  while v <= numel(varargin)
    param_name = varargin{v};
    if isKey(params_to_variables,param_name)
      assert(v+1<=numel(varargin));
      v = v+1;
      % Trick: use feval on anonymous function to use assignin to this workspace 
      feval(@()assignin('caller',params_to_variables(param_name),varargin{v}));
    else
      error('Unsupported parameter: %s',varargin{v});
    end
    v=v+1;
  end

  % The right way to deal with them would be to make a list of feature edges
  % (aka "exterior edges") on the original mesh and be sure these end up in any
  % planar pataches. They would include the patch boundaries and any other
  % internal non-manifold edges.
  NME = nonmanifold_edges(F);

  A = adjacency_dihedral_angle_matrix(V,F);
  % Adjacency matrix of nearly coplanar neighbors
  AF = A>=min_delta_angle;
  % get connected components
  [~,C] = graphconncomp(AF);
  tsurf(F,V,'CData',randcycle(C))

  [UC,~,ic] = unique(C);
  ucounts = histc(C,UC);
  counts = ucounts(ic);

  tsurf(F,V,'CData',C);
  axis equal;
  drawnow;

  W = V;
  G = F(counts<=min_size,:);
  % loop over connected components
  %for c = reshape(UC(ucounts>min_size),1,[])
  for c = 1:max(C)
    if ucounts(c) > min_size
      Fc = F(C==c,:);
      assert(size(Fc,1)>min_size);
      %S = statistics(V,Fc,'Fast',true);
      %% Not dealing with holes yet
      %if S.num_boundary_loops > 1
      %  warning('Skipping high-genus planar patch...');
      %  G = [G;Fc];
      %  continue;
      %end
      %assert(S.num_boundary_loops == 1);
      uf = unique(Fc);
      % Fit plane to all points
      [~,A] = affine_fit(V(uf,:));
      % Only keep outline points
      O = outline(Fc);

      % Non manifold edges on this patch
      NMEc = NME(all(ismember(NME,uf),2),:);
      E = [O;NMEc];

      uo = unique(E);
      % Nothing to gain by remeshing
      if ~force_remesh && numel(uo) == numel(uf)
        G = [G;Fc];
        continue;
      end
      % only boundary edges projected to plane
      Vuo = V(uo,:)*A;
      J = 1:size(V,1);
      J(uo) = 1:numel(uo);
      % Remap E to Vu
      O = J(O);
      E = J(E);

      % THIS IS INSANELY SLOW
      % DT = delaunayTriangulation(Vuo(:,1),Vuo(:,2));
      % DT.Constraints = E;
      % Gc = DT.ConnectivityList;
      % Triangle is way faster...
      [Wuo,Gc] = triangle(Vuo,E,[],'Quiet');
      assert(size(Gc,1) >= 1);
      assert(size(Wuo,1) == size(Vuo,1));
      % easier to remove holes post hoc than pass hole positions to triangle
      AE = adjacency_matrix(E);
      [~,CE] = graphconncomp(AE);
      if max(CE) > 1
        w = winding_number(Vuo,O,barycenter(Vuo,Gc));
        % should only be 1s and 0s
        Gc = Gc(abs(w)>0.1,:);
      end


      % remap Gc to V
      Gc = uo(Gc);
      % old mean normal
      oldN = mean(normalizerow(normals(V,Fc)));
      N = mean(normalizerow(normals(V,Gc)));
      flip  = dot(oldN,N) < 0;
      if flip
        Gc = fliplr(Gc);
      end
      tsurf(Gc,W);
      G = [G;Gc];
    end
  end

  [W,IM] = remove_unreferenced(W,G);
  G = IM(G);

end
