classdef HFSSGeometryBuilder
    %HFSSGEOMETRYBUILDER Emit the complete parametric CAD dependency sequence.
    methods (Static)
        function build(w,g)
            w.stage('Create Coordinate Systems');
            HFSSGeometryBuilder.cs(w,'slot_t_td','Global', ...
                {'(slot_feed_w/2)*exp(slot_t_L*r_flare)','0mm','slot_t_L'});
            HFSSGeometryBuilder.cs(w,'slot_feed_td','Global',{'-x_feed','0mm','z_feed'});
            HFSSGeometryBuilder.cs(w,'patch_td','Global',{'aperture_w/2','0mm','L_flare'});
            HFSSGeometryBuilder.cs(w,'RelativeCS1','patch_td',{'0mm','-thickness/2','0mm'});
            w.stage('Build Flare');
            HFSSGeometryBuilder.wcs(w,'Global');
            for k = 1:2
                upper = 'L_flare'; if k == 2, upper = 'slot_t_L'; end
                w.api('oEditor','CreateEquationSurface', ...
                    {'NAME:EquationBasedSurfaceParameters', ...
                    'XuvFunction:=','_v*((slot_feed_w/2)*exp((_u)*r_flare))', ...
                    'YuvFunction:=','0','ZuvFunction:=','_u','uStart:=','0', ...
                    'uEnd:=',upper,'vStart:=','-1','vEnd:=','1','Version:=',1}, ...
                    HFSSScript.attributes(sprintf('EquationSurface%d',k),'vacuum','Global',true));
            end
            HFSSGeometryBuilder.copy(w,'EquationSurface2','EquationSurface2_1');
            HFSSGeometryBuilder.subtract(w,'EquationSurface1','EquationSurface2_1',true);
            HFSSGeometryBuilder.remove(w,'EquationSurface2_1');
            HFSSGeometryBuilder.wcs(w,'slot_t_td');
            w.api('oEditor','Rotate',HFSSScript.selection('EquationSurface2'), ...
                {'NAME:RotateParameters','RotateAxis:=','Y','RotateAngle:=','deg_slot_t'});
            w.stage('Build Cavity');
            HFSSGeometryBuilder.wcs(w,'slot_feed_td');
            HFSSGeometryBuilder.rectangle(w,'Rectangle1','slot_feed_td','0mm','0mm','-h3_slot_feed','slot_feed_w');
            HFSSGeometryBuilder.rectangle(w,'Rectangle2','slot_feed_td','0mm','-h3_slot_feed','-slot_feed_w','slot_feed_w+h2+cavity_w');
            HFSSGeometryBuilder.rectangle(w,'Rectangle3','slot_feed_td','slot_feed_w+h2','-h3_slot_feed-slot_feed_w','cavity_L','cavity_w');
            HFSSGeometryBuilder.unite(w,'EquationSurface1,EquationSurface2,Rectangle1,Rectangle2,Rectangle3');
            w.stage('Build Metal Sheets');
            HFSSGeometryBuilder.wcs(w,'patch_td');
            HFSSGeometryBuilder.rectangle(w,'Vivaldi_1','patch_td','0mm','0mm','-L_patch','-aperture_w');
            HFSSGeometryBuilder.subtract(w,'Vivaldi_1','EquationSurface1',false);
            w.api('oEditor','ThickenSheet',HFSSScript.selection('Vivaldi_1'), ...
                {'NAME:SheetThickenParameters','Thickness:=','thickness','BothSides:=',true});
            HFSSGeometryBuilder.checkBounds(w,g.plate1Bounds,'Thickened first plate');
            w.stage('Create Dual-Pol');
            HFSSGeometryBuilder.clonePolarization(w,'Vivaldi_1','Vivaldi_2');
            HFSSGeometryBuilder.checkBounds(w,g.bodyBounds,'Orthogonal plate pair');
            HFSSGeometryBuilder.wcs(w,'RelativeCS1');
            HFSSGeometryBuilder.box(w,'Box1','RelativeCS1', ...
                {'0mm','0mm','0mm'},{'thickness','thickness','-L_patch'});
            HFSSGeometryBuilder.wcs(w,'Global');
            HFSSGeometryBuilder.box(w,'De','Global', ...
                {'(de_L+thickness)/2','-(de_W-aperture_w)/2','z_feed-h3_slot_feed-slot_feed_w'}, ...
                {'-de_L','de_W','-h_de'});
            HFSSGeometryBuilder.unite(w,'Vivaldi_1,Vivaldi_2,Box1,De');
            w.checked('volumeValue = oEditor.GetObjectVolume("Vivaldi_1")');
            w.require('CDbl(volumeValue) > 0','United antenna has no positive volume.');
            HFSSGeometryBuilder.connectivity(w);
        end
        function cs(w,name,parent,origin)
            HFSSGeometryBuilder.wcs(w,parent);
            w.api('oEditor','CreateRelativeCS', ...
                {'NAME:RelativeCSParameters','Mode:=','Axis/Position', ...
                'OriginX:=',origin{1},'OriginY:=',origin{2},'OriginZ:=',origin{3}, ...
                'XAxisXvec:=','1mm','XAxisYvec:=','0mm','XAxisZvec:=','0mm', ...
                'YAxisXvec:=','0mm','YAxisYvec:=','1mm','YAxisZvec:=','0mm'}, ...
                {'NAME:Attributes','Name:=',name});
            w.api('oEditor','ChangeProperty',{'NAME:AllTabs', ...
                {'NAME:Geometry3DCSTab',{'NAME:PropServers',name}, ...
                {'NAME:ChangedProps',{'NAME:Reference CS','Value:=',parent}}}});
        end
        function wcs(w,name)
            w.api('oEditor','SetWCS',{'NAME:SetWCS Parameter','Working Coordinate System:=',name,'RegionDepCSOk:=',false});
        end
        function rectangle(w,name,cs,x,z,width,height)
            w.api('oEditor','CreateRectangle',{'NAME:RectangleParameters','IsCovered:=',false, ...
                'XStart:=',x,'YStart:=','0mm','ZStart:=',z,'Width:=',width, ...
                'Height:=',height,'WhichAxis:=','Y'},HFSSScript.attributes(name,'vacuum',cs,true));
            w.api('oEditor','CoverLines',HFSSScript.selection(name));
        end
        function box(w,name,cs,pos,sz)
            w.api('oEditor','CreateBox',{'NAME:BoxParameters','XPosition:=',pos{1}, ...
                'YPosition:=',pos{2},'ZPosition:=',pos{3},'XSize:=',sz{1}, ...
                'YSize:=',sz{2},'ZSize:=',sz{3}},HFSSScript.attributes(name,'aluminum',cs,false));
        end
        function subtract(w,blank,tools,keep)
            w.api('oEditor','Subtract',{'NAME:Selections','Blank Parts:=',blank,'Tool Parts:=',tools}, ...
                {'NAME:SubtractParameters','KeepOriginals:=',keep});
            w.checked('items = oEditor.GetObjectsInGroup("Unclassified")');
            w.require('CountItems(items) = 0','Subtract produced Unclassified geometry.');
        end
        function unite(w,names)
            w.api('oEditor','Unite',HFSSScript.selection(names),{'NAME:UniteParameters','KeepOriginals:=',false});
            w.checked('items = oEditor.GetObjectsInGroup("Unclassified")');
            w.require('CountItems(items) = 0','Unite produced Unclassified geometry.');
        end
        function remove(w,names), w.api('oEditor','Delete',HFSSScript.selection(names)); end
        function copy(w,source,destination)
            w.checked('beforeObjects = AllObjects()');
            w.api('oEditor','Copy',HFSSScript.selection(source));
            w.checked('oEditor.Paste');
            HFSSGeometryBuilder.renameNew(w,destination);
        end
        function clonePolarization(w,source,destination)
            HFSSGeometryBuilder.wcs(w,'RelativeCS1');
            w.checked('beforeObjects = AllObjects()');
            w.api('oEditor','DuplicateAroundAxis',HFSSScript.selection(source), ...
                {'NAME:DuplicateAroundAxisParameters','CreateNewObjects:=',true, ...
                'WhichAxis:=','Z','AngleStr:=','-90deg','Numclones:=','2'}, ...
                {'NAME:Options','DuplicateAssignments:=',false});
            HFSSGeometryBuilder.renameNew(w,destination);
            w.api('oEditor','Move',HFSSScript.selection(destination), ...
                {'NAME:TranslateParameters','TranslateVectorX:=','0mm', ...
                'TranslateVectorY:=','thickness','TranslateVectorZ:=','0mm'});
        end
        function renameNew(w,destination)
            w.checked('created = SingleNewObject(beforeObjects)');
            w.api('oEditor','ChangeProperty',{'NAME:AllTabs', ...
                {'NAME:Geometry3DAttributeTab',{'NAME:PropServers',HFSSScript.raw('created')}, ...
                {'NAME:ChangedProps',{'NAME:Name','Value:=',destination}}}});
        end
        function checkBounds(w,expected,label)
            % 2021 R2 lacks GetObjectBoundingBox. Call only when the modeled
            % inventory's combined envelope is the intended target.
            HFSSGeometryBuilder.wcs(w,'Global');
            w.checked('bounds = oEditor.GetModelBoundingBox()');
            for k = 1:6
                w.require(sprintf('Abs(CDbl(bounds(%d)) - %.15g) < 0.001',k-1,expected(k)), ...
                    [label ': bounding box mismatch; inspect rectangle axes / thickening / transforms.']);
            end
            w.add(['Note ' HFSSScript.quote(['BOUNDS|' label]) ' & "|" & Join(bounds, "|")']);
        end
        function connectivity(w)
            % Diagnose a disposable copy, preserving the modeled body's history.
            HFSSGeometryBuilder.copy(w,'Vivaldi_1','BodyConnectivityCheck');
            w.api('oEditor','SeparateBody',HFSSScript.selection('BodyConnectivityCheck'), ...
                {'CreateGroupsForNewObjects:=',false});
            w.checked('created = NewObjectNames(beforeObjects)');
            w.require('Len(created) > 0','Connectivity diagnostic returned no body.');
            HFSSGeometryBuilder.remove(w,HFSSScript.raw('created'));
            w.require('UBound(Split(created, ",")) = 0','Antenna contains disconnected bodies after Boolean operations.');
            w.add('Note "CONNECTIVITY|one separated body"');
        end
    end
end
