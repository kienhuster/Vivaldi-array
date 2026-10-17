function variables = vivaldiBuilderVariables(p)
%VIVALDIBUILDERVARIABLES Complete dependent expressions, never frozen numbers.
[~,meta] = vivaldiBuilderDefaultParams();
variables = cell(numel(meta),2);
for k = 1:numel(meta)
    variables(k,:) = {meta(k).name,sprintf('%.15g%s',p.(meta(k).name),meta(k).unit)};
end
variables = [variables; {
    'slot_t_L','6.4mm+them';
    'L_flare','L_flare_1+slot_t_L';
    'r_flare','(1/L_flare)*ln(aperture_w/slot_feed_w)';
    'z_feed','((slot_feed_w/2)*exp((slot_t_L)*r_flare)+slot_feed_w/2)*sin(deg_slot_t)+slot_t_L*(1-cos(deg_slot_t))';
    'x_feed','((slot_feed_w/2)*exp((slot_t_L)*r_flare)+slot_feed_w/2)*cos(deg_slot_t)+slot_t_L*(sin(deg_slot_t))-(slot_feed_w/2)*exp((slot_t_L)*r_flare)';
    'L_patch','L_flare_1+slot_t_L-z_feed+h3_slot_feed+slot_feed_w+h_de';
    'h_cabin','h_de+slot_feed_w';
    'h_cabout','h_cabin-slot_feed_w';
    'h_cabmid','h_cabin-slot_feed_w';
    'de_L','aperture_w+thickness';'de_W','aperture_w+thickness';
    'lamda','60mm';'h_box','lamda/2+L_patch';
    'scan_phi','0deg';'scan_theta','0deg';'c2','0mm'}];
% Dependency order: independent literals, then a topologically sorted DAG.
end
