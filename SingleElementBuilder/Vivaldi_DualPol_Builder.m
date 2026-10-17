function fig = Vivaldi_DualPol_Builder()
%VIVALDI_DUALPOL_BUILDER Single-element MATLAB frontend for HFSS 2021 R2.
% Run from this directory or add it to the MATLAB path. No PyAEDT required.
[p,meta] = vivaldiBuilderDefaultParams(); cfg = vivaldiBuilderConfig();
logger = HFSSBuildLogger(); job = []; monitor = []; busy = false;
projectFile = ''; activeParams = p; lastLog = ''; resultSets = {};
fig = uifigure('Name','Vivaldi Dual-Pol Builder Pro','Position',[80 60 1240 840]);
fig.CloseRequestFcn = @closeApp;
outer = uigridlayout(fig,[2 1]); outer.RowHeight = {42,'1x'};
header = uilabel(outer,'Text','Vivaldi Dual-Pol Builder Pro  |  Single Element  |  HFSS 2021 R2', ...
    'FontSize',20,'FontWeight','bold','FontColor',[.1 .3 .5]);
header.Layout.Row = 1;
tabs = uitabgroup(outer); tabs.Layout.Row = 2;
geometryTab = uitab(tabs,'Title','Geometry Parameters');
previewTab = uitab(tabs,'Title','Antenna Preview');
builderTab = uitab(tabs,'Title','HFSS Builder');
resultsTab = uitab(tabs,'Title','Simulation & Results');
manufacturingTab = uitab(tabs,'Title','Manufacturing & Logs');

%% Geometry controls
geometryLayout = uigridlayout(geometryTab,[3 1]); geometryLayout.RowHeight = {'1x',42,68};
panel = uipanel(geometryLayout,'Scrollable','on');
inputs = uigridlayout(panel,[numel(meta) 4]); inputs.ColumnWidth = {260,110,'1x',45};
inputs.RowHeight = repmat({35},1,numel(meta));
edits = struct(); sliders = struct();
for k = 1:numel(meta)
    n = meta(k).name;
    uilabel(inputs,'Text',[meta(k).group ' | ' n],'Interpreter','none');
    edits.(n) = uieditfield(inputs,'numeric','Value',p.(n),'ValueChangedFcn',@(src,~)change(n,src.Value));
    sliders.(n) = uislider(inputs,'Limits',meta(k).limits,'Value',p.(n), ...
        'ValueChangedFcn',@(src,~)change(n,src.Value));
    uilabel(inputs,'Text',meta(k).unit);
end
actions = uigridlayout(geometryLayout,[1 4]);
uibutton(actions,'Text','Reset Original','ButtonPushedFcn',@(~,~)reset());
uibutton(actions,'Text','Load Config','ButtonPushedFcn',@(~,~)loadConfig());
uibutton(actions,'Text','Save Config','ButtonPushedFcn',@(~,~)exportFile('save'));
uibutton(actions,'Text','Validate Parameters','ButtonPushedFcn',@(~,~)validateParameters());
derivedLabel = uilabel(geometryLayout,'WordWrap','on','FontName','Consolas');

%% Mathematical preview controls
previewLayout = uigridlayout(previewTab,[2 1]); previewLayout.RowHeight = {40,'1x'};
previewControls = uigridlayout(previewLayout,[1 5]);
viewControl = uidropdown(previewControls,'Items',{'3D','Front View','Side View','Top View'}, ...
    'ValueChangedFcn',@(~,~)preview());
dimensionControl = uicheckbox(previewControls,'Text','Show Dimensions','Value',true,'ValueChangedFcn',@(~,~)preview());
coaxControl = uicheckbox(previewControls,'Text','Show Coax','Value',true,'ValueChangedFcn',@(~,~)preview());
csControl = uicheckbox(previewControls,'Text','Show Coordinate Systems','Value',false,'ValueChangedFcn',@(~,~)preview());
uibutton(previewControls,'Text','Refresh Preview','ButtonPushedFcn',@(~,~)preview());
previewAxes = uiaxes(previewLayout);

