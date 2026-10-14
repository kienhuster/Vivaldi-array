function tests = testVivaldiElementDesigner
% Run: results = runtests('tests'); assertSuccess(results)
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath')));
t.TestData.oldPath=path; addpath(root);
t.TestData.root=root;
t.TestData.temp=tempname; mkdir(t.TestData.temp);
end
function teardownOnce(t)
path(t.TestData.oldPath); rmdir(t.TestData.temp,'s');
end
function testDefaultParameters(t)
p=vivaldiDefaultParams(); [ok,e,~,g]=vivaldiValidateParams(p);
verifyTrue(t,ok,strjoin(e,newline));
verifyEqual(t,g.L_flare,46.4,'AbsTol',1e-12);
verifyEqual(t,g.r_flare,.0795017,'AbsTol',5e-8);
verifyEqual(t,g.L_patch,49.2363033,'AbsTol',1e-7);
verifyEqual(t,2*g.flareHalfWidth(end),p.aperture_w,'AbsTol',1e-10);
verifyEqual(t,g.h_cabmid,p.h_de,'AbsTol',1e-12);
end
function testFlareLengthChange(t)
p=vivaldiDefaultParams(); before=vivaldiCalculateGeometry(p);
p.L_flare_1=45; [ok,~,~,after]=vivaldiValidateParams(p);
verifyTrue(t,ok); verifyEqual(t,after.L_flare,51.4,'AbsTol',1e-12);
verifyLessThan(t,after.r_flare,before.r_flare);
verifyGreaterThan(t,after.L_patch,before.L_patch);
verifyNotEqual(t,after.u(100),before.u(100));
verifyLessThan(t,p.slot_feed_w/2*exp(after.r_flare*20),p.slot_feed_w/2*exp(before.r_flare*20));
end
function testTarget49And50(t)
p=vivaldiDefaultParams();
for target=[49 50]
    [q,c]=vivaldiSolveTargetLength(p,target);
    verifyLessThan(t,abs(c.after.L_patch-target),.001);
    names=setdiff(fieldnames(p),{'L_flare_1'});
    for k=1:numel(names), verifyEqual(t,q.(names{k}),p.(names{k})); end
    verifyNotEqual(t,q.L_flare_1,p.L_flare_1);
