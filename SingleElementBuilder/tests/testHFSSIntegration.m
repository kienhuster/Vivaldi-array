function tests = testHFSSIntegration
% Explicit opt-in: requires Windows, MATLAB and licensed HFSS 2021 R2.
tests = functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath = path; addpath(fileparts(fileparts(mfilename('fullpath'))));
end
function teardownOnce(t), path(t.TestData.oldPath); end
function testBuildWithoutSource(t), build(t,'',0); end
function testLengthVariation(t), build(t,'L_flare_1',45); end
function testApertureVariation(t), build(t,'aperture_w',22); end
function testCavityWidthVariation(t), build(t,'cavity_w',1.6); end
function testCavityLengthVariation(t), build(t,'cavity_L',5.5); end
function testThicknessVariation(t), build(t,'thickness',2.2); end
function testSlotVariation(t), build(t,'slot_feed_w',.6); end
function build(t,name,value)
assumeTrue(t,ispc && strcmp(getenv('VIVALDI_RUN_HFSS_TESTS'),'1'), ...
    'HFSS integration unrun: opt in on Windows with VIVALDI_RUN_HFSS_TESTS=1.');
cfg = vivaldiBuilderConfig(); cfg.exe = getenv('VIVALDI_HFSS_EXE');
assumeTrue(t,isfile(cfg.exe),'Set VIVALDI_HFSS_EXE to the licensed HFSS 2021 R2 executable.');
cfg.outputDir = fullfile(tempdir,'VivaldiBuilderIntegration'); cfg.timeoutSeconds = 7200;
cfg.input = ''; % No original project is opened or used for rebuilding.
p = vivaldiBuilderDefaultParams(); if ~isempty(name), p.(name) = value; end
job = HFSSAutomationBridge('generate','build',cfg,p);
job = HFSSAutomationBridge('launch',job,cfg.exe);
while true
    state = HFSSAutomationBridge('poll',job);
    if state.terminal, break; end
    pause(1);
end
verifyEqual(t,state.state,'BUILT',state.log);
if ~strcmp(state.state,'BUILT'), return; end
verifyTrue(t,isfile(job.output));
q = vivaldiBuilderReadProject(job.output,cfg.design);
names = fieldnames(p);
for k = 1:numel(names), verifyEqual(t,q.(names{k}),p.(names{k}),'AbsTol',1e-10); end
verifyTrue(t,contains(state.log,'VALIDATE_RETURN|1'));
verifyTrue(t,contains(state.log,'INVENTORY|'));
verifyTrue(t,contains(state.log,'PORT_LINE|port1|OUTER_TO_INNER|'));
verifyTrue(t,contains(state.log,'PORT_LINE|port2|OUTER_TO_INNER|'));
text = fileread(job.output);
setups = regexp(text,'\$begin ''SolveSetups''([\s\S]*?)\$end ''SolveSetups''','tokens');
original = {};
for k = 1:numel(setups)
    matches = regexp(setups{k}{1},'\$begin ''Setup1''([\s\S]*?)\$end ''Setup1''','tokens');
    original = [original matches]; %#ok<AGROW>
end
verifyEqual(t,numel(original),1);
if numel(original) == 1
    for required = {"Frequency='5GHz'",'MaxDeltaS=0.02','MinimumPasses=5','MaximumPasses=50', ...
            "RangeStart='5GHz'","RangeEnd='20GHz'","RangeStep='0.25GHz'"}
        verifyTrue(t,contains(original{1}{1},required{1}));
    end
end
% Retain projects/logs for independent visual CAD and port-direction comparison.
end
