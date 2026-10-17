function tests=testBuilderGUI
%TESTBUILDERGUI Desktop-only smoke/behavior tests; does not claim HFSS success.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
testCase.TestData.root=root;
end

function setup(testCase)
testCase.assumeTrue(usejava('desktop') && exist('uifigure','file')==2, ...
    'Requires a MATLAB desktop with uifigure; headless/static checks cannot run GUI tests.');
fig=Vivaldi_DualPol_Builder('Visible','off'); testCase.TestData.figure=fig;
end

function teardown(testCase)
if isfield(testCase.TestData,'figure') && isvalid(testCase.TestData.figure)
    close(testCase.TestData.figure);
end
end

function testFiveTabsAndHonestInitialState(testCase)
fig=testCase.TestData.figure;
group=findall(fig,'Tag','BuilderTabs');
testCase.verifyNumElements(group.Children,5);
testCase.verifyFalse(fig.UserData.hasVerifiedProject);
testCase.verifyFalse(fig.UserData.simulated);
testCase.verifyEqual(findall(fig,'Tag','RunAnalysis').Enable,'off');
testCase.verifyEqual(findall(fig,'Tag','RunSimulation').Enable,'off');
testCase.verifyEqual(findall(fig,'Tag','SimulationState').Text,'Not Simulated');
label=findall(fig,'Tag','PreviewDisclaimer');
testCase.verifyTrue(contains(label.Text,'MATHEMATICAL PREVIEW'));
end

function testParameterEditUpdatesDependenciesAndKeepsSolverDisabled(testCase)
fig=testCase.TestData.figure;
field=findall(fig,'Tag','Parameter_L_flare_1'); field.Value=45;
callback=field.ValueChangedFcn; callback(field,[]);
testCase.verifyEqual(fig.UserData.parameters.L_flare_1,45);
testCase.verifyEqual(fig.UserData.geometry.L_flare,51.4,'AbsTol',1e-10);
testCase.verifyGreaterThan(fig.UserData.geometry.L_patch,49.236303290);
testCase.verifyFalse(fig.UserData.currentModel);
testCase.verifyEqual(findall(fig,'Tag','RunAnalysis').Enable,'off');
end

function testInvalidCoaxBlocksBuild(testCase)
fig=testCase.TestData.figure;
field=findall(fig,'Tag','Parameter_r_cabin'); field.Value=.4;
callback=field.ValueChangedFcn; callback(field,[]);
testCase.verifyEqual(findall(fig,'Tag','BuildFromScratch').Enable,'off');
testCase.verifyTrue(contains(findall(fig,'Tag','BuilderStatus').Text,'Invalid parameters'));
testCase.verifyFalse(fig.UserData.simulated);
end

function testOfflineScriptGenerationNeverBecomesBuildSuccess(testCase)
fig=testCase.TestData.figure; folder=tempname; mkdir(folder);
cleanup=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
output=findall(fig,'Tag','HFSSOutputDirectory'); output.Value=folder;
offline=findall(fig,'Tag','OfflineScripts'); offline.Value=true;
button=findall(fig,'Tag','BuildFromScratch'); callback=button.ButtonPushedFcn; callback(button,[]);
scripts=dir(fullfile(folder,'*.vbs'));
testCase.verifyNotEmpty(scripts);
testCase.verifyTrue(contains(findall(fig,'Tag','BuilderStatus').Text,'SCRIPT_GENERATED'));
testCase.verifyFalse(fig.UserData.hasVerifiedProject);
testCase.verifyFalse(fig.UserData.simulated);
testCase.verifyEqual(findall(fig,'Tag','RunAnalysis').Enable,'off');
testCase.verifyEqual(findall(fig,'Tag','SimulationState').Text,'Not Simulated');
end

function testPreviewContainsTwoThickenedPlatesAndPorts(testCase)
fig=testCase.TestData.figure;
ax=findall(fig,'Tag','BuilderPreviewAxes');
testCase.verifyGreaterThanOrEqual(numel(findall(ax,'Type','patch')),8);
testCase.verifyTrue(contains(strjoin(string(ax.Title.String)),'NOT HFSS CAD'));
testCase.verifyEqual(fig.UserData.geometry.plates(1).normal * ...
    fig.UserData.geometry.plates(2).normal',0,'AbsTol',1e-12);
end
