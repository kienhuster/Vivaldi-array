function out = vivaldiBuilderIO(action,file,p)
%VIVALDIBUILDERIO Versioned configs, dimensional CSV and configuration reports.
out = [];
switch lower(action)
    case 'load'
        saved = jsondecode(fileread(file));
        assert(isfield(saved,'schema') && strcmp(saved.schema,'vivaldi-dual-pol-builder/1'), ...
            'VivaldiBuilder:Schema','Unsupported configuration schema.');
        out = saved.params; defaults = vivaldiBuilderDefaultParams();
        assert(isequal(sort(fieldnames(out)),sort(fieldnames(defaults))), ...
            'VivaldiBuilder:Schema','Configuration parameter names differ.');
        [ok,e] = vivaldiBuilderValidate(out);
        assert(ok,'VivaldiBuilder:Parameters','%s',strjoin(e,newline));
    case {'save','report'}
        [ok,e,warning,g] = vivaldiBuilderValidate(p);
        assert(ok,'VivaldiBuilder:Parameters','%s',strjoin(e,newline));
        out = struct('schema','vivaldi-dual-pol-builder/1','params',p);
        if strcmpi(action,'report')
            out.geometry = rmfield(g,'transform2'); out.warnings = warning;
            out.verification = 'Mathematical configuration only; no HFSS result implied.';
        end
        fid = fopen(file,'w','n','UTF-8');
        assert(fid >= 0,'VivaldiBuilder:Write','Cannot write configuration.');
        cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
        fprintf(fid,'%s\n',jsonencode(out));
    case 'dimensions'
        [ok,e,~,g] = vivaldiBuilderValidate(p);
        assert(ok,'VivaldiBuilder:Parameters','%s',strjoin(e,newline));
        [~,meta] = vivaldiBuilderDefaultParams();
        names = {meta.name}'; units = {meta.unit}'; values = cellfun(@(n)p.(n),names);
        derived = {'slot_t_L','L_flare','r_flare','x_feed','z_feed','L_patch', ...
            'de_L','de_W','h_cabin','h_cabout','h_cabmid'}';
        derivedUnits = repmat({'mm'},size(derived)); derivedUnits{3} = 'mm^-1';
        names = [names;derived]; units = [units;derivedUnits];
        values = [values;cellfun(@(n)g.(n),derived)];
        out = table(names,values,units,'VariableNames',{'Variable','Nominal','Unit'});
        writetable(out,file);
    otherwise, error('VivaldiBuilder:IO','Unknown file operation.');
end
end
