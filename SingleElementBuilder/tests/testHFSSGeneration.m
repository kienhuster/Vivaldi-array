function tests = testHFSSGeneration
%TESTHFSSGENERATION Portable MATLAB generation checks; never HFSS CAD proof.
% Run: results=runtests('tests/testHFSSGeneration.m'); assertSuccess(results)
tests = functiontests(localfunctions);
end

function setupOnce(t)
t.TestData.oldPath = path;
addpath(fileparts(fileparts(mfilename('fullpath'))));
t.TestData.temp = tempname;
mkdir(t.TestData.temp);
end

function teardownOnce(t)
path(t.TestData.oldPath);
rmdir(t.TestData.temp, 's');
end

function testFullPrimitiveAndBooleanSequence(t)
[body, ~] = cadScript();
expected = {'CreateRelativeCS',4; 'CreateEquationSurface',2; ...
    'CreateRectangle',4; 'CoverLines',5; 'ThickenSheet',1; ...
    'CreateBox',2; 'CreateCylinder',3; 'CreateCircle',1; ...
    'Subtract',5; 'Unite',2; 'AssignMaterial',2; 'SetModelUnits',1};
for k = 1:size(expected,1)
    verifyEqual(t,commandCount(body,expected{k,1}),expected{k,2},expected{k,1});
end
verifyFalse(t,contains(body,'CreateEquationBasedSurface'));
verifyFalse(t,contains(body,'SheetThicken '));
verifyEqual(t,numel(regexp(body,'(?m)^BuilderCloneNamed [^\r\n]*, "rotate"\s*$','match')),5);
verifyEqual(t,numel(regexp(body,'(?m)^BuilderCloneNamed [^\r\n]*, "copy"\s*$','match')),7);
verifyTrue(t,contains(body,'"Thickness:=", "thickness", "BothSides:=", True'));
verifyTrue(t,contains(body,'"WhichAxis:=", "Y"'));
verifyTrue(t,contains(body,'"Width:=", "-L_patch", "Height:=", "-aperture_w"'));
verifyTrue(t,contains(body,'"Width:=", "cavity_L", "Height:=", "cavity_w"'));
end

function testShortFlareCopiedBeforeLocalRotation(t)
[body, ~] = cadScript();
copy = position(body,'BuilderCloneNamed "EquationSurface2", "EquationSurface2_1", "copy"');
cut = position(body,'oEditor.Subtract Array("NAME:Selections", "Blank Parts:=", "EquationSurface1"');
rotate = position(body,'oEditor.Rotate Array("NAME:Selections", "Selections:=", "EquationSurface2"');
verifyLessThan(t,copy,cut);
verifyLessThan(t,cut,rotate);
localCS = strfind(body,'"Working Coordinate System:=", "slot_t_td"');
verifyTrue(t,any(localCS>cut & localCS<rotate));
verifyTrue(t,contains(body,'"RotateAxis:=", "Y", "RotateAngle:=", "deg_slot_t"'));
% EquationSurface2 is retained while only its unrotated clone is consumed.
verifyTrue(t,contains(body,'"Tool Parts:=", "EquationSurface2_1"'));
verifyFalse(t,contains(body,'"Tool Parts:=", "EquationSurface2"'));
end

function testNestedCoordinatesAndSharedSecondPolarizationTransform(t)
[body, helpers] = cadScript();
verifyTrue(t,contains(body,'"OriginX:=", "-x_feed"'));
verifyTrue(t,contains(body,'"OriginY:=", "-thickness/2"'));
verifyTrue(t,contains(body,['Array("NAME:PropServers", "RelativeCS1"), ' ...
    'Array("NAME:ChangedProps", Array("NAME:Reference CS", "Value:=", "patch_td"))']));
