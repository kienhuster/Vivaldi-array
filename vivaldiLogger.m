classdef vivaldiLogger < handle
    %VIVALDILOGGER In-memory structured log; explicit UTF-8 JSON export.
    properties (SetAccess=private)
        Entries = struct('time',{},'event',{},'details',{})
        LastError = ''
    end
    methods
        function add(obj,event,details)
            if nargin<3, details=struct(); end
            t=datetime('now','TimeZone','local','Format','yyyy-MM-dd HH:mm:ss Z');
            obj.Entries(end+1)=struct('time',char(t),'event',char(event),'details',details);
            if strcmpi(event,'ERROR')
                if isstruct(details) && isfield(details,'message'), obj.LastError=details.message;
                else, obj.LastError=jsonencode(details); end
            end
        end
        function lines=lines(obj)
            lines=cell(1,numel(obj.Entries));
            for k=1:numel(lines)
                e=obj.Entries(k); lines{k}=[e.time ' | ' e.event ' | ' jsonencode(e.details)];
            end
            if isempty(lines), lines={'Chưa có thao tác.'}; end
        end
        function export(obj,path)
            fid=fopen(path,'w','n','UTF-8');
            assert(fid>=0,'Vivaldi:LogWrite','Không thể ghi log.');
            cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
            fprintf(fid,'%s',jsonencode(obj.Entries));
        end
    end
end
