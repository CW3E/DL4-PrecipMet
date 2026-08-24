function output_txt = customDataTip(~, event_obj)
    try
        hTarget = event_obj.Target;

        % Get data
        xData = get(hTarget, 'XData');
        yData = get(hTarget, 'YData');
        xData = xData(:);
        yData = yData(:);

        % Use DataIndex directly (available in R2024b)
        idx = event_obj.DataIndex;

        % Format X label
        if isdatetime(xData)
            xLabel = datestr(xData(idx), 'dd-mmm-yyyy HH:MM:SS');
        else
            xLabel = num2str(xData(idx));
        end

        % Format output
        output_txt = {
            [xLabel], ...
            ['X Index: ', num2str(idx)], ...
            ['Y: ', num2str(yData(idx))] ...
        };
    catch ME
        output_txt = {'Error in customDataTip:', ME.message};
    end
end
