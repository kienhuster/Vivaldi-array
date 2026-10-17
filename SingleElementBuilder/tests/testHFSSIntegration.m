function tests = testHFSSIntegration
%TESTHFSSINTEGRATION Opt-in real MATLAB/Windows/HFSS 2021 R2 acceptance tests.
% A filtered/incomplete test is NOT evidence of a successful HFSS run.
% Enable: VIVALDI_RUN_HFSS_TESTS=1 and VIVALDI_HFSS_EXE=<ansysedt.exe>.
% Variation CAD runs additionally require VIVALDI_RUN_VARIATIONS=1.
tests = functiontests(localfunctions);
end

function setupOnce(t)
root = fileparts(fileparts(mfilename('fullpath')));
t.TestData.oldPath = path;
addpath(root);
t.TestData.root = root;
t.TestData.exe = getenv('VIVALDI_HFSS_EXE');
t.TestData.enabled = ispc && strcmp(getenv('VIVALDI_RUN_HFSS_TESTS'),'1');
t.TestData.variations = strcmp(getenv('VIVALDI_RUN_VARIATIONS'),'1');
t.TestData.temp = tempname;
mkdir(t.TestData.temp);
% Evidence is deliberately retained, including failures and partial CAD.
fprintf('\nHFSS integration evidence: %s\n', t.TestData.temp);
end

function teardownOnce(t)
path(t.TestData.oldPath);
end

function testScratchBuildWithoutSource(t)
requireRuntime(t);
p = vivaldiBuilderDefaultParams();
cfg = configuration(t,'scratch_default');
cfg.sourcePath = fullfile(t.TestData.temp,'source_does_not_exist.aedt');
assertFalse(t,isfile(cfg.sourcePath));
job = HFSSAutomationBridge('generate','build',cfg,p);
script = readText(job.scriptPath);
main = regexp(script,'(?s)Sub Main\(\)(.*?)End Sub','tokens','once');
assertNotEmpty(t,main,'Generated scratch job has no Main procedure.');
verifyFalse(t,contains(main{1},'OpenProject'), ...
    'Scratch build must not open a template project.');
verifyTrue(t,contains(main{1},'oDesktop.NewProject()'));
state = execute(t,job,cfg);
verifyTrue(t,state.success, state.log);
inspectSaved(t,job.projectPath,p);
end

function testUpdatePreservesSourceHash(t)
requireRuntime(t);
reference = fullfile(t.TestData.root,'reference','17_10_2026_vivaldi.aedt');
assertTrue(t,isfile(reference),'The read-only reference file is required for Update acceptance.');
referenceHash = sha256(reference);
assertEqual(t,referenceHash, ...
    '631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619');
source = fullfile(t.TestData.temp,'protected_update_source.aedt');
copyfile(reference,source);
beforeHash = sha256(source);
sourceGuard = onCleanup(@()verifySourceHashes(t,source,beforeHash,reference,referenceHash)); %#ok<NASGU>
p = vivaldiBuilderDefaultParams();
p.L_flare_1 = 45; % Original source has an unlinked 2mm mid-cutter move.
cfg = configuration(t,'updated_flare');
cfg.sourcePath = source;
cfg.originalPath = source;
job = HFSSAutomationBridge('generate','update',cfg,p);
assertNotEqual(t,job.projectPath,source);
state = execute(t,job,cfg);
verifyTrue(t,state.success, state.log);
verifyEqual(t,sha256(source),beforeHash,'Update modified its original AEDT source.');
verifyEqual(t,sha256(reference),referenceHash,'Update modified the repository reference.');
inspectSaved(t,job.projectPath,p);
% sourceGuard checks both files even if execution or CAD verification fails.
end

function testVariationFlareLength(t)
runVariation(t,'L_flare_1',45);
end

function testVariationAperture(t)
runVariation(t,'aperture_w',22);
end

function testVariationCavityWidth(t)
runVariation(t,'cavity_w',1.6);
end

function testVariationCavityLength(t)
runVariation(t,'cavity_L',5.5);
end

function testVariationThickness(t)
runVariation(t,'thickness',2.2);
end

function testVariationFeedSlotWidth(t)
runVariation(t,'slot_feed_w',0.6);
end

