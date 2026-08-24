%% plotPrecipMet

function X = plotPrecipMet(var1, var2)
% Plot data from a DL4-Met Hydroclimate Station
% PLOT_DL4_V2(FILENAME,NPRINT) plots the DL4 data structure saved
%    as a .mat or .csa file. CSA is a text file format.
%    NPRINT sets print option:
%       0 will not print or save figures
%       1 will save figure as a pdf file
%       2 will save figure 
%
% PLOTPRECIPMET(X,NPRINT) plots the DL4 data contained in structure X 
%
% PLOTPRECIPMET is interactive
%    User is prompted for data file to load.  NPRINT is
%    set to its default value
%
%    NPRINT is optional, default value is 0
%
% Requires: loadcsv.m
%           customDataTip.m
%           enableDynamicTimeTitle.m
%
% 
% Revisions:
%
% 5 Dec 2025 - Douglas Alden
% modified from plot_dl4.m

nprint = 0;
set(0, 'DefaultLineLineWidth', 2);
set(0,'defaultAxesXGrid','on');
set(0,'defaultAxesYGrid','on');

%% Read file to plot

% Handle input options = no arguments, thus interactive mode
if nargin==0
    [filename, pathname] = uigetfile( ...
        { '*.csa; *.csv; *.mat' }, ...
        'PLOTPRECIPMET: Select CSV-file, MAT-file to plot');   
    if isequal(filename,0)
       disp('File selection cancelled by user')
       return;
    else
       disp(['File selected ', fullfile(pathname, filename)])
    end
    
    if regexp(filename,'csv') % user selected CSV-file
        X = loadcsv(filename);
    else  % user selected MAT-file
        load(filename);
    end
end

% Handle input options = 1 arguments, load selected file or variable
if nargin==1
    if isstruct(var1)
        X = var1;
    elseif ischar(var1)
        filename = var1;
        if regexp(filename,'csv') % user selected CSV-file
            X = loadcsv(filename);
        else  % user selected MAT-file
            load(filename, X);
        end
    end
end

% Handle input options 2, but first option is empty
if nargin==2
    if isempty(var1)
        [filename, pathname] = uigetfile( ...
            { '*.csa; *.mat' }, ...
            'PLOTPRECIPMET: Select CSV-file or MAT-file to plot');   
        if isequal(filename,0)
            disp('User selected Cancel')
            return
        else
            disp(['File selected: ', fullfile(pathname, filename)])
        end
    
        if regexp(filename,'csv') % user selected CSV-file
            X = loadcsv(filename);
        else  % user selected MAT-file
            load(filename, X);
        end
    elseif isstruct(var1)
        X = var1;
    elseif ischar(var1)
        filename = var1;
        if regexp(filename,'csv') % user selected CSV-file
            X = loadcsv(filename);
        else  % user selected MAT-file
            load(filename, X);
        end
    end
    if ischar(var2)
        nprint = var2;
    end
end

%% Set up plots

% Ensure root units are pixels and get the size of the screen
set(0,'Units','pixels')
scrsz = get(0,'ScreenSize');
taskbar = 40;   % Taskbar height in Windows 7 with large icons

axes_defaults = struct ( 'XMinorTick', 'on', ...
        'YMinorTick','on', ...
        'FontWeight','bold', ...
        'FontSize',12, ...
        'Box','on', ...
        'XGrid','on', ...
        'YGrid','on' );


%% Make Plots

%% Precip and BattV
fig = figure('OuterPosition', ...
    [1 taskbar scrsz(3)/2 scrsz(4)/2], ...
    'Name', 'Precip, BattV', 'NumberTitle', 'off');

tiledlayout(3,1)
precip = nexttile;
set(precip, axes_defaults);

% Precipitation
plot(precip, X.Time, [X.Precip0, X.Precip1]); % cumulative totals
    
xlim(precip, [X.Time(1) X.Time(end)]);
ylabel(precip, { 'Precipitation', 'inches' } );
legend(precip,'Precip0','Precip1', 'Location','EastOutside')
%% 

precipMinute = nexttile;
set(precipMinute, axes_defaults);
p = plot(precipMinute, X.Time, [X.Precip0_Min, X.Precip1_Min]); % minute sums
p(1).Color = 'b'; p(1).LineStyle = "-";
p(2).Color = 'r'; p(2).LineStyle = '-';
ylabel(precipMinute, { 'Precip by Minute', 'inches' } );
legend(precipMinute,'Precip0','Precip1', 'Location','EastOutside')

battV = nexttile;
set(battV, axes_defaults);
p = plot(battV, X.Time, X.BattV);
ylabel(battV, {'Battery', 'Volts'} );
    
% Date formatted tick labels, automatically updated when zoomed or
% panned. Multi-plot figures are linked.
linkaxes([precip precipMinute battV], 'x')
%% 

sensorNames = ["Precip BattV"];


% update the data cursor
dcm = datacursormode(fig);
set(dcm, 'UpdateFcn', {@customDataTip}, 'Enable', 'on');

% enable a dynamic time title 
enableDynamicTimeTitle(fig)

% Save or print figures
if nprint == 3
    last= '.png';
    outfile = strcat(file, '_', sensorNames, last);
    print(fig,outfile,'-dpng','-fillpage');
elseif nprint == 2
    last = '.pdf';
    outfile = strcat(file, '_', sensorNames, last);
    print(fig,outfile,'-dpdf','-fillpage');
elseif nprint == 1
    last= '.fig';
    saveas(fig,outfile,'fig');
end

if (nprint > 0)
    fprintf ('saving %s to %s file\n', sensorNames, last);
else
    fprintf ('Did not save or print figure %s\n', sensorNames);
end

% reset changes to default values
set(0, 'DefaultLineLineWidth', 'factory');
set(0,'defaultAxesXGrid','factory');
set(0,'defaultAxesYGrid','factory');

end