end
end
function testImpossibleTarget(t)
p=vivaldiDefaultParams();
verifyError(t,@()vivaldiSolveTargetLength(p,500,[1 100]),'Vivaldi:NoRoot');
end
function testInvalidParameters(t)
p=vivaldiDefaultParams();
bad={p,p,p,p,p,p,p,p};
bad{1}.aperture_w=p.slot_feed_w;
bad{2}.L_flare_1=-1; bad{3}.h2=NaN;
bad{4}.r_cabin=p.r_cabmid; bad{5}.them=-7;
bad{6}.deg_slot_t=90; bad{7}.aperture_w=Inf; bad{8}.h_de=1+1i;
for k=1:numel(bad), [ok,e]=vivaldiValidateParams(bad{k}); verifyFalse(t,ok); verifyNotEmpty(t,e); end
end
function testConvenienceRangesAreNotPhysicalLimits(t)
p=vivaldiDefaultParams(); p.L_flare_1=150; p.positionx=-.1;
[ok]=vivaldiValidateParams(p); verifyTrue(t,ok);
end
function testSaveLoad(t)
p=vivaldiDefaultParams(); p.L_flare_1=45; p.them=.125;
file=fullfile(t.TestData.temp,'config.json');
vivaldiSaveConfig('save',file,p); q=vivaldiSaveConfig('load',file);
verifyEqual(t,q,p);
end
function testInvalidConfigRejected(t)
file=fullfile(t.TestData.temp,'bad.json'); writeText(file,'{"schema":"wrong","params":{}}');
verifyError(t,@()vivaldiSaveConfig('load',file),'Vivaldi:ConfigSchema');
end
function testSourceInventory(t)
info=vivaldiInspectProject(fullfile(t.TestData.root,'Vivaldi_23_9_2026.aedt'));
verifyEqual(t,info.designs,{'dual_pol_vivaldi_patch_Wflare_20'});
verifyEqual(t,size(info.variables,1),31);
parts=info.parts; top=cellfun(@(v)strcmp(v.section,'ToplevelParts'),parts);
verifyEqual(t,sum(top),8); verifyEqual(t,sum(~top),17);
verifyEqual(t,sum(cellfun(@(v)strcmp(v.type,'Lumped Port'),info.boundaries)),2);
verifyEqual(t,sum(cellfun(@(v)strcmp(v.type,'Radiation'),info.boundaries)),1);
end
function testScriptProtectionAndNoAutomaticSolve(t)
p=vivaldiDefaultParams(); p.L_flare_1=45; cfg=config(t);
source=fileread(cfg.input); job=vivaldiHFSSBridge('generate','update',cfg,p);
script=readScript(job.script);
verifyEqual(t,fileread(cfg.input),source);
verifyTrue(t,contains(script,'oProject.SaveAs'));
verifyTrue(t,contains(script,'ChangeProperty'));
verifyFalse(t,contains(script,'AnalyzeAll'));
verifyFalse(t,contains(script,'EditSources'));
verifyFalse(t,contains(script,'DuplicateAlongLine'));
verifyFalse(t,contains(script,'SetVariableValue "L_patch"'));
verifyLessThan(t,strfind(script,'oProject.SaveAs'),strfind(script,'oDesign.ChangeProperty'));
verifyTrue(t,contains(script,'If Not Check("SaveAs before modifying variables") Then Exit Sub'));
verifyTrue(t,contains(script,'If Not Require(a = beforeObjects'));
end
function testUnchangedVariablesNotRewritten(t)
job=vivaldiHFSSBridge('generate','update',config(t),vivaldiDefaultParams());
verifyFalse(t,contains(readScript(job.script),'oDesign.ChangeProperty'));
end
function testOriginalAndExistingOutputRejected(t)
cfg=config(t); cfg.outputDir=t.TestData.root; cfg.outputName='Vivaldi_23_9_2026.aedt';
verifyError(t,@()vivaldiHFSSBridge('generate','update',cfg,vivaldiDefaultParams()),'Vivaldi:OriginalProtection');
cfg=config(t); writeText(fullfile(cfg.outputDir,cfg.outputName),'existing user file');
verifyError(t,@()vivaldiHFSSBridge('generate','update',cfg,vivaldiDefaultParams()),'Vivaldi:ExistingOutput');
delete(fullfile(cfg.outputDir,cfg.outputName));
end
function testUnknownFormulaRejected(t)
cfg=config(t); altered=strrep(fileread(cfg.input),'6.4mm+them','7mm+them');
cfg.input=fullfile(t.TestData.temp,'different.aedt'); writeText(cfg.input,altered);
verifyError(t,@()vivaldiHFSSBridge('generate','update',cfg,vivaldiDefaultParams()),'Vivaldi:FormulaMismatch');
end
function testFailureStatusAndOfflineUnavailable(t)
job=vivaldiHFSSBridge('generate','connect',config(t),vivaldiDefaultParams());
fid=fopen(job.status,'w','n','UTF-16LE'); fwrite(fid,65279,'uint16');
fprintf(fid,'STATE|FAILED|now|Mock COM/license failure\r\n'); fclose(fid);
s=vivaldiHFSSBridge('poll',job);
verifyEqual(t,s.state,'FAILED'); verifyTrue(t,s.terminal);
verifyTrue(t,contains(s.log,'Mock COM/license failure'));
verifyError(t,@()vivaldiHFSSBridge('launch',job,'missing-ansysedt.exe'),'Vivaldi:HFSSUnavailable');
% This verifies status handling, not an actual HFSS script failure.
end
function testIntermediateConnectionNotTerminal(t)
job=vivaldiHFSSBridge('generate','update',config(t),vivaldiDefaultParams());
fid=fopen(job.status,'w','n','UTF-16LE'); fwrite(fid,65279,'uint16');
fprintf(fid,'STATE|CONNECTED|now|Version mock\r\n'); fclose(fid);
s=vivaldiHFSSBridge('poll',job); verifyFalse(t,s.terminal);
end
function testRealCSVImportAndRejection(t)
file=fullfile(t.TestData.temp,'measured.csv');
writeText(file,sprintf('Freq [GHz],S11 [dB],S22 [dB]\n5,-10,-11\n6,-12,-13\n'));
info=vivaldiLoadResults(file); r=vivaldiLoadResults(file,info.columns{1},info.columns(2:3));
verifyEqual(t,r.x,[5;6]); verifyEqual(t,r.y,[-10 -11;-12 -13]);
verifyError(t,@()vivaldiLoadResults(file,'missing',info.columns(2)),'Vivaldi:ResultColumns');
end
function testDimensionsAndLogger(t)
p=vivaldiDefaultParams(); g=vivaldiCalculateGeometry(p);
file=fullfile(t.TestData.temp,'dimensions.csv'); T=vivaldiExportDimensions(p,g,file,.05);
verifyTrue(t,isfile(file)); verifyEqual(t,T.Nominal(strcmp(T.Variable,'L_patch')),g.L_patch);
logger=vivaldiLogger(); logger.add('ERROR',struct('message','test error'));
verifyEqual(t,logger.LastError,'test error');
file=fullfile(t.TestData.temp,'log.json'); logger.export(file);
verifyTrue(t,contains(fileread(file),'test error'));
end
function cfg=config(t)
cfg=struct('input',fullfile(t.TestData.root,'Vivaldi_23_9_2026.aedt'), ...
    'outputDir',t.TestData.temp,'outputName','updated.aedt', ...
    'design','dual_pol_vivaldi_patch_Wflare_20');
end
function text=readScript(file)
fid=fopen(file,'r','n','UTF-16LE'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
text=fscanf(fid,'%c'); text=erase(text,char(65279));
end
function writeText(file,text)
fid=fopen(file,'w','n','UTF-8'); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',text);
end
