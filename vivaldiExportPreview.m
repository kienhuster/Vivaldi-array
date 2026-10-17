function vivaldiExportPreview(p, g, options, filename, notes)
    % VIVALDIEXPORTPREVIEW Render in a disposable figure; never mutate the GUI.
    % The cleanup receives only a graphics handle, never a nested GUI callback.
    temporary = figure('Visible', 'off', 'HandleVisibility', 'off');
    cleanup = onCleanup(@()deletePreviewFigure(temporary)); %#ok<NASGU>
    ax = axes('Parent', temporary);
    vivaldiPlotPreview(ax, p, g, options);
    captions = ax.Title.String;
    if ischar(captions)
        captions = {captions};
    end
    title(ax, [captions(:); {char(notes)}], 'Interpreter', 'none', 'FontSize', 10);
    exportgraphics(ax, filename, 'Resolution', 300);
end

function deletePreviewFigure(fig)
    if isgraphics(fig)
        delete(fig);
    end
end
