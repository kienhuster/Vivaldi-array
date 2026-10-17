function out = HFSSAutomationBridge(action, varargin)
    % HFSSAUTOMATIONBRIDGE Generate/launch/poll Windows HFSS 2021 R2 jobs.
    % Script generation is portable. A generated script is never a successful CAD
    % build. Only an acknowledged HFSS job plus saved-file checks can succeed.
    switch lower(char(action))
        case 'detect'
            out = HFSSRuntimeSupport.findExecutables(varargin{:});
        case 'generate'
            out = generate(varargin{:});
        case 'launch'
            out = launch(varargin{:});
        case 'poll'
            out = poll(varargin{:});
        otherwise
            error('VivaldiBuilder:BridgeAction', 'Unknown bridge action.');
    end
end

function job = generate(action, cfg, p)
    action = lower(char(action));
    assert(ismember(action, {'connect', 'build', 'update', 'validate', 'save', 'analyze', 'reports'}), ...
           'VivaldiBuilder:BridgeAction', 'Unsupported job action.');
    [ok, errors, ~, g] = vivaldiBuilderValidate(p);
    assert(ok, 'VivaldiBuilder:Parameters', '%s', strjoin(errors, newline));
    cfg = defaults(cfg, action);
    assert(strcmp(cfg.version, '2021.2'), 'VivaldiBuilder:Version', 'Only HFSS 2021 R2 (2021.2) is targeted.');
    assert(ismember(cfg.profile, {'Original', 'QuickTest'}), 'VivaldiBuilder:Profile', 'Unknown solver profile.');
    assert(ismember(cfg.excitedPort, [1 2]), 'VivaldiBuilder:Excitation', 'Select one port, 1 or 2.');
    assert(isempty(cfg.studyBand) || (isnumeric(cfg.studyBand) && numel(cfg.studyBand) == 2 && ...
                                      all(isfinite(cfg.studyBand)) && cfg.studyBand(1) > 0 && cfg.studyBand(2) > cfg.studyBand(1)), ...
           'VivaldiBuilder:StudyBand', 'Study band must be empty or [start stop] GHz.');
    assert(~(strcmp(cfg.profile, 'QuickTest') && ~isempty(cfg.studyBand)), ...
           'VivaldiBuilder:Profile', 'QuickTest and StudyBand are separate profiles; select one.');
    assert(isscalar(cfg.timeoutSeconds) && isfinite(cfg.timeoutSeconds) && cfg.timeoutSeconds > 0, ...
           'VivaldiBuilder:Timeout', 'A finite positive timeout is required.');
    assert(isvarname(cfg.designName), 'VivaldiBuilder:DesignName', 'Use an ASCII MATLAB-style identifier for the design.');
    if ~isfolder(cfg.outputDir)
        [made, msg] = mkdir(cfg.outputDir);
        assert(made, 'VivaldiBuilder:OutputDirectory', '%s', msg);
    end
    job = struct('action', action, 'cfg', cfg, 'params', p, 'scriptPath', '', 'statusPath', '', ...
                 'consolePath', '', 'projectPath', '', 'validationPath', '', 'process', [], ...
                 'startedAt', [], 'timeoutSeconds', cfg.timeoutSeconds, 'id', '');
    base = tempname(cfg.outputDir);
    [~, job.id] = fileparts(base);
    job.scriptPath = [base '.vbs'];
    job.statusPath = [base '.status'];
    job.consolePath = [base '.console.log'];
    job.validationPath = [base '.validation.log'];
    if ismember(action, {'build', 'update'})
        name = cfg.projectName;
        assert(~isempty(regexp(name, '^[A-Za-z0-9_][A-Za-z0-9_. -]*$', 'once')) && ...
               ~ismember(name(end), '. ') && isempty(strfind(name, '..')) && ...
               isempty(regexpi(name, '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)', 'once')), ...
               'VivaldiBuilder:ProjectName', 'Use a valid new Windows project basename without extension.');
        job.projectPath = fullfile(cfg.outputDir, [name '.aedt']);
        assert(~isfile(job.projectPath) && ~isfile([job.projectPath '.lock']), ...
               'VivaldiBuilder:ExistingOutput', 'Output exists or is locked; choose a new project name.');
        assert(~isfile([job.projectPath '.builder.json']), ...
               'VivaldiBuilder:ExistingOutput', 'A prior build record exists; choose a new project name.');
        if strcmp(action, 'update')
            assert(isfile(cfg.sourcePath), 'VivaldiBuilder:SourceProject', 'Select an existing AEDT project.');
            assert(~isfile([cfg.sourcePath '.lock']), 'VivaldiBuilder:ProjectLocked', 'Close the source in HFSS; do not remove its lock.');
            assert(~samePath(cfg.sourcePath, job.projectPath), 'VivaldiBuilder:OriginalProtection', 'Output must differ from the source.');
            checkSource(cfg.sourcePath, cfg.designName, p, g);
        end
    elseif ~strcmp(action, 'connect')
        assert(isfile(cfg.projectPath), 'VivaldiBuilder:WorkingProject', 'Choose a verified generated working project.');
        job.projectPath = cfg.projectPath;
        recordPath = [job.projectPath '.builder.json'];
        assert(isfile(recordPath), 'VivaldiBuilder:UnownedProject', ...
               'Only projects produced by this builder can be modified directly. Use Update Existing to create a protected copy.');
        record = jsondecode(fileread(recordPath));
        assert(isfield(record, 'schema') && strcmp(record.schema, 'vivaldi-builder-working-copy-1') && ...
               isfield(record, 'projectPath') && samePath(record.projectPath, job.projectPath), ...
               'VivaldiBuilder:UnownedProject', 'Working-copy record is missing or does not match this path.');
        if isfield(record, 'originalPath') && ~isempty(record.originalPath)
            assert(~samePath(record.originalPath, job.projectPath), 'VivaldiBuilder:OriginalProtection', 'Working copy cannot be its source.');
        end
        protected = {cfg.originalPath, cfg.sourcePath, fullfile(fileparts(mfilename('fullpath')), 'reference', '17_10_2026_vivaldi.aedt')};
        for k = 1:numel(protected)
            if isempty(protected{k})
                continue
            end
            assert(~samePath(protected{k}, job.projectPath), 'VivaldiBuilder:OriginalProtection', 'This action cannot modify the source/reference project.');
        end
        checkSaved(job.projectPath, cfg.designName, p);
    end
    if ~isempty(cfg.studyBand)
        cfg.runSetup = 'StudyBand1';
    elseif strcmp(cfg.profile, 'QuickTest')
        cfg.runSetup = 'QuickTest';
    else
        cfg.runSetup = 'Setup1';
    end
    cfg.solution = [cfg.runSetup ' : Sweep'];
    cfg.resultsDir = fullfile(cfg.outputDir, [job.id '_results']);
    if strcmp(action, 'reports')
        [made, msg] = mkdir(cfg.resultsDir);
        assert(made, 'VivaldiBuilder:ResultsDirectory', '%s', msg);
    end
    job.cfg = cfg;
    w = HFSSScriptWriter();
    w.helper(runtimeHelpers());
    w.helper(HFSSCADHelpers());
    w.stage('Connect');
    w.call('Set oApp = CreateObject("Ansoft.ElectronicsDesktop.2021.2")', 'Connect HFSS 2021 R2 COM');
    w.call('Set oDesktop = oApp.GetAppDesktop()', 'GetAppDesktop');
    w.call('sbVersion = CStr(oDesktop.GetVersion())', 'Read actual desktop version');
    w.require('InStr(1, sbVersion, "2021.2", vbTextCompare) = 1', 'COM desktop is not HFSS 2021 R2; check registration.');
    w.line('Note "Connected actual HFSS version " & sbVersion');
    if strcmp(action, 'connect')
        w.line('State "CONNECTED", "Desktop responded; solver license is not yet verified."');
    else
        w.stage('Create Project');
        if strcmp(action, 'build')
            w.call('Set oProject = oDesktop.NewProject()', 'Create a genuinely new project');
            w.call(['oProject.InsertDesign "HFSS", ' w.q(cfg.designName) ', "DrivenModal", ""'], 'Insert new HFSS design');
        elseif strcmp(action, 'update')
            w.call(['Set oProject = oDesktop.OpenProject(' w.q(cfg.sourcePath) ')'], 'Open source read-only until SaveAs');
        else
            w.call(['Set oProject = SBWorkingProject(' w.q(job.projectPath) ')'], 'Find/open working project');
        end
        w.call(['Set oDesign = oProject.SetActiveDesign(' w.q(cfg.designName) ')'], 'Select exact design');
        w.call('Set oEditor = oDesign.SetActiveEditor("3D Modeler")', 'Get 3D Modeler');
        w.call('Set oBoundary = oDesign.GetModule("BoundarySetup")', 'Boundary module');
        w.call('Set oAnalysis = oDesign.GetModule("AnalysisSetup")', 'Analysis module');
        w.call('Set oRadField = oDesign.GetModule("RadField")', 'Far field module');
        w.call('Set oSolutions = oDesign.GetModule("Solutions")', 'Solutions module');
        w.call('Set oReport = oDesign.GetModule("ReportSetup")', 'Report module');
        if ~ismember(action, {'build', 'update'})
            emitLiveVariables(w, g);
        end
        if ismember(action, {'build', 'update'})
            w.require(['Not fs.FileExists(' w.q(job.projectPath) ')'], 'Output appeared since generation; refusing overwrite.');
            w.stage('Save recovery copy');
            w.call(['oProject.SaveAs ' w.q(job.projectPath) ', True'], 'SaveAs before geometry mutation');
            w.call(['sbMatch = SBProjectMatches(oProject, ' w.q(job.projectPath) ')'], 'Confirm SaveAs identity');
            w.require('sbMatch', 'SaveAs did not switch to the requested working copy.');
            w.line('workingCopyReady = True');
        else
            w.line('workingCopyReady = True');
        end
        if strcmp(action, 'build')
            w.stage('Create Variables');
            variableCommands(w, g, 'NewProps');
            w.call(['oDesign.ChangeProperty Array("NAME:AllTabs", Array("NAME:LocalVariableTab", Array("NAME:PropServers", "LocalVariables"), Array("NAME:NewProps", Array("NAME:alpha", "PropType:=", "PostProcessingVariableProp", "UserDef:=", True, "Value:=", "0deg"))))'], 'Create postprocessing alpha');
            emitMaterials(w);
            HFSSGeometryBuilder(w, p);
            HFSSCoaxBuilder(w, p);
            HFSSSetupBuilder(w, p, cfg);
        elseif strcmp(action, 'update')
            w.stage('Create Variables');
            w.line('Note "UPDATE EXISTING: SaveAs completed; replay the existing parametric history."');
            variableCommands(w, g, 'ChangedProps');
            emitExcitation(w, cfg);
        end
        if ismember(action, {'build', 'update', 'validate', 'analyze', 'save', 'reports'})
            emitInventory(w, g);
            w.stage('Validate');
            w.call(['sbValidation = oDesign.ValidateDesign(' w.q(job.validationPath) ')'], 'HFSS ValidateDesign');
            w.require('sbValidation = 1', 'HFSS validation failed; inspect the validation report and geometry.');
            w.require(['fs.FileExists(' w.q(job.validationPath) ')'], 'HFSS validation report was not produced.');
            w.line('Note "HFSS ValidateDesign returned 1. Port phase/contact comparison still requires acceptance tests."');
        end
        if strcmp(action, 'analyze')
            w.stage('Analyze selected setup');
            w.call(['sbMatch = BuilderContainsName(oAnalysis.GetSetups(), ' w.q(cfg.runSetup) ')'], 'Check selected setup exists');
            w.require('sbMatch', 'Selected profile is absent in this existing project. Build from scratch with that profile first.');
            emitExcitation(w, cfg);
            w.line(['Note ' w.q(['Analyze only ' cfg.runSetup '; no Optimetrics or AnalyzeAll.'])]);
            w.call(['oDesign.Analyze ' w.q(cfg.runSetup)], 'Analyze selected single-element setup');
            % Actual solution vectors are required, not a process exit or old status.
            w.helper(solutionEvidence(cfg, g));
            w.call(['sbMatch = SBHasNetworkData(' w.q(cfg.solution) ')'], 'Read solved S-parameter data');
            w.require('sbMatch', 'Analyze returned but no nonempty S-parameter solution was available.');
        elseif strcmp(action, 'reports')
            HFSSPostProcessing('emit', w, cfg);
        end
        w.stage('Save');
        w.call('oProject.Save', 'Save working project');
        w.require(['fs.FileExists(' w.q(job.projectPath) ')'], 'Saved project file is missing.');
        w.call(['sbSize = fs.GetFile(' w.q(job.projectPath) ').Size'], 'Check saved file size');
        w.require('sbSize > 0', 'Saved project is empty.');
        states = struct('build', 'BUILT', 'update', 'UPDATED', 'validate', 'VALIDATED', 'save', 'SAVED', 'analyze', 'SIMULATED', 'reports', 'REPORTS_EXPORTED');
        w.line(['State ' w.q(states.(action)) ', ' w.q(job.projectPath)]);
    end
    header = { ...
              'Option Explicit', ...
              'Dim fs, statusPath, jobId, workingCopyReady', ...
              'Dim oApp, oDesktop, oProject, oDesign, oEditor, oBoundary, oAnalysis, oRadField, oSolutions, oReport', ...
              'Dim sbErr, sbDesc, sbVersion, sbMatch, sbValidation, sbSize, sbNames, sbBounds', ...
              'Set fs = CreateObject("Scripting.FileSystemObject")', ...
              ['statusPath = ' w.q(job.statusPath)], ['jobId = ' w.q(job.id)], ...
              'workingCopyReady = False'};
    header = [header w.Declarations];
    body = [header {strjoin(w.Helpers, newline), 'Sub Main()', ...
                    'WriteLog "JOB|" & jobId', 'State "STARTING", jobId'} w.Lines {'End Sub', 'Main'}];
    writeScript(job.scriptPath, strjoin(body, sprintf('\r\n')));
    % Offline generation must be repeatable. Record ownership only after an
    % acknowledged build/update and successful saved-model readback in poll().
    job.script = job.scriptPath;
    job.status = job.statusPath;
    job.console = job.consolePath;
    job.output = job.projectPath;
