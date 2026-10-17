function tests = testBuilderGUI
tests = functiontests(localfunctions);
end
function testLaunchFiveTabs(t)
assumeTrue(t,usejava('desktop'),'MATLAB desktop is required for uifigure smoke test.');
old = path; cleanupPath = onCleanup(@()path(old)); %#ok<NASGU>
addpath(fileparts(fileparts(mfilename('fullpath'))));
fig = Vivaldi_DualPol_Builder(); cleanup = onCleanup(@()delete(fig)); %#ok<NASGU>
verifyEqual(t,numel(findall(fig,'Type','uitab')),5);
buttons = findall(fig,'Type','uibutton');
verifyTrue(t,any(strcmp({buttons.Text},'BUILD FULL ANTENNA IN HFSS')));
verifyTrue(t,any(strcmp({buttons.Text},'Update Existing Project')));
end