%% HFSS controls
builder = uigridlayout(builderTab,[13 3]); builder.ColumnWidth = {180,'1x',170};
builder.RowHeight = {30,30,30,30,30,30,30,30,100,38,55,48,'1x'};
exeEdit = rowField(builder,1,'Path to ansysedt.exe',cfg.exe);
uibutton(builder,'Text','Browse HFSS','ButtonPushedFcn',@(~,~)browseExe());
moveLast(builder,1,3);
versionEdit = rowField(builder,2,'HFSS Version',cfg.version); versionEdit.Editable = 'off';
projectEdit = rowField(builder,3,'Project Name',cfg.project);
directoryEdit = rowField(builder,4,'Output Directory',cfg.outputDir);
uibutton(builder,'Text','Browse Output','ButtonPushedFcn',@(~,~)browseDirectory()); moveLast(builder,4,3);
designEdit = rowField(builder,5,'Design Name',cfg.design);
labelAt(builder,6,1,'Build Mode');
modeControl = uidropdown(builder,'Items',{'Build From Scratch','Update Existing Project'});
modeControl.Layout.Row = 6; modeControl.Layout.Column = 2;
inputEdit = rowField(builder,7,'Existing Project .aedt','');
uibutton(builder,'Text','Load Project Params','ButtonPushedFcn',@(~,~)browseProject()); moveLast(builder,7,3);
timeoutEdit = rowField(builder,8,'Timeout (seconds)',cfg.timeoutSeconds);
buttonPanel = uigridlayout(builder,[2 4]); buttonPanel.Layout.Row = 9; buttonPanel.Layout.Column = [1 3];
runButtons = gobjects(1,8);
runButtons(1) = uibutton(buttonPanel,'Text','Connect HFSS','ButtonPushedFcn',@(~,~)run('connect',false));
runButtons(2) = uibutton(buttonPanel,'Text','Check HFSS Installation','ButtonPushedFcn',@(~,~)detect());
runButtons(3) = uibutton(buttonPanel,'Text','BUILD FULL ANTENNA IN HFSS', ...
    'BackgroundColor',[.15 .45 .65],'FontColor','white','ButtonPushedFcn',@(~,~)run('build',false));
runButtons(4) = uibutton(buttonPanel,'Text','Update Existing Project','ButtonPushedFcn',@(~,~)run('update',false));
runButtons(5) = uibutton(buttonPanel,'Text','Validate Geometry','ButtonPushedFcn',@(~,~)run('validate',false));
runButtons(6) = uibutton(buttonPanel,'Text','Save Project Copy','ButtonPushedFcn',@(~,~)run('save',false));
runButtons(7) = uibutton(buttonPanel,'Text','Export Automation Script','ButtonPushedFcn',@(~,~)offline());
runButtons(8) = uibutton(buttonPanel,'Text','Open Output Folder','ButtonPushedFcn',@(~,~)openOutput());
progressLabel = uilabel(builder,'Text','Idle — HFSS validation pending','FontWeight','bold');
progressLabel.Layout.Row = 10; progressLabel.Layout.Column = [1 3];
outputLabel = uilabel(builder,'Text','No HFSS project built yet.','WordWrap','on');
outputLabel.Layout.Row = 11; outputLabel.Layout.Column = [1 3];
explanation = uilabel(builder,'Text', ...
    'Build From Scratch creates a new project. Update saves a new copy before editing. Generating a script does not confirm an HFSS build.', ...
    'WordWrap','on'); explanation.Layout.Row = 12; explanation.Layout.Column = [1 3];
stageList = uitextarea(builder,'Editable','off','Value', ...
    {'Stages: Connect → Create Project → Variables → Coordinate Systems → Flare → Cavity'; ...
    'Metal Sheets → Dual-Pol → Coax → Boolean → Materials → Ports → Region → Solution → Validate → Save'; ...
    'Boolean and validation errors stop the job. Inspect status.log, console.log and the recovery project.'});
stageList.Layout.Row = 13; stageList.Layout.Column = [1 3];