end

function variableCommands(w, g, kind)
    order = 1:size(g.expressions, 1);
    if strcmp(kind, 'NewProps')
        % HFSS validates expressions when adding a variable. Define independent
        % names (including them) before source-order dependent expressions.
        independent = ismember(g.expressions(:, 1), g.independentNames);
        order = [find(independent).' find(~independent).'];
    end
    for k = order
        name = g.expressions{k, 1};
        value = g.expressions{k, 2};
        if strcmp(kind, 'NewProps')
            prop = ['Array(' w.q(['NAME:' name]) ', "PropType:=", "VariableProp", "UserDef:=", True, "Value:=", ' w.q(value) ')'];
        else
            prop = ['Array(' w.q(['NAME:' name]) ', "Value:=", ' w.q(value) ')'];
        end
        command = ['oDesign.ChangeProperty Array("NAME:AllTabs", Array("NAME:LocalVariableTab", Array("NAME:PropServers", "LocalVariables"), Array(' w.q(['NAME:' kind]) ', ' prop ')))'];
        w.call(command, ['Define variable ' name]);
    end
end

function emitInventory(w, g)
    w.stage('Check saved-model inventory');
    w.call('sbMatch = (oEditor.GetModelUnits() = "mm")', 'Read model units');
    w.require('sbMatch', 'Expected model units mm; change units in a separate reviewed project copy.');
    names = {'Vivaldi_1', 'cable_in', 'cable_out', 'cable_in_1', 'cable_out_1', 'port1', 'port2', 'RadiatingSurface'};
    quoted = cellfun(@(x)w.q(x), names, 'UniformOutput', false);
    w.call(['sbMatch = BuilderHasExactlyNames(Array(' strjoin(quoted, ',') '))'], 'Check exact eight model objects');
    w.require('sbMatch', 'Unexpected/missing model objects or leftover cutters.');
    w.call('sbSize = BuilderGroupCount("Unclassified")', 'Check unclassified geometry');
    w.require('sbSize = 0', 'Unclassified geometry remains after Boolean operations.');
    w.call('sbNames = oBoundary.GetExcitations()', 'Read assigned excitations');
    w.call('sbMatch = SBTwoPorts(sbNames)', 'Check two lumped port assignments');
    w.require('sbMatch', 'Expected exactly two Lumped Ports named 1 and 2.');
    w.call('sbMatch = SBHasRadiation(oBoundary.GetBoundaries())', 'Check radiation assignment');
    w.require('sbMatch', 'Open1 Radiation boundary is missing.');
    w.call('sbMatch = (oDesign.GetSolutionType() = "DrivenModal")', 'Check solution type');
    w.require('sbMatch', 'Solution type changed from DrivenModal.');
    w.call('sbBounds = SBVertexBounds("Vivaldi_1")', 'Read actual metal vertex bounds');
    flat = [g.bounds.body(:, 1).' g.bounds.body(:, 2).'];
    for k = 1:6
        w.require(sprintf('Abs(sbBounds(%d) - %.15g) < 0.00001', k - 1, flat(k)), ...
                  'Metal bounds differ from the reconstructed parameters. Inspect geometry.');
    end
    w.line('Note "Inventory and metal vertex bounds checked; this alone does not establish correct void topology."');
