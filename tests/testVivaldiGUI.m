function tests=testVivaldiGUI
% Optional GUI checks on MATLAB with a display. No HFSS/license required.
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path; addpath(fileparts(fileparts(mfilename('fullpath'))));
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testOfflineGUIAndPreviewRefresh(t)
assumeTrue(t,usejava('desktop'),'GUI smoke test requires MATLAB desktop/display.');
fig=Vivaldi_Element_Designer(); cleanup=onCleanup(@()delete(fig)); %#ok<NASGU>
fig.Visible='off'; drawnow;
verifyTrue(t,isvalid(fig));
handles=findall(fig);
axesHandles=handles(arrayfun(@(h)isa(h,'matlab.ui.control.UIAxes'),handles));
verifyGreaterThanOrEqual(t,numel(axesHandles),2);
edits=handles(arrayfun(@(h)isa(h,'matlab.ui.control.NumericEditField'),handles));
field=[];
for k=1:numel(edits)
    if isnumeric(edits(k).Value) && isequal(edits(k).Value,40), field=edits(k); break; end
end
verifyNotEmpty(t,field); field.Value=45;
field.ValueChangedFcn(field,struct('Value',45)); drawnow;
tables=findall(fig,'Type','uitable'); found=false;
for k=1:numel(tables)
    data=tables(k).Data;
    if iscell(data) && size(data,2)==3 && ~isempty(data)
        idx=find(strcmp(data(:,1),'L_flare'),1);
        if ~isempty(idx), found=abs(str2double(data{idx,2})-51.4)<1e-7; end
    end
end
verifyTrue(t,found);
end
