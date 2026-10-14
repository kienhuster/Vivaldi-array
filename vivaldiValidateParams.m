function [ok, errors, warnings, g] = vivaldiValidateParams(p)
%VIVALDIVALIDATEPARAMS Algebraic checks, not a replacement for HFSS validation.
errors = {}; warnings = {}; g = struct();
defaults = vivaldiDefaultParams(); names = fieldnames(defaults);
if ~isstruct(p) || ~isscalar(p)
    errors = {'Cấu hình phải là một struct scalar.'}; ok = false; return;
end
for k = 1:numel(names)
    n = names{k};
    if ~isfield(p,n) || ~isnumeric(p.(n)) || ~isscalar(p.(n)) ...
            || ~isreal(p.(n)) || ~isfinite(p.(n))
        errors{end+1} = [n ': cần số thực hữu hạn scalar.']; %#ok<AGROW>
    elseif ~ismember(n,{'them','positionx','deg_slot_t'}) && p.(n)<=0
        errors{end+1} = [n ': phải dương.']; %#ok<AGROW>
    end
end
if ~isempty(errors), ok = false; return; end
if p.aperture_w<=p.slot_feed_w, errors{end+1}='aperture_w phải lớn hơn slot_feed_w.'; end
if p.them < -6.4, errors{end+1}='slot_t_L = 6.4 + them không được âm.'; end
% Conservative workflow domain; outside it the original transition is unverified.
if p.deg_slot_t<0 || p.deg_slot_t>=90
    errors{end+1}='Miền transition hỗ trợ: 0 <= deg_slot_t < 90°. Đây là miền phần mềm, không phải chứng nhận vật lý.';
end
if ~(p.r_cabin<p.r_cabmid && p.r_cabmid<p.r_cabout)
    errors{end+1}='Cần 0 < r_cabin < r_cabmid < r_cabout.';
end
if ~isempty(errors), ok=false; return; end
g = vivaldiCalculateGeometry(p);
vals = [g.slot_t_L g.L_flare g.r_flare g.x_feed g.z_feed g.L_patch ...
    g.h_cabin g.h_cabmid g.h_cabout g.flareHalfWidth];
if ~isreal(vals) || any(~isfinite(vals)) || g.L_flare<=0 || g.L_patch<=0
    errors{end+1}='Hình học dẫn xuất không hữu hạn hoặc chiều dài không dương.';
end
if g.z_feed>=g.L_flare
    errors{end+1}='Vị trí z_feed nằm ngoài chiều dài flare.';
end
if 2*p.r_cabout>p.thickness
    warnings{end+1}='Đường kính coax lớn hơn chiều dày kim loại: kiểm tra tiếp xúc trong HFSS.';
end
if p.cavity_L>g.L_patch || p.cavity_w>p.aperture_w
    warnings{end+1}='Cavity lớn hơn bao kích thước danh nghĩa: nguy cơ giao cắt.';
end
if abs(g.coax_x)+p.r_cabout>p.aperture_w/2
    warnings{end+1}='Coax có thể ra ngoài bao aperture: kiểm tra CAD.';
end
if any(cellfun(@(n) p.(n)~=defaults.(n),names))
    warnings{end+1}='Thiết kế đã đổi: cần HFSS kiểm tra giao cắt, port, lưới và hiệu năng RF.';
end
ok = isempty(errors);
end