end

function job = launch(job, exe)
    assert(ispc, 'VivaldiBuilder:WindowsRequired', 'HFSS VBScript Automation requires Windows. Offline generation remains available.');
    assert(usejava('jvm'), 'VivaldiBuilder:JVM', 'The nonblocking bridge requires the MATLAB JVM.');
    exe = HFSSRuntimeSupport.resolveExecutable(exe);
    assert(isfile(job.scriptPath) && ~isfile(job.statusPath), 'VivaldiBuilder:JobReuse', 'Generate a fresh job before launching.');
    args = java.util.ArrayList();
    args.add(char(exe));
    args.add('-RunScript');
    args.add(job.scriptPath);
    builder = java.lang.ProcessBuilder(args);
    builder.redirectErrorStream(true);
    builder.redirectOutput(java.io.File(job.consolePath));
    job.process = builder.start();
    job.startedAt = now;
end

function state = poll(job)
    state = struct('state', 'SCRIPT_GENERATED', 'terminal', false, 'success', false, 'log', '', ...
                   'alive', false, 'projectPath', job.projectPath, 'elapsedSeconds', 0);
    if ~isempty(job.startedAt)
        state.elapsedSeconds = (now - job.startedAt) * 86400;
        state.state = 'LAUNCHED';
    end
    if isfile(job.statusPath)
        raw = HFSSRuntimeSupport.readUTF16(job.statusPath);
        state.log = raw;
        if ~isempty(raw) && raw(end) ~= char(10)
            ending = find(raw == char(10), 1, 'last');
            if isempty(ending)
                raw = '';
            else
                raw = raw(1:ending);
            end
        end
        acknowledgment = ['(?m)^JOB\|' regexptranslate('escape', job.id) '\r?$'];
        if ~isempty(regexp(raw, acknowledgment, 'once'))
            tokens = regexp(raw, '(?m)^STATE\|([A-Z_]+)\|', 'tokens');
            if ~isempty(tokens)
                state.state = tokens{end}{1};
            end
        elseif ~isempty(raw)
            state.state = 'FAILED';
            state.log = [raw newline 'Job identity acknowledgment is missing.'];
        end
    end
    expected = struct('connect', 'CONNECTED', 'build', 'BUILT', 'update', 'UPDATED', ...
                      'validate', 'VALIDATED', 'save', 'SAVED', 'analyze', 'SIMULATED', 'reports', 'REPORTS_EXPORTED');
    state.success = strcmp(state.state, expected.(job.action));
    state.terminal = state.success || strcmp(state.state, 'FAILED');
    if state.success && ~strcmp(job.action, 'connect')
        try
            checkSaved(job.projectPath, job.cfg.designName, job.params);
            if ismember(job.action, {'build', 'update'})
                saveOwnership(job);
            end
        catch err
            state.state = 'FAILED';
            state.success = false;
            state.log = [state.log newline 'Saved model readback failed: ' err.message];
        end
    end
    if ~isempty(job.process)
        state.alive = job.process.isAlive();
    end
    if ~state.terminal && ~isempty(job.startedAt)
        if state.elapsedSeconds > job.timeoutSeconds
            state.state = 'TIMED_OUT';
            state.terminal = true;
            state.log = [state.log newline 'Monitoring timed out. HFSS was not terminated; inspect its state before another job.'];
        elseif ~state.alive
            state.state = 'WAITING_FOR_SCRIPT';
            state.log = [state.log newline 'Launcher exited; awaiting the acknowledged HFSS script result.'];
        end
    end