verifyTrue(t,contains(helpers,'"WhichAxis:=", "Z", "AngleStr:=", "-90deg", "NumClones:=", "2"'));
targets = {'Vivaldi_2','cable_in_1','cable_out_1','cable_mid_1','port2'};
for k = 1:numel(targets)
    pattern = ['(?m)^oEditor\.Move Array\("NAME:Selections", "Selections:=", "' ...
        targets{k} '"[^\r\n]*"TranslateVectorY:=", "thickness"'];
    verifyEqual(t,numel(regexp(body,pattern,'match')),1,targets{k});
end
verifyFalse(t,contains(body,'"TranslateVectorY:=", "2mm"'));
verifyFalse(t,contains(body,'DuplicateAlongLine'));
end

function testAllSixFullCylinderSnapshotsPrecedeHollowing(t)
[body, ~] = cadScript();
hollow1 = position(body,'oEditor.Subtract Array("NAME:Selections", "Blank Parts:=", "cable_out"');
hollow2 = position(body,'oEditor.Subtract Array("NAME:Selections", "Blank Parts:=", "cable_out_1"');
sources = {'cable_in','cable_in_1','cable_mid','cable_mid_1','cable_out','cable_out_1'};
cutters = {'cable_in_2','cable_in_1_1','cable_mid_2','cable_mid_1_1','cable_out_2','cable_out_1_1'};
for k = 1:numel(cutters)
    snapshot = position(body,sprintf('BuilderCloneNamed "%s", "%s", "copy"',sources{k},cutters{k}));
    verifyLessThan(t,snapshot,hollow1,cutters{k});
    verifyLessThan(t,snapshot,hollow2,cutters{k});
end
verifyLessThan(t,hollow1,hollow2);
sixTools = ['"Tool Parts:=", "' strjoin(cutters,',') '"'];
verifyEqual(t,numel(strfind(body,sixTools)),1);
finalCut = position(body,sixTools);
verifyLessThan(t,hollow2,finalCut);
verifyTrue(t,contains(body,'BuilderFaceCount("cable_out_2") = 3'));
verifyTrue(t,contains(body,'BuilderFaceCount("cable_out_1_1") = 3'));
verifyTrue(t,contains(body,'BuilderFaceCount("cable_out") = 4'));
verifyTrue(t,contains(body,'BuilderFaceCount("cable_out_1") = 4'));
verifyTrue(t,contains(body,'BuilderVerifyCylinder("cable_in",'));
verifyTrue(t,contains(body,'BuilderVerifyCylinder("cable_out_1",'));
verifyTrue(t,contains(body,'BuilderVerifyCircularSheet("port2",'));
verifyTrue(t,contains(body,'source Subtract5858 KeepOriginals=true'));
verifyFalse(t,contains(body,'PTFE'));
verifyFalse(t,contains(body,'FR4'));
end

function testCloneNamesAreQueriedAndRenamedWithoutSuffixGuesses(t)
[~, helpers] = cadScript();
verifyTrue(t,contains(helpers,'beforeNames = BuilderObjectNames()'));
verifyTrue(t,contains(helpers,'afterNames = BuilderObjectNames()'));
verifyTrue(t,contains(helpers,'newCount <> 1 Then Err.Raise'));
verifyTrue(t,contains(helpers,'"NAME:Geometry3DAttributeTab"'));
verifyTrue(t,contains(helpers,'Array("NAME:Name", "Value:=", desiredName)'));
verifyTrue(t,contains(helpers,'Array("Solids", "Sheets", "Lines", "Unclassified")'));
verifyFalse(t,contains(helpers,'sourceName & "_1"'));
verifyFalse(t,contains(helpers,'On Error Resume Next'));
verifyFalse(t,contains(helpers,'GetEdgeID'));
end

function testScratchGenerationDoesNotReadOrOpenOriginal(t)
p = vivaldiBuilderDefaultParams();
out = fullfile(t.TestData.temp,'scratch_without_original');
mkdir(out);
absent = fullfile(out,'missing_reference.aedt');
cfg = struct('outputDir',out,'projectName','scratch_without_original', ...
    'sourcePath',absent,'originalPath',absent);
