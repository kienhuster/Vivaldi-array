function tests=testBuilderBridge
% Unit tests of generation and status protocol, not execution of COM/HFSS.
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;
t.TestData.root=fileparts(fileparts(mfilename('fullpath'))); addpath(t.TestData.root);
t.TestData.folder=tempname; mkdir(t.TestData.folder);
t.TestData.reference=fullfile(t.TestData.root,'reference','17_10_2026_vivaldi.aedt');
end
function teardownOnce(t)
path(t.TestData.oldPath); rmdir(t.TestData.folder,'s');
end
function testGeneratedDoesNotMeanBuilt(t)
job=HFSSAutomationBridge('generate','build',config(t,'offline'),vivaldiBuilderDefaultParams());
s=HFSSAutomationBridge('poll',job);
verifyEqual(t,s.state,'SCRIPT_GENERATED'); verifyFalse(t,s.success); verifyFalse(t,s.terminal);
verifyFalse(t,isfile(job.projectPath)); verifyTrue(t,isfile(job.scriptPath));
verifyFalse(t,isfile([job.projectPath '.builder.json']));
again=HFSSAutomationBridge('generate','build',config(t,'offline'),vivaldiBuilderDefaultParams());
verifyNotEqual(t,again.scriptPath,job.scriptPath);
end
function testIndependentVariablesPrecedeDependentExpressions(t)
job=HFSSAutomationBridge('generate','build',config(t,'variables'),vivaldiBuilderDefaultParams());
s=readScript(job.scriptPath);
verifyLessThan(t,position(s,'Array("NAME:them", "PropType:="'),position(s,'Array("NAME:slot_t_L", "PropType:="'));
verifyLessThan(t,position(s,'Array("NAME:aperture_w", "PropType:="'),position(s,'Array("NAME:r_flare", "PropType:="'));
verifyLessThan(t,position(s,'oMaterials.AddMaterial'),position(s,'oEditor.CreateEquationSurface'));
end
function testExistingOutputsAndSourceAreProtected(t)
cfg=config(t,'existing');
file=fullfile(cfg.outputDir,[cfg.projectName '.aedt']); write(file,'existing work');
verifyError(t,@()HFSSAutomationBridge('generate','build',cfg,vivaldiBuilderDefaultParams()),'VivaldiBuilder:ExistingOutput');
verifyEqual(t,fileread(file),'existing work');
cfg=config(t,'original'); cfg.projectPath=t.TestData.reference;
verifyError(t,@()HFSSAutomationBridge('generate','save',cfg,vivaldiBuilderDefaultParams()),'VivaldiBuilder:UnownedProject');
end
function testUpdateSavesCopyBeforeMutation(t)
cfg=config(t,'update'); cfg.sourcePath=t.TestData.reference;
source=fileread(cfg.sourcePath); p=vivaldiBuilderDefaultParams(); p.L_flare_1=45;
job=HFSSAutomationBridge('generate','update',cfg,p); s=readScript(job.scriptPath);
verifyEqual(t,fileread(cfg.sourcePath),source);
verifyLessThan(t,position(s,'oProject.SaveAs '),position(s,'Array("NAME:ChangedProps"'));
verifyLessThan(t,position(s,'workingCopyReady = True'),position(s,'Array("NAME:ChangedProps"'));
verifyFalse(t,isfile(job.projectPath));
verifyFalse(t,contains(s,'oDesign.Analyze '));
end
function testUnlinkedOriginalHistoryRejectsThicknessUpdate(t)
cfg=config(t,'thickness'); cfg.sourcePath=t.TestData.reference;
p=vivaldiBuilderDefaultParams(); p.thickness=2.2;
verifyError(t,@()HFSSAutomationBridge('generate','update',cfg,p),'VivaldiBuilder:UnlinkedSourceHistory');
end
function testUnknownSourceFormulaRejected(t)
cfg=config(t,'formula'); cfg.sourcePath=fullfile(t.TestData.folder,'bad_source.aedt');
write(cfg.sourcePath,strrep(fileread(t.TestData.reference),'6.4mm+them','7mm+them'));
verifyError(t,@()HFSSAutomationBridge('generate','update',cfg,vivaldiBuilderDefaultParams()),'VivaldiBuilder:FormulaMismatch');
end
function testStatusIdentityAndExpectedAction(t)
job=HFSSAutomationBridge('generate','connect',config(t,'status'),vivaldiBuilderDefaultParams());
writeStatus(job,['JOB|wrong' newline 'STATE|CONNECTED|time|wrong']);
s=HFSSAutomationBridge('poll',job); verifyEqual(t,s.state,'FAILED'); verifyFalse(t,s.success);
writeStatus(job,['JOB|' job.id newline 'STATE|BUILT|time|wrong action']);
s=HFSSAutomationBridge('poll',job); verifyFalse(t,s.success);
writeStatus(job,['JOB|' job.id newline 'STATE|CONNECTED|time|mocked status protocol only']);
s=HFSSAutomationBridge('poll',job); verifyTrue(t,s.success); verifyTrue(t,s.terminal);
% This verifies protocol parsing, never actual connection or licensing.
end
function testTimeoutDoesNotKillProcess(t)
job=HFSSAutomationBridge('generate','connect',config(t,'timeout'),vivaldiBuilderDefaultParams());
job.startedAt=now-1; s=HFSSAutomationBridge('poll',job);
verifyEqual(t,s.state,'TIMED_OUT'); verifyFalse(t,s.success);
verifyTrue(t,contains(s.log,'not terminated'));
end
function testQuotingAndInputControls(t)
verifyEqual(t,HFSSScriptWriter.q('A"B'),'"A""B"');
verifyError(t,@()HFSSScriptWriter.q(['x' newline 'y']),'VivaldiBuilder:ScriptValue');
cfg=config(t,'invalid'); cfg.projectName='..\source';
verifyError(t,@()HFSSAutomationBridge('generate','build',cfg,vivaldiBuilderDefaultParams()),'VivaldiBuilder:ProjectName');
cfg=config(t,'invalid_profile'); cfg.profile='QuickTest'; cfg.studyBand=[6 18];
verifyError(t,@()HFSSAutomationBridge('generate','build',cfg,vivaldiBuilderDefaultParams()),'VivaldiBuilder:Profile');
end
function cfg=config(t,name)
cfg=struct('outputDir',t.TestData.folder,'projectName',name, ...
    'designName','dual_pol_vivaldi_patch_Wflare_20','version','2021.2');
end
function result=position(s,needle)
result=strfind(s,needle); assert(~isempty(result),'Missing expected script text.'); result=result(1);
end
function out=readScript(file)
out=HFSSRuntimeSupport.readUTF16(file);
end
function write(file,text)
fid=fopen(file,'w','n','UTF-8'); c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',text);
end
function writeStatus(job,text)
HFSSRuntimeSupport.writeUTF16(job.statusPath,[text sprintf('\r\n')]);
end
