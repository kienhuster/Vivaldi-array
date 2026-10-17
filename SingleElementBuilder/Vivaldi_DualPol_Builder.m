function fig = Vivaldi_DualPol_Builder(varargin)
%VIVALDI_DUALPOL_BUILDER One dual-pol element: MATLAB GUI + HFSS automation.
% Vivaldi_DualPol_Builder; optional ('Visible','off') supports desktop tests.
% No HFSS action starts merely by opening this app or changing a parameter.
parser=inputParser; addParameter(parser,'Visible','on'); parse(parser,varargin{:});
[p,meta]=vivaldiBuilderDefaultParams(); original=p;
fields=struct(); sliders=struct(); activeJob=[]; detachedJob=[]; monitor=[]; lastBuilt=[];
jobParams=[]; jobConfig=[]; lastPollLog=''; logLines={}; datasets={};
busyButtons=gobjects(0); geometryValid=false; geometry=[]; closing=false;
outDir=fullfile(tempdir,'VivaldiDualPolBuilder');
fig=uifigure('Name','Vivaldi Dual-Pol Builder Pro','Tag','VivaldiDualPolBuilder', ...
    'Position',[70 60 1400 870],'Visible',parser.Results.Visible, ...
    'CloseRequestFcn',@closeApp,'Color',[.96 .97 .99]);
shell=uigridlayout(fig,[2 1]); shell.RowHeight={'1x',38};
tabs=uitabgroup(shell,'Tag','BuilderTabs');
status=uilabel(shell,'Text','Not Simulated — chưa dựng CAD trong HFSS.', ...
    'FontWeight','bold','Tag','BuilderStatus','WordWrap','on');
geometryTab=uitab(tabs,'Title','1 · Geometry Parameters','Tag','GeometryTab');
previewTab=uitab(tabs,'Title','2 · Antenna Preview','Tag','PreviewTab');
builderTab=uitab(tabs,'Title','3 · HFSS Builder','Tag','HFSSBuilderTab');
resultsTab=uitab(tabs,'Title','4 · Simulation & Results','Tag','ResultsTab');
manufacturingTab=uitab(tabs,'Title','5 · Manufacturing & Logs','Tag','ManufacturingTab');

% Geometry: independent variables only; all dependencies remain computed.
gg=uigridlayout(geometryTab,[1 2]); gg.ColumnWidth={'2x','1x'};
left=uigridlayout(gg,[3 1]); left.RowHeight={38,'1x',52};
uilabel(left,'Text','Một phần tử dual-pol · kích thước mm, góc độ', ...
    'FontWeight','bold'); groups=uitabgroup(left);
groupLabels={'Flare','Transition','Slot','Cavity','Metal Thickness','Coaxial Feed','Base Dimensions','Advanced'};
groupFields={{'L_flare_1','aperture_w'},{'them','deg_slot_t'}, ...
    {'slot_feed_w','h3_slot_feed','h2'},{'cavity_w','cavity_L'}, ...
    {'thickness'},{'r_cabin','r_cabmid','r_cabout','positionx'},{'h_de'}, ...
    {'lamda','scan_phi','scan_theta','c2'}};
for group=1:numel(groupLabels)
    tab=uitab(groups,'Title',groupLabels{group}); names=groupFields{group};
    grid=uigridlayout(tab,[numel(names)*2+1 4]);
    grid.ColumnWidth={130,'1x',45,45}; grid.Scrollable='on';
    grid.RowHeight=[repmat({32,46},1,numel(names)),{'1x'}];
    for k=1:numel(names)
        name=names{k}; m=meta(strcmp({meta.name},name));
        label=uilabel(grid,'Text',[name ' — ' m.label],'Tooltip',m.tip, ...
            'Interpreter','none'); place(label,2*k-1,[1 4]);
        fields.(name)=uieditfield(grid,'numeric','Value',p.(name), ...
            'Tooltip',m.tip,'Tag',['Parameter_' name], ...
            'ValueChangedFcn',@(src,~)changeParameter(name,src.Value));
        place(fields.(name),2*k,1);
        sliders.(name)=uislider(grid,'Limits',m.range,'Value',p.(name), ...
            'MajorTicks',[],'MinorTicks',[],'Tag',['Slider_' name], ...
            'ValueChangedFcn',@(src,~)changeParameter(name,src.Value), ...
            'ValueChangingFcn',@(~,event)changeParameter(name,event.Value));
        place(sliders.(name),2*k,2);
        unit=uilabel(grid,'Text',m.unit); place(unit,2*k,3);
        restore=uibutton(grid,'Text','Reset','ButtonPushedFcn', ...
            @(~,~)changeParameter(name,original.(name))); place(restore,2*k,4);
    end
end
parameterActions=uigridlayout(left,[1 4]);
uibutton(parameterActions,'Text','Reset Original','ButtonPushedFcn',@resetOriginal);
uibutton(parameterActions,'Text','Load Config','ButtonPushedFcn',@loadConfig);
uibutton(parameterActions,'Text','Save Config','ButtonPushedFcn',@saveConfig);
uibutton(parameterActions,'Text','Validate Parameters','ButtonPushedFcn',@validateParameters);
right=uigridlayout(gg,[3 1]); right.RowHeight={38,'1x',210};
uilabel(right,'Text','Giá trị dẫn xuất — cập nhật tự động','FontWeight','bold');
dimensionTable=uitable(right,'ColumnName',{'Biến','Giá trị','Đơn vị'}, ...
    'ColumnWidth',{150,135,70},'RowName',{},'Tag','DerivedDimensions');
