classdef HFSSPostProcessing
    %HFSSPOSTPROCESSING Real HFSS reports/CSV only; no synthetic RF data.
    methods (Static)
        function reports(w,cfg,job)
            w.stage('Export Results');
            solution = [cfg.profile ' : Sweep'];
            HFSSPostProcessing.report(w,job,'S_parameters','Modal Solution Data', ...
                'Rectangular Plot',solution,{}, {'Freq:=',{'All'}}, ...
                {'X Component:=','Freq','Y Component:=', ...
                {'dB(S(1,1))','dB(S(2,2))','dB(S(2,1))','dB(S(1,2))'}});
            HFSSPostProcessing.report(w,job,'VSWR','Modal Solution Data', ...
                'Rectangular Plot',solution,{}, {'Freq:=',{'All'}}, ...
                {'X Component:=','Freq','Y Component:=',{'VSWR(1)','VSWR(2)'}});
            context = {'Context:=','3D'};
            frequency = sprintf('%gGHz',cfg.reportFrequency);
            cut = {'Theta:=',{'All'},'Phi:=',{'0deg'},'Freq:=',{frequency}};
            HFSSPostProcessing.report(w,job,'Realized_Gain_Cut','Far Fields', ...
                'Rectangular Plot',solution,context,cut, ...
                {'X Component:=','Theta','Y Component:=',{'dB(RealizedGainTotal)'}});
            HFSSPostProcessing.report(w,job,'Radiation_2D','Far Fields', ...
                'Radiation Pattern',solution,context,cut, ...
                {'Ang Component:=','Theta','Mag Component:=',{'dB(RealizedGainTotal)'}});
            HFSSPostProcessing.report(w,job,'Radiation_3D','Far Fields', ...
                '3D Polar Plot',solution,context, ...
                {'Theta:=',{'All'},'Phi:=',{'All'},'Freq:=',{frequency}}, ...
                {'Phi Component:=','Phi','Theta Component:=','Theta', ...
                'Mag Component:=',{'dB(RealizedGainTotal)'}});
            HFSSPostProcessing.report(w,job,'Radiation_Efficiency','Antenna Params', ...
                'Rectangular Plot',solution,context,{'Freq:=',{'All'}}, ...
                {'X Component:=','Freq','Y Component:=',{'RadiationEfficiency'}});
        end
        function report(w,job,name,category,kind,solution,context,variations,components)
            % Unique project copy: these names cannot overwrite source reports.
            name = ['Builder_' name];
            w.api('oReport','CreateReport',name,category,kind,solution,context,variations,components);
            file = fullfile(job.directory,[name '.csv']);
            w.api('oReport','ExportToFile',name,file,false);
            w.require(['fs.FileExists(' HFSSScript.quote(file) ')'],'HFSS did not export the requested report CSV.');
            w.add(['Note ' HFSSScript.quote(['CSV|' file])]);
        end
        function data = loadCSV(file,xColumn,yColumns)
            assert(isfile(file),'VivaldiBuilder:CSV','CSV file does not exist.');
            T = readtable(file,'VariableNamingRule','preserve');
            if nargin == 1
                data = T; return;
            end
            assert(ismember(xColumn,T.Properties.VariableNames) ...
                && all(ismember(yColumns,T.Properties.VariableNames)), ...
                'VivaldiBuilder:CSVColumns','Select existing CSV columns.');
            x = T{:,xColumn}; y = T{:,yColumns};
            assert(isnumeric(x) && isnumeric(y) && isreal(x) && isreal(y) ...
                && ~isempty(x) && size(x,2) == 1 && all(isfinite(x(:))) && all(isfinite(y(:))), ...
                'VivaldiBuilder:CSVData','Selected columns must contain finite real numeric samples.');
            data = struct('file',file,'xName',xColumn,'yNames',{yColumns},'x',x,'y',y);
        end
        function result = hpbw(angle,gainDB)
            validateattributes(angle,{'numeric'},{'vector','real','finite'});
            validateattributes(gainDB,{'numeric'},{'vector','real','finite','numel',numel(angle)});
            [angle,order] = sort(angle(:)); gainDB = gainDB(order);
            assert(numel(angle) >= 3 && all(diff(angle)>0),'VivaldiBuilder:HPBW', ...
                'Supply at least three unique angles from one constant-frequency, constant-phi cut.');
            [peak,k] = max(gainDB); level = peak-3;
            left = find(gainDB(1:k) <= level,1,'last');
            right = find(gainDB(k:end) <= level,1,'first')+k-1;
            result = struct('degrees',NaN,'left',NaN,'right',NaN,'peak',peak, ...
                'reason','Cut does not bracket both half-power crossings; no HPBW claimed.');
            if isempty(left) || isempty(right) || left == k || right == k, return; end
            x1 = interp1(gainDB([left left+1]),angle([left left+1]),level);
            x2 = interp1(gainDB([right-1 right]),angle([right-1 right]),level);
            result.degrees = x2-x1; result.left = x1; result.right = x2;
            result.reason = 'Nearest -3 dB crossings around the strongest sampled lobe; no circular-cut extrapolation.';
        end
    end
end