end

function emitExcitation(w, cfg)
    power = {'0W', '0W'};
    power{cfg.excitedPort} = '1W';
    w.call(['oSolutions.EditSources Array(Array("IncludePortPostProcessing:=", False, "SpecifySystemPower:=", False), ' ...
            'Array("Name:=", "1:1", "Magnitude:=", ' w.q(power{1}) ', "Phase:=", "0deg"), ' ...
            'Array("Name:=", "2:1", "Magnitude:=", ' w.q(power{2}) ', "Phase:=", "0deg"))'], ...
           'Apply explicitly selected single-port excitation to working copy');
end

function emitLiveVariables(w, g)
    for k = 1:size(g.expressions, 1)
        w.call(['sbVersion = CStr(oDesign.GetVariableValue(' w.q(g.expressions{k, 1}) '))'], ...
               ['Read live parameter ' g.expressions{k, 1}]);
        expected = regexprep(g.expressions{k, 2}, '\s', '');
        w.require(['Replace(Replace(Replace(sbVersion, " ", ""), vbTab, ""), vbCrLf, "") = ' w.q(expected)], ...
                  ['Live HFSS expression changed for ' g.expressions{k, 1} '; save a new working copy with Update Existing.']);
    end
end

function emitMaterials(w)
    w.stage('Assign Materials');
    w.declare('Dim oMaterials');
    w.call('Set oMaterials = oProject.GetDefinitionManager()', 'Get project material definitions');
    materials = {'aluminum', '1.000021', '38000000'; 'copper', '0.999991', '58000000'};
    for k = 1:size(materials, 1)
        name = materials{k, 1};
        args = ['Array(' w.q(['NAME:' name]) ', "CoordinateSystemType:=", "Cartesian", "BulkOrSurfaceType:=", 1, ' ...
                'Array("NAME:PhysicsTypes", "set:=", Array("Electromagnetic")), ' ...
                '"permittivity:=", "1", "permeability:=", ' w.q(materials{k, 2}) ...
                ', "conductivity:=", ' w.q(materials{k, 3}) ')'];
        w.call(['sbMatch = BuilderContainsName(oMaterials.GetProjectMaterialNames(), ' w.q(name) ')'], 'Check project material name');
        w.line('If sbMatch Then');
        w.call(['oMaterials.EditMaterial ' w.q(name) ', ' args], ['Set source EM properties of ' name]);
        w.line('Else');
        w.call(['oMaterials.AddMaterial ' args], ['Add source EM properties of ' name]);
        w.line('End If');
    end
