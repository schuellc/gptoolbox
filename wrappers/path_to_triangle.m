function s = path_to_triangle()
  % PATH_TO_TRIANGLE Returns absolute, system-dependent path to triangle
  % executable
  %
  % Outputs:
  %   s  path to triangle as string
  %  
  % See also: triangle

  if ispc
      
    % add your path of triangle.exe here
    paths = {
       'c:/prg/lib/triangle/Release/triangle.exe';
       'D:/libraries/triangle/bin/triangle.exe'
    };
    
    for i=1:size(paths,1)
        if exist(paths{i},'file') == 2
            s = paths{i};
            break;
        end
    end

  elseif ismac
    s = '/opt/local/bin/triangle';
  elseif isunix 
    % I guess this means linux
    s = '/usr/local/bin/triangle';
  end
end

