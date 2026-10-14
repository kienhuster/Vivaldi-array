function info = vivaldiInspectProject(path)
%VIVALDIINSPECTPROJECT Read-only AEDT text inventory; no eval, no CAD rewriting.
text=fileread(path); lines=regexp(text,'\r?\n','split'); stack={};
info=struct('path',path,'designs',{{}},'variables',{{}}, ...
    'parts',{{}},'boundaries',{{}},'coordinateSystems',{{}},'source',text);
part=[]; boundary=[]; cs=[];
for k=1:numel(lines)
    line=strtrim(lines{k});
    b=regexp(line,'^\$begin ''([^'']+)''$','tokens','once');
    if ~isempty(b)
        stack{end+1}=b{1};
        if strcmp(b{1},'GeometryPart')
            part=struct('name','','material','','section',stack{end-1},'line',k,'operations',{{}});
        elseif numel(stack)>=2 && strcmp(stack{end-1},'Boundaries')
            boundary=struct('name',b{1},'type','','line',k);
        elseif strcmp(b{1},'Operation') && any(strcmp(stack,'CoordinateSystems'))
            cs=struct('name','','line',k,'properties',{{}});
        end
        continue;
    end
    e=regexp(line,'^\$end ''([^'']+)''$','tokens','once');
    if ~isempty(e)
        assert(~isempty(stack) && strcmp(stack{end},e{1}), ...
            'Vivaldi:AEDTFormat','Khối AEDT không cân bằng tại dòng %d.',k);
        if strcmp(e{1},'GeometryPart'), info.parts{end+1}=part; part=[]; end
        if ~isempty(boundary) && strcmp(e{1},boundary.name)
            info.boundaries{end+1}=boundary; boundary=[];
        end
        if ~isempty(cs) && strcmp(e{1},'Operation') && any(strcmp(stack,'CoordinateSystems'))
            info.coordinateSystems{end+1}=cs; cs=[];
        end
        stack(end)=[]; continue;
    end
    if isempty(stack), continue; end
    v=regexp(line,'^VariableProp\(''([^'']+)'', ''[^'']*'', ''[^'']*'', ''([^'']*)''\)','tokens','once');
    if ~isempty(v), info.variables(end+1,:)={v{1},v{2}}; end
    n=regexp(line,'^Name=''([^'']*)''','tokens','once');
    if ~isempty(n) && numel(stack)==2 && strcmp(stack{end},'HFSSModel')
        info.designs{end+1}=n{1};
    end
    if ~isempty(part)
        if strcmp(stack{end},'Attributes')
            if ~isempty(n), part.name=n{1}; end
            m=regexp(line,'^MaterialValue=''([^'']*)''','tokens','once');
            if ~isempty(m), part.material=m{1}; end
        end
        m=regexp(line,'^OperationType=''([^'']+)''','tokens','once');
        if ~isempty(m), part.operations{end+1}=m{1}; end
    end
    if ~isempty(boundary)
        m=regexp(line,'^BoundType=''([^'']+)''','tokens','once');
        if ~isempty(m), boundary.type=m{1}; end
    end
    if ~isempty(cs)
        if ~isempty(n), cs.name=n{1}; end
        cs.properties{end+1}=line;
    end
end
assert(isempty(stack),'Vivaldi:AEDTFormat','Khối AEDT chưa đóng.');
assert(~isempty(info.designs),'Vivaldi:NoDesign','Không tìm thấy HFSSModel dạng text. Chọn design trong HFSS nếu tệp không hỗ trợ.');
info.version=regexp(text,'Version\(202\d, \d\)','match','once');
end
