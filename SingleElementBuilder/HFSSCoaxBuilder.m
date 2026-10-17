classdef HFSSCoaxBuilder
    methods (Static)
        function build(w,g)
            w.stage('Create Coax');
            HFSSGeometryBuilder.wcs(w,'slot_feed_td');
            HFSSCoaxBuilder.cylinder(w,'cable_in','r_cabin','-h3_slot_feed','-h_cabin');
            HFSSCoaxBuilder.cylinder(w,'cable_out','r_cabout','-h3_slot_feed-slot_feed_w','-h_cabout');
            HFSSCoaxBuilder.cylinder(w,'cable_mid','r_cabmid','-h3_slot_feed-slot_feed_w','-h_cabmid');
            HFSSGeometryBuilder.subtract(w,'cable_out','cable_mid',true);
            w.api('oEditor','CreateCircle',{'NAME:CircleParameters','IsCovered:=',false, ...
                'XCenter:=','-positionx+slot_feed_w+h2','YCenter:=','0mm', ...
                'ZCenter:=','-h3_slot_feed-h_cabin','Radius:=','r_cabmid', ...
                'WhichAxis:=','Z','NumSegments:=','0'}, ...
                HFSSScript.attributes('port1','vacuum','slot_feed_td',true));
            w.api('oEditor','CoverLines',HFSSScript.selection('port1'));
            names = {'cable_in','cable_out','cable_mid','port1'};
            copies = {'cable_in_1','cable_out_1','cable_mid_1','port2'};
            for k = 1:4, HFSSGeometryBuilder.clonePolarization(w,names{k},copies{k}); end
            w.stage('Apply Boolean');
            sources = {'cable_in','cable_in_1','cable_mid','cable_mid_1','cable_out','cable_out_1'};
            cutters = cell(1,6);
            for k = 1:6
                cutters{k} = sprintf('coax_cutter_%d',k);
                HFSSGeometryBuilder.copy(w,sources{k},cutters{k});
            end
            HFSSGeometryBuilder.subtract(w,'Vivaldi_1',strjoin(cutters,','),true);
            HFSSGeometryBuilder.remove(w,strjoin([cutters {'cable_mid','cable_mid_1'}],','));
            HFSSGeometryBuilder.connectivity(w);
            HFSSGeometryBuilder.checkBounds(w,g.bodyBounds,'Antenna including both coax feeds');
            w.stage('Assign Materials');
            HFSSCoaxBuilder.material(w,'Vivaldi_1','aluminum',false);
            HFSSCoaxBuilder.material(w,'cable_in,cable_out,cable_in_1,cable_out_1','copper',false);
        end
        function cylinder(w,name,radius,z,height)
            w.api('oEditor','CreateCylinder',{'NAME:CylinderParameters', ...
                'XCenter:=','-positionx+slot_feed_w+h2','YCenter:=','0mm', ...
                'ZCenter:=',z,'Radius:=',radius,'Height:=',height, ...
                'WhichAxis:=','Z','NumSides:=','0'}, ...
                HFSSScript.attributes(name,'copper','slot_feed_td',false));
        end
        function material(w,names,material,solveInside)
            w.api('oEditor','AssignMaterial',HFSSScript.selection(names), ...
                {'NAME:Attributes','MaterialValue:=',['"' material '"'], ...
                'SolveInside:=',solveInside});
        end
        function ports(w,p,g,editExisting)
            w.stage('Assign Ports');
            HFSSGeometryBuilder.wcs(w,'Global');
            centers = [g.coax1;g.coax2];
            for k = 1:2
                conductor = 'cable_in'; if k == 2, conductor = 'cable_in_1'; end
                args = [{sprintf('port%d',k),conductor} num2cell(centers(k,:)) {p.r_cabmid,p.r_cabin}];
                encoded = cellfun(@(x)w.value(x),args,'UniformOutput',false);
                w.checked(['portLine = FindPortLine(' strjoin(encoded,', ') ')']);
                mode = {'NAME:Mode1','ModeNum:=',1,'UseIntLine:=',true, ...
                    {'NAME:IntLine','Start:=',HFSSScript.raw('portLine(0)'), ...
                    'End:=',HFSSScript.raw('portLine(1)')}, ...
                    'AlignmentGroup:=',0,'CharImp:=','Zpi','RenormImp:=','50ohm'};
                port = {['NAME:' num2str(k)],'Objects:=',{sprintf('port%d',k)}, ...
                    'DoDeembed:=',false,'RenormalizeAllTerminals:=',true, ...
                    {'NAME:Modes',mode},'ShowReporterFilter:=',false, ...
                    'ReporterFilter:=',{true},'Impedance:=','50ohm'};
                if editExisting
                    w.api('oBoundary','EditLumpedPort',num2str(k),port);
                else
                    w.api('oBoundary','AssignLumpedPort',port);
                end
            end
        end
    end
end