end

function checkSource(file, design, p, g)
    info = vivaldiBuilderInspect(file, design);
    assert(strcmp(info.solutionType, 'DrivenModal'), 'VivaldiBuilder:SourceSchema', 'Source is not DrivenModal.');
    independent = fieldnames(p);
    for k = 1:size(g.expressions, 1)
        rows = find(strcmp(info.variables(:, 1), g.expressions{k, 1}));
        assert(isscalar(rows), 'VivaldiBuilder:SourceSchema', 'Missing or duplicated variable %s.', g.expressions{k, 1});
        if ~ismember(g.expressions{k, 1}, independent)
            source = regexprep(info.variables{rows, 2}, '\s', '');
            expected = regexprep(g.expressions{k, 2}, '\s', '');
            assert(strcmp(source, expected), 'VivaldiBuilder:FormulaMismatch', 'Unsupported source formula for %s.', g.expressions{k, 1});
        end
    end
    % The supplied original has a hard-coded 2mm translation in the mid cutter.
    % Do not silently claim parametric regeneration when this historical literal
    % would leave the second cutter off-axis after thickness changes.
    if abs(p.thickness - 2) > 1e-12
        literal = regexp(info.sourceText, '(?s)Name=''cable_mid_1''.*?\$end ''GeometryPart''', 'match', 'once');
        assert(isempty(regexp(literal, '(?:YTranslate|MoveVectorY|TranslateVectorY)=''2mm''', 'once')), ...
               'VivaldiBuilder:UnlinkedSourceHistory', ...
               'Source cable_mid_1 has a literal 2mm move. Use Build From Scratch for a thickness change.');
    end
