function vivaldiBuilderPreview(ax,p,options)
%VIVALDIBUILDERPREVIEW Sampled mathematical CSG, never labeled as HFSS CAD.
if nargin < 3, options = struct(); end
defaults = struct('coax',true,'coordinates',false,'dimensions',true,'view','3D');
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(options,names{k}), options.(names{k}) = defaults.(names{k}); end
end
[ok,e,~,g] = vivaldiBuilderValidate(p);
assert(ok,'VivaldiBuilder:Preview','%s',strjoin(e,newline));
u = linspace(g.slot_t_L,g.L_flare,240);
width = p.slot_feed_w/2*exp(u*g.r_flare);
cut = polyshape([width -fliplr(width)],[u fliplr(u)],'Simplify',true);
u = linspace(0,g.slot_t_L,100); width = p.slot_feed_w/2*exp(u*g.r_flare);
short = [width -fliplr(width);u fliplr(u)]';
center = g.cs.slot_t_td([1 3]);
R = [cosd(p.deg_slot_t) sind(p.deg_slot_t);-sind(p.deg_slot_t) cosd(p.deg_slot_t)];
short = (short-center)*R'+center;
cut = union(cut,polyshape(short(:,1),short(:,2),'Simplify',true));
rectangles = [0 0 p.slot_feed_w -p.h3_slot_feed; ...
    0 -p.h3_slot_feed p.slot_feed_w+p.h2+p.cavity_w -p.slot_feed_w; ...
    p.slot_feed_w+p.h2 -p.h3_slot_feed-p.slot_feed_w p.cavity_w p.cavity_L];
for k = 1:3
    r = rectangles(k,:); x = r(1)+[-0 1 1 0]*r(3)-g.x_feed;
    z = r(2)+[0 0 1 1]*r(4)+g.z_feed;
    cut = union(cut,polyshape(x,z,'Simplify',true));
end
plate = polyshape([-1 1 1 -1]*p.aperture_w/2,[g.z_base g.z_base g.L_flare g.L_flare]);
plate = subtract(plate,cut);
cla(ax); hold(ax,'on');
extrude(plate,p.thickness,false,[.75 .77 .82]);
extrude(plate,p.thickness,true,[.45 .62 .82]);
box([p.aperture_w/2 -p.thickness/2 g.z_base], ...
    [p.thickness p.thickness g.L_patch],[.6 .65 .7]);
box([-p.aperture_w/2 -p.thickness/2 g.z_base], ...
    [g.de_L g.de_W p.h_de],[.55 .57 .62]);
if options.coax
    for k = 1:2
        c = g.coax1; if k == 2, c = g.coax2; end
        for r = [p.r_cabin p.r_cabmid p.r_cabout]
            [x,y,z] = cylinder(r,32);
            h = p.h_de; if r == p.r_cabin, h = g.h_cabin; end
            surf(ax,x+c(1),y+c(2),z*h+c(3),'FaceColor',[.85 .48 .2], ...
                'EdgeColor','none','FaceAlpha',.7);
        end
    end
end
if options.coordinates
    names = fieldnames(g.cs);
    for k = 1:numel(names)
        c = g.cs.(names{k}); plot3(ax,c(1),c(2),c(3),'k+');
        text(ax,c(1),c(2),c(3),[' ' names{k}],'Interpreter','none');
    end
end
xlabel(ax,'X (mm)'); ylabel(ax,'Y (mm)'); zlabel(ax,'Z (mm)');
title(ax,'Mathematical preview — not HFSS CAD','Interpreter','none');
if options.dimensions
    subtitle(ax,sprintf('Envelope %.3g x %.3g x %.6f mm | sampled flare / cavity',g.de_L,g.de_W,g.L_patch));
end
axis(ax,'equal'); grid(ax,'on');
switch options.view
    case 'Front View', view(ax,0,0);
    case 'Side View', view(ax,90,0);
    case 'Top View', view(ax,0,90);
    otherwise, view(ax,40,22);
end
hold(ax,'off');

    function extrude(shape,t,second,color)
        tr = triangulation(shape); pts = tr.Points;
        for side = [-1 1]
            v = [pts(:,1) side*t/2*ones(size(pts,1),1) pts(:,2)];
            if second, v = g.transform2(v); end
            patch(ax,'Faces',tr.ConnectivityList,'Vertices',v,'FaceColor',color,'EdgeColor','none','FaceAlpha',.9);
        end
        [bx,bz] = boundary(shape);
        for j = 1:numel(bx)-1
            if any(isnan([bx(j:j+1);bz(j:j+1)])), continue; end
            v = [bx(j) -t/2 bz(j);bx(j+1) -t/2 bz(j+1); ...
                bx(j+1) t/2 bz(j+1);bx(j) t/2 bz(j)];
            if second, v = g.transform2(v); end
            patch(ax,'Faces',[1 2 3 4],'Vertices',v,'FaceColor',color,'EdgeColor','none');
        end
    end
    function box(origin,sz,color)
        v = [0 0 0;1 0 0;1 1 0;0 1 0;0 0 1;1 0 1;1 1 1;0 1 1].*sz+origin;
        patch(ax,'Faces',[1 2 3 4;5 6 7 8;1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8], ...
            'Vertices',v,'FaceColor',color,'EdgeColor',[.3 .3 .3]);
    end
end