%% Simulation and genuine result import
results = uigridlayout(resultsTab,[5 1]); results.RowHeight = {70,44,32,'1x',35};
simulation = uigridlayout(results,[2 6]);
uilabel(simulation,'Text','Solver Profile'); uilabel(simulation,'Text','Excitation Port');
uilabel(simulation,'Text','Quick Start GHz'); uilabel(simulation,'Text','Quick Stop GHz');
uilabel(simulation,'Text','Quick Step GHz'); uilabel(simulation,'Text','Pattern GHz');
profileControl = uidropdown(simulation,'Items',{'Setup1','QuickTest'});
portControl = uidropdown(simulation,'Items',{'1','2'});
fStartEdit = uieditfield(simulation,'numeric','Value',cfg.fStart);
fStopEdit = uieditfield(simulation,'numeric','Value',cfg.fStop);
fStepEdit = uieditfield(simulation,'numeric','Value',cfg.fStep);
frequencyEdit = uieditfield(simulation,'numeric','Value',cfg.reportFrequency);
resultActions = uigridlayout(results,[1 5]);
simulateButton = uibutton(resultActions,'Text','Run Analysis','ButtonPushedFcn',@(~,~)run('simulate',false));
reportButton = uibutton(resultActions,'Text','Export HFSS Reports','ButtonPushedFcn',@(~,~)run('reports',false));
uibutton(resultActions,'Text','Load / Compare CSV','ButtonPushedFcn',@(~,~)importResults());
uibutton(resultActions,'Text','HPBW of Last CSV Cut','ButtonPushedFcn',@(~,~)hpbw());
uibutton(resultActions,'Text','Clear Plot','ButtonPushedFcn',@(~,~)clearResults());
simulationLabel = uilabel(results,'Text','Not Simulated','FontWeight','bold');
resultAxes = uiaxes(results); title(resultAxes,'No RF data loaded');
uilabel(results,'Text','Setup1: original 5–20 GHz / 0.25 GHz. QuickTest: lower accuracy, separate setup; not a substitute for the original solution.', ...
    'WordWrap','on');