parameterInfo=uitextarea(right,'Editable','off','Tag','ParameterValidation');

% Mathematical preview is explicitly separate from the HFSS CAD model.
pg=uigridlayout(previewTab,[4 1]); pg.RowHeight={42,42,'1x',58};
uilabel(pg,'Text','MATHEMATICAL PREVIEW — không phải CAD xuất từ HFSS', ...
    'FontWeight','bold','FontColor',[.7 .25 .05],'Tag','PreviewDisclaimer');
previewOptions=uigridlayout(pg,[1 4]);
viewChoice=uidropdown(previewOptions,'Items',{'3D','Front View','Side View','Top View'}, ...
    'Value','3D','ValueChangedFcn',@(~,~)refresh(),'Tag','PreviewView');
showDimensions=uicheckbox(previewOptions,'Text','Show Dimensions','Value',false, ...
    'ValueChangedFcn',@(~,~)refresh());
showCoax=uicheckbox(previewOptions,'Text','Show Coax','Value',true, ...
    'ValueChangedFcn',@(~,~)refresh());
showCoordinates=uicheckbox(previewOptions,'Text','Show Coordinate Systems','Value',false, ...
    'ValueChangedFcn',@(~,~)refresh());
previewAxes=uiaxes(pg,'Tag','BuilderPreviewAxes');
uilabel(pg,'Text',['Preview lấy mẫu đường cong, khoét flare/transition xoay đúng CS, khe và cavity. ' ...
    'Tiếp xúc, Boolean 3D và port phải được kiểm tra trong HFSS.'],'WordWrap','on');

% Build and update are different operations, with an explicit offline mode.
bg=uigridlayout(builderTab,[1 2]); bg.ColumnWidth={'2x','1x'};
form=uigridlayout(bg,[12 3]); form.ColumnWidth={180,'1x',150};
form.RowHeight={36,36,36,36,36,36,36,42,42,110,64,'1x'};
uilabel(form,'Text','Path to ansysedt.exe');
exeField=uieditfield(form,'text','Tag','HFSSExecutable');
uibutton(form,'Text','Browse…','ButtonPushedFcn',@chooseExecutable);
uilabel(form,'Text','HFSS Version'); versionField=uieditfield(form,'text','Value','2021.2','Tag','HFSSVersion');
uibutton(form,'Text','Auto-detect','ButtonPushedFcn',@checkInstallation);
uilabel(form,'Text','Project Name'); projectField=uieditfield(form,'text','Value','Vivaldi_DualPol_Custom', ...
    'Tag','HFSSProjectName','ValueChangedFcn',@(~,~)refresh()); filler(form);
uilabel(form,'Text','Design Name'); designField=uieditfield(form,'text','Value','dual_pol_vivaldi_patch_Wflare_20', ...
    'Tag','HFSSDesignName','ValueChangedFcn',@(~,~)refresh()); filler(form);
uilabel(form,'Text','Output Directory'); outputField=uieditfield(form,'text','Value',outDir, ...
    'Tag','HFSSOutputDirectory','ValueChangedFcn',@(~,~)refresh());
uibutton(form,'Text','Browse…','ButtonPushedFcn',@chooseOutput);
uilabel(form,'Text','Build Mode'); modeChoice=uidropdown(form, ...
    'Items',{'Build From Scratch','Update Existing Project'},'ValueChangedFcn',@(~,~)refresh(), ...
    'Tag','HFSSBuildMode'); filler(form);
uilabel(form,'Text','Existing .aedt (Update)'); sourceField=uieditfield(form,'text', ...
    'Tag','HFSSSourceProject','ValueChangedFcn',@(~,~)refresh());
uibutton(form,'Text','Browse…','ButtonPushedFcn',@chooseSource);
offline=uicheckbox(form,'Text','Offline: chỉ sinh script; chưa có xác nhận HFSS', ...
    'Value',~ispc,'Tag','OfflineScripts','ValueChangedFcn',@(~,~)refresh());
place(offline,8,[1 3]);
uilabel(form,'Text','Timeout (phút)'); timeout=uieditfield(form,'numeric','Value',240, ...
    'Limits',[1 1440],'Tag','HFSSJobTimeout');
uilabel(form,'Text','Timeout không tắt HFSS.','WordWrap','on');
actions=uigridlayout(form,[2 4]); place(actions,10,[1 3]);
connectButton=uibutton(actions,'Text','Connect HFSS','ButtonPushedFcn',@(~,~)hfssAction('connect')); busyButtons(end+1)=connectButton;
uibutton(actions,'Text','Check Installation','ButtonPushedFcn',@checkInstallation);
buildButton=uibutton(actions,'Text','Build From Scratch','Tag','BuildFromScratch', ...
    'ButtonPushedFcn',@(~,~)hfssAction('build')); busyButtons(end+1)=buildButton;
updateButton=uibutton(actions,'Text','Update Existing','Tag','UpdateExisting', ...
    'ButtonPushedFcn',@(~,~)hfssAction('update')); busyButtons(end+1)=updateButton;
validateButton=uibutton(actions,'Text','Validate Geometry','Tag','ValidateHFSS', ...
    'ButtonPushedFcn',@(~,~)hfssAction('validate')); busyButtons(end+1)=validateButton;
saveButton=uibutton(actions,'Text','Save Project','Tag','SaveHFSSProject', ...
    'ButtonPushedFcn',@(~,~)hfssAction('save')); busyButtons(end+1)=saveButton;
