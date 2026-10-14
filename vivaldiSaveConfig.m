function p = vivaldiSaveConfig(action,path,p)
%VIVALDISAVECONFIG Versioned JSON; never evaluates expressions from a file.
switch lower(action)
    case 'save'
        [ok,e]=vivaldiValidateParams(p);
        assert(ok,'Vivaldi:InvalidConfig','%s',strjoin(e,newline));
        payload=struct('schema','vivaldi-element-1','reference','Vivaldi_23_9_2026.aedt','params',p);
        fid=fopen(path,'w','n','UTF-8'); assert(fid>=0,'Vivaldi:ConfigWrite','Không thể ghi cấu hình.');
        c=onCleanup(@()fclose(fid)); %#ok<NASGU>
        fprintf(fid,'%s',jsonencode(payload));
    case 'load'
        payload=jsondecode(fileread(path));
        assert(isstruct(payload) && isscalar(payload) && isfield(payload,'schema') ...
            && strcmp(payload.schema,'vivaldi-element-1') && isfield(payload,'params'), ...
            'Vivaldi:ConfigSchema','Không đúng schema cấu hình.');
        p=payload.params; defaults=vivaldiDefaultParams();
        assert(isequal(sort(fieldnames(p)),sort(fieldnames(defaults))), ...
            'Vivaldi:ConfigFields','Cấu hình thiếu biến hoặc chứa biến không hỗ trợ.');
        [ok,e]=vivaldiValidateParams(p);
        assert(ok,'Vivaldi:InvalidConfig','%s',strjoin(e,newline));
    otherwise
        error('Vivaldi:ConfigAction','Thao tác cấu hình không hợp lệ.');
end
end
