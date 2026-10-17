function tests = testVivaldiDebug
    % MATLAB regression tests; UI cases explicitly require a MATLAB desktop.
    tests = functiontests(localfunctions);
end

function setupOnce(t)
    t.TestData.oldPath = path;
    t.TestData.root = fileparts(fileparts(mfilename('fullpath')));
    addpath(t.TestData.root, fullfile(t.TestData.root, 'SingleElementBuilder'));
    t.TestData.folder = [tempname ' space có dấu'];
    mkdir(t.TestData.folder);
end

function teardownOnce(t)
    path(t.TestData.oldPath);
    rmdir(t.TestData.folder, 's');
end

function testSelectedDesignInOctoberProject(t)
    file = fullfile(t.TestData.root, 'SingleElementBuilder', 'reference', '17_10_2026_vivaldi.aedt');
    info = vivaldiInspectProject(file, 'dual_pol_vivaldi_patch_Wflare_20');
    verifyEqual(t, info.designs, {'dual_pol_vivaldi_patch_Wflare_20'});
    verifyEqual(t, size(info.variables, 1), 31);
    verifyEqual(t, info.source, fileread(file));
    cfg = struct('input', file, 'outputDir', t.TestData.folder, 'outputName', 'October update.aedt', ...
                 'design', info.designs{1});
    job = vivaldiHFSSBridge('generate', 'update', cfg, vivaldiDefaultParams());
    verifyTrue(t, isfile(job.script));
    verifyFalse(t, isfile(job.output));
end

function testDiscoveryAndQuotedSpacedPath(t)
    folder = fullfile(t.TestData.folder, 'AnsysEM', 'AnsysEM21.2', 'Win64');
    mkdir(folder);
    exe = fullfile(folder, 'ansysedt.exe');
    fid = fopen(exe, 'w');
    fclose(fid); % fixture only; never executed
    found = HFSSRuntimeSupport.findExecutables({t.TestData.folder}, false);
    verifyEqual(t, found, {exe});
    resolved = HFSSRuntimeSupport.resolveExecutable([' "' exe '" ']);
    verifyTrue(t, isfile(resolved));
    verifyError(t, @()HFSSRuntimeSupport.resolveExecutable(fullfile(folder, 'missing.exe')), ...
                'Vivaldi:ExecutableNotFound');
end

function testUnicodeScriptAndPartialStatus(t)
    file = fullfile(t.TestData.folder, 'script có dấu.vbs');
    text = sprintf('Unicode: có dấu "C:\\Program Files\\AnsysEM"\r\n');
    HFSSRuntimeSupport.writeUTF16(file, text);
    verifyEqual(t, HFSSRuntimeSupport.readUTF16(file), text);
    cfg = struct('outputDir', t.TestData.folder);
    job = HFSSAutomationBridge('generate', 'connect', cfg, vivaldiBuilderDefaultParams());
    HFSSRuntimeSupport.writeUTF16(job.statusPath, ['JOB|' job.id]);
    job.startedAt = now - 1;
    state = HFSSAutomationBridge('poll', job);
    verifyEqual(t, state.state, 'TIMED_OUT');
    verifyFalse(t, state.success);
    HFSSRuntimeSupport.writeUTF16(job.statusPath, sprintf('JOB|%s-extra\r\nSTATE|CONNECTED|time|mock\r\n', job.id));
    state = HFSSAutomationBridge('poll', job);
    verifyEqual(t, state.state, 'FAILED');
end

function testDetachedLauncherIsNotCompletion(t)
    job = HFSSAutomationBridge('generate', 'connect', struct('outputDir', t.TestData.folder), vivaldiBuilderDefaultParams());
    job.startedAt = now;
    job.process = struct('isAlive', @()false);
    state = HFSSAutomationBridge('poll', job);
    verifyEqual(t, state.state, 'WAITING_FOR_SCRIPT');
    verifyFalse(t, state.terminal);
    verifyFalse(t, state.success);
end

function testLegacyGUIEditCalculateAndTarget(t)
    assumeTrue(t, usejava('desktop'), 'Requires a MATLAB desktop; no UI result claimed headlessly.');
    fig = Vivaldi_Element_Designer('Visible', 'off');
    cleanup = onCleanup(@()delete(fig)); %#ok<NASGU>
    field = findall(fig, 'Tag', 'Parameter_L_flare_1');
    field.Value = 45;
    callback = field.ValueChangedFcn;
    callback(field, []);
    calculate = findall(fig, 'Tag', 'CalculateDimensions');
    callback = calculate.ButtonPushedFcn;
    callback(calculate, []);
    verifyEqual(t, fig.UserData.geometry.L_flare, 51.4, 'AbsTol', 1e-10);
    before = fig.UserData.parameters;
    target = findall(fig, 'Tag', 'TargetLength');
    button = findall(fig, 'Tag', 'CalculateTarget');
    for value = [49 50]
        target.Value = value;
        callback = button.ButtonPushedFcn;
        callback(button, []);
        verifyEqual(t, fig.UserData.geometry.L_patch, value, 'AbsTol', 1e-6);
        names = setdiff(fieldnames(before), {'L_flare_1'});
        for k = 1:numel(names)
            verifyEqual(t, fig.UserData.parameters.(names{k}), before.(names{k}));
        end
    end
end

function testExportNeverRefreshesOrMutatesGUI(t)
    assumeTrue(t, usejava('desktop'), 'Requires MATLAB graphics/exportgraphics.');
    fig = Vivaldi_Element_Designer('Visible', 'off');
    cleanup = onCleanup(@()delete(fig)); %#ok<NASGU>
    axesList = findall(fig, 'Type', 'axes');
    ax = axesList(end);
    before = ax.Title.String;
    figureCount = numel(findall(groot, 'Type', 'figure'));
    p = fig.UserData.parameters;
    g = vivaldiCalculateGeometry(p);
    file = fullfile(t.TestData.folder, 'preview.png');
    vivaldiExportPreview(p, g, struct('dimensions', true), file, 'Regression test');
    verifyTrue(t, isfile(file));
    verifyEqual(t, ax.Title.String, before);
    verifyEqual(t, numel(findall(groot, 'Type', 'figure')), figureCount);
    failed = false;
    try
        vivaldiExportPreview(p, g, struct(), fullfile(tempname, 'missing', 'preview.png'), 'Expected I/O failure');
    catch
        failed = true;
    end
    verifyTrue(t, failed);
    verifyEqual(t, ax.Title.String, before);
    verifyEqual(t, numel(findall(groot, 'Type', 'figure')), figureCount);
end

function testMissingExecutableDoesNotCloseBuilder(t)
    assumeTrue(t, usejava('desktop'), 'Requires MATLAB desktop callbacks.');
    fig = Vivaldi_DualPol_Builder('Visible', 'off');
    cleanup = onCleanup(@()delete(fig)); %#ok<NASGU>
    offline = findall(fig, 'Tag', 'OfflineScripts');
    offline.Value = false;
    executable = findall(fig, 'Tag', 'HFSSExecutable');
    executable.Value = fullfile(t.TestData.folder, 'absent', 'ansysedt.exe');
    button = findall(fig, 'Tag', 'BuildFromScratch');
    callback = button.ButtonPushedFcn;
    callback(button, []);
    verifyTrue(t, isvalid(fig));
    verifyFalse(t, fig.UserData.hasVerifiedProject);
    verifyEmpty(t, fig.UserData.activeJob);
end
