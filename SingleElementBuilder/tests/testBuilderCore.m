function tests = testBuilderCore
tests = functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath = path;
t.TestData.root = fileparts(fileparts(mfilename('fullpath'))); addpath(t.TestData.root);
t.TestData.temp = tempname; mkdir(t.TestData.temp);
end
function teardownOnce(t)
path(t.TestData.oldPath); rmdir(t.TestData.temp,'s');
end
function testOriginalNumbersAndTransforms(t)
p = vivaldiBuilderDefaultParams(); [ok,errors,~,g] = vivaldiBuilderValidate(p);
verifyTrue(t,ok,strjoin(errors,newline));
verifyEqual(t,g.L_flare,46.4,'AbsTol',1e-12);
verifyEqual(t,g.r_flare,.0795017124,'AbsTol',1e-10);
verifyEqual(t,g.x_feed,2.499330861,'AbsTol',1e-9);
verifyEqual(t,g.z_feed,.663696710,'AbsTol',1e-9);
verifyEqual(t,g.L_patch,49.236303290,'AbsTol',1e-9);
verifyEqual(t,g.cs.slot_feed_td,[-g.x_feed 0 g.z_feed],'AbsTol',1e-12);
verifyEqual(t,g.cs.RelativeCS1,[10 -1 46.4],'AbsTol',1e-12);
verifyEqual(t,g.coax1,[.450669139 0 -2.836303290],'AbsTol',1e-9);
verifyEqual(t,g.coax2,[11 10.549330861 -2.836303290],'AbsTol',1e-9);
verifyEqual(t,g.R2*g.R2',eye(3),'AbsTol',1e-12);
verifyEqual(t,g.bodyBounds,[-10 -1 g.z_base 12 21 46.4],'AbsTol',1e-12);
end
function testTargetLengthOnlyChangesFlare(t)
p = vivaldiBuilderDefaultParams(); names = setdiff(fieldnames(p),{'L_flare_1'});
for target = [49 50]
    [q,g] = vivaldiBuilderTargetLength(p,target);
    verifyEqual(t,g.L_patch,target,'AbsTol',1e-8);
    for k = 1:numel(names), verifyEqual(t,q.(names{k}),p.(names{k})); end
end
end
function testInvalidParameters(t)
p = vivaldiBuilderDefaultParams(); cases = {p,p,p,p,p,p,p};
cases{1}.h_de = 0; cases{2}.aperture_w = p.slot_feed_w;
cases{3}.r_cabin = p.r_cabmid; cases{4}.them = -6.4;
cases{5}.h2 = NaN; cases{6}.deg_slot_t = 90; cases{7}.cavity_w = 1+1i;
for k = 1:numel(cases), verifyFalse(t,vivaldiBuilderValidate(cases{k})); end
end
function testSixParameterVariations(t)
p = vivaldiBuilderDefaultParams(); initial = vivaldiBuilderGeometry(p);
names = {'L_flare_1','aperture_w','cavity_w','cavity_L','thickness','slot_feed_w'};
values = [45 22 1.6 5.5 2.2 .6];
for k = 1:numel(names)
    q = p; q.(names{k}) = values(k); [ok,e,~,g] = vivaldiBuilderValidate(q);
    verifyTrue(t,ok,strjoin(e,newline));
    verifyEqual(t,g.cs.RelativeCS1,g.cs.patch_td+[0 -q.thickness/2 0],'AbsTol',1e-12);
    verifyEqual(t,g.coax2,g.transform2(g.coax1),'AbsTol',1e-12);
    if strcmp(names{k},'L_flare_1'), verifyGreaterThan(t,g.L_patch,initial.L_patch); end
end
end
function testReferenceProjectPreflight(t)
file = fullfile(t.TestData.root,'reference','17_10_2026_vivaldi.aedt');
p = vivaldiBuilderReadProject(file,'dual_pol_vivaldi_patch_Wflare_20');
verifyEqual(t,p,vivaldiBuilderDefaultParams());
verifyError(t,@()vivaldiBuilderReadProject(file,'HFSSDesign1'),'VivaldiBuilder:Formula');
end
function testChangedFormulaIsRejected(t)
text = fileread(fullfile(t.TestData.root,'reference','17_10_2026_vivaldi.aedt'));
file = fullfile(t.TestData.temp,'changed.aedt');
writeText(file,strrep(text,'6.4mm+them','7mm+them'));
verifyError(t,@()vivaldiBuilderReadProject(file,'dual_pol_vivaldi_patch_Wflare_20'),'VivaldiBuilder:Formula');
end
function testBuildDoesNotUseOriginalProject(t)
cfg = config(t); cfg.input = 'MISSING_SOURCE.aedt';
job = HFSSAutomationBridge('generate','build',cfg,vivaldiBuilderDefaultParams()); script = readScript(job.script);
verifyTrue(t,contains(script,'oDesktop.NewProject()'));
verifyFalse(t,contains(script,'OpenProject('));
verifyFalse(t,contains(script,'MISSING_SOURCE'));
verifyFalse(t,contains(script,'AnalyzeAll'));
verifyFalse(t,contains(script,'oDesign.Analyze '));
verifyFalse(t,isfile(job.output)); % Script generation is explicitly not a completed build.
sequence = {'oEditor.CreateEquationSurface','oEditor.Copy','oEditor.Subtract', ...
    'oEditor.Rotate','oEditor.CreateRectangle','oEditor.Unite','oEditor.ThickenSheet', ...
    'oEditor.DuplicateAroundAxis','oEditor.Move','oEditor.CreateBox','oEditor.Unite', ...
    'oEditor.CreateCylinder','oBoundary.AssignLumpedPort','oEditor.CreateRegion', ...
    'oAnalysis.InsertSetup','oRad.InsertFarFieldSphereSetup','Inventory','ValidateModel','State "BUILT"'};
position = 1;
for k = 1:numel(sequence)
    next = strfind(script(position:end),sequence{k});
    verifyNotEmpty(t,next,['Missing/incorrect order: ' sequence{k}]);
    if isempty(next), return; end
    position = position+next(1)+numel(sequence{k})-1;
end
verifyTrue(t,contains(script,'"BothSides:=", True'));
verifyTrue(t,contains(script,'NAME:Reference CS'));
verifyTrue(t,contains(script,'OUTER_TO_INNER'));
verifyTrue(t,contains(script,'CLng(result) <> 1')); % 0 must never count as passed.
end
function testSixCoaxCuttersAndNoExtraDielectric(t)
job = HFSSAutomationBridge('generate','build',config(t),vivaldiBuilderDefaultParams());
script = readScript(job.script);
for k = 1:6, verifyTrue(t,contains(script,sprintf('coax_cutter_%d',k))); end
verifyTrue(t,contains(script,'coax_cutter_1,coax_cutter_2,coax_cutter_3,coax_cutter_4,coax_cutter_5,coax_cutter_6'));
verifyFalse(t,contains(lower(script),'ptfe')); verifyFalse(t,contains(lower(script),'fr4'));
verifyFalse(t,contains(script,'ParametricSetup'));
end
function testUpdateProtectsSourceBeforeEditing(t)
cfg = config(t); cfg.input = fullfile(t.TestData.root,'reference','17_10_2026_vivaldi.aedt');
original = fileread(cfg.input); p = vivaldiBuilderDefaultParams(); p.L_flare_1 = 45;
job = HFSSAutomationBridge('generate','update',cfg,p); script = readScript(job.script);
verifyEqual(t,fileread(cfg.input),original);
verifyTrue(t,contains(script,'oDesktop.OpenProject('));
saved = strfind(script,['oProject.SaveAs ' HFSSScript.quote(job.output)]);
changed = strfind(script,'oDesign.ChangeProperty ');
verifyLessThan(t,saved(1),changed(1));
verifyFalse(t,contains(script,'CreateEquationSurface'));
verifyFalse(t,contains(script,'NAME:NewProps'));
verifyTrue(t,contains(script,'EditLumpedPort'));
verifyNotEqual(t,job.output,cfg.input);
verifyFalse(t,contains(script,'oDesign.Analyze '));
end
function testStaleSimulationParametersRejected(t)
cfg = config(t); cfg.input = fullfile(t.TestData.root,'reference','17_10_2026_vivaldi.aedt');
p = vivaldiBuilderDefaultParams(); p.L_flare_1 = 45;
verifyError(t,@()HFSSAutomationBridge('generate','simulate',cfg,p),'VivaldiBuilder:StaleParameters');
end
function testInvalidNamesAndSweepRejected(t)
cfg = config(t); cfg.project = '../source';
verifyError(t,@()HFSSAutomationBridge('generate','build',cfg,vivaldiBuilderDefaultParams()),'VivaldiBuilder:Name');
cfg = config(t); cfg.fStep = 0;
verifyError(t,@()HFSSAutomationBridge('generate','build',cfg,vivaldiBuilderDefaultParams()),'MATLAB:expectedPositive');
end
function testQuickTestNeverEditsOriginalSetup(t)
cfg = config(t); cfg.profile = 'QuickTest';
cfg.input = fullfile(t.TestData.root,'reference','17_10_2026_vivaldi.aedt');
job = HFSSAutomationBridge('generate','simulate',cfg,vivaldiBuilderDefaultParams()); script = readScript(job.script);
verifyTrue(t,contains(script,'oDesign.Analyze "QuickTest"'));
verifyTrue(t,contains(script,'oAnalysis.EditFrequencySweep "QuickTest", "Sweep"'));
verifyFalse(t,contains(script,'oAnalysis.EditFrequencySweep "Setup1"'));
verifyFalse(t,contains(script,'AnalyzeAll'));
end
function testTerminalAndFailureStates(t)
job = HFSSAutomationBridge('generate','connect',config(t),vivaldiBuilderDefaultParams());
fid = fopen(job.status,'w','n','UTF-16LE'); fwrite(fid,65279,'uint16');
fprintf(fid,'STATE|RUNNING|now|Create Coax\r\n'); fclose(fid);
state = HFSSAutomationBridge('poll',job); verifyFalse(t,state.terminal);
fid = fopen(job.status,'a','n','UTF-16LE'); fprintf(fid,'STATE|FAILED|now|Mock Boolean error\r\n'); fclose(fid);
state = HFSSAutomationBridge('poll',job); verifyTrue(t,state.terminal); verifyEqual(t,state.state,'FAILED');
end
function testConfigAndDimensionExports(t)
p = vivaldiBuilderDefaultParams(); file = fullfile(t.TestData.temp,'config.json');
vivaldiBuilderIO('save',file,p); verifyEqual(t,vivaldiBuilderIO('load',file),p);
T = vivaldiBuilderIO('dimensions',fullfile(t.TestData.temp,'dimensions.csv'),p);
verifyEqual(t,T.Nominal(strcmp(T.Variable,'L_patch')),49.236303290,'AbsTol',1e-9);
verifyEqual(t,T.Unit(strcmp(T.Variable,'r_flare')),{'mm^-1'});
end
function testDetachedLauncherAndTimeout(t)
job = HFSSAutomationBridge('generate','connect',config(t),vivaldiBuilderDefaultParams());
job.process = struct('isAlive',@()false); job.started = tic; job.timeout = 120;
state = HFSSAutomationBridge('poll',job); verifyFalse(t,state.terminal);
verifyEqual(t,state.state,'WAITING_FOR_SCRIPT');
job.timeout = -1; state = HFSSAutomationBridge('poll',job);
verifyTrue(t,state.timedOut); verifyEqual(t,state.state,'TIMED_OUT');
end
function testCSVAndHPBWMath(t)
% Explicit synthetic fixtures test the importer/math, never claim RF results.
file = fullfile(t.TestData.temp,'fixture.csv'); writeText(file,sprintf('Theta [deg],Gain [dB]\n-10,-3\n0,0\n10,-3\n'));
data = HFSSPostProcessing.loadCSV(file,'Theta [deg]',{'Gain [dB]'});
result = HFSSPostProcessing.hpbw(data.x,data.y); verifyEqual(t,result.degrees,20,'AbsTol',1e-12);
result = HFSSPostProcessing.hpbw([0 1 2],[0 -1 -2]); verifyTrue(t,isnan(result.degrees));
verifyError(t,@()HFSSPostProcessing.hpbw([0 0 1],[-3 0 -3]),'VivaldiBuilder:HPBW');
end
function testTypedScriptEscapesQuotes(t)
w = HFSSScript(); w.api('object','Method',{'NAME:Test','Value:=','A "quoted" path'});
verifyTrue(t,contains(w.text(),'A ""quoted"" path'));
verifyError(t,@()HFSSScript.quote(sprintf('bad\nvalue')),'VivaldiBuilder:VBString');
end
function cfg = config(t)
cfg = vivaldiBuilderConfig(); cfg.outputDir = t.TestData.temp;
end
function text = readScript(file)
text = HFSSScript.read(file);
end
function writeText(file,text)
fid = fopen(file,'w','n','UTF-8'); cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',text);
end