end

function checkSaved(file, design, p)
    assert(isfile(file), 'VivaldiBuilder:SavedProject', 'The expected saved project is missing.');
    info = vivaldiBuilderInspect(file, design);
    g = vivaldiBuilderGeometry(p);
    expected = {'Vivaldi_1', 'cable_in', 'cable_out', 'cable_in_1', 'cable_out_1', 'port1', 'port2', 'RadiatingSurface'};
    assert(isequal(sort(info.topLevelNames), sort(expected)), 'VivaldiBuilder:Inventory', 'Saved top-level inventory differs from the eight required objects.');
    assert(info.portCount == 2 && info.radiationCount == 1 && info.noArray && strcmp(info.solutionType, 'DrivenModal'), ...
           'VivaldiBuilder:SavedAssignments', 'Saved ports, radiation, solution type or NoArray setting did not verify.');
    for k = 1:size(g.expressions, 1)
        rows = find(strcmp(info.variables(:, 1), g.expressions{k, 1}));
        assert(isscalar(rows), 'VivaldiBuilder:SavedVariables', 'Saved variable %s is missing or ambiguous.', g.expressions{k, 1});
        a = regexprep(info.variables{rows, 2}, '\s', '');
        b = regexprep(g.expressions{k, 2}, '\s', '');
        assert(strcmp(a, b), 'VivaldiBuilder:SavedVariables', 'Saved expression differs for %s.', g.expressions{k, 1});
    end
end

