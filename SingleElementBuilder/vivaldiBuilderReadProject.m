function p = vivaldiBuilderReadProject(file,design)
%VIVALDIBUILDERREADPROJECT Strict read-only preflight, scoped to one HFSSModel.
assert(isfile(file) && endsWith(lower(file),'.aedt'),'VivaldiBuilder:Input','Select an existing .aedt project.');
text = fileread(file);
blocks = regexp(text,'\$begin ''HFSSModel''([\s\S]*?)\$end ''HFSSModel''','tokens');
found = {};
for k = 1:numel(blocks)
    name = regexp(blocks{k}{1},'(?m)^\s*Name=''([^'']+)''','tokens','once');
    if ~isempty(name) && strcmp(name{1},design), found{end+1} = blocks{k}{1}; end %#ok<AGROW>
end
assert(numel(found) == 1,'VivaldiBuilder:Design','Selected design not found uniquely.');
text = found{1};
assert(~isempty(strfind(text,'SolutionType=''DrivenModal''')), ...
    'VivaldiBuilder:Design','Expected a DrivenModal design.'); %#ok<STREMP>
arraySetup = regexp(text,'\$begin ''ArraySetup''([\s\S]*?)\$end ''ArraySetup''','tokens','once');
assert(~isempty(arraySetup) && ~isempty(strfind(arraySetup{1},'UseOption=''NoArray''')), ...
    'VivaldiBuilder:Design','Only single-element NoArray projects are supported.'); %#ok<STREMP>
source = regexp(text,'(?m)^\s*VariableProp\(''([^'']+)'', ''UD'', '''', ''([^'']*)''\)','tokens');
[p,meta] = vivaldiBuilderDefaultParams(); variables = vivaldiBuilderVariables(p);
for k = 1:size(variables,1)
    matches = source(cellfun(@(v)strcmp(v{1},variables{k,1}),source));
    assert(numel(matches) == 1,'VivaldiBuilder:Formula','Missing variable %s.',variables{k,1});
    value = regexprep(matches{1}{2},'\s','');
    if k <= numel(meta)
        pattern = ['^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)' meta(k).unit '$'];
        number = regexp(value,pattern,'tokens','once');
        assert(~isempty(number),'VivaldiBuilder:Formula','Independent variable %s is not a literal.',variables{k,1});
        p.(variables{k,1}) = str2double(number{1});
    elseif ~ismember(variables{k,1},{'lamda','scan_phi','scan_theta','c2'})
        expected = regexprep(variables{k,2},'\s','');
        assert(strcmp(value,expected),'VivaldiBuilder:Formula', ...
            'Dependent formula differs: %s. Inspect this model before updating.',variables{k,1});
    end
end
parts = regexp(text,'\$begin ''ToplevelParts''([\s\S]*?)\$end ''ToplevelParts''','tokens','once');
assert(~isempty(parts),'VivaldiBuilder:Inventory','No top-level geometry.');
partNames = regexp(parts{1},'(?m)^\s*Name=''([^'']+)''','tokens');
partNames = cellfun(@(v)v{1},partNames,'UniformOutput',false);
expected = {'Vivaldi_1','cable_in','cable_out','cable_in_1','cable_out_1','port1','port2','RadiatingSurface'};
assert(isequal(sort(partNames),sort(expected)),'VivaldiBuilder:Inventory','Expected exactly the eight single-element objects.');
[ok,e] = vivaldiBuilderValidate(p);
assert(ok,'VivaldiBuilder:Parameters','%s',strjoin(e,newline));
end
