classdef HFSSBuildLogger < handle
    properties
        Entries = {}
    end
    methods
        function add(logger,level,message)
            logger.Entries{end+1} = struct('time',datestr(now,30),'level',level,'message',message);
        end
        function export(logger,file)
            fid = fopen(file,'w','n','UTF-8');
            assert(fid>=0,'VivaldiBuilder:Log','Cannot write log.');
            cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
            for k = 1:numel(logger.Entries), fprintf(fid,'%s\n',jsonencode(logger.Entries{k})); end
        end
    end
end