function cfg = defaults(cfg, action)
    d = struct('version', '2021.2', 'projectName', ['Vivaldi_dual_pol_' datestr(now, 'yyyymmdd_HHMMSS')], ...
               'designName', 'dual_pol_vivaldi_patch_Wflare_20', 'outputDir', tempdir, ...
               'sourcePath', '', 'projectPath', '', 'originalPath', '', 'profile', 'Original', ...
               'excitedPort', 1, 'studyBand', [], 'resultFrequencyGHz', 5, 'timeoutSeconds', 600);
    if strcmp(action, 'analyze')
        d.timeoutSeconds = 14400;
    end
    fields = fieldnames(d);
    for k = 1:numel(fields)
        if ~isfield(cfg, fields{k})
            cfg.(fields{k}) = d.(fields{k});
        end
    end
    textFields = {'version', 'projectName', 'designName', 'outputDir', 'sourcePath', ...
                  'projectPath', 'originalPath', 'profile'};
    for k = 1:numel(textFields)
        value = cfg.(textFields{k});
        if isstring(value) && isscalar(value)
            value = char(value);
        end
        assert(ischar(value) && (isrow(value) || isempty(value)), ...
               'VivaldiBuilder:ConfigText', 'Names and paths must be scalar text.');
        cfg.(textFields{k}) = value;
    end
end

function yes = samePath(a, b)
    a = char(java.io.File(a).getCanonicalPath());
    b = char(java.io.File(b).getCanonicalPath());
    yes = strcmpi(a, b);
end

function writeScript(file, text)
    HFSSRuntimeSupport.writeUTF16(file, [text sprintf('\r\n')]);
end

function saveOwnership(job)
    originalPath = '';
    if strcmp(job.action, 'update')
        originalPath = job.cfg.sourcePath;
    end
    record = struct('schema', 'vivaldi-builder-working-copy-1', 'projectPath', job.projectPath, ...
                    'originalPath', originalPath, 'jobId', job.id, 'note', 'Acknowledged runtime and saved model readback.');
    fid = fopen([job.projectPath '.builder.json'], 'w', 'n', 'UTF-8');
    assert(fid >= 0, 'VivaldiBuilder:WorkingCopyRecord', 'Cannot write working-copy record.');
    cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s\n', jsonencode(record));
end

function lines = runtimeHelpers()
    lines = { ...
             'Sub WriteLog(message)', '  Dim f', ...
             '  Set f = fs.OpenTextFile(statusPath, 8, True, -1)', ...
             '  f.WriteLine message', '  f.Close', 'End Sub', ...
             'Sub Note(message)', '  WriteLog "NOTE|" & CStr(Now) & "|" & message', 'End Sub', ...
             'Sub State(name, message)', '  WriteLog "STATE|" & name & "|" & CStr(Now) & "|" & message', 'End Sub', ...
             'Sub Stage(name)', '  WriteLog "STAGE|" & name & "|" & CStr(Now)', 'End Sub', ...
             'Sub Fail(message)', '  Dim n, d', ...
             '  State "FAILED", message', ...
             '  If workingCopyReady Then', ...
             '    Err.Clear', '    On Error Resume Next', '    oProject.Save', ...
             '    n = Err.Number', '    d = Err.Description', '    On Error GoTo 0', ...
             '    If n <> 0 Then Note "Recovery save failed: " & d', ...
             '    If n = 0 Then Note "Partial working project retained for inspection; not a successful build."', ...
             '  End If', 'End Sub', ...
             'Function SBProjectMatches(project, path)', '  Dim actual', ...
             '  actual = fs.BuildPath(project.GetPath(), project.GetName() & ".aedt")', ...
             '  SBProjectMatches = (LCase(fs.GetAbsolutePathName(actual)) = LCase(fs.GetAbsolutePathName(path)))', 'End Function', ...
             'Function SBWorkingProject(path)', '  Dim names, name, candidate', ...
             '  names = oDesktop.GetProjectList()', '  For Each name In names', ...
             '    Set candidate = oDesktop.SetActiveProject(CStr(name))', ...
             '    If SBProjectMatches(candidate, path) Then', ...
             '      Set SBWorkingProject = candidate', '      Exit Function', '    End If', '  Next', ...
             '  Set SBWorkingProject = oDesktop.OpenProject(path)', 'End Function', ...
             'Function SBTwoPorts(names)', '  Dim k, count, has1, has2', ...
             '  count = 0', '  has1 = False', '  has2 = False', ...
             '  For k = LBound(names) To UBound(names) Step 2', ...
             '    If names(k+1) <> "Lumped Port" Then SBTwoPorts = False: Exit Function', ...
             '    count = count + 1', '    If names(k) = "1" Then has1 = True', ...
             '    If names(k) = "2" Then has2 = True', '  Next', ...
             '  SBTwoPorts = (count = 2 And has1 And has2)', 'End Function', ...
             'Function SBHasRadiation(names)', '  Dim k', '  SBHasRadiation = False', ...
             '  For k = LBound(names) To UBound(names) Step 2', ...
             '    If names(k) = "Open1" And names(k+1) = "Radiation" Then SBHasRadiation = True', '  Next', 'End Function', ...
             'Function SBVertexBounds(name)', '  Dim ids, id, point, lo(2), hi(2), axis, first', ...
             '  ids = oEditor.GetVertexIDsFromObject(name)', '  first = True', ...
             '  For Each id In ids', '    point = oEditor.GetVertexPosition(id)', ...
             '    For axis = 0 To 2', '      If first Then', ...
             '        lo(axis) = CDbl(point(axis))', '        hi(axis) = CDbl(point(axis))', ...
             '      Else', '        If CDbl(point(axis)) < lo(axis) Then lo(axis) = CDbl(point(axis))', ...
             '        If CDbl(point(axis)) > hi(axis) Then hi(axis) = CDbl(point(axis))', '      End If', ...
             '    Next', '    first = False', '  Next', ...
             '  If first Then Err.Raise vbObjectError+301, "SBVertexBounds", "No metal vertices"', ...
             '  SBVertexBounds = Array(lo(0),lo(1),lo(2),hi(0),hi(1),hi(2))', 'End Function'};
