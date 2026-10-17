function [q,g] = vivaldiBuilderTargetLength(p,target)
%VIVALDIBUILDERTARGETLENGTH Change only L_flare_1 to reach total length in mm.
validateattributes(target,{'numeric'},{'scalar','real','finite','positive'});
[ok,e] = vivaldiBuilderValidate(p);
assert(ok,'VivaldiBuilder:Parameters','%s',strjoin(e,newline));
q = p;
f = @(length) residual(p,length,target);
bounds = [.01 max(100,2*target)];
assert(f(bounds(1))*f(bounds(2)) <= 0,'VivaldiBuilder:Target', ...
    'No positive main-flare length brackets this target.');
q.L_flare_1 = fzero(f,bounds);
[ok,e,~,g] = vivaldiBuilderValidate(q);
assert(ok,'VivaldiBuilder:Target','%s',strjoin(e,newline));
end
function r = residual(p,length,target)
p.L_flare_1 = length; g = vivaldiBuilderGeometry(p); r = g.L_patch-target;
end