assertFalse(t,isfile(absent));
job = HFSSAutomationBridge('generate','build',cfg,p);
script = readScript(job.scriptPath);
main = mainBody(script);
verifyTrue(t,contains(main,'Set oProject = oDesktop.NewProject()'));
verifyTrue(t,contains(main,'oProject.InsertDesign "HFSS"'));
verifyFalse(t,contains(main,'OpenProject'));
verifyFalse(t,contains(main,'SBWorkingProject'));
verifyFalse(t,contains(script,absent));
verifyTrue(t,contains(main,'oEditor.CreateEquationSurface'));
verifyTrue(t,contains(main,'"Tool Parts:=", "cable_in_2,cable_in_1_1,cable_mid_2,cable_mid_1_1,cable_out_2,cable_out_1_1"'));
verifyEqual(t,numel(regexp(main,'(?m)^oBoundary\.AssignLumpedPort\s','match')),2);
verifyTrue(t,contains(main,'oBoundary.AssignRadiation'));
verifyTrue(t,contains(main,'oDesign.ValidateDesign('));
verifyTrue(t,contains(main,'BuilderHasExactlyNames(Array('));
verifyFalse(t,contains(main,'AnalyzeAll'));
verifyFalse(t,contains(main,'oDesign.Analyze '));
verifyFalse(t,isfile(job.projectPath),'Generation must not claim/create an HFSS project artifact.');
verifyFalse(t,isfile(job.statusPath),'Generation must not forge an HFSS acknowledgment.');
% NewProps/geometry are allowed only after protecting the new project first.
verifyLessThan(t,position(main,'oProject.SaveAs '),position(main,'"NAME:NewProps"'));
verifyLessThan(t,position(main,'oEditor.SetModelUnits '),position(main,'oEditor.CreateRelativeCS '));
end

function testEveryCADOperationHasItsOwnGuard(t)
[body, ~] = cadScript();
lines = regexp(body,'\r?\n','split');
for k = 1:numel(lines)
    if startsWith(lines{k},'oEditor.') || startsWith(lines{k},'BuilderCloneNamed ')
        assertGreaterThan(t,k,2);
        assertLessThan(t,k,numel(lines)-3);
        verifyEqual(t,lines{k-1},'On Error Resume Next');
        verifyEqual(t,lines{k-2},'Err.Clear');
        verifyEqual(t,lines{k+1},'sbErr = Err.Number');
        verifyEqual(t,lines{k+2},'sbDesc = Err.Description');
        verifyEqual(t,lines{k+3},'On Error GoTo 0');
    end
end
end

function [body, helpers] = cadScript()
w = HFSSScriptWriter();
p = vivaldiBuilderDefaultParams();
HFSSGeometryBuilder(w,p);
HFSSCoaxBuilder(w,p);
body = strjoin(w.Lines,newline);
helpers = strjoin(w.Helpers,newline);
end

function n = commandCount(body,method)
n = numel(regexp(body,['(?m)^oEditor\.' method '\s'],'match'));
end

function index = position(text,needle)
indices = strfind(text,needle);
assert(numel(indices)==1,'VivaldiBuilder:TestAmbiguousToken', ...
    'Expected exactly one generated token: %s',needle);
index = indices(1);
end

function main = mainBody(script)
index = strfind(script,'Sub Main()');
assert(numel(index)==1,'Expected one Main procedure.');
main = script(index:end);
end

function text = readScript(file)
fid = fopen(file,'r');
assert(fid>=0,'Cannot read generated script.');
cleaner = onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes = fread(fid,Inf,'*uint8')';
assert(numel(bytes)>2 && isequal(bytes(1:2),uint8([255 254])), ...
    'Generated VBScript must use its declared UTF-16LE encoding.');
text = native2unicode(bytes(3:end),'UTF-16LE');
end
