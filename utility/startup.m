% Custom startup which loads last working directory and workspace
%
% See also: finish

if ispc
	lastworkspace = strcat(getenv('USERPROFILE'),'\AppData\Local\Temp\lastworkspace.mat');
elseif ismac
	lastworkspace = '/var/tmp/lastworkspace.mat';
end

try
  load(lastworkspace);
catch
  disp('Sorry, but I could not load last workspace from:')
  disp(lastworkspace)
end;

if ispref('StartupDirectory','LastWorkingDirectory')
    lwd = getpref('StartupDirectory','LastWorkingDirectory');
    try
        cd(lwd)
    catch
        disp('Sorry, but I could not go to your last working directory:')
        disp(lwd)
    end;
end;
clear lwd;
format short g;
