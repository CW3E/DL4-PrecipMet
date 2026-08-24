function enableDynamicTimeTitleTopTile(fig)
% enableDynamicTimeTitleTopTile sets up dynamic title updates for the top-left tile in a tiledlayout.
% It uses the MarkedClean event to catch zoom, pan, and restore view.
%
% Usage:
%   fig = figure;
%   t = tiledlayout(fig, 2, 1);
%   ax1 = nexttile(t); plot(ax1, X1.Time, X1.Data);
%   ax2 = nexttile(t); plot(ax2, X2.Time, X2.Data);
%   enableDynamicTimeTitleTopTile(fig);

    if nargin < 1 || ~isgraphics(fig, 'figure')
        fig = gcf;
    end

    % Find all axes in the figure that are children of a tiledlayout
    allAxes = findall(fig, 'Type', 'axes');
    layoutAxes = allAxes(arrayfun(@(ax) isa(ax.Parent, 'matlab.graphics.layout.TiledChartLayout'), allAxes));

    if isempty(layoutAxes)
        warning('No axes found in a tiledlayout.');
        return;
    end

    % Sort axes by vertical position to find the top-left one
    positions = arrayfun(@(ax) ax.Position(2), layoutAxes);
    [~, topIdx] = max(positions);
    topAx = layoutAxes(topIdx);

    % Initial title setup
    updateTitle(topAx, topAx.XLim);

    % Clear zoom/pan callbacks to avoid conflict
    zoomObj = zoom(fig);
    panObj = pan(fig);
    set(zoomObj, 'ActionPostCallback', []);
    set(panObj, 'ActionPostCallback', []);

    % Add listener for redraw (catches zoom, pan, restore view)
    addlistener(topAx, 'MarkedClean', @(src, evt) updateTitle(topAx, topAx.XLim));
end

function updateTitle(ax, xLimits)
    % Get the figure name
    fig = ancestor(ax, 'figure');
    figName = fig.Name;

    % Determine time range
    if isa(ax.XAxis, 'matlab.graphics.axis.decorator.DatetimeRuler')
        startTime = xLimits(1);
        endTime   = xLimits(2);
    else
        startTime = datetime(xLimits(1), 'ConvertFrom', 'posixtime');
        endTime   = datetime(xLimits(2), 'ConvertFrom', 'posixtime');
    end

    % Clear default title and any previous custom title lines
    title(ax, '');
    delete(findall(ax, 'Tag', 'CustomTitleLine'));

    % Get y-axis limits for positioning
    yLimits = ax.YLim;
    yTop = yLimits(2);
    yRange = range(yLimits);

    % Estimate number of vertical tiles by grouping axes by Y position
    layout = ax.Parent;
    allAxes = findall(layout, 'Type', 'axes');
    yPositions = arrayfun(@(a) a.Position(2), allAxes);
    uniqueY = unique(round(yPositions, 2));  % round to avoid floating point noise
    numRows = numel(uniqueY);

    % Adjust vertical spacing based on number of rows
    switch numRows
        case 1
            offset1 = 0.06;
            offset2 = 0.02;
        case 2
            offset1 = 0.12;
            offset2 = 0.04;
        case 3
            offset1 = 0.18;
            offset2 = 0.06;
        otherwise
            offset1 = 0.10;
            offset2 = 0.03;
    end

    % Create first line (figure name)
    text(mean(xLimits), yTop + offset1 * yRange, figName, ...
        'Parent', ax, ...
        'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', ...
        'FontSize', 12, ...
        'Tag', 'CustomTitleLine');

    % Create second line (time range)
    timeStr = sprintf('%s to %s', ...
        datestr(startTime, 'mmm dd yyyy'), ...
        datestr(endTime, 'mmm dd yyyy'));

    text(mean(xLimits), yTop + offset2 * yRange, timeStr, ...
        'Parent', ax, ...
        'HorizontalAlignment', 'center', ...
        'FontSize', 9, ...
        'Tag', 'CustomTitleLine');
end
