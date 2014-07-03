% Custom finish.m which is called on `quit`, saves history and current
% workspace.
%
% See also: startup.m

% Use preferences
% [instead](http://www.mathworks.ch/ch/help/matlab/matlab_env/exit-matlab-.html#bs6j5on-4)
% Preferences > MATLAB > General > Confirmation Dialogs > Confirm before
% exiting MATLAB
%
% if usejava('desktop')
%   button = questdlg('Are you sure you want to quit?', 'Exit Dialog','Cancel','Quit','Cancel');
%   
%   if strcmp(button,'Cancel') || strcmp(button,'')
%     quit cancel;
%     return
%   end
% end

if ispc
	lastworkspace = strcat(getenv('USERPROFILE'),'\AppData\Local\Temp\lastworkspace.mat');
elseif ismac
	lastworkspace = '/var/tmp/lastworkspace.mat';
end
disp(['Saving workspace data to ' lastworkspace]);
save(lastworkspace);

setpref('StartupDirectory','LastWorkingDirectory',pwd) 

% try 
%     preserve_history; 
% catch EM 
%     h=msgbox(EM.message,sprintf('Error: %s',EM.identifier),'error'); 
%     uiwait(h); 
%     return 
% end