function runVariation(t,name,value)
requireRuntime(t);
assumeTrue(t,t.TestData.variations, ...
    'NOT RUN: set VIVALDI_RUN_VARIATIONS=1 for six real one-at-a-time CAD rebuilds.');
p = vivaldiBuilderDefaultParams();
p.(name) = value;
cfg = configuration(t,['variation_' name]);
cfg.sourcePath = fullfile(t.TestData.temp,'absent_template.aedt');
job = HFSSAutomationBridge('generate','build',cfg,p);
state = execute(t,job,cfg);
verifyTrue(t,state.success, state.log);
inspectSaved(t,job.projectPath,p);
end

function requireRuntime(t)
assumeTrue(t,t.TestData.enabled, ...
    'NOT RUN: real HFSS acceptance requires Windows and VIVALDI_RUN_HFSS_TESTS=1.');
% Once explicitly enabled, a bad executable is a failure, never a skip.
assertTrue(t,~isempty(t.TestData.exe) && isfile(t.TestData.exe), ...
    'VIVALDI_HFSS_EXE must point to the installed HFSS 2021 R2 ansysedt.exe.');
end

function cfg = configuration(t,name)
out = fullfile(t.TestData.temp,name);
if ~isfolder(out), mkdir(out); end
cfg = struct('exe',t.TestData.exe,'version','2021.2', ...
    'projectName',name,'designName','dual_pol_vivaldi_patch_Wflare_20', ...
    'outputDir',out,'profile','Original','excitedPort',1, ...
    'studyBand',[],'resultFrequencyGHz',5,'timeoutSeconds',1200);
end

function state = execute(t,job,cfg)
job = HFSSAutomationBridge('launch',job,cfg.exe);
timer = tic;
while true
    state = HFSSAutomationBridge('poll',job);
    if state.terminal, break; end
    if toc(timer) > cfg.timeoutSeconds
        assertFail(t,sprintf(['HFSS acceptance timed out after %gs; inspect %s and %s. ' ...
            'The external HFSS process may still be running.\n%s'], ...
            cfg.timeoutSeconds,job.scriptPath,job.statusPath,state.log));
    end
    pause(1);
end
assertTrue(t,state.success, sprintf('HFSS state=%s\n%s',state.state,state.log));
assertTrue(t,isfile(job.projectPath), ...
    'A successful status requires a real saved AEDT artifact.');
% The script must require ValidateDesign()==1 and log its validated stage;
% saved text alone cannot establish that the HFSS validator actually ran.
verifyTrue(t,contains(state.log,'HFSS ValidateDesign returned 1.'), ...
    'Status log must acknowledge the actual successful HFSS validation return value.');
verifyTrue(t,isfile(job.validationPath),'HFSS validation report is missing.');
end

function inspectSaved(t,projectPath,p)
info = vivaldiBuilderInspect(projectPath,'dual_pol_vivaldi_patch_Wflare_20');
expected = {'RadiatingSurface';'cable_in';'cable_out';'port1'; ...
    'Vivaldi_1';'cable_in_1';'cable_out_1';'port2'};
verifyEqual(t,sort(info.topLevelNames(:)),sort(expected), ...
    'Saved model must have exactly the eight active objects, with no model cutters.');
verifyEqual(t,size(info.variables,1),31);
verifyEqual(t,info.portCount,2);
verifyEqual(t,info.radiationCount,1);
verifyTrue(t,info.noArray);
verifyEqual(t,info.solutionType,'DrivenModal');
materialNames = {'Vivaldi_1','cable_in','cable_out','cable_in_1', ...
    'cable_out_1','port1','port2','RadiatingSurface'};
materialValues = {'aluminum','copper','copper','copper','copper', ...
    'vacuum','vacuum','vacuum'};
for j = 1:numel(materialNames)
    k = find(strcmp(info.materials(:,1),materialNames{j}),1);
    assertNotEmpty(t,k,['Missing material for ' materialNames{j}]);
    verifyEqual(t,info.materials{k,2},materialValues{j});