analyzeButton=uibutton(actions,'Text','Run Analysis','Tag','RunAnalysis', ...
    'ButtonPushedFcn',@(~,~)hfssAction('analyze')); busyButtons(end+1)=analyzeButton;
uibutton(actions,'Text','Open Output Folder','ButtonPushedFcn',@openOutput);
modelState=uilabel(form,'Text','Chưa có project đã dựng và xác nhận trong HFSS.', ...
    'WordWrap','on','Tag','BuiltModelState'); place(modelState,11,[1 3]);
note=uilabel(form,'Text',['Build tạo project mới bằng API, độc lập với file nguồn. ' ...
    'Update bắt buộc Save As trước sửa. Script được tạo không đồng nghĩa build thành công. ' ...
    'Đóng GUI chỉ dừng theo dõi, không đóng HFSS.'],'WordWrap','on'); place(note,12,[1 3]);
progress=uigridlayout(bg,[4 1]); progress.RowHeight={32,275,40,'1x'};
uilabel(progress,'Text','Tiến độ thực từ HFSS','FontWeight','bold');
stages={'Connect','Create Project','Create Variables','Create Coordinate Systems', ...
    'Build Flare','Build Cavity','Build Metal Sheets','Create Dual-Pol','Create Coax', ...
    'Apply Boolean','Assign Materials','Assign Ports','Create Open Region', ...
    'Create Solution','Validate','Save'};
stageList=uilistbox(progress,'Items',stages,'Tag','HFSSStages');
recheckButton=uibutton(progress,'Text','Recheck timed-out HFSS job','Enable','off', ...
    'ButtonPushedFcn',@recheckDetached,'Tag','RecheckHFSSJob');
runtimeLog=uitextarea(progress,'Editable','off','Value',{'No active HFSS job.'},'Tag','HFSSRuntimeLog');

% Plot only imported numeric data; solver state requires runtime evidence.
rg=uigridlayout(resultsTab,[6 1]); rg.RowHeight={90,55,45,34,'1x',60};
simulationControls=uigridlayout(rg,[2 4]);
uilabel(simulationControls,'Text','Solver Profile'); uilabel(simulationControls,'Text','Frequency sweep');
uilabel(simulationControls,'Text','Excited Port (1 W / 0°)'); uilabel(simulationControls,'Text','Report frequency (GHz)');
profileChoice=uidropdown(simulationControls,'Items',{'Original','QuickTest'},'Tag','SolverProfile', ...
    'ValueChangedFcn',@(~,~)simulationChanged('profile'));
bandChoice=uidropdown(simulationControls,'Items',{'Original 5–20 GHz','Study 6–18 GHz'}, ...
    'Tag','StudyBand','ValueChangedFcn',@(~,~)simulationChanged('band'));
portChoice=uidropdown(simulationControls,'Items',{'1','2'},'Tag','ExcitedPort', ...
    'ValueChangedFcn',@(~,~)refresh());
frequencyField=uieditfield(simulationControls,'numeric','Value',5,'Limits',[.001 1000], ...
    'Tag','ReportFrequencyGHz');
resultActions=uigridlayout(rg,[1 6]);
analyzeButton2=uibutton(resultActions,'Text','Run Simulation','Tag','RunSimulation', ...
    'ButtonPushedFcn',@(~,~)hfssAction('analyze')); busyButtons(end+1)=analyzeButton2;
reportsButton=uibutton(resultActions,'Text','Create/Export HFSS Reports','Tag','CreateHFSSReports', ...
    'ButtonPushedFcn',@(~,~)hfssAction('reports')); busyButtons(end+1)=reportsButton;
uibutton(resultActions,'Text','Load CSV / Add Comparison','ButtonPushedFcn',@importResults);
traceChoice=uidropdown(resultActions,'Items',{'All numeric series'},'ValueChangedFcn',@(~,~)plotResults(), ...
    'Tag','ResultTrace');
uibutton(resultActions,'Text','Measure HPBW','ButtonPushedFcn',@measureHPBW,'Tag','MeasureHPBW');
uibutton(resultActions,'Text','Clear Comparison','ButtonPushedFcn',@clearResults);
resultState=uilabel(rg,'Text','Not Simulated','FontWeight','bold','Tag','SimulationState','WordWrap','on');
hpbwState=uilabel(rg,'Text','HPBW: cần một angular cut gain (dB) thật, có đủ hai giao điểm −3 dB.', ...
    'Tag','HPBWState','WordWrap','on');
resultAxes=uiaxes(rg,'Tag','BuilderResultsAxes'); title(resultAxes,'Not Simulated');
uilabel(rg,'Text',['Original: Setup1, 5 GHz adaptive; 5–20 GHz / 0.25 GHz discrete. ' ...
    'Study 6–18 GHz và QuickTest dùng setup/sweep riêng. QuickTest không thay thế nghiệm Original. ' ...
    'CSV nạp ngoài được ghi rõ nguồn; không coi là xác nhận mô phỏng trong phiên này.'],'WordWrap','on');

mg=uigridlayout(manufacturingTab,[1 2]); mg.ColumnWidth={'1x','1x'};
manufacturing=uigridlayout(mg,[9 2]); manufacturing.ColumnWidth={255,'1x'};
manufacturing.RowHeight={42,42,42,42,70,50,50,50,'1x'};
uilabel(manufacturing,'Text','L_patch hiện tại (mm)'); lengthLabel=uilabel(manufacturing,'Text','');
uilabel(manufacturing,'Text','Chiều dài mục tiêu (mm)'); targetField=uieditfield(manufacturing,'numeric', ...
    'Value',49,'Limits',[.001 Inf],'Tag','TargetLength');
