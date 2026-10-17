classdef HFSSScriptWriter < handle
    %HFSSSCRIPTWRITER Emit auditable VBScript with one guarded API call at a time.
    properties (SetAccess=private)
        Lines = {}
        Helpers = {}
        Declarations = {}
    end
    methods
        function line(w,text)
            w.Lines{end+1}=char(text);
        end
        function declare(w,text)
            if ~ismember(char(text),w.Declarations)
                w.Declarations{end+1}=char(text);
            end
        end
        function helper(w,lines)
            if ischar(lines), lines={lines}; end
            % Whole payload deduplication; helper bodies keep their line order.
            payload=strjoin(lines,newline);
            if ~ismember(payload,w.Helpers), w.Helpers{end+1}=payload; end
        end
        function call(w,statement,label)
            % Error handling is limited to this operation; the next operation
            % is unreachable after any error. There is no blanket suppression.
            w.line('Err.Clear');
            w.line('On Error Resume Next');
            w.line(statement);
            w.line('sbErr = Err.Number');
            w.line('sbDesc = Err.Description');
            w.line('On Error GoTo 0');
            w.line(['If sbErr <> 0 Then Fail ' w.q(label) ' & ": " & CStr(sbErr) & " " & sbDesc: Exit Sub']);
        end
        function stage(w,name)
            w.line(['Stage ' w.q(name)]);
        end
        function require(w,condition,message)
            w.declare('Dim sbCondition');
            w.call(['sbCondition = (' condition ')'],['Readback: ' message]);
            w.line(['If Not sbCondition Then Fail ' w.q(message) ': Exit Sub']);
        end
    end
    methods (Static)
        function out=q(value)
            value=char(value);
            assert(isrow(value)||isempty(value),'VivaldiBuilder:ScriptValue','Script value must be scalar text.');
            assert(~any(value==char(0)|value==char(10)|value==char(13)), ...
                'VivaldiBuilder:ScriptValue','Newlines and NUL are not permitted in script literals.');
            out=['"' strrep(value,'"','""') '"'];
        end
        function out=array(items)
            out=['Array(' strjoin(items,', ') ')'];
        end
    end
end
