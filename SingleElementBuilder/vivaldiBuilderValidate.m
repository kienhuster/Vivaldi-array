function [ok, errors, warnings, g] = vivaldiBuilderValidate(p)
%VIVALDIBUILDERVALIDATE Algebraic checks; CAD contacts still need HFSS.
errors = {}; warnings = {}; g = [];
[defaults,meta] = vivaldiBuilderDefaultParams();
if ~isstruct(p) || ~isscalar(p)
    errors = {'Parameters must be a scalar structure.'}; ok = false; return;
end
for k = 1:numel(meta)
    n = meta(k).name;
    if ~isfield(p,n) || ~isnumeric(p.(n)) || ~isreal(p.(n)) ...
            || ~isscalar(p.(n)) || ~isfinite(p.(n))
        errors{end+1} = [n ': expected a finite real scalar.']; %#ok<AGROW>
    end
end
if ~isempty(errors), ok = false; return; end
positive = setdiff(fieldnames(defaults),{'them','positionx','deg_slot_t'});
for k = 1:numel(positive)
    if p.(positive{k}) <= 0, errors{end+1} = [positive{k} ' must be positive.']; end %#ok<AGROW>
end
if p.aperture_w <= p.slot_feed_w, errors{end+1} = 'aperture_w must exceed slot_feed_w.'; end
if ~(p.r_cabin < p.r_cabmid && p.r_cabmid < p.r_cabout)
    errors{end+1} = 'Require r_cabin < r_cabmid < r_cabout.';
end
if 6.4+p.them <= 0, errors{end+1} = 'Transition length must be positive.'; end
if p.deg_slot_t < 0 || p.deg_slot_t >= 90, errors{end+1} = 'Require 0 <= deg_slot_t < 90.'; end
if ~isempty(errors), ok = false; return; end
g = vivaldiBuilderGeometry(p);
if ~isfinite(g.L_patch) || g.L_patch <= 0 || ~isfinite(g.r_flare)
    errors{end+1} = 'Derived dimensions are not finite and positive.';
end
if g.coax1(1)-p.r_cabout < -p.aperture_w/2 ...
        || g.coax1(1)+p.r_cabout > p.aperture_w/2
    warnings{end+1} = 'Coax extends beyond the first plate width; inspect contacts in HFSS.';
end
if p.cavity_L > g.L_patch || p.cavity_w > p.aperture_w
    warnings{end+1} = 'Cavity dimensions exceed the plate envelope.';
end
if p.r_cabin > p.slot_feed_w/2
    warnings{end+1} = 'Inner conductor may intersect the slot walls.';
end
warnings{end+1} = 'Parameter checks do not certify Boolean validity, contacts or port orientation.';
ok = isempty(errors);
end
