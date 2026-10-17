function [p, report] = vivaldiBuilderConfig(action, filename, p)
%VIVALDIBUILDERCONFIG Strict versioned JSON; parameters only, never eval.
% save writes atomically in the selected directory. No credentials or paths
% to license servers are serialized. load rejects unknown/missing fields.
action=textScalar(action,'action'); filename=textScalar(filename,'filename');
schema='vivaldi-dual-pol-builder'; model='dual_pol_vivaldi_patch_Wflare_20';
switch lower(action)
    case 'save'
        assert(nargin>=3,'VivaldiBuilder:ConfigParameters','Save requires parameters.');
        [ok,errors]=vivaldiBuilderValidate(p);
        assert(ok,'VivaldiBuilder:InvalidConfig','%s',strjoin(errors,newline));
        payload=struct('schema',schema,'version',1,'model',model,'units','mm-deg','parameters',p);
        body=jsonencode(payload);
        folder=fileparts(filename);if isempty(folder),folder=pwd;end
        assert(isfolder(folder),'VivaldiBuilder:ConfigWrite','Thư mục cấu hình không tồn tại.');
        tmp=[tempname(folder) '.json'];cleanup=onCleanup(@()removeTemp(tmp)); %#ok<NASGU>
        writeText(tmp,body);
        [moved,message]=movefile(tmp,filename,'f');
        assert(moved,'VivaldiBuilder:ConfigWrite','Không lưu được cấu hình: %s',message);
    case 'load'
        assert(isfile(filename),'VivaldiBuilder:ConfigRead','Không tìm thấy tệp cấu hình.');
        details=dir(filename);
        assert(details.bytes<=1024*1024,'VivaldiBuilder:ConfigSize','Tệp cấu hình vượt 1 MiB.');
        try
            payload=jsondecode(fileread(filename));
        catch ex
            error('VivaldiBuilder:ConfigJSON','JSON không hợp lệ: %s',ex.message);
        end
        expected={'schema';'version';'model';'units';'parameters'};
        assert(isstruct(payload) && isscalar(payload) && ...
            isequal(sort(fieldnames(payload)),sort(expected)), ...
            'VivaldiBuilder:ConfigSchema','Thiếu trường hoặc có trường JSON không hỗ trợ.');
        assert(ischar(payload.schema) && strcmp(payload.schema,schema) ...
            && isnumeric(payload.version) && isscalar(payload.version) ...
            && isreal(payload.version) && isfinite(payload.version) && payload.version==1 ...
            && ischar(payload.model) && strcmp(payload.model,model) ...
            && ischar(payload.units) && strcmp(payload.units,'mm-deg'), ...
            'VivaldiBuilder:ConfigSchema','Schema, version, model hoặc đơn vị không hỗ trợ.');
        p=payload.parameters;
        [ok,errors]=vivaldiBuilderValidate(p);
        assert(ok,'VivaldiBuilder:InvalidConfig','%s',strjoin(errors,newline));
    otherwise
        error('VivaldiBuilder:ConfigAction','Thao tác cấu hình phải là save hoặc load.');
end
report=struct('schema',schema,'version',1,'filename',filename, ...
    'action',lower(action),'validation','Parameters Only - HFSS Validation Pending');
end
function s=textScalar(value,name)
if isstring(value) && isscalar(value),value=char(value);end
assert(ischar(value) && isrow(value) && ~isempty(value) && ~any(value==char(0)), ...
    'VivaldiBuilder:ConfigText','%s phải là chuỗi scalar không rỗng.',name);
s=value;
end
function writeText(filename,body)
fid=fopen(filename,'w','n','UTF-8');
assert(fid>=0,'VivaldiBuilder:ConfigWrite','Không mở được tệp cấu hình để ghi.');
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
count=fprintf(fid,'%s',body);
assert(count>=numel(body),'VivaldiBuilder:ConfigWrite','Ghi cấu hình không đầy đủ.');
end
function removeTemp(filename)
if isfile(filename),delete(filename);end
end
