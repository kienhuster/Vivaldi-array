function g = vivaldiBuilderGeometry(p)
%VIVALDIBUILDERGEOMETRY Scalar formulas and rigid transforms; lengths in mm.
g.slot_t_L = 6.4+p.them;
g.L_flare = p.L_flare_1+g.slot_t_L;
g.r_flare = log(p.aperture_w/p.slot_feed_w)/g.L_flare;
a = p.slot_feed_w/2*exp(g.slot_t_L*g.r_flare);
g.z_feed = (a+p.slot_feed_w/2)*sind(p.deg_slot_t) ...
    +g.slot_t_L*(1-cosd(p.deg_slot_t));
g.x_feed = (a+p.slot_feed_w/2)*cosd(p.deg_slot_t) ...
    +g.slot_t_L*sind(p.deg_slot_t)-a;
g.L_patch = g.L_flare-g.z_feed+p.h3_slot_feed+p.slot_feed_w+p.h_de;
g.de_L = p.aperture_w+p.thickness; g.de_W = g.de_L;
g.h_cabin = p.h_de+p.slot_feed_w;
g.h_cabout = p.h_de; g.h_cabmid = p.h_de;
g.z_base = g.L_flare-g.L_patch;
g.cs.Global = [0 0 0]; g.cs.slot_t_td = [a 0 g.slot_t_L];
g.cs.slot_feed_td = [-g.x_feed 0 g.z_feed];
g.cs.patch_td = [p.aperture_w/2 0 g.L_flare];
g.cs.RelativeCS1 = [p.aperture_w/2 -p.thickness/2 g.L_flare];
g.R2 = [0 1 0;-1 0 0;0 0 1];
g.transform2 = @(xyz) (xyz-g.cs.RelativeCS1)*g.R2' ...
    +g.cs.RelativeCS1+[0 p.thickness 0];
g.coax1 = [-g.x_feed-p.positionx+p.slot_feed_w+p.h2 0 g.z_base];
g.coax2 = g.transform2(g.coax1);
g.bodyBounds = [-p.aperture_w/2 -p.thickness/2 g.z_base ...
    p.aperture_w/2+p.thickness p.aperture_w+p.thickness/2 g.L_flare];
g.plate1Bounds = [-p.aperture_w/2 -p.thickness/2 g.z_base ...
    p.aperture_w/2 p.thickness/2 g.L_flare];
g.plate2Bounds = [p.aperture_w/2 p.thickness/2 g.z_base ...
    p.aperture_w/2+p.thickness p.aperture_w+p.thickness/2 g.L_flare];
end
