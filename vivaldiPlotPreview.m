function h = vivaldiPlotPreview(ax,p,g,options)
%VIVALDIPLOTPREVIEW Source equation/operand diagram, NOT a manufacturing CAD.
if nargin<4, options=struct(); end
base=struct('view','Top View','flare',true,'feed',true,'coax',true, ...
    'polarization2',true,'dimensions',true,'envelope',true);
fn=fieldnames(base);
for k=1:numel(fn), if ~isfield(options,fn{k}), options.(fn{k})=base.(fn{k}); end, end
cla(ax); hold(ax,'on'); h=gobjects(0); colors=[.08 .48 .82;.9 .38 .13];
for pol=1:(1+logical(options.polarization2))
    if options.envelope
        xyz=[-p.aperture_w/2 p.aperture_w/2 p.aperture_w/2 -p.aperture_w/2 -p.aperture_w/2; ...
            zeros(1,5);g.z_base g.z_base g.L_flare g.L_flare g.z_base];
        draw(xyz,'--',sprintf('Bao danh nghĩa P%d (sơ đồ)',pol));
    end
    if options.flare
        draw([g.flareHalfWidth;zeros(size(g.u));g.u],'-',sprintf('Equation flare + P%d',pol));
        draw([-g.flareHalfWidth;zeros(size(g.u));g.u],'-',sprintf('Equation flare − P%d',pol));
    end
    if options.feed
        % Rectangle1/2/3 use slot_feed_td, origin (-x_feed,0,z_feed).
        rect(-g.x_feed,g.z_feed-p.h3_slot_feed,p.slot_feed_w,p.h3_slot_feed,'Transition');
        rect(-g.x_feed,g.z_feed-p.h3_slot_feed-p.slot_feed_w, ...
            p.slot_feed_w+p.h2+p.cavity_w,p.slot_feed_w,'Feed slot');
        rect(-g.x_feed+p.slot_feed_w+p.h2, ...
            g.z_feed-p.h3_slot_feed-p.slot_feed_w,p.cavity_w,p.cavity_L,'Cavity operand');
    end
    if options.coax
        t=linspace(0,2*pi,80);
        for r=[p.r_cabin p.r_cabmid p.r_cabout]
            xyz=[g.coax_x+r*cos(t);r*sin(t);g.coax_z+zeros(size(t))];
            draw(xyz,':',sprintf('Coax r=%.3g P%d',r,pol));
        end
        draw([g.coax_x g.coax_x;0 0;g.coax_z g.coax_z-g.h_cabin],':','Trục coax');
    end
end
if options.dimensions
    pol=1;
    x=-p.aperture_w/2-3;
    draw([x x;0 0;g.z_base g.L_flare],'-','L_patch');
    quiver3(ax,x,0,g.z_base,0,0,g.L_patch,0,'Color',[.3 .3 .3],'MaxHeadSize',.12,'HandleVisibility','off');
    quiver3(ax,x,0,g.L_flare,0,0,-g.L_patch,0,'Color',[.3 .3 .3],'MaxHeadSize',.12,'HandleVisibility','off');
    text(ax,x,0,(g.z_base+g.L_flare)/2,sprintf(' L_patch %.6f mm',g.L_patch),'FontSize',10);
    draw([-p.aperture_w/2 p.aperture_w/2;0 0;g.L_flare+2 g.L_flare+2],'-','aperture');
    text(ax,0,0,g.L_flare+3,sprintf('aperture %.3f mm',p.aperture_w),'HorizontalAlignment','center');
end
axis(ax,'equal'); grid(ax,'on'); xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)'); zlabel(ax,'Z (mm)');
switch options.view
    case 'Top View', view(ax,0,0); % Look along Y at XZ; explicitly labelled.
    case 'Side View', view(ax,90,0);
    otherwise, view(ax,35,25);
end
title(ax,{'Sơ đồ phương trình/operand — KHÔNG phải CAD hoàn chỉnh', ...
    'Chưa tái tạo Boolean, phần transition quay và tiếp xúc kim loại'},'FontSize',11);
hold(ax,'off');
    function draw(xyz,style,name)
        if pol==2
            % -90 degrees about Z in RelativeCS1 followed by +thickness Y.
            origin=[p.aperture_w/2;-p.thickness/2;0];
            R=[0 1 0;-1 0 0;0 0 1];
            xyz=R*(xyz-origin)+origin+[0;p.thickness;0];
        end
        h(end+1)=plot3(ax,xyz(1,:),xyz(2,:),xyz(3,:),style, ...
            'Color',colors(pol,:),'LineWidth',1.4,'DisplayName',name);
    end
    function rect(x,z,w,l,name)
        draw([x x+w x+w x x;zeros(1,5);z z z+l z+l z],'-.',sprintf('%s P%d',name,pol));
    end
end
