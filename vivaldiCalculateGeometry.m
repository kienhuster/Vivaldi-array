function g = vivaldiCalculateGeometry(p)
%VIVALDICALCULATEGEOMETRY Exact scalar expressions from ModelSetup/Properties.
g.slot_t_L = 6.4 + p.them;
g.L_flare = p.L_flare_1 + g.slot_t_L;
g.r_flare = log(p.aperture_w / p.slot_feed_w) / g.L_flare;
a = p.slot_feed_w/2 * exp(g.slot_t_L*g.r_flare);
g.z_feed = (a+p.slot_feed_w/2)*sind(p.deg_slot_t) ...
    + g.slot_t_L*(1-cosd(p.deg_slot_t));
g.x_feed = (a+p.slot_feed_w/2)*cosd(p.deg_slot_t) ...
    + g.slot_t_L*sind(p.deg_slot_t)-a;
g.L_patch = p.L_flare_1+g.slot_t_L-g.z_feed ...
    +p.h3_slot_feed+p.slot_feed_w+p.h_de;
g.h_cabin = p.h_de+p.slot_feed_w;
g.h_cabmid = g.h_cabin-p.slot_feed_w;
g.h_cabout = g.h_cabin-p.slot_feed_w;
g.de_L = p.aperture_w+p.thickness;
g.de_W = g.de_L;
% lamda is an independent HFSS variable: do not silently retune the setup.
g.u = linspace(0,g.L_flare,401);
g.flareHalfWidth = p.slot_feed_w/2*exp(g.r_flare*g.u);
g.aperture_w = p.aperture_w;
g.z_base = g.L_flare-g.L_patch;
g.coax_x = -g.x_feed-p.positionx+p.slot_feed_w+p.h2;
g.coax_z = g.z_feed-p.h3_slot_feed;
end
