classdef HFSSBuildLogger < handle
    %HFSSBUILDLOGGER Structured requests and actual HFSS runtime evidence.
    % add/stage record application events, not successful CAD/solver actions.
    % ingest imports STATE/STAGE/NOTE records emitted by the HFSS script.
    properties (SetAccess=private)
        Entries = struct('time',{},'event',{},'details',{},'source',{})
        LastError = ''
    end
    properties (Access=private)
        ReadPaths = {}
        ReadCounts = []
    end
    methods
        function obj=HFSSBuildLogger(label)
            if nargin>0 && ~isempty(label)
                obj.add('SESSION',struct('label',char(label),'runtimeVerified',false));
            end
        end
        function add(obj,event,details)
            if nargin<3, details=struct(); end
            obj.append(obj.timestamp(),char(event),details,'MATLAB application');
        end
        function stage(obj,name,details)
            if nargin<3, details=struct(); end
            if ~isstruct(details), details=struct('message',details); end
            details.stage=char(name); details.runtimeVerified=false;
            obj.add('STAGE_REQUESTED',details);
        end
        function count=ingest(obj,path)
            % Status files use UTF-16LE from Windows FSO, with a BOM. A plain
            % UTF-8 log is accepted too. Never interpret process exit as solve.
            count=0;
            if ~isfile(path), return; end
            fid=fopen(path,'r');
            assert(fid>=0,'VivaldiBuilder:LogRead','Cannot open HFSS status log.');
            cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
            bytes=fread(fid,Inf,'*uint8')';
            if numel(bytes)>=2 && isequal(bytes(1:2),uint8([255 254]))
                bytes=bytes(3:end); encoding='UTF-16LE';
            elseif numel(bytes)>=2 && bytes(2)==0
                encoding='UTF-16LE';
            else
                encoding='UTF-8';
            end
            if strcmp(encoding,'UTF-16LE') && mod(numel(bytes),2), bytes(end)=[]; end
            raw=native2unicode(bytes,encoding);
            lines=regexp(raw,'\r\n|\n|\r','split');
            % A last unterminated line may still be being written. It is read
            % only when terminated, preventing partial records from becoming
            % permanent evidence or swallowing their eventual complete text.
            if isempty(raw)||~any(raw(end)==[char(10),char(13)])
                lines(end)=[];
            elseif ~isempty(lines)&&isempty(lines{end})
                lines(end)=[];
            end
            index=find(strcmp(obj.ReadPaths,char(path)),1);
            if isempty(index)
                obj.ReadPaths{end+1}=char(path); obj.ReadCounts(end+1)=0;
                index=numel(obj.ReadCounts);
            end
            if numel(lines)<obj.ReadCounts(index)
                obj.add('LOG_RESTARTED',struct('path',char(path), ...
                    'message','Status file was truncated; new records follow.'));
                obj.ReadCounts(index)=0;
            end
            for k=obj.ReadCounts(index)+1:numel(lines)
                line=lines{k}; parts=strsplit(line,'|','CollapseDelimiters',false);
                if numel(parts)>=3&&strcmp(parts{1},'STATE')
                    details=struct('state',parts{2},'message',strjoin(parts(4:end),'|'), ...
                        'path',char(path),'raw',line,'runtimeVerified',true);
                    obj.append(parts{3},parts{2},details,'HFSS runtime status');
                elseif numel(parts)>=3&&strcmp(parts{1},'STAGE')
                    details=struct('stage',parts{2},'path',char(path), ...
                        'raw',line,'runtimeVerified',true);
                    obj.append(parts{3},'STAGE',details,'HFSS runtime status');
                elseif numel(parts)>=3&&strcmp(parts{1},'NOTE')
                    details=struct('message',strjoin(parts(3:end),'|'),'path',char(path), ...
                        'raw',line,'runtimeVerified',true);
                    obj.append(parts{2},'NOTE',details,'HFSS runtime status');
                elseif ~isempty(line)
                    obj.append(obj.timestamp(),'RAW',struct('message',line, ...
                        'path',char(path),'runtimeVerified',false),'Unclassified status text');
                end
                count=count+1;
            end
            obj.ReadCounts(index)=numel(lines);
        end
        function result=lines(obj)
            result=cell(1,numel(obj.Entries));
            for k=1:numel(obj.Entries)
                entry=obj.Entries(k);
                result{k}=[entry.time ' | ' entry.event ' | ' jsonencode(entry.details)];
            end
            if isempty(result), result={'No events recorded; HFSS has not been verified.'}; end
        end
        function export(obj,path)
            assert(~isfile(path),'VivaldiBuilder:ExistingLog', ...
                'Log export already exists; choose a new name to preserve prior evidence.');
            fid=fopen(path,'w','n','UTF-8');
            assert(fid>=0,'VivaldiBuilder:LogWrite','Cannot write log export.');
            cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
            payload=struct('format','VivaldiDualPolBuildLog-v1', ...
                'exportedAtUTC',obj.timestamp(),'entries',obj.Entries, ...
                'interpretation','Runtime records are stage evidence. Inspect terminal states, geometry validation and actual solution data separately.');
            fprintf(fid,'%s',jsonencode(payload));
        end
    end
    methods (Access=private)
        function append(obj,time,event,details,source)
            obj.Entries(end+1)=struct('time',char(time),'event',char(event), ...
                'details',details,'source',char(source));
            if any(strcmpi(event,{'ERROR','FAILED','TIMEOUT'}))
                if isstruct(details)&&isfield(details,'message'), obj.LastError=char(details.message);
                else, obj.LastError=jsonencode(details); end
            end
        end
    end
    methods (Static,Access=private)
        function result=timestamp()
            t=datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z''');
            result=char(t);
        end
    end
end