end
verifyVariable(t,info.variables,'L_flare_1',p.L_flare_1,'mm');
verifyVariable(t,info.variables,'aperture_w',p.aperture_w,'mm');
verifyVariable(t,info.variables,'cavity_w',p.cavity_w,'mm');
verifyVariable(t,info.variables,'cavity_L',p.cavity_L,'mm');
verifyVariable(t,info.variables,'thickness',p.thickness,'mm');
verifyVariable(t,info.variables,'slot_feed_w',p.slot_feed_w,'mm');
names = info.variables(:,1);
k = find(strcmp(names,'L_patch'),1);
assertNotEmpty(t,k);
verifyEqual(t,regexprep(info.variables{k,2},'\s',''), ...
    'L_flare_1+slot_t_L-z_feed+h3_slot_feed+slot_feed_w+h_de');
s = info.sourceText;
for j = 1:5
    attributes = regexp(s,['(?s)\$begin ''Attributes''\s+Name=''' ...
        materialNames{j} '''(.*?)\$end ''Attributes'''],'tokens','once');
    assertNotEmpty(t,attributes,['Missing attributes for ' materialNames{j}]);
    verifyTrue(t,contains(attributes{1},'SolveInside=false'), ...
        [materialNames{j} ' must solve outside the metal.']);
end
% These checks inspect the artifact actually saved by HFSS, not generated VBS.
requirePattern(t,s,'SetupType=''HfssDriven''','Driven adaptive setup');
requirePattern(t,s,'Frequency=''5GHz''','5 GHz adaptive frequency');
requirePattern(t,s,'MaximumPasses=50','Original maximum passes');
requirePattern(t,s,'MinimumPasses=5','Original minimum passes');
requirePattern(t,s,'MaxDeltaS=0\.02','Original convergence delta');
requirePattern(t,s,'RangeStart=''5GHz''','Sweep start');
requirePattern(t,s,'RangeEnd=''20GHz''','Sweep end');
requirePattern(t,s,'RangeStep=''0\.25GHz''','Sweep step');
requirePattern(t,s,'Type=''Discrete''','Discrete frequency sweep');
requirePattern(t,s,'SaveFields=true','Saved fields');
requirePattern(t,s,'\$begin ''3D''','3D sphere');
requirePattern(t,s,'\$begin ''Elevation''','Elevation sphere');
requirePattern(t,s,'\$begin ''Azimuth''','Azimuth sphere');
requirePattern(t,s,'Impedance=''50ohm''','50 ohm lumped ports');
requirePattern(t,s,'UseIntLine=true','Integration line assignment');
verifyGreaterThanOrEqual(t,numel(regexp(s,'UseIntLine=true','match')),2);
verifyGreaterThanOrEqual(t,numel(regexp(s,'BoundType=''Lumped Port''','match')),2);
requirePattern(t,s,'BothSides=true','Symmetric metal thickness');
% Automated status/file checks do not replace visual port/contact acceptance.
end

function verifyVariable(t,variables,name,number,unit)
k = find(strcmp(variables(:,1),name),1);
assertNotEmpty(t,k,['Missing variable ' name]);
expression = regexprep(variables{k,2},'\s','');
tokens = regexp(expression,['^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)' unit '$'], ...
    'tokens','once');
assertNotEmpty(t,tokens,['Expected a literal ' unit ' variable: ' name]);
verifyEqual(t,str2double(tokens{1}),number,'AbsTol',1e-10);
end

function requirePattern(t,s,pattern,label)
verifyNotEmpty(t,regexp(s,pattern,'once'),['Missing saved HFSS setting: ' label]);
end

function verifySourceHashes(t,source,beforeHash,reference,referenceHash)
verifyEqual(t,sha256(source),beforeHash,'Update modified its original AEDT source.');
verifyEqual(t,sha256(reference),referenceHash,'Update modified the repository reference.');
end

function s = readText(file)
fid = fopen(file,'r');
assert(fid>=0,'Cannot read generated script.');
cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes = fread(fid,Inf,'*uint8')';
if numel(bytes)>=2 && isequal(bytes(1:2),uint8([255 254]))
    s = native2unicode(bytes(3:end),'UTF-16LE');
else
    s = native2unicode(bytes,'UTF-8');
end
end

function value = sha256(file)
fid = fopen(file,'r');
assert(fid>=0,'Cannot read AEDT file for SHA-256.');
cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
md = javaMethod('getInstance','java.security.MessageDigest','SHA-256');
while ~feof(fid)
    md.update(fread(fid,1048576,'*uint8'));
end
value = lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
