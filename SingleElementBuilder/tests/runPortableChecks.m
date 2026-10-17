function summary = runPortableChecks(outputDirectory)
%RUNPORTABLECHECKS Executable numerical/generator checks (MATLAB or Octave).
% Does NOT execute the MATLAB GUI, Windows VBScript, COM, CAD or an RF solver.
if nargin == 0, outputDirectory = tempname; end
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
root = fileparts(fileparts(mfilename('fullpath')));
old = path; cleanup = onCleanup(@()path(old)); %#ok<NASGU>
addpath(root);
passed = {}; p = vivaldiBuilderDefaultParams(); g = vivaldiBuilderGeometry(p);
actual = [g.L_flare g.r_flare g.x_feed g.z_feed g.L_patch];
expected = [46.4 .0795017124 2.499330861 .663696710 49.236303290];
assert(all(abs(actual-expected) < 1e-9)); record('default scalar regression');
assert(norm(g.cs.RelativeCS1-[10 -1 46.4]) < 1e-10);
assert(norm(g.cs.slot_feed_td-[-g.x_feed 0 g.z_feed]) < 1e-10);
assert(norm(g.coax2-[11 10.549330861 -2.836303290]) < 1e-9);
assert(norm(g.R2*g.R2'-eye(3)) < 1e-12); record('coordinate transforms and coax positions');
for target = [49 50]
    [q,h] = vivaldiBuilderTargetLength(p,target); assert(abs(h.L_patch-target) < 1e-8);
    names = setdiff(fieldnames(p),{'L_flare_1'});
    for k = 1:numel(names), assert(q.(names{k}) == p.(names{k})); end
    record(sprintf('target %g mm preserves other inputs',target));
end
cfg = vivaldiBuilderConfig(); cfg.outputDir = outputDirectory;
reference = fullfile(root,'reference','17_10_2026_vivaldi.aedt'); original = fileread(reference);
assert(isequal(p,vivaldiBuilderReadProject(reference,cfg.design))); record('read-only reference preflight');
cfg.input = 'DOES_NOT_EXIST.aedt';
job = HFSSAutomationBridge('generate','build',cfg,p); script = readScript(job.script);
assert(has(script,'oDesktop.NewProject()') && ~has(script,'OpenProject('));
assert(~has(script,'DOES_NOT_EXIST') && ~isfile(job.output));
assert(~has(script,'oDesign.Analyze ') && ~has(script,'AnalyzeAll'));
assert(has(script,'oEditor.ThickenSheet') && has(script,'"BothSides:=", True'));
assert(has(script,'CLng(result) <> 1') && has(script,'oDesktop.CloseProject created'));
assert(has(script,'oEditor.SeparateBody')); record('scratch generation independent of source and no automatic solve');
sequence = {'oEditor.CreateEquationSurface','oEditor.Copy','oEditor.Subtract','oEditor.Rotate', ...
    'oEditor.CreateRectangle','oEditor.Unite','oEditor.ThickenSheet','oEditor.DuplicateAroundAxis', ...
    'oEditor.Move','oEditor.CreateBox','oEditor.Unite','oEditor.CreateCylinder', ...
    'oBoundary.AssignLumpedPort','oEditor.CreateRegion','oAnalysis.InsertSetup', ...
    'oRad.InsertFarFieldSphereSetup','Inventory','ValidateModel','State "BUILT"'};
position = 1;
for k = 1:numel(sequence)
    index = strfind(script(position:end),sequence{k});
    assert(~isempty(index),['Missing or out of order: ' sequence{k}]);
    position = position+index(1)+numel(sequence{k})-1;
end
record('CAD dependency and validation sequence');
for k = 1:6, assert(has(script,sprintf('coax_cutter_%d',k))); end
assert(~has(lower(script),'ptfe') && ~has(lower(script),'fr4'));
assert(has(script,'OUTER_TO_INNER')); record('six coax cutters and geometry-derived port lines');
names = {'L_flare_1','aperture_w','cavity_w','cavity_L','thickness','slot_feed_w'};
values = [45 22 1.6 5.5 2.2 .6];
for k = 1:6
    q = p; q.(names{k}) = values(k); [ok,~,~,h] = vivaldiBuilderValidate(q); assert(ok);
    assert(norm(h.cs.RelativeCS1-h.cs.patch_td-[0 -q.thickness/2 0]) < 1e-10);
    job = HFSSAutomationBridge('generate','build',cfg,q);
    assert(isfile(job.script)); record(['variation formulas / script: ' names{k}]);
end
cfg.input = reference; q = p; q.L_flare_1 = 45;
job = HFSSAutomationBridge('generate','update',cfg,q); script = readScript(job.script);
saved = strfind(script,['oProject.SaveAs ' HFSSScript.quote(job.output)]);
changed = strfind(script,'oDesign.ChangeProperty ');
assert(saved(1) < changed(1) && has(script,'oBoundary.EditLumpedPort'));
assert(~has(script,'CreateEquationSurface') && strcmp(fileread(reference),original));
record('update SaveAs precedes edits and source is unchanged');
failed = false;
try, HFSSAutomationBridge('generate','simulate',cfg,q);
catch error, failed = strcmp(error.identifier,'VivaldiBuilder:StaleParameters'); end
assert(failed); record('stale GUI simulation rejected');
cfg.profile = 'QuickTest'; job = HFSSAutomationBridge('generate','simulate',cfg,p);
script = readScript(job.script);
assert(has(script,'oDesign.Analyze "QuickTest"'));
assert(has(script,'oAnalysis.EditFrequencySweep "QuickTest", "Sweep"'));
assert(~has(script,'oAnalysis.EditFrequencySweep "Setup1"'));
record('QuickTest independent of original setup');
for action = {'validate','save','reports'}
    job = HFSSAutomationBridge('generate',action{1},cfg,p); script = readScript(job.script);
    assert(~has(script,'oDesign.Analyze ') && ~has(script,'AnalyzeAll'));
    assert(has(script,'oProject.SaveAs ') && has(script,'ValidateModel'));
end
record('validate, save and report jobs never launch a solve');
configFile = fullfile(outputDirectory,'config.json');
vivaldiBuilderIO('save',configFile,p); assert(isequal(vivaldiBuilderIO('load',configFile),p));
record('configuration JSON round trip');
% Clearly synthetic math fixtures; no RF data is generated for the product.
result = HFSSPostProcessing.hpbw([-10 0 10],[-3 0 -3]); assert(abs(result.degrees-20)<1e-12);
result = HFSSPostProcessing.hpbw([0 1 2],[0 -1 -2]); assert(isnan(result.degrees));
record('HPBW crossings and insufficient-cut handling');
bad = p; bad.r_cabin = p.r_cabmid; assert(~vivaldiBuilderValidate(bad));
bad = p; bad.them = -6.4; assert(~vivaldiBuilderValidate(bad));
bad = p; bad.h2 = NaN; assert(~vivaldiBuilderValidate(bad)); record('invalid geometry inputs rejected');
job = HFSSAutomationBridge('generate','connect',cfg,p);
writeStatus(job.status,sprintf('STATE|RUNNING|now|Mock stage\r\n'));
state = HFSSAutomationBridge('poll',job); assert(~state.terminal && strcmp(state.state,'RUNNING'));
writeStatus(job.status,sprintf('STATE|RUNNING|now|Mock stage\r\nSTATE|FAILED|now|Mock failure\r\n'));
state = HFSSAutomationBridge('poll',job); assert(state.terminal && strcmp(state.state,'FAILED'));
record('status parser distinguishes pending from failed (mock log)');
job = HFSSAutomationBridge('generate','connect',cfg,p);
job.process = struct('isAlive',@()false); job.started = tic; job.timeout = 120;
state = HFSSAutomationBridge('poll',job);
assert(~state.terminal && strcmp(state.state,'WAITING_FOR_SCRIPT'));
job.timeout = -1; state = HFSSAutomationBridge('poll',job);
assert(state.timedOut && strcmp(state.state,'TIMED_OUT'));
record('detached launcher and timeout never imply success (mock process)');
summary = struct('runner',version,'passed',{passed},'count',numel(passed), ...
    'unrun',{{'MATLAB unit suite','uifigure/preview','Windows VBScript/COM','HFSS CAD/validation/solve','MATLAB table/CSV import'}});
fid = fopen(fullfile(outputDirectory,'portable-results.json'),'w');
fprintf(fid,'%s\n',jsonencode(summary)); fclose(fid);
fprintf('%d portable check groups passed. MATLAB GUI and HFSS integration remain unrun.\n',numel(passed));
    function record(name)
        passed{end+1} = name; fprintf('PASS: %s\n',name);
    end
end
function yes = has(text,pattern), yes = ~isempty(strfind(text,pattern)); end %#ok<STREMP>
function text = readScript(file)
text = HFSSScript.read(file);
end
function writeStatus(file,text)
fid = fopen(file,'wb'); fwrite(fid,[255 254],'uint8');
fwrite(fid,unicode2native(text,'UTF-16LE'),'uint8'); fclose(fid);
end
