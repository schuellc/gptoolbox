function t = tsurf(F,V,varargin)
  % TSURF trisurf wrapper, easily plot triangle meshes with(out) face or vertex
  % indices. Attaches callbacks so that click-and-holding on the mesh and then
  % pressing 'm' launches meshplot (if available)
  %
  % t = tsurf(F,V);
  % t = tsurf(F,V,'ParameterName',ParameterValue, ...)
  %
  % Inputs:
  %   F  list of faces #F x 3
  %   V  vertex positiosn #V x 3 or #V x 2
  %   Optional:
  %     'VertexIndices' followed by 
  %     'FaceIndices' followed by 
  %                   0 -> off
  %                   1 -> text and grey background
  %                  >1 -> text
  %%     'ColorMultiplier' followed by #CData list of color multiplier values.
  %     ... additional options passed on to trisurf
  % Outputs:
  %  t  handle to trisurf object
  %
  % Copyright 2011, Alec Jacobson (jacobson@inf.ethz.ch)
  %
  % Example:
  %   % Compose with set function to set trisurf parameters to achieve
  %   % sharp isointervals
  %   tsurf(F,V, ...
  %     'FaceColor','interp', ...
  %     'FaceLighting','phong', ...
  %     'EdgeColor',[0.2 0.2 0.2]); 
  %   colormap(flag(8))
  %
  % See also: trisurf
  %


  vertex_indices = 0;
  face_indices = 0;

  v = 1;
  while v<=numel(varargin) && ischar(varargin{v}) 
    switch varargin{v}
    case 'VertexIndices'
      v = v+1;
      assert(v<=numel(varargin));
      vertex_indices = varargin{v};
    case 'FaceIndices'
      v = v+1;
      assert(v<=numel(varargin));
      face_indices = varargin{v};
    otherwise
      break;
    end
    v = v+1;
  end

  % number of vertices
  n = size(V,1);

  % nuymber of dimensions
  dim = size(V,2);

  if(dim==2 || (dim ==3 && sum(abs(V(:,3))) == 0))
    V = [V(:,1) V(:,2) 0*V(:,1)];
    dim = 2;
  elseif(dim>3 || dim<2 ) 
    error('V must be #V x 3 or #V x 2');
    return;
  end

  switch size(F,2)
  case 3
    t_copy = trisurf(F,V(:,1),V(:,2),V(:,3));
    if(face_indices==1)
      FC = (V(F(:,1),:)+V(F(:,2),:)+V(F(:,3),:))./3;
      text(FC(:,1),FC(:,2),FC(:,3),num2str((1:size(F,1))'),'BackgroundColor',[.7 .7 .7]);
    elseif(face_indices)
      FC = (V(F(:,1),:)+V(F(:,2),:)+V(F(:,3),:))./3;
      text(FC(:,1),FC(:,2),FC(:,3),num2str((1:size(F,1))'));
    end
  case 4
    t_copy = tetramesh(F,V,'FaceAlpha',0.5);
    if(face_indices==1)
      FC = (V(F(:,1),:)+V(F(:,2),:)+V(F(:,3),:)+V(F(:,4),:))./3;
      text(FC(:,1),FC(:,2),FC(:,3),num2str((1:size(F,1))'),'BackgroundColor',[.7 .7 .7]);
    elseif(face_indices)
      FC = (V(F(:,1),:)+V(F(:,2),:)+V(F(:,3),:)+V(F(:,4),:))./3;
      text(FC(:,1),FC(:,2),FC(:,3),num2str((1:size(F,1))'));
    end
    set(gcf,'Renderer','OpenGL');
  otherwise
    error(['Unsupported simplex size: size(F,2) = ' num2str(size(F,2))]);  
  end
  
  % if 2d then set to view (x,y) plane
  if( dim == 2)
    view(2);
  end

  if(vertex_indices==1)
    text(V(:,1),V(:,2),V(:,3),num2str((1:n)'),'BackgroundColor',[.8 .8 .8]);
  elseif(vertex_indices)
    text(V(:,1),V(:,2),V(:,3),num2str((1:n)'));
  end
  % uncomment these to switch to a better 3d surface viewing mode
  %axis equal; axis vis3d;
  %axis(reshape([min(V(:,1:dim));max(V(:,1:dim))],1,dim*2));
  axis tight;

  if v<=numel(varargin)
    set(t_copy,varargin{v:end});
  end

  % Only output if called with output variable, prevents ans = ... output on
  % terminal
  if nargout>=1
    t = t_copy;
  end

  % subversively set up the callbacks so that if the user clicks and holds on
  % the mesh then hits m, meshplot will open with this mesh
  set(t_copy,'buttondownfcn',@onmeshdown);

  function onmeshdown(src,ev)
    set(gcf,'windowbuttonupfcn',        @onmeshup);
    set(gcf,'keypressfcn',        @onkeypress);
  end

  function onkeypress(src,ev)
    switch ev.Character
    case 'm'
      V3 = V;
      if size(V3,2) == 2
        V3(:,3) = 0*V(:,1);
      end
      fprintf('Opening mesh in meshplot...\n');
      meshplot(V3,F);
    otherwise
      warning(['Unknown key: ' ev.Character]);
    end
  end

  function append_current_point()
  end

  function onmeshup(src,ev)
    set(gcf,'windowbuttonupfcn','');
    set(gcf,'keypressfcn',      '');
  end

end