uibutton(manufacturing,'Text','Target 49 mm','ButtonPushedFcn',@(~,~)solveTarget(49));
uibutton(manufacturing,'Text','Target 50 mm','ButtonPushedFcn',@(~,~)solveTarget(50));
uibutton(manufacturing,'Text','Giải L_flare_1 cho mục tiêu','ButtonPushedFcn',@(~,~)solveTarget(targetField.Value));
uilabel(manufacturing,'Text','Chỉ đổi L_flare_1.','WordWrap','on');
targetInfo=uilabel(manufacturing,'Text','Chưa tìm nghiệm mục tiêu.','WordWrap','on'); place(targetInfo,5,[1 2]);
uibutton(manufacturing,'Text','Export Dimensions CSV','ButtonPushedFcn',@exportDimensions);
uibutton(manufacturing,'Text','Export Configuration Report','ButtonPushedFcn',@exportReport);
uibutton(manufacturing,'Text','Export HFSS / App Log','ButtonPushedFcn',@exportLogs);
uibutton(manufacturing,'Text','Save Parameters JSON','ButtonPushedFcn',@saveConfig);
manufacturingNote=uilabel(manufacturing,'Text',['Bảng kích thước là dữ liệu danh nghĩa. ' ...
    'Chưa xác nhận dung sai gia công, CAD Boolean hoặc kết quả RF.'],'WordWrap','on'); place(manufacturingNote,8,[1 2]);