%% Manufacturing and logging
manufacturing = uigridlayout(manufacturingTab,[4 1]); manufacturing.RowHeight = {44,44,45,'1x'};
targetPanel = uigridlayout(manufacturing,[1 4]);
uilabel(targetPanel,'Text','Target total length (mm)');
targetEdit = uieditfield(targetPanel,'numeric','Value',49);
uibutton(targetPanel,'Text','Solve L_flare_1','ButtonPushedFcn',@(~,~)target(targetEdit.Value));
uibutton(targetPanel,'Text','Set Target 50 mm','ButtonPushedFcn',@(~,~)target(50));
exports = uigridlayout(manufacturing,[1 3]);
uibutton(exports,'Text','Export Dimensions CSV','ButtonPushedFcn',@(~,~)exportFile('dimensions'));
uibutton(exports,'Text','Export Configuration Report','ButtonPushedFcn',@(~,~)exportFile('report'));
uibutton(exports,'Text','Export HFSS Logs','ButtonPushedFcn',@(~,~)exportLogs());
lengthLabel = uilabel(manufacturing,'Text','','WordWrap','on');
logBox = uitextarea(manufacturing,'Editable','off','FontName','Consolas');
tabs.SelectionChangedFcn = @(~,~)previewSelected();
refresh(); preview();
logMessage('INFO','Offline ready. Implemented — HFSS Validation Pending.');

    function change(name,value)
        p.(name) = value; simulationLabel.Text = 'Not Simulated — parameters changed';
        refresh(); if tabs.SelectedTab == previewTab, preview(); end
    end
    function refresh()
        [ok,e,~,g] = vivaldiBuilderValidate(p);
        for j = 1:numel(meta)
            n = meta(j).name; edits.(n).Value = p.(n);
            limits = meta(j).limits;
            if isreal(p.(n)) && isfinite(p.(n))
                sliders.(n).Limits = [min(limits(1),p.(n)) max(limits(2),p.(n))];
                sliders.(n).Value = p.(n);
            end
        end
        if ok
            derivedLabel.Text = sprintf('L_flare %.6f mm | r_flare %.10f mm^-1 | x_feed %.9f mm | z_feed %.9f mm\nL_patch %.9f mm | base %.3f x %.3f mm', ...
                g.L_flare,g.r_flare,g.x_feed,g.z_feed,g.L_patch,g.de_L,g.de_W);
            lengthLabel.Text = sprintf('Total length L_patch = %.9f mm. Target solver changes only L_flare_1.',g.L_patch);
        else
            derivedLabel.Text = strjoin(e,' | '); lengthLabel.Text = 'Invalid dimensions; correct parameters first.';
        end
    end
    function previewSelected(), if tabs.SelectedTab == previewTab, preview(); end, end
    function preview()
        try
            vivaldiBuilderPreview(previewAxes,p,struct('coax',coaxControl.Value, ...
                'coordinates',csControl.Value,'dimensions',dimensionControl.Value,'view',viewControl.Value));
        catch error
            title(previewAxes,['Preview unavailable: ' error.message],'Interpreter','none');
            logMessage('ERROR',error.message);
        end
    end
    function reset(), p = vivaldiBuilderDefaultParams(); refresh(); simulationLabel.Text = 'Not Simulated'; end
    function validateParameters()
        [ok,e,warning] = vivaldiBuilderValidate(p);
        if ok, message = strjoin([{'Algebraic checks passed.'} warning],newline);
        else, message = strjoin(e,newline); end
        logMessage('PARAMETERS',message); uialert(fig,message,'Parameter Validation','Icon','info');
    end
    function target(value)
        try
            [p,~] = vivaldiBuilderTargetLength(p,value); targetEdit.Value = value;
            refresh(); simulationLabel.Text = 'Not Simulated — target length changed';
        catch error, showError(error); end
    end
    function loadConfig()
        [file,folder] = uigetfile('*.json','Load builder configuration');
        if isequal(file,0), return; end
        try, p = vivaldiBuilderIO('load',fullfile(folder,file)); refresh(); simulationLabel.Text = 'Not Simulated';
        catch error, showError(error); end
    end
    function exportFile(action)
        ext = '*.json'; if strcmp(action,'dimensions'), ext = '*.csv'; end
        [file,folder] = uiputfile(ext,['Export ' action]);
        if isequal(file,0), return; end
        try, vivaldiBuilderIO(action,fullfile(folder,file),p); logMessage('EXPORT',fullfile(folder,file));
        catch error, showError(error); end
    end
    function browseExe()
        [file,folder] = uigetfile('ansysedt.exe');
        if ~isequal(file,0), exeEdit.Value = fullfile(folder,file); end
    end
    function browseDirectory()
        folder = uigetdir(directoryEdit.Value);
        if ~isequal(folder,0), directoryEdit.Value = folder; end
    end
    function browseProject()
        [file,folder] = uigetfile('*.aedt','Choose existing project (original will be preserved)');
        if isequal(file,0), return; end
        try
            source = fullfile(folder,file);
            q = vivaldiBuilderReadProject(source,designEdit.Value);
            p = q; inputEdit.Value = source; projectFile = source;
            refresh(); simulationLabel.Text = 'Not Simulated — loaded project parameters';
        catch error, showError(error); end
    end
    function detect()
        found = HFSSAutomationBridge('detect');
        if isempty(found), logMessage('INSTALLATION','No HFSS executable found. Select its path manually; offline tools remain available.');
        else, exeEdit.Value = found{1}; logMessage('INSTALLATION',strjoin(found,newline)); end
    end
    function offline()
        action = 'build'; if strcmp(modeControl.Value,'Update Existing Project'), action = 'update'; end
        run(action,true);
    end
    function run(action,generateOnly)
        if busy, uialert(fig,'A job is still running. Inspect HFSS before starting another.','HFSS Busy'); return; end
        try
            cfg.exe = exeEdit.Value; cfg.version = versionEdit.Value;
            cfg.project = projectEdit.Value; cfg.outputDir = directoryEdit.Value;
            cfg.design = designEdit.Value; cfg.input = inputEdit.Value;
            cfg.timeoutSeconds = timeoutEdit.Value; cfg.profile = profileControl.Value;
            cfg.port = str2double(portControl.Value); cfg.fStart = fStartEdit.Value;
            cfg.fStop = fStopEdit.Value; cfg.fStep = fStepEdit.Value; cfg.reportFrequency = frequencyEdit.Value;
            if ~ismember(action,{'build','connect','update'})
                assert(~isempty(projectFile),'VivaldiBuilder:Project','Build a project or load an existing project first.');
                cfg.input = projectFile;
            end
            if strcmp(action,'build'), modeControl.Value = 'Build From Scratch';
            elseif strcmp(action,'update'), modeControl.Value = 'Update Existing Project'; end
            job = HFSSAutomationBridge('generate',action,cfg,p); activeParams = p;
            outputLabel.Text = ['Job directory: ' job.directory];
            logMessage('SCRIPT_GENERATED',[upper(action) ' | ' job.script]);
            progressLabel.Text = 'SCRIPT_GENERATED — no HFSS build confirmed';
            if generateOnly || ~ispc || ~isfile(cfg.exe)
                logMessage('OFFLINE','Script saved. Windows + MATLAB + licensed HFSS 2021 R2 is required to execute it.'); return;
            end
            job = HFSSAutomationBridge('launch',job,cfg.exe); busy = true; lastLog = '';
            setBusy(true);
            monitor = timer('ExecutionMode','fixedSpacing','Period',1,'BusyMode','drop', ...
                'TimerFcn',@(~,~)tick(),'ErrorFcn',@(~,~)monitorError());
            start(monitor); progressLabel.Text = 'LAUNCHED — waiting for HFSS';
            if strcmp(action,'simulate'), simulationLabel.Text = 'Running — no completed solution confirmed'; end
        catch error, showError(error); end
    end
    function tick()
        if ~isvalid(fig), return; end
        state = HFSSAutomationBridge('poll',job);
        if ~strcmp(lastLog,state.log)
            lastLog = state.log; stageList.Value = cellstr(splitlines(string(state.log)));
        end
        progressLabel.Text = state.state;
        if strcmp(state.state,'RUNNING')
            stages = regexp(state.log,'(?m)^STATE\|RUNNING\|[^|]*\|([^\r\n]*)','tokens');
            if ~isempty(stages), progressLabel.Text = ['RUNNING — ' stages{end}{1}]; end
        end
        if state.timedOut
            progressLabel.Text = 'TIMED OUT — HFSS may still be running; monitoring continues'; return;
        end
        if ~state.terminal, return; end
        stop(monitor); delete(monitor); monitor = []; busy = false; setBusy(false);
        logMessage(state.state,state.log);
        if ~ismember(state.state,{'FAILED','CONNECTED'})
            projectFile = job.output; inputEdit.Value = projectFile;
            outputLabel.Text = ['HFSS saved: ' projectFile];
            if ~isequal(p,activeParams), simulationLabel.Text = 'Not Simulated — controls differ from completed job';
            elseif strcmp(state.state,'SIMULATED')
                simulationLabel.Text = 'HFSS returned with solution samples and CSV reports; inspect convergence.';
            else, simulationLabel.Text = 'Not Simulated — geometry validated; no solve completed in this job'; end
        elseif strcmp(state.state,'FAILED')
            simulationLabel.Text = 'Not Simulated — job failed; inspect logs and recovery project';
        end
    end
    function setBusy(value)
        enabled = 'on'; if value, enabled = 'off'; end
        for j = 1:numel(runButtons)-1, runButtons(j).Enable = enabled; end
        simulateButton.Enable = enabled; reportButton.Enable = enabled;
    end
    function monitorError()
        progressLabel.Text = 'Monitor error — inspect HFSS and logs; no success assumed';
        logMessage('ERROR','Monitoring failed. Close the application only after inspecting the active HFSS operation.');
    end
    function importResults()
        [file,folder] = uigetfile('*.csv','Load genuine HFSS/exported measurement CSV');
        if isequal(file,0), return; end
        try
            source = fullfile(folder,file); T = HFSSPostProcessing.loadCSV(source);
            columns = T.Properties.VariableNames;
            [x,ok] = listdlg('ListString',columns,'SelectionMode','single','PromptString','Choose X column (with units)');
            if ~ok, return; end
            [y,ok] = listdlg('ListString',columns,'SelectionMode','multiple','PromptString','Choose numeric Y columns');
            if ~ok, return; end
            data = HFSSPostProcessing.loadCSV(source,columns{x},columns(y));
            if ~isempty(resultSets)
                assert(strcmp(resultSets{1}.xName,data.xName),'VivaldiBuilder:CSVUnits', ...
                    'Comparison requires the same X column and units. Clear the plot before changing axes.');
            end
            resultSets{end+1} = data;
            hold(resultAxes,'on');
            for j = 1:size(data.y,2)
                plot(resultAxes,data.x,data.y(:,j),'DisplayName',[file ' | ' data.yNames{j}]);
            end
            hold(resultAxes,'off'); legend(resultAxes,'show','Interpreter','none'); grid(resultAxes,'on');
            xlabel(resultAxes,data.xName,'Interpreter','none'); ylabel(resultAxes,'Imported values (see column units)');
            title(resultAxes,'Imported CSV — provenance is the selected file, not current GUI geometry');
            logMessage('CSV',source);
        catch error, showError(error); end
    end
    function hpbw()
        try
            assert(~isempty(resultSets),'VivaldiBuilder:HPBW','Import an angular gain cut first.');
            data = resultSets{end};
            assert(contains(lower(data.xName),'deg'),'VivaldiBuilder:HPBW','X column must explicitly be in degrees.');
            assert(contains(lower(data.yNames{1}),'db'),'VivaldiBuilder:HPBW','Y column must explicitly be in dB.');
            result = HFSSPostProcessing.hpbw(data.x,data.y(:,1));
            uialert(fig,sprintf('HPBW = %g deg\n%s',result.degrees,result.reason),'HPBW','Icon','info');
        catch error, showError(error); end
    end
    function clearResults(), cla(resultAxes); resultSets = {}; title(resultAxes,'No RF data loaded'); end
    function openOutput()
        folder = directoryEdit.Value; if ~isempty(job), folder = job.directory; end
        if ispc && isfolder(folder), winopen(folder); else, logMessage('OUTPUT',folder); end
    end
    function exportLogs()
        folder = uigetdir(pwd,'Export MATLAB log and current HFSS job logs');
        if isequal(folder,0), return; end
        logger.export(fullfile(folder,['builder_' datestr(now,30) '.jsonl']));
        if ~isempty(job)
            for source = {job.status,job.console,job.validation}
                if isfile(source{1})
                    [~,name,ext] = fileparts(source{1});
                    destination = [tempname(folder) '_' name ext]; copyfile(source{1},destination);
                end
            end
        end
    end
    function logMessage(level,message)
        logger.add(level,message);
        entries = logger.Entries; rows = cell(1,numel(entries));
        for j = 1:numel(entries), rows{j} = [entries{j}.time ' | ' entries{j}.level ' | ' entries{j}.message]; end
        logBox.Value = rows;
    end
    function showError(error), logMessage('ERROR',error.message); uialert(fig,error.message,'Vivaldi Builder'); end
    function closeApp(~,~)
        if ~isempty(monitor) && isvalid(monitor), stop(monitor); delete(monitor); end
        % Never kill HFSS or delete its results when closing the frontend.
        delete(fig);
    end
end

function edit = rowField(grid,row,label,value)
labelAt(grid,row,1,label);
kind = 'text'; if isnumeric(value), kind = 'numeric'; end
edit = uieditfield(grid,kind,'Value',value); edit.Layout.Row = row; edit.Layout.Column = 2;
end
function labelAt(grid,row,column,text)
label = uilabel(grid,'Text',text); label.Layout.Row = row; label.Layout.Column = column;
end
function moveLast(grid,row,column)
control = grid.Children(1); control.Layout.Row = row; control.Layout.Column = column;
end
