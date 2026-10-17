function result = runDebugPortableChecks(outputFolder)
    % RUNDEBUGPORTABLECHECKS Execute non-UI/non-COM regressions in MATLAB/Octave.
    % These checks do not substitute for MATLAB desktop or Windows HFSS tests.
    if nargin == 0
        outputFolder = tempname;
    end
    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end
    root = fileparts(fileparts(mfilename('fullpath')));
    oldPath = path;
    cleanup = onCleanup(@()path(oldPath)); %#ok<NASGU>
    addpath(root, fullfile(root, 'SingleElementBuilder'));
    passed = {};
    p = vivaldiDefaultParams();
    g = vivaldiCalculateGeometry(p);
    assert(abs(g.L_patch - 49.23630329005893) < 1e-10);
    q = p;
    q.L_flare_1 = 45;
    assert(vivaldiValidateParams(q));
    h = vivaldiCalculateGeometry(q);
    assert(abs(h.L_flare - 51.4) < 1e-10);
    record('legacy scalar formulas and parameter edit');
    for target = [49 50]
        [q, comparison] = vivaldiSolveTargetLength(p, target);
        assert(abs(comparison.after.L_patch - target) < 1e-6);
        unchanged(p, q);
        record(sprintf('legacy target %g mm', target));
    end
    builder = vivaldiBuilderDefaultParams();
    g = vivaldiBuilderGeometry(builder);
    assert(abs(g.L_patch - 49.23630329005893) < 1e-10);
    record('builder default scalar formulas');
    for target = [49 50]
        [q, comparison] = vivaldiBuilderTargetLength(builder, target);
        assert(abs(comparison.after.L_patch - target) < 1e-6);
        unchanged(builder, q);
        record(sprintf('builder target %g mm', target));
    end
    reference = fullfile(root, 'SingleElementBuilder', 'reference', '17_10_2026_vivaldi.aedt');
    fullSource = fileread(reference);
    info = vivaldiInspectProject(reference, 'dual_pol_vivaldi_patch_Wflare_20');
    assert(isequal(info.designs, {'dual_pol_vivaldi_patch_Wflare_20'}));
    assert(size(info.variables, 1) == 31 && strcmp(info.source, fullSource));
    record('October project with two designs is scoped correctly');
    fixtureRoot = fullfile(outputFolder, 'space có dấu');
    fixtureBin = fullfile(fixtureRoot, 'AnsysEM', 'AnsysEM21.2', 'Win64');
    mkdir(fixtureBin);
    exe = fullfile(fixtureBin, 'ansysedt.exe');
    fid = fopen(exe, 'w');
    fclose(fid);
    found = HFSSRuntimeSupport.findExecutables({fixtureRoot}, false);
    assert(isequal(found, {exe}));
    resolved = HFSSRuntimeSupport.resolveExecutable([' "' exe '" ']);
    assert(isfile(resolved));
    record('discovery and quoted executable path with spaces/Unicode (fixture, never executed)');
    failed = false;
    try
        HFSSRuntimeSupport.resolveExecutable(fullfile(fixtureBin, 'missing.exe'));
    catch err
        failed = strcmp(err.identifier, 'Vivaldi:ExecutableNotFound');
    end
    assert(failed);
    record('missing executable produces a controlled error');
    text = sprintf('Unicode: có dấu "C:\\Program Files\\AnsysEM"\r\n');
    file = fullfile(outputFolder, 'unicode.vbs');
    HFSSRuntimeSupport.writeUTF16(file, text);
    assert(strcmp(HFSSRuntimeSupport.readUTF16(file), text));
    record('UTF-16 byte round trip');
    cfg = struct('outputDir', outputFolder, 'projectName', 'Portable build space', ...
                 'designName', 'dual_pol_vivaldi_patch_Wflare_20');
    first = HFSSAutomationBridge('generate', 'build', cfg, builder);
    second = HFSSAutomationBridge('generate', 'build', cfg, builder);
    assert(~strcmp(first.scriptPath, second.scriptPath));
    assert(~isfile(first.projectPath) && ~isfile([first.projectPath '.builder.json']));
    script = HFSSRuntimeSupport.readUTF16(first.scriptPath);
    assert(~isempty(strfind(script, 'oDesktop.NewProject()')));
    record('repeatable scratch script generation without Ansys, output or ownership record');
    cfg.projectName = 'Portable quick';
    cfg.profile = 'QuickTest';
    quick = HFSSAutomationBridge('generate', 'build', cfg, builder);
    assert(isfile(quick.scriptPath));
    record('QuickTest script generation');
    cfg.projectName = 'Portable study';
    cfg.profile = 'Original';
    cfg.studyBand = [6 18];
    study = HFSSAutomationBridge('generate', 'build', cfg, builder);
    assert(isfile(study.scriptPath));
    record('StudyBand script generation');
    legacyCfg = struct('outputDir', outputFolder);
    legacy = vivaldiHFSSBridge('generate', 'connect', legacyCfg, p);
    assert(isfile(legacy.script));
    record('legacy connection script generated without Ansys');
    connect = HFSSAutomationBridge('generate', 'connect', cfg, builder);
    connect.startedAt = now;
    connect.process = struct('isAlive', @()false);
    state = HFSSAutomationBridge('poll', connect);
    assert(strcmp(state.state, 'WAITING_FOR_SCRIPT') && ~state.terminal && ~state.success);
    record('detached launcher remains pending (mock process)');
    HFSSRuntimeSupport.writeUTF16(connect.statusPath, ['JOB|' connect.id]);
    connect.startedAt = now - 1;
    state = HFSSAutomationBridge('poll', connect);
    assert(strcmp(state.state, 'TIMED_OUT') && ~state.success);
    record('partial acknowledgment still reaches timeout (mock status)');
    HFSSRuntimeSupport.writeUTF16(connect.statusPath, sprintf('JOB|%s-extra\r\nSTATE|CONNECTED|time|mock\r\n', connect.id));
    state = HFSSAutomationBridge('poll', connect);
    assert(strcmp(state.state, 'FAILED'));
    record('job ID prefix cannot acknowledge another job');
    HFSSRuntimeSupport.writeUTF16(connect.statusPath, sprintf('JOB|%s\r\nSTATE|CONNECTED|time|mock\r\n', connect.id));
    state = HFSSAutomationBridge('poll', connect);
    assert(state.success && state.terminal);
    record('complete matching connection acknowledgment (mock protocol only)');
    bad = first;
    bad.startedAt = now;
    bad.process = struct('isAlive', @()false);
    HFSSRuntimeSupport.writeUTF16(bad.statusPath, sprintf('JOB|%s\r\nSTATE|BUILT|time|mock\r\n', bad.id));
    state = HFSSAutomationBridge('poll', bad);
    assert(~state.success && strcmp(state.state, 'FAILED') && ~isfile([bad.projectPath '.builder.json']));
    record('mock BUILT cannot bypass missing saved-model validation');
    assert(strcmp(fileread(reference), fullSource));
    record('HFSS reference remains unchanged');
    result = struct('runner', version, 'count', numel(passed), 'passed', {passed}, ...
                    'unrun', {{'MATLAB Code Analyzer/checkcode', 'MATLAB desktop GUI and exportgraphics', ...
                  'Windows ProcessBuilder/COM', 'HFSS CAD/Validate/solver'}});
    fid = fopen(fullfile(outputFolder, 'debug-portable-results.json'), 'w');
    fprintf(fid, '%s\n', jsonencode(result));
    fclose(fid);
    fprintf('%d portable groups passed; GUI and HFSS runtime remain unrun.\n', result.count);

    function record(name)
        passed{end + 1} = name;
        fprintf('PASS: %s\n', name);
    end

end

function unchanged(before, after)
    names = setdiff(fieldnames(before), {'L_flare_1'});
    for k = 1:numel(names)
        assert(isequal(before.(names{k}), after.(names{k})));
    end
end