logs=uigridlayout(mg,[2 1]); logs.RowHeight={34,'1x'};
uilabel(logs,'Text','Nhật ký hình học / Automation','FontWeight','bold');
logArea=uitextarea(logs,'Editable','off','Tag','BuilderAppLog');
appendLog('APP_OPEN','Implemented — HFSS Validation Pending.'); refresh();

    function changeParameter(name,value)
        p.(name)=value; appendLog('PARAMETER',sprintf('%s = %.10g',name,value)); refresh();
    end
    function resetOriginal(~,~)
        p=original; appendLog('RESET','Original 17/10/2026 parameters restored.'); refresh();
    end
    function cfg=configuration()
        cfg=struct('exe',exeField.Value,'version',versionField.Value, ...
            'projectName',projectField.Value,'designName',designField.Value, ...
            'outputDir',outputField.Value,'sourcePath',sourceField.Value, ...
            'profile',profileChoice.Value,'excitedPort',str2double(portChoice.Value), ...
            'studyBand',[],'resultFrequencyGHz',frequencyField.Value, ...
            'resultsDir',outputField.Value,'timeoutSeconds',timeout.Value*60);
        if strcmp(bandChoice.Value,'Study 6–18 GHz'), cfg.studyBand=[6 18]; end
    end
    function simulationChanged(changed)
        if strcmp(changed,'profile') && strcmp(profileChoice.Value,'QuickTest')
            if strcmp(bandChoice.Value,'Study 6–18 GHz')
                bandChoice.Value='Original 5–20 GHz';
                appendLog('QUICKTEST_PROFILE','QuickTest uses its own coarse 5–20 GHz sweep; StudyBand1 deselected.');
            end
            samples=[5 10 15 20];
            if ~any(abs(samples-frequencyField.Value)<1e-9)
                [~,nearest]=min(abs(samples-frequencyField.Value)); frequencyField.Value=samples(nearest);
                appendLog('REPORT_FREQUENCY',sprintf('QuickTest report frequency set to its actual %.g GHz sweep sample.',frequencyField.Value));
            end
        elseif strcmp(changed,'band') && strcmp(bandChoice.Value,'Study 6–18 GHz')
            if strcmp(profileChoice.Value,'QuickTest')
                profileChoice.Value='Original';
                appendLog('STUDY_PROFILE','StudyBand1 uses Original accuracy settings; QuickTest deselected.');
            end
            if frequencyField.Value<6 || frequencyField.Value>18
                frequencyField.Value=6;
                appendLog('REPORT_FREQUENCY','Report frequency set to 6 GHz, inside selected StudyBand1.');
            end
        end
        refresh();
    end
    function value=buildIdentity(cfg)
        names={'projectName','designName','outputDir','profile','excitedPort','studyBand'};
        value=struct();
        for ii=1:numel(names), value.(names{ii})=cfg.(names{ii}); end
    end
    function current=isCurrent()
        current=~isempty(lastBuilt) && isequaln(lastBuilt.params,p) && ...
            isequaln(lastBuilt.identity,buildIdentity(configuration()));
    end
    function refresh()
        for ii=1:numel(meta)
            name=meta(ii).name; value=p.(name);
            if isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value)
                fields.(name).Value=value;
                sliders.(name).Limits=[min(meta(ii).range(1),value) max(meta(ii).range(2),value)];
                sliders.(name).Value=value;
            end
        end
        [geometryValid,errors,warnings,geometry]=vivaldiBuilderValidate(p);
        if geometryValid
            names={'L_patch','L_flare','slot_t_L','r_flare','x_feed','z_feed', ...
                'de_L','de_W','h_cabin','h_cabout','h_cabmid'};
            rows=cell(numel(names),3);
            for ii=1:numel(names)
                unit='mm'; if strcmp(names{ii},'r_flare'), unit='1/mm'; end
                rows(ii,:)={names{ii},geometry.(names{ii}),unit};
            end
            dimensionTable.Data=rows; lengthLabel.Text=sprintf('%.9f',geometry.L_patch);
            message=[{'Tham số số học hợp lệ; chưa phải HFSS Validate.'},warnings(:)'];
            parameterInfo.Value=message;
            try
                opts=struct('view',viewChoice.Value,'dimensions',showDimensions.Value, ...
                    'coax',showCoax.Value,'coordinates',showCoordinates.Value);
                vivaldiBuilderPreview(previewAxes,p,geometry,opts);
            catch err
                cla(previewAxes); title(previewAxes,'Mathematical preview unavailable');
                appendLog('PREVIEW_ERROR',err.message);
            end
        else
            dimensionTable.Data={}; lengthLabel.Text='Invalid parameters';
            parameterInfo.Value=errors(:); cla(previewAxes);
            title(previewAxes,'Invalid parameters — preview/build blocked');
        end
        current=isCurrent(); idle=isempty(activeJob) && isempty(detachedJob);
        recheckButton.Enable=onoff(~isempty(detachedJob));
        for ii=1:numel(busyButtons), busyButtons(ii).Enable=onoff(idle); end
        buildButton.Enable=onoff(idle && geometryValid && strcmp(modeChoice.Value,'Build From Scratch'));
        updateButton.Enable=onoff(idle && geometryValid && strcmp(modeChoice.Value,'Update Existing Project'));
        validateButton.Enable=onoff(idle && geometryValid && current);
        saveButton.Enable=onoff(idle && geometryValid && current);
        analyzeButton.Enable=onoff(idle && geometryValid && current);
        analyzeButton2.Enable=analyzeButton.Enable;
        solved=current && lastBuilt.solved;
        reportsButton.Enable=onoff(idle && solved);
        if isempty(lastBuilt)
            modelState.Text='Chưa có project dựng/cập nhật đã được HFSS xác nhận.';
        elseif current
            modelState.Text=['HFSS project đã xác nhận: ' lastBuilt.path];
        else
            modelState.Text='STALE MODEL: tham số hoặc solver setup đã đổi; cần Build / Update lại trước mô phỏng.';
        end
        if ~geometryValid
            status.Text=['Invalid parameters: ' strjoin(errors,' | ')];
        elseif ~isempty(detachedJob)
            status.Text='TIMED_OUT — HFSS có thể vẫn chạy; dùng Recheck trước khi bắt đầu tác vụ tiếp.';
        elseif ~isempty(activeJob)
            status.Text=['HFSS job đang theo dõi: ' upper(activeJob.action)];
        elseif ~current && ~isempty(lastBuilt)
            status.Text='STALE MODEL — cần dựng lại theo cấu hình hiện tại. Not Simulated for current parameters.';
        elseif solved
            status.Text='SIMULATED — nhận xác nhận runtime và dữ liệu thật từ HFSS.';
        else
            status.Text='Not Simulated — hình học toán học sẵn sàng; CAD cần HFSS runtime validation.';
        end
        if isempty(datasets)
            if solved, resultState.Text='SIMULATED — HFSS runtime xác nhận; tạo/xuất báo cáo để vẽ dữ liệu.';
            else, resultState.Text='Not Simulated'; end
        else
            resultState.Text=sprintf('Imported CSV: %d bộ dữ liệu ngoài; %s',numel(datasets), ...
                simulationText(solved));
        end
        fig.UserData=struct('parameters',p,'geometry',geometry,'currentModel',current, ...
            'hasVerifiedProject',~isempty(lastBuilt),'simulated',solved, ...
            'activeJob',activeJob,'detachedJob',detachedJob,'lastBuilt',lastBuilt);
    end
    function validateParameters(~,~)
        [ok,errors,warnings]=vivaldiBuilderValidate(p);
        if ok, appendLog('PARAMETERS_VALID',['Math only. ' strjoin(warnings,' | ')]);
        else, appendLog('PARAMETERS_INVALID',strjoin(errors,' | ')); end
        refresh();
    end
    function assertParameters()
        [ok,errors]=vivaldiBuilderValidate(p);
        assert(ok,'VivaldiBuilder:InvalidParameters','%s',strjoin(errors,newline));
    end
    function hfssAction(action)
        try
            assert(isempty(activeJob) && isempty(detachedJob),'VivaldiBuilder:JobBusy', ...
                'Một tác vụ HFSS đang chạy hoặc đã timeout; dùng Recheck trước khi tạo job mới.');
            cfg=configuration();
            if ~strcmp(action,'connect'), assertParameters(); end
            if any(strcmp(action,{'validate','save','analyze','reports'}))
                assert(isCurrent(),'VivaldiBuilder:StaleModel','Cần build/update đúng snapshot tham số trước thao tác này.');
                cfg.projectPath=lastBuilt.path; cfg.originalPath=lastBuilt.originalPath;
            end
            if strcmp(action,'reports')
                assert(lastBuilt.solved,'VivaldiBuilder:NotSimulated','Chưa có nghiệm được HFSS runtime xác nhận.');
            end
            if strcmp(action,'build')
                cfg.sourcePath=''; % Scratch build never reads a template project.
            elseif strcmp(action,'update')
                assert(isfile(cfg.sourcePath),'VivaldiBuilder:MissingSource','Chọn .aedt nguồn cho Update Existing.');
                cfg.originalPath=cfg.sourcePath;
            end
            requestParams=p;
            if strcmp(action,'connect'), requestParams=original; end
            job=HFSSAutomationBridge('generate',action,cfg,requestParams);
            appendLog('SCRIPT_GENERATED',job.scriptPath);
            runtimeLog.Value={['SCRIPT_GENERATED: ' job.scriptPath], ...
                'Chưa xác nhận thao tác nào hoàn tất trong HFSS.'};
            if offline.Value
                refresh(); status.Text=['SCRIPT_GENERATED — ' upper(action) '; HFSS chưa thực thi.']; return;
            end
            if ~ispc || isempty(cfg.exe) || ~isfile(cfg.exe)
                appendLog('RUNTIME_UNAVAILABLE','Đã giữ script. Cần Windows + ansysedt.exe để chạy Automation.');
                refresh(); status.Text='SCRIPT_GENERATED — HFSS runtime unavailable; CAD/build chưa được xác nhận.'; return;
            end
            activeJob=HFSSAutomationBridge('launch',job,cfg.exe);
            jobParams=p; jobConfig=cfg; lastPollLog='';
            monitor=timer('ExecutionMode','fixedSpacing','Period',1,'BusyMode','drop', ...
                'TimerFcn',@pollJob,'ErrorFcn',@timerError,'Name','VivaldiHFSSMonitor');
            start(monitor); appendLog('RUNTIME_STARTED',activeJob.scriptPath); refresh();
        catch err, showError(err); end
    end
    function pollJob(~,~)
        if closing || isempty(activeJob) || ~isvalid(fig), return; end
        try
            runtime=HFSSAutomationBridge('poll',activeJob);
            if ~isempty(runtime.log)
                raw=asText(runtime.log); runtimeLog.Value=splitlines(raw);
                if ~strcmp(raw,lastPollLog)
                    appendLog('HFSS_RUNTIME',raw); lastPollLog=raw;
                    updateStage(raw);
                end
            end
            status.Text=sprintf('HFSS %s — %s (%.0f s)',upper(activeJob.action),runtime.state,runtime.elapsedSeconds);
            if runtime.terminal
                completed=activeJob; activeJob=[]; disposeMonitor();
                if runtime.success
                    acceptRuntime(completed,runtime); appendLog(runtime.state,runtime.projectPath);
                else
                    appendLog(runtime.state,['HFSS không xác nhận thành công. ' asText(runtime.log)]);
                    if strcmp(runtime.state,'TIMED_OUT')
                        if runtime.alive, detachedJob=completed; end
                        appendLog('TIMEOUT','Dừng theo dõi; HFSS có thể vẫn chạy. Không khởi chạy job trùng trước khi kiểm tra HFSS.');
                    end
                end
                refresh();
                if ~runtime.success, status.Text=[runtime.state ' — xem log; chưa có xác nhận hoàn tất.']; end
            end
        catch err
            activeJob=[]; disposeMonitor(); showError(err); refresh();
        end
    end
    function recheckDetached(~,~)
        if isempty(detachedJob), return; end
        try
            runtime=HFSSAutomationBridge('poll',detachedJob);
            runtimeLog.Value=splitlines(asText(runtime.log));
            if runtime.success
                completed=detachedJob; detachedJob=[]; acceptRuntime(completed,runtime);
                appendLog(runtime.state,'Terminal runtime evidence received after timeout.');
            elseif ~runtime.alive
                detachedJob=[]; appendLog('DETACHED_JOB_ENDED','Process ended without a successful runtime acknowledgment.');
            else
                appendLog('DETACHED_JOB_RUNNING','HFSS process is still active; no duplicate job will be launched.');
            end
            refresh();
        catch err, showError(err); end
    end
    function acceptRuntime(job,runtime)
        if any(strcmp(job.action,{'build','update'}))
            originalPath=''; if isfield(jobConfig,'originalPath'), originalPath=jobConfig.originalPath; end
            lastBuilt=struct('path',runtime.projectPath,'params',jobParams, ...
                'identity',buildIdentity(jobConfig),'solved',false,'validated',true, ...
                'originalPath',originalPath);
        elseif strcmp(job.action,'analyze')
            if ~isempty(lastBuilt) && strcmp(lastBuilt.path,runtime.projectPath), lastBuilt.solved=true; end
        elseif strcmp(job.action,'validate')
            if ~isempty(lastBuilt), lastBuilt.validated=true; end
        end
    end
    function updateStage(textValue)
        entries=regexp(textValue,'(?m)^STAGE\|([^|\r\n]+)\|','tokens');
        if isempty(entries), return; end
        actual=entries{end}{1};
        if ~ismember(actual,stageList.Items), stageList.Items=[stages,{actual}]; end
        stageList.Value=actual;
    end
    function timerError(~,event)
        if closing, return; end
        appendLog('MONITOR_ERROR',asText(event.Data)); activeJob=[]; disposeMonitor(); refresh();
    end
    function disposeMonitor()
        if ~isempty(monitor)
            try, stop(monitor); delete(monitor); catch, end
            monitor=[];
        end
    end
    function checkInstallation(~,~)
        try
            found=HFSSAutomationBridge('detect'); detected=firstExecutable(found);
            if ~isempty(detected), exeField.Value=detected; end
            report=evalc('disp(found)'); appendLog('INSTALLATION_CHECK',report);
            runtimeLog.Value=splitlines(report);
        catch err, showError(err); end
    end
    function chooseExecutable(~,~)
        [name,folder]=uigetfile('*.exe','Chọn ansysedt.exe');
        if isequal(name,0), return; end
        exeField.Value=fullfile(folder,name);
    end
    function chooseSource(~,~)
        [name,folder]=uigetfile('*.aedt','Chọn project nguồn — chỉ Update Existing');
        if isequal(name,0), return; end
        sourceField.Value=fullfile(folder,name); refresh();
    end
    function chooseOutput(~,~)
        folder=uigetdir(outputField.Value,'Thư mục output');
        if isequal(folder,0), return; end
        outputField.Value=folder; refresh();
    end
    function openOutput(~,~)
        try
            if ~isfolder(outputField.Value), mkdir(outputField.Value); end
            if ispc, winopen(outputField.Value); else, web(['file://' outputField.Value],'-browser'); end
        catch err, showError(err); end
    end
    function saveConfig(~,~)
        try
            assertParameters(); [name,folder]=uiputfile('*.json','Lưu thông số hình học');
            if isequal(name,0), return; end
            vivaldiBuilderConfig('save',fullfile(folder,name),p);
            appendLog('CONFIG_SAVED',fullfile(folder,name));
        catch err, showError(err); end
    end
    function loadConfig(~,~)
        try
            [name,folder]=uigetfile('*.json','Nạp thông số hình học'); if isequal(name,0), return; end
            loaded=vivaldiBuilderConfig('load',fullfile(folder,name)); p=loaded;
            appendLog('CONFIG_LOADED',fullfile(folder,name)); refresh();
        catch err, showError(err); end
    end
    function solveTarget(value)
        try
            assertParameters(); [q,report]=vivaldiBuilderTargetLength(p,value); p=q; targetField.Value=value;
            targetInfo.Text=sprintf('L_flare_1 = %.9f mm; L_patch = %.9f mm; sai số %.3g mm. Các biến khác giữ nguyên.', ...
                p.L_flare_1,report.after.L_patch,report.residual);
            appendLog('TARGET_SOLVED',targetInfo.Text); refresh();
        catch err, showError(err); end
    end
    function rows=dimensionRows()
        assertParameters(); rows={'Variable','Value','Unit','Kind'};
        for ii=1:numel(meta), rows(end+1,:)={meta(ii).name,p.(meta(ii).name),meta(ii).unit,'Independent'}; end %#ok<AGROW>
        names=fieldnames(geometry);
        for ii=1:numel(names)
            value=geometry.(names{ii});
            if isnumeric(value) && isscalar(value)
                unit='mm'; if strcmp(names{ii},'r_flare'), unit='1/mm'; end
                rows(end+1,:)={names{ii},value,unit,'Derived'}; %#ok<AGROW>
            end
        end
    end
    function exportDimensions(~,~)
        try
            rows=dimensionRows(); [name,folder]=uiputfile('*.csv','Xuất bảng kích thước danh nghĩa');
            if isequal(name,0), return; end
            writecell(rows,fullfile(folder,name)); appendLog('DIMENSIONS_EXPORTED',fullfile(folder,name));
        catch err, showError(err); end
    end
    function exportReport(~,~)
        try
            assertParameters(); [name,folder]=uiputfile('*.json','Xuất báo cáo cấu hình');
            if isequal(name,0), return; end
            report=struct('application','Vivaldi Dual-Pol Builder Pro','parameters',p, ...
                'builder',configuration(),'dimensions',{dimensionRows()}, ...
                'status','Implemented — HFSS Validation Pending','currentVerifiedModel',isCurrent(), ...
                'lastRuntimeEvidence',lastBuilt,'csvSources',{cellfun(@(x)x.path,datasets,'UniformOutput',false)});
            writeText(fullfile(folder,name),jsonencode(report)); appendLog('CONFIG_REPORT_EXPORTED',fullfile(folder,name));
        catch err, showError(err); end
    end
    function exportLogs(~,~)
        try
            [name,folder]=uiputfile('*.txt','Xuất nhật ký ứng dụng và HFSS'); if isequal(name,0), return; end
            writeText(fullfile(folder,name),strjoin(logLines,newline)); appendLog('LOG_EXPORTED',fullfile(folder,name));
        catch err, showError(err); end
    end
    function importResults(~,~)
        try
            [name,folder]=uigetfile('*.csv','Nạp dữ liệu thật từ HFSS / CSV ngoài');
            if isequal(name,0), return; end
            data=HFSSPostProcessing('load',fullfile(folder,name));
            if isempty(data.x) || isempty(data.y)
                appendLog('CSV_REQUIRES_SELECTION',[data.path ' | ' data.status]);
                resultState.Text=data.status;
                if strcmp(fig.Visible,'on'), uialert(fig,data.status,'CSV cần chọn một frequency / cut'); end
                return;
            end
            data.comparisonLabel=sprintf('%s [imported %d]',name,numel(datasets)+1);
            datasets{end+1}=data;
            labels={'All numeric series'};
            for ii=1:numel(datasets), labels=union(labels,[{'All numeric series'},datasets{ii}.labels(:)'],'stable'); end
            traceChoice.Items=labels; traceChoice.Value='All numeric series';
            appendLog('CSV_IMPORTED',fullfile(folder,name)); plotResults(); refresh();
        catch err, showError(err); end
    end
    function clearResults(~,~)
        datasets={}; traceChoice.Items={'All numeric series'}; traceChoice.Value='All numeric series';
        hpbwState.Text='HPBW: chưa có dữ liệu angular cut thật.';
        plotResults(); refresh();
    end
    function measureHPBW(~,~)
        try
            choices={}; mapping=zeros(0,2);
            for ii=1:numel(datasets)
                data=datasets{ii}; axisName=lower(data.xLabel);
                if ~contains(axisName,'deg') || ~any(contains(axisName,{'theta','phi','angle'})), continue; end
                for jj=1:numel(data.labels)
                    label=lower(data.labels{jj});
                    if ~contains(label,'gain') || ~contains(label,'db'), continue; end
                    if ~strcmp(traceChoice.Value,'All numeric series') && ~strcmp(traceChoice.Value,data.labels{jj}), continue; end
                    choices{end+1}=[data.comparisonLabel ' · ' data.labels{jj}]; %#ok<AGROW>
                    mapping(end+1,:)=[ii jj]; %#ok<AGROW>
                end
            end
            assert(~isempty(choices),'VivaldiBuilder:HPBWData', ...
                'Nạp một angular cut (độ) với cột gain dB; không dùng S-parameter hoặc dữ liệu gain tuyến tính để đo HPBW.');
            selected=1;
            if numel(choices)>1
                [selected,ok]=listdlg('PromptString','Chọn angular cut gain dB để đo HPBW', ...
                    'SelectionMode','single','ListString',choices,'ListSize',[600 180]);
                if ~ok, return; end
            end
            data=datasets{mapping(selected,1)}; series=mapping(selected,2);
            report=HFSSPostProcessing('hpbw',data.x,data.y(:,series));
            if isfinite(report.widthDeg)
                hpbwState.Text=sprintf('HPBW đo từ CSV: %.5g°; peak %.5g° / %.5g dB. %s', ...
                    report.widthDeg,report.peakAngleDeg,report.peakGainDB,choices{selected});
            else
                hpbwState.Text=['HPBW chưa đo được: ' report.reason];
            end
            appendLog('HPBW',hpbwState.Text);
        catch err, showError(err); end
    end
    function plotResults()
        cla(resultAxes); hold(resultAxes,'on'); legends={}; xLabels={}; incompatible=false;
        for ii=1:numel(datasets)
            data=datasets{ii}; selected=1:numel(data.labels);
            if ~strcmp(traceChoice.Value,'All numeric series')
                selected=find(strcmp(data.labels,traceChoice.Value));
            end
            if isempty(selected), continue; end
            if ~isempty(xLabels) && ~strcmp(xLabels{1},data.xLabel), incompatible=true; break; end
            xLabels{end+1}=data.xLabel; %#ok<AGROW>
            for jj=selected(:)'
                plot(resultAxes,data.x,data.y(:,jj),'LineWidth',1.3);
                legends{end+1}=[data.comparisonLabel ' · ' data.labels{jj}]; %#ok<AGROW>
            end
        end
        if incompatible
            cla(resultAxes); title(resultAxes,'Không chồng dữ liệu có trục khác đơn vị/ngữ nghĩa.');
            appendLog('CSV_AXIS_MISMATCH','Clear comparison before loading a different measurement domain.');
        elseif isempty(legends)
            title(resultAxes,'Not Simulated — chưa có dữ liệu CSV phù hợp');
        else
            xlabel(resultAxes,xLabels{1},'Interpreter','none'); ylabel(resultAxes,'Imported numeric values (units in legend)');
            title(resultAxes,'IMPORTED CSV — dữ liệu ngoài, không xác nhận solver trong phiên');
            legend(resultAxes,legends,'Interpreter','none','Location','best'); grid(resultAxes,'on');
        end
        hold(resultAxes,'off');
    end
    function appendLog(event,message)
        logLines{end+1}=sprintf('[%s] %s | %s',datestr(now,31),event,asText(message));
        if exist('logArea','var') && isvalid(logArea), logArea.Value=logLines(:); end
    end
    function showError(err)
        appendLog('ERROR',[err.identifier ' | ' err.message]);
        status.Text=err.message;
        if isvalid(fig) && strcmp(fig.Visible,'on'), uialert(fig,err.message,'Lỗi / chưa được kiểm chứng'); end
    end
    function closeApp(~,~)
        closing=true; disposeMonitor(); % Do not terminate HFSS or its COM process.
        delete(fig);
    end
end

function place(control,row,column)
control.Layout.Row=row; control.Layout.Column=column;
end

function filler(parent)
uilabel(parent,'Text','');
end

function value=onoff(condition)
if condition, value='on'; else, value='off'; end
end

function value=simulationText(solved)
if solved, value='HFSS runtime confirmed a solution for the current snapshot.';
else, value='Not Simulated in this session for the current snapshot.'; end
end

function value=asText(value)
if ischar(value), return; end
if isstring(value), value=strjoin(cellstr(value(:)),newline); return; end
if iscell(value), value=strjoin(cellfun(@asText,value(:),'UniformOutput',false),newline); return; end
if isa(value,'MException'), value=value.message; return; end
value=evalc('disp(value)');
end

function path=firstExecutable(value)
path='';
if isstring(value), value=cellstr(value); end
if ischar(value)
    if isfile(value), path=value; end
elseif iscell(value)
    for k=1:numel(value), path=firstExecutable(value{k}); if ~isempty(path), return; end, end
elseif isstruct(value)
    names={'exe','path','paths','executables','candidates','installations'};
    for j=1:numel(value)
        for k=1:numel(names)
            if isfield(value,names{k}), path=firstExecutable(value(j).(names{k})); end
            if ~isempty(path), return; end
        end
    end
end
end

function writeText(path,value)
fid=fopen(path,'w','n','UTF-8');
assert(fid>=0,'VivaldiBuilder:ExportFailed','Không thể ghi %s.',path);
cleaner=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',value);
end
