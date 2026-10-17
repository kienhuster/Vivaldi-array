function fig = Vivaldi_Element_Designer(varargin)
    % VIVALDI_ELEMENT_DESIGNER Offline single-element designer + safe HFSS bridge.
    % MATLAB R2020b+ recommended. Base MATLAB only; Windows for HFSS automation.
    parser = inputParser;
    addParameter(parser, 'Visible', 'on');
    parse(parser, varargin{:});
    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'SingleElementBuilder'));
    [p, meta] = vivaldiDefaultParams();
    original = p;
    logger = vivaldiLogger();
    fields = struct();
    sliders = struct();
    job = [];
    monitor = [];
    lastJobLog = '';
    copyPath = '';
    copyParams = [];
    copySource = '';
    jobBridge = 'legacy';
    lastTarget = [];
    sourceInfo = [];
    jobParams = [];
    jobSource = '';
    busyButtons = gobjects(0);
    outDir = fullfile(tempdir, 'VivaldiElementDesigner');
    if ~isfolder(outDir)
        mkdir(outDir);
    end
    fig = uifigure('Name', 'Vivaldi Element Designer Pro', 'Position', [60 60 1380 850], ...
                   'Color', [.96 .97 .99], 'CloseRequestFcn', @closeApp, 'Visible', 'off');
    shell = uigridlayout(fig, [2 1]);
    shell.RowHeight = {'1x', 34};
    tabs = uitabgroup(shell);
    status = uilabel(shell, 'Text', 'Offline — Not Simulated', 'FontWeight', 'bold');
    designTab = uitab(tabs, 'Title', '1 · Thiết kế hình học');
    targetTab = uitab(tabs, 'Title', '2 · Target Antenna Length');
    hfssTab = uitab(tabs, 'Title', '3 · HFSS Integration');
    exportTab = uitab(tabs, 'Title', '4 · Manufacturing & Export');
    logTab = uitab(tabs, 'Title', '5 · Log & Diagnostics');

    layout = uigridlayout(designTab, [1 3]);
    layout.ColumnWidth = {370, '1x', 280};
    left = uigridlayout(layout, [3 1]);
    left.RowHeight = {42, '1x', 75};
    uilabel(left, 'Text', 'MỘT phần tử dual-polarized · mm / độ', 'FontWeight', 'bold');
    groups = uitabgroup(left);
    groupNames = {'Flare & Aperture', 'Slot & Transition', 'Cavity & Feed', 'Coaxial Structure', 'Advanced Parameters'};
    for j = 1:numel(groupNames)
        tab = uitab(groups, 'Title', groupNames{j});
        ids = find(strcmp({meta.group}, groupNames{j}));
        grid = uigridlayout(tab, [numel(ids) * 2 + 1 4]);
        grid.ColumnWidth = {90, '1x', 35, 38};
        grid.RowHeight = [repmat({32, 42}, 1, numel(ids)), {'1x'}];
        grid.Scrollable = 'on';
        for k = 1:numel(ids)
            m = meta(ids(k));
            n = m.name;
            row = 2 * k - 1;
            label = uilabel(grid, 'Text', [n ' — ' m.label], 'Tooltip', m.tip, 'FontSize', 11);
            place(label, row, [1 4]);
            fields.(n) = uieditfield(grid, 'numeric', 'Value', p.(n), 'Tooltip', m.tip, ...
                                     'Tag', ['Parameter_' n], ...
                                     'ValueChangedFcn', @(src, ~)changeParam(n, src.Value));
            place(fields.(n), row + 1, 1);
            sliders.(n) = uislider(grid, 'Limits', m.range, 'Value', p.(n), 'MajorTicks', [], ...
                                   'MinorTicks', [], 'Tooltip', 'Miền slider chỉ để thao tác; ô số có thể mở rộng miền.', ...
                                   'ValueChangedFcn', @(src, ~)changeParam(n, src.Value));
            place(sliders.(n), row + 1, 2);
            unit = uilabel(grid, 'Text', m.unit);
            place(unit, row + 1, 3);
            button = uibutton(grid, 'Text', '↺', 'Tooltip', 'Phục hồi riêng biến này', ...
                              'ButtonPushedFcn', @(~, ~)changeParam(n, original.(n)));
            place(button, row + 1, 4);
        end
    end
    parameterActions = uigridlayout(left, [1 2]);
    uibutton(parameterActions, 'Text', 'Restore Original Parameters', 'ButtonPushedFcn', @restoreAll);
    uibutton(parameterActions, 'Text', 'Calculate', 'Tag', 'CalculateDimensions', 'ButtonPushedFcn', @calculateDimensions);
    center = uigridlayout(layout, [3 1]);
    center.RowHeight = {40, '1x', 85};
    views = uigridlayout(center, [1 4]);
    views.ColumnWidth = {'1x', 70, 70, 70};
    ax = uiaxes(center);
    axtoolbar(ax, {'zoomin', 'zoomout', 'pan', 'rotate', 'restoreview'});
    viewChoice = uidropdown(views, 'Items', {'Top View', 'Side View', '3D View'}, 'ValueChangedFcn', @(~, ~)refresh());
    uibutton(views, 'Text', 'Zoom', 'ButtonPushedFcn', @(~, ~)set(ax, 'Interactions', zoomInteraction));
    uibutton(views, 'Text', 'Pan', 'ButtonPushedFcn', @(~, ~)set(ax, 'Interactions', panInteraction));
    uibutton(views, 'Text', 'Rotate', 'ButtonPushedFcn', @(~, ~)set(ax, 'Interactions', rotateInteraction));
    layers = uigridlayout(center, [2 3]);
    layerControls = struct();
    layerNames = {'flare', 'feed', 'coax', 'polarization2', 'dimensions', 'envelope'};
    layerLabels = {'Flare', 'Cavity & Feed', 'Coax', 'Phân cực 2', 'Đường đo', 'Bao danh nghĩa'};
    for k = 1:numel(layerNames)
        layerControls.(layerNames{k}) = uicheckbox(layers, 'Text', layerLabels{k}, 'Value', true, 'ValueChangedFcn', @(~, ~)refresh());
    end
    right = uigridlayout(layout, [5 1]);
    right.RowHeight = {32, 245, '1x', 42, 42};
    uilabel(right, 'Text', 'Kích thước & thay đổi', 'FontWeight', 'bold');
    dimensions = uitable(right, 'ColumnName', {'Biến', 'Giá trị', 'Đơn vị'}, 'ColumnWidth', {110, 95, 50}, 'RowName', {});
    changeSummary = uitextarea(right, 'Editable', 'off');
    uibutton(right, 'Text', 'Save Configuration (.json)', 'ButtonPushedFcn', @saveConfiguration);
    uibutton(right, 'Text', 'Load Configuration (.json)', 'ButtonPushedFcn', @loadConfiguration);

    tg = uigridlayout(targetTab, [7 2]);
    tg.RowHeight = {45, 45, 45, 45, 45, '1x', 60};
    tg.ColumnWidth = {310, '1x'};
    uilabel(tg, 'Text', 'Chiều dài mục tiêu L_patch (mm)');
    target = uieditfield(tg, 'numeric', 'Value', 49, 'Tag', 'TargetLength');
    uilabel(tg, 'Text', 'Giới hạn tìm L_flare_1 dưới (mm)');
    lowerBound = uieditfield(tg, 'numeric', 'Value', .001);
    uilabel(tg, 'Text', 'Giới hạn tìm L_flare_1 trên (mm)');
    upperBound = uieditfield(tg, 'numeric', 'Value', 200);
    uilabel(tg, 'Text', 'Chỉ đổi L_flare_1, giữ nguyên các biến khác.');
    uibutton(tg, 'Text', 'Calculate Dimensions', 'Tag', 'CalculateTarget', 'ButtonPushedFcn', @calculateTarget);
    uilabel(tg, 'Text', '49 / 50 mm phải được giải lại hình học.');
    targetMessage = uilabel(tg, 'Text', 'Chưa tính mục tiêu.');
    comparisonTable = uitable(tg, 'ColumnName', {'Biến', 'Before', 'After', 'Đơn vị'}, 'RowName', {});
    place(comparisonTable, 6, [1 2]);
    note = uilabel(tg, 'Text', 'Miền tìm nghiệm do người dùng chọn; nghiệm đại số vẫn cần kiểm tra CAD và mô phỏng.', 'WordWrap', 'on');
    place(note, 7, [1 2]);

    hg = uigridlayout(hfssTab, [11 3]);
    hg.ColumnWidth = {240, '1x', 170};
    hg.RowHeight = {40, 40, 40, 40, 40, 40, 45, 45, '1x', 32, 32};
    uilabel(hg, 'Text', 'Dự án HFSS đầu vào (.aedt)');
    inputField = uieditfield(hg, 'text');
    uibutton(hg, 'Text', 'Chọn HFSS…', 'ButtonPushedFcn', @chooseProject);
    uilabel(hg, 'Text', 'Design đã kiểm tra');
    designChoice = uidropdown(hg, 'Items', {'Chưa chọn'});
    uibutton(hg, 'Text', 'Inspect Project', 'ButtonPushedFcn', @inspectSelected);
    uilabel(hg, 'Text', 'Ansys executable');
    exeField = uieditfield(hg, 'text', 'Tag', 'HFSSExecutable');
    uibutton(hg, 'Text', 'Chọn ansysedt.exe…', 'ButtonPushedFcn', @chooseExe);
    uilabel(hg, 'Text', 'Thư mục kết quả');
    outputField = uieditfield(hg, 'text', 'Value', outDir);
    uibutton(hg, 'Text', 'Chọn thư mục…', 'ButtonPushedFcn', @chooseOutput);
    uilabel(hg, 'Text', 'Tên file mới (không ghi đè)');
    nameField = uieditfield(hg, 'text', 'Value', 'Vivaldi_element_custom.aedt');
    uibutton(hg, 'Text', 'Auto-detect Ansys', 'ButtonPushedFcn', @detectAnsys);
    unknownAcknowledged = uicheckbox(hg, 'Text', 'Tôi đã kiểm tra CAD/biến của file khác bản tham chiếu 17/10; preview chỉ là sơ đồ toán học.');
    place(unknownAcknowledged, 6, [1 3]);
    commands = uigridlayout(hg, [1 4]);
    place(commands, 7, [1 3]);
    busyButtons(end + 1) = uibutton(commands, 'Text', 'Build Antenna', 'Tag', 'BuildAntenna', 'ButtonPushedFcn', @buildAntenna);
    busyButtons(end + 1) = uibutton(commands, 'Text', 'Connect HFSS', 'ButtonPushedFcn', @(~, ~)hfssAction('connect', true));
    busyButtons(end + 1) = uibutton(commands, 'Text', 'Update Geometry (Save As)', 'ButtonPushedFcn', @(~, ~)hfssAction('update', true));
    busyButtons(end + 1) = uibutton(commands, 'Text', 'Generate Update Script', 'ButtonPushedFcn', @(~, ~)hfssAction('update', false));
    commands2 = uigridlayout(hg, [1 3]);
    place(commands2, 8, [1 3]);
    busyButtons(end + 1) = uibutton(commands2, 'Text', 'Validate Model', 'ButtonPushedFcn', @(~, ~)hfssAction('validate', true));
    busyButtons(end + 1) = uibutton(commands2, 'Text', 'Run Simulation…', 'ButtonPushedFcn', @(~, ~)hfssAction('simulate', true));
    uibutton(commands2, 'Text', 'Import Results CSV…', 'ButtonPushedFcn', @importResults);
    hfssInfo = uitextarea(hg, 'Editable', 'off', 'Value', {'Offline — Not Simulated. Chọn file và Inspect trước khi cập nhật.'});
    place(hfssInfo, 9, [1 3]);
    hfssState = uilabel(hg, 'Text', 'Không có tác vụ HFSS.', 'WordWrap', 'on');
    place(hfssState, 10, [1 3]);
    hint = uilabel(hg, 'Text', 'Validation API trả về mã thô; cần đọc báo cáo. Không tự mô phỏng khi đổi kích thước.', 'FontSize', 11);
    place(hint, 11, [1 3]);

    eg = uigridlayout(exportTab, [8 2]);
    eg.ColumnWidth = {350, '1x'};
    eg.RowHeight = {40, 40, 40, 50, 45, 45, 45, '1x'};
    uilabel(eg, 'Text', 'Vật liệu nhà gia công xác nhận');
    materialField = uieditfield(eg, 'text', 'Value', 'aluminum (tham chiếu HFSS; xác nhận với nhà gia công)');
    uilabel(eg, 'Text', 'Dung sai tuyến tính ± (mm)');
    tolerance = uieditfield(eg, 'numeric', 'Value', .05, 'Limits', [0 Inf], 'ValueChangedFcn', @(~, ~)refresh());
    uilabel(eg, 'Text', 'Khe tối thiểu nhà gia công cam kết (mm)');
    minGap = uieditfield(eg, 'numeric', 'Value', .2, 'Limits', [0 Inf], 'ValueChangedFcn', @(~, ~)refresh());
    uilabel(eg, 'Text', 'Ảnh xuất là sơ đồ có chú thích, không phải đường cắt.', 'WordWrap', 'on');
    manufacturing = uilabel(eg, 'Text', '', 'WordWrap', 'on');
    uibutton(eg, 'Text', 'Export Dimensions CSV', 'ButtonPushedFcn', @exportCSV);
    uibutton(eg, 'Text', 'Export Preview PNG', 'ButtonPushedFcn', @(~, ~)exportPicture('png'));
    uibutton(eg, 'Text', 'Export Preview PDF', 'ButtonPushedFcn', @(~, ~)exportPicture('pdf'));
    noDXF = uilabel(eg, 'Text', 'DXF chưa khả dụng: cần đường bao CAD chính xác từ HFSS.', 'WordWrap', 'on');
    place(noDXF, 6, 2);
    resultTitle = uilabel(eg, 'Text', 'Not Simulated — chưa có dữ liệu thực.');
    place(resultTitle, 7, [1 2]);
    resultAxes = uiaxes(eg);
    place(resultAxes, 8, [1 2]);
    title(resultAxes, 'Not Simulated');

    lg = uigridlayout(logTab, [2 3]);
    lg.RowHeight = {'1x', 42};
    logArea = uitextarea(lg, 'Editable', 'off');
    place(logArea, 1, [1 3]);
    uibutton(lg, 'Text', 'Export Log (.json)', 'ButtonPushedFcn', @exportLog);
    uibutton(lg, 'Text', 'Copy Error', 'ButtonPushedFcn', @(~, ~)clipboard('copy', logger.LastError));
    uibutton(lg, 'Text', 'Refresh Log', 'ButtonPushedFcn', @(~, ~)refreshLog());

    reference = fullfile(root, 'SingleElementBuilder', 'reference', '17_10_2026_vivaldi.aedt');
    inputField.Value = reference;
    detected = HFSSRuntimeSupport.findExecutables([], false);
    if ~isempty(detected)
        exeField.Value = detected{1};
    end
    logger.add('APP_OPEN', struct('params', p, 'platform', computer, 'preview', 'source operand diagram only'));
    refresh();
    inspectSelected();
    fig.Visible = parser.Results.Visible;

    function place(control, row, column)
        control.Layout.Row = row;
        control.Layout.Column = column;
    end

    function changeParam(n, value)
        before = p;
        p.(n) = value;
        logger.add('PARAMETER_CHANGE', struct('variable', n, 'before', before, 'after', p));
        refresh();
    end

    function restoreAll(~, ~)
        before = p;
        p = original;
        lastTarget = [];
        logger.add('RESTORE', struct('before', before, 'after', p));
        refresh();
    end

    function refresh()
        if ~isvalid(fig)
            return
        end
        for i = 1:numel(meta)
            n = meta(i).name;
            value = p.(n);
            if isfinite(value) && isreal(value)
                fields.(n).Value = value;
                lim = meta(i).range;
                % Numeric entry may expand a convenience slider domain.
                lim = [min(lim(1), value) max(lim(2), value)];
                sliders.(n).Limits = lim;
                sliders.(n).Value = value;
            end
        end
        [valid, errors, warnings, g] = vivaldiValidateParams(p);
        fig.UserData = struct('parameters', p, 'geometry', g, 'valid', valid);
        for i = 1:numel(meta)
            if valid
                fields.(meta(i).name).BackgroundColor = [1 1 1];
            else
                fields.(meta(i).name).BackgroundColor = [1 .9 .9];
            end
        end
        if ~valid
            status.Text = ['Tham số không hợp lệ: ' strjoin(errors, ' | ')];
            status.FontColor = [.8 .12 .1];
            dimensions.Data = {};
            changeSummary.Value = errors;
            cla(ax);
            title(ax, 'Tham số không hợp lệ — cập nhật HFSS/export bị chặn.');
            manufacturing.Text = 'Không xuất kích thước khi tham số không hợp lệ.';
            refreshLog();
            return
        end
        options = struct('view', viewChoice.Value);
        for i = 1:numel(layerNames)
            options.(layerNames{i}) = layerControls.(layerNames{i}).Value;
        end
        try
            vivaldiPlotPreview(ax, p, g, options);
        catch err
            cla(ax);
            title(ax, 'Preview unavailable — see diagnostics');
            logger.add('PREVIEW_ERROR', struct('identifier', err.identifier, 'message', err.message));
        end
        names = {'L_patch', 'L_flare', 'aperture_w', 'r_flare', 'x_feed', 'z_feed', 'slot_t_L', 'h_cabin', 'de_L', 'de_W'};
        rows = cell(numel(names), 3);
        for i = 1:numel(names)
            unit = 'mm';
            if strcmp(names{i}, 'r_flare')
                unit = '1/mm';
            end
            rows(i, :) = {names{i}, sprintf('%.7f', g.(names{i})), unit};
        end
        dimensions.Data = rows;
        summary = {};
        for i = 1:numel(meta)
            n = meta(i).name;
            if p.(n) ~= original.(n)
                summary{end + 1} = sprintf('%s: %.7g → %.7g %s', n, original.(n), p.(n), meta(i).unit); %#ok<AGROW>
            end
        end
        if isempty(summary)
            summary = {'Tham số tham chiếu nguyên gốc.'};
        end
        summary = [summary warnings];
        changeSummary.Value = summary;
        status.Text = sprintf('Offline hình học · L_patch %.7f mm · RF: xem dữ liệu thực/HFSS', g.L_patch);
        status.FontColor = [.12 .4 .3];
        small = min([p.slot_feed_w p.cavity_w]);
        worst = small - 2 * tolerance.Value;
        targetText = 'Chưa đặt chiều dài mục tiêu.';
        if ~isempty(lastTarget)
            targetText = sprintf('Sai lệch mục tiêu %.7f mm.', g.L_patch - lastTarget);
        end
        manufacturing.Text = sprintf('Khe danh nghĩa tối thiểu trong slot/cavity: %.4f mm; bảo thủ sau ± dung sai mỗi mép: %.4f mm. %s', small, worst, targetText);
        if worst < minGap.Value
            manufacturing.FontColor = [.8 .15 .1];
        else
            manufacturing.FontColor = [.2 .3 .4];
        end
        refreshLog();
    end

    function refreshLog()
        if isvalid(logArea)
            logArea.Value = logger.lines();
        end
    end

    function fail(err)
        if ~isvalid(fig)
            return
        end
        logger.add('ERROR', struct('identifier', err.identifier, 'message', err.message, 'project', inputField.Value));
        status.Text = err.message;
        status.FontColor = [.8 .1 .1];
        refreshLog();
        if isvalid(fig) && strcmp(fig.Visible, 'on')
            uialert(fig, err.message, 'Lỗi / phần chưa kiểm chứng');
        end
    end

    function assertValid()
        [valid, errors] = vivaldiValidateParams(p);
        assert(valid, 'Vivaldi:InvalidParameters', '%s', strjoin(errors, newline));
    end

    function calculateTarget(~, ~)
        try
            before = p;
            [p, c] = vivaldiSolveTargetLength(p, target.Value, [lowerBound.Value upperBound.Value]);
            lastTarget = target.Value;
            names = {'L_flare_1', 'L_patch', 'L_flare', 'r_flare', 'x_feed', 'z_feed'};
            rows = cell(numel(names), 4);
            for i = 1:numel(names)
                n = names{i};
                unit = 'mm';
                if strcmp(n, 'r_flare')
                    unit = '1/mm';
                end
                if strcmp(n, 'L_flare_1')
                    a = before.(n);
                    b = p.(n);
                else
                    a = c.before.(n);
                    b = c.after.(n);
                end
                rows(i, :) = {n, a, b, unit};
            end
            comparisonTable.Data = rows;
            targetMessage.Text = sprintf('Đã áp dụng; sai số %.9g mm.', c.residual);
            logger.add('TARGET_SOLVED', c);
            refresh();
        catch err
            fail(err);
        end
    end

    function calculateDimensions(~, ~)
        try
            assertValid();
            refresh();
        catch err
            fail(err);
        end
    end

    function buildAntenna(~, ~)
        try
            assertValid();
            assert(isempty(monitor), 'Vivaldi:Busy', 'An HFSS job is already monitored.');
            assert(isfile(reference), 'Vivaldi:MissingReference', 'Thiếu 17_10_2026_vivaldi.aedt; không dùng thiết kế thay thế.');
            exe = HFSSRuntimeSupport.resolveExecutable(exeField.Value);
            exeField.Value = exe;
            assert(ispc, 'Vivaldi:HFSSUnavailable', 'Build Antenna requires Windows. Generate Update Script remains available offline.');
            builderParams = vivaldiBuilderDefaultParams();
            names = fieldnames(p);
            for ii = 1:numel(names)
                builderParams.(names{ii}) = p.(names{ii});
            end
            [~, projectName] = fileparts(nameField.Value);
            cfg = struct('projectName', projectName, 'designName', 'dual_pol_vivaldi_patch_Wflare_20', ...
                         'outputDir', outputField.Value, 'sourcePath', '', 'version', '2021.2');
            generated = HFSSAutomationBridge('generate', 'build', cfg, builderParams);
            job = HFSSAutomationBridge('launch', generated, exe);
            jobBridge = 'builder';
            jobParams = p;
            jobSource = inputField.Value;
            lastJobLog = '';
            set(busyButtons, 'Enable', 'off');
            hfssState.Text = 'Build launched — waiting for actual HFSS validation and saved model.';
            monitor = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, 'BusyMode', 'drop', 'TimerFcn', @pollHFSS);
            start(monitor);
        catch err
            fail(err);
        end
    end

    function saveConfiguration(~, ~)
        try
            assertValid();
            [file, folder] = uiputfile('*.json', 'Lưu cấu hình');
            if isequal(file, 0)
                return
            end
            vivaldiSaveConfig('save', fullfile(folder, file), p);
            logger.add('CONFIG_SAVED', struct('path', fullfile(folder, file), 'params', p));
            refreshLog();
        catch err
            fail(err);
        end
    end

    function loadConfiguration(~, ~)
        try
            [file, folder] = uigetfile('*.json', 'Mở cấu hình');
            if isequal(file, 0)
                return
            end
            before = p;
            loaded = vivaldiSaveConfig('load', fullfile(folder, file));
            p = loaded;
            lastTarget = [];
            logger.add('CONFIG_LOADED', struct('path', fullfile(folder, file), 'before', before, 'after', p));
            refresh();
        catch err
            fail(err);
        end
    end

    function chooseProject(~, ~)
        [file, folder] = uigetfile('*.aedt', 'Chọn HFSS (bản mới được kiểm tra riêng)');
        if isequal(file, 0)
            return
        end
        inputField.Value = fullfile(folder, file);
        unknownAcknowledged.Value = false;
        sourceInfo = [];
        inspectSelected();
    end

    function inspectSelected(varargin)
        try
            info = vivaldiInspectProject(inputField.Value);
            sourceInfo = info;
            designChoice.Items = info.designs;
            desired = 'dual_pol_vivaldi_patch_Wflare_20';
            if ismember(desired, info.designs)
                designChoice.Value = desired;
            else
                designChoice.Value = info.designs{1};
            end
            rows = {['File: ' info.path], ['Phiên bản: ' info.version], ...
                    'Variables (preview chỉ dùng công thức tham chiếu, không tự eval tệp):'};
            for i = 1:size(info.variables, 1)
                rows{end + 1} = [info.variables{i, 1} ' = ' info.variables{i, 2}];
            end %#ok<AGROW>
            rows{end + 1} = 'Đối tượng nguồn (top-level/operand):';
            for i = 1:numel(info.parts)
                v = info.parts{i};
                rows{end + 1} = [v.section ': ' v.name ' ' v.material]; %#ok<AGROW>
            end
            for i = 1:numel(info.boundaries)
                v = info.boundaries{i};
                rows{end + 1} = ['Boundary ' v.name ': ' v.type]; %#ok<AGROW>
            end
            rows{end + 1} = 'Integration lines gắn entity: phải kiểm tra hướng trong HFSS; tọa độ 0 trong text không phải vị trí toàn cục.';
            hfssInfo.Value = rows;
            logger.add('PROJECT_INSPECTED', struct('path', info.path, 'designs', {info.designs}, 'version', info.version));
            refreshLog();
        catch err
            sourceInfo = [];
            fail(err);
        end
    end

    function chooseExe(~, ~)
        [file, folder] = uigetfile('*.exe', 'Chọn ansysedt.exe');
        if ~isequal(file, 0)
            exeField.Value = fullfile(folder, file);
        end
    end

    function chooseOutput(~, ~)
        folder = uigetdir(outputField.Value, 'Thư mục kết quả');
        if ~isequal(folder, 0)
            outputField.Value = folder;
        end
    end

    function detectAnsys(~, ~)
        try
            paths = vivaldiHFSSBridge('detect');
            if isempty(paths)
                error('Vivaldi:HFSSUnavailable', 'Không phát hiện Ansys trên Windows. Chọn executable thủ công; offline vẫn hoạt động.');
            end
            [idx, ok] = listdlg('ListString', paths, 'SelectionMode', 'single', 'PromptString', 'Chọn bản Ansys');
            if ok
                exeField.Value = paths{idx};
            end
        catch err
            fail(err);
        end
    end

    function hfssAction(mode, launch)
        try
            assertValid();
            assert(isempty(monitor), 'Vivaldi:Busy', 'Đang theo dõi một tác vụ HFSS.');
            cfg = struct('input', inputField.Value, 'outputDir', outputField.Value, ...
                         'outputName', nameField.Value, 'design', designChoice.Value, 'original', inputField.Value);
            if ~strcmp(mode, 'connect')
                assert(~isempty(sourceInfo) && strcmp(sourceInfo.path, inputField.Value), ...
                       'Vivaldi:InspectRequired', 'Inspect Project trước khi thao tác.');
            end
            if strcmp(mode, 'update')
                currentText = fileread(inputField.Value);
                assert(strcmp(currentText, sourceInfo.source), 'Vivaldi:ProjectChanged', 'Dự án đã thay đổi sau Inspect; kiểm tra lại.');
                if ~strcmp(currentText, fileread(reference))
                    assert(unknownAcknowledged.Value, 'Vivaldi:NewModelReview', ...
                           'File khác bản tham chiếu. Kiểm tra hình học/biến trong HFSS và đánh dấu xác nhận; không giả định hai phiên bản giống nhau.');
                end
            elseif ismember(mode, {'validate', 'simulate'})
                assert(~isempty(copyPath) && isequal(copyParams, p) && strcmp(copySource, inputField.Value), ...
                       'Vivaldi:CopyRequired', 'Cần Update Geometry thành công cho đúng tham số hiện tại trước.');
                cfg.input = copyPath;
            end
            if strcmp(mode, 'simulate')
                answer = uiconfirm(fig, 'Chạy Setup1 trên bản sao? Có thể mất nhiều thời gian và dùng license HFSS.', ...
                                   'Xác nhận mô phỏng', 'Options', {'Chạy', 'Hủy'}, 'DefaultOption', 2, 'CancelOption', 2);
                if ~strcmp(answer, 'Chạy')
                    return
                end
            end
            generated = vivaldiHFSSBridge('generate', mode, cfg, p);
            logger.add('SCRIPT_GENERATED', struct('mode', mode, 'script', generated.script, 'input', cfg.input, 'output', generated.output, 'params', p));
            hfssState.Text = ['Đã tạo script: ' generated.script];
            refreshLog();
            if ~launch
                return
            end
            job = vivaldiHFSSBridge('launch', generated, exeField.Value);
            job.started = tic;
            jobBridge = 'legacy';
            jobParams = p;
            jobSource = inputField.Value;
            lastJobLog = '';
            logger.add('HFSS_LAUNCHED', struct('mode', mode, 'script', job.script, 'console', job.console));
            set(busyButtons, 'Enable', 'off');
            hfssState.Text = 'Đã khởi động tiến trình HFSS; chưa xác nhận kết nối/kết quả.';
            monitor = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, 'BusyMode', 'drop', 'TimerFcn', @pollHFSS);
            start(monitor);
            refreshLog();
        catch err
            fail(err);
        end
    end

    function pollHFSS(~, ~)
        if ~isvalid(fig)
            return
        end
        try
            if strcmp(jobBridge, 'builder')
                s = HFSSAutomationBridge('poll', job);
                elapsed = s.elapsedSeconds;
                mode = job.action;
            else
                s = vivaldiHFSSBridge('poll', job);
                elapsed = toc(job.started);
                mode = job.mode;
            end
            if ~strcmp(s.log, lastJobLog)
                logger.add('HFSS_STATUS', struct('state', s.state, 'mode', mode, 'raw', s.log));
                lastJobLog = s.log;
                hfssInfo.Value = regexp(s.log, '\r?\n', 'split');
                refreshLog();
            end
            hfssState.Text = sprintf('HFSS: %s · %.0f s · chi tiết trong Log & Diagnostics.', s.state, elapsed);
            if elapsed > 120 && ismember(s.state, {'LAUNCHED', 'STARTING'})
                hfssState.Text = ['Chưa xác nhận kết nối HFSS sau 120 s. Kiểm tra license/dialog, script và console log; tiến trình có thể vẫn chạy.'];
            end
            if s.terminal
                if strcmp(s.state, 'TIMED_OUT')
                    hfssState.Text = 'Timed out — HFSS may still be running. Monitoring continues; no duplicate job.';
                    return
                end
                stop(monitor);
                delete(monitor);
                monitor = [];
                set(busyButtons, 'Enable', 'on');
                if ismember(s.state, {'UPDATED', 'BUILT'})
                    copyPath = job.output;
                    copyParams = jobParams;
                    copySource = jobSource;
                    logger.add('COPY_SAVED', struct('path', copyPath, 'params', copyParams));
                elseif strcmp(s.state, 'FAILED')
                    logger.add('ERROR', struct('message', s.log, 'script', job.script, 'console', job.console));
                end
                refreshLog();
            end
        catch err
            % A status file can be momentarily busy while HFSS writes it.
            logger.add('POLL_DIAGNOSTIC', struct('message', err.message));
            refreshLog();
        end
    end

    function importResults(~, ~)
        try
            [file, folder] = uigetfile('*.csv', 'Nạp CSV thực đã xuất HFSS');
            if isequal(file, 0)
                return
            end
            path = fullfile(folder, file);
            info = vivaldiLoadResults(path);
            [xi, ok] = listdlg('ListString', info.columns, 'SelectionMode', 'single', 'PromptString', 'Chọn X: Freq [GHz] hoặc Theta/Phi [deg]');
            if ~ok
                return
            end
            [yi, ok] = listdlg('ListString', info.columns, 'SelectionMode', 'multiple', 'PromptString', 'Chọn Y: S11/S22/S21 dB, Gain hoặc Pattern (đúng đơn vị header)');
            if ~ok
                return
            end
            assert(~ismember(xi, yi), 'Vivaldi:ResultColumns', 'Không chọn cùng cột cho X và Y.');
            r = vivaldiLoadResults(path, info.columns{xi}, info.columns(yi));
            cla(resultAxes);
            plot(resultAxes, r.x, r.y, 'LineWidth', 1.5);
            grid(resultAxes, 'on');
            xlabel(resultAxes, r.xLabel, 'Interpreter', 'none');
            ylabel(resultAxes, 'Giá trị theo header CSV');
            legend(resultAxes, r.labels, 'Interpreter', 'none', 'Location', 'best');
            title(resultAxes, file, 'Interpreter', 'none');
            resultTitle.Text = ['Dữ liệu thực từ ' file ' — chưa xác nhận thuộc cấu hình GUI hiện tại; đơn vị theo header.'];
            logger.add('RESULTS_IMPORTED', struct('path', path, 'x', r.xLabel, 'y', {r.labels}, 'rows', height(r.table)));
            tabs.SelectedTab = exportTab;
            refreshLog();
        catch err
            fail(err);
        end
    end

    function exportCSV(~, ~)
        try
            assertValid();
            [file, folder] = uiputfile('*.csv', 'Bảng kích thước danh nghĩa');
            if isequal(file, 0)
                return
            end
            path = fullfile(folder, file);
            g = vivaldiCalculateGeometry(p);
            vivaldiExportDimensions(p, g, path, tolerance.Value);
            % Separate context sidecar records manufacturing assumptions.
            context = struct('materialUserProvided', materialField.Value, 'thickness_mm', p.thickness, ...
                             'tolerance_mm', tolerance.Value, 'fabricatorMinGap_mm', minGap.Value, ...
                             'target_mm', lastTarget, 'previewOnly', true, 'scope', 'Nominal values; not a verified cutting drawing');
            fid = fopen([path '.notes.json'], 'w', 'n', 'UTF-8');
            assert(fid >= 0, 'Vivaldi:ExportWrite', 'Không ghi được ghi chú.');
            c = onCleanup(@()fclose(fid));
            fprintf(fid, '%s', jsonencode(context)); %#ok<NASGU>
            logger.add('DIMENSIONS_EXPORTED', struct('path', path, 'context', context));
            refreshLog();
        catch err
            fail(err);
        end
    end

    function exportPicture(ext)
        try
            assertValid();
            [file, folder] = uiputfile(['*.' ext], 'Xuất sơ đồ preview có chú thích');
            if isequal(file, 0)
                return
            end
            path = fullfile(folder, file);
            options = struct('view', viewChoice.Value, 'dimensions', true);
            for i = 1:numel(layerNames)
                if ~strcmp(layerNames{i}, 'dimensions')
                    options.(layerNames{i}) = layerControls.(layerNames{i}).Value;
                end
            end
            notes = sprintf('%s | thickness %.4g mm | dung sai yêu cầu ±%.4g mm', ...
                            materialField.Value, p.thickness, tolerance.Value);
            vivaldiExportPreview(p, vivaldiCalculateGeometry(p), options, path, notes);
            logger.add('PREVIEW_EXPORTED', struct('path', path, 'previewOnly', true));
            refreshLog();
        catch err
            fail(err);
        end
    end

    function exportLog(~, ~)
        try
            [file, folder] = uiputfile('*.json', 'Xuất nhật ký');
            if isequal(file, 0)
                return
            end
            logger.export(fullfile(folder, file));
        catch err
            fail(err);
        end
    end

    function closeApp(~, ~)
        if ~isempty(monitor)
            answer = uiconfirm(fig, 'HFSS vẫn chạy độc lập. Đóng GUI sẽ dừng theo dõi; tiến trình HFSS và status log vẫn tiếp tục.', ...
                               'Đóng ứng dụng', 'Options', {'Đóng', 'Tiếp tục theo dõi'}, 'DefaultOption', 2, 'CancelOption', 2);
            if ~strcmp(answer, 'Đóng')
                return
            end
            stop(monitor);
            delete(monitor);
        end
        delete(fig);
    end

end
