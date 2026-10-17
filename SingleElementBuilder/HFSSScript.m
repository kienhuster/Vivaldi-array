classdef HFSSScript < handle
    %HFSSSCRIPT Typed VBScript writer with immediate per-operation error checks.
    properties
        Lines = {}
        Counter = 0
        Stage = 'Initialize'
    end
    methods
        function add(s,line), s.Lines{end+1} = char(line); end
        function stage(s,name)
            s.Stage = name;
            s.add(['State "RUNNING", ' s.quote(name)]);
        end
        function checked(s,line)
            s.add('On Error Resume Next');
            s.add('Err.Clear');
            s.add(line);
            s.add('errorNumber = Err.Number : errorText = Err.Description');
            s.add('On Error GoTo 0');
            s.add(['If errorNumber <> 0 Then Fail ' s.quote(s.Stage) ', errorNumber, errorText']);
        end
        function api(s,object,method,varargin)
            args = cellfun(@(v)s.value(v),varargin,'UniformOutput',false);
            s.checked([object '.' method ' ' strjoin(args,', ')]);
        end
        function require(s,expression,message)
            s.add(['If Not (' expression ') Then Fail ' s.quote(s.Stage) ', 513, ' s.quote(message)]);
        end
        function v = value(s,x)
            if iscell(x)
                items = cellfun(@(v)s.value(v),x,'UniformOutput',false);
                s.Counter = s.Counter+1; v = sprintf('a%d',s.Counter);
                s.add(['Dim ' v]);
                % Break at token boundaries without breaking quoted strings.
                line = [v ' = Array('];
                for k = 1:numel(items)
                    if k > 1
                        if numel(line)+numel(items{k}) > 180
                            s.add([line ', _']); line = '    ';
                        else
                            line = [line ', ']; %#ok<AGROW>
                        end
                    end
                    line = [line items{k}]; %#ok<AGROW>
                end
                s.add([line ')']);
            elseif isstruct(x) && isfield(x,'vb')
                v = x.vb;
            elseif ischar(x) || (isstring(x) && isscalar(x))
                v = s.quote(char(x));
            elseif islogical(x) && isscalar(x)
                if x, v = 'True'; else, v = 'False'; end
            elseif isnumeric(x) && isscalar(x) && isreal(x) && isfinite(x)
                v = sprintf('%.17g',x);
            else
                error('VivaldiBuilder:VBValue','Unsupported Automation value.');
            end
        end
        function text = text(s), text = strjoin(s.Lines,sprintf('\r\n')); end
        function write(s,file)
            fid = fopen(file,'wb');
            assert(fid >= 0,'VivaldiBuilder:Write','Cannot write script.');
            cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
            fwrite(fid,[255 254],'uint8');
            fwrite(fid,unicode2native([s.text() sprintf('\r\n')],'UTF-16LE'),'uint8');
        end
    end
    methods (Static)
        function v = raw(text), v = struct('vb',text); end
        function q = quote(text)
            text = char(text);
            assert(~any(text < 32),'VivaldiBuilder:VBString','Control characters in script string.');
            q = ['"' strrep(text,'"','""') '"'];
        end
        function a = attributes(name,material,cs,solveInside)
            a = {'NAME:Attributes','Name:=',name,'Flags:=','','Color:=','(190 190 200)', ...
                'Transparency:=',0,'PartCoordinateSystem:=',cs,'UDMId:=','', ...
                'MaterialValue:=',['"' material '"'],'SurfaceMaterialValue:=','""', ...
                'SolveInside:=',solveInside,'UseMaterialAppearance:=',false};
        end
        function a = selection(names)
            a = {'NAME:Selections','Selections:=',names,'NewPartsModelFlag:=','Model'};
        end
        function text = read(file)
            fid = fopen(file,'rb');
            assert(fid >= 0,'VivaldiBuilder:Read','Cannot read UTF-16 file.');
            cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
            bytes = fread(fid,Inf,'*uint8')';
            if numel(bytes) >= 2 && isequal(bytes(1:2),uint8([255 254])), bytes = bytes(3:end); end
            if mod(numel(bytes),2), bytes = bytes(1:end-1); end % log may be mid-write
            text = native2unicode(bytes,'UTF-16LE');
        end
    end
end