end

function lines = solutionEvidence(cfg, g)
    families = {'"Freq:="', 'Array("All")'};
    for k = 1:numel(g.independentNames)
        families = [families, {HFSSScriptWriter.q([g.independentNames{k} ':=']), 'Array("Nominal")'}]; %#ok<AGROW>
    end
    if ~isempty(cfg.studyBand)
        sweep = cfg.studyBand(1):.25:cfg.studyBand(2);
    elseif strcmp(cfg.profile, 'QuickTest')
        sweep = 5:5:20;
    else
        sweep = 5:.25:20;
    end
    expected = strjoin(arrayfun(@(x)sprintf('%.15g', x), sweep, 'UniformOutput', false), ',');
    lines = { ...
             'Function SBHasNetworkData(solution)', ...
             '  Dim data, variation, samples, expression, frequencies, expected, units, factor, k, count', ...
             ['  expected = Array(' expected ')'], ...
             '  SBHasNetworkData = False', ...
             '  For Each expression In Array("mag(S(1,1))", "mag(S(2,2))", "mag(S(2,1))", "mag(S(1,2))")', ...
             ['    data = oReport.GetSolutionDataPerVariation("Modal Solution Data", solution, Array(), Array(' strjoin(families, ',') '), Array(expression))'], ...
             '    If Not IsArray(data) Then Exit Function', ...
             '    count = 0', ...
             '    For Each variation In data', ...
             '      count = count + 1', ...
             '      frequencies = variation.GetSweepValues("Freq", False)', ...
             '      samples = variation.GetRealDataValues(expression, False)', ...
             '      If Not IsArray(frequencies) Then Exit Function', ...
             '      If Not IsArray(samples) Then Exit Function', ...
             '      If UBound(frequencies) <> UBound(expected) Then Exit Function', ...
             '      If UBound(samples) <> UBound(expected) Then Exit Function', ...
             '      units = LCase(CStr(variation.GetSweepUnits("Freq")))', ...
             '      Select Case units', ...
             '        Case "hz": factor = 0.000000001', ...
             '        Case "khz": factor = 0.000001', ...
             '        Case "mhz": factor = 0.001', ...
             '        Case "ghz": factor = 1', ...
             '        Case Else: Err.Raise vbObjectError+302, "SBHasNetworkData", "Unknown frequency unit"', ...
             '      End Select', ...
             '      For k = 0 To UBound(expected)', ...
             '        If Not IsNumeric(frequencies(k)) Then Exit Function', ...
             '        If Abs(CDbl(frequencies(k))*factor-CDbl(expected(k))) > 0.0000001 Then Exit Function', ...
             '        If Not IsNumeric(samples(k)) Then Exit Function', ...
             '        If CDbl(samples(k)) < 0 Then Exit Function', ...
             '        If Not (Abs(CDbl(samples(k))) < 1E+300) Then Exit Function', ...
             '      Next', ...
             '    Next', ...
             '    If count <> 1 Then Exit Function', ...
             '  Next', ...
             '  SBHasNetworkData = True', 'End Function'};
end
