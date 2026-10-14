function [after, comparison] = vivaldiSolveTargetLength(p, target, bounds)
%VIVALDISOLVETARGETLENGTH Solve only L_flare_1 in a user-visible search domain.
if nargin<3, bounds=[0.001 200]; end
[ok,errors,~,before] = vivaldiValidateParams(p);
assert(ok,'Vivaldi:InvalidParameters','%s',strjoin(errors,newline));
validateattributes(target,{'numeric'},{'real','finite','scalar','positive'});
validateattributes(bounds,{'numeric'},{'real','finite','vector','numel',2,'positive'});
assert(bounds(1)<bounds(2),'Vivaldi:SearchDomain','Giới hạn dưới phải nhỏ hơn giới hạn trên.');
% Scan valid portions instead of evaluating fzero across invalid geometry.
xs = linspace(bounds(1),bounds(2),1001); ys = nan(size(xs));
for k=1:numel(xs)
    trial=p; trial.L_flare_1=xs(k);
    [valid,~,~,geom]=vivaldiValidateParams(trial);
    if valid, ys(k)=geom.L_patch-target; end
end
exact=find(abs(ys)<1e-9,1);
if ~isempty(exact)
    root=xs(exact);
else
    pair=find(isfinite(ys(1:end-1)) & isfinite(ys(2:end)) ...
        & ys(1:end-1).*ys(2:end)<0,1);
    assert(~isempty(pair),'Vivaldi:NoRoot', ...
        'Không tìm thấy nghiệm hợp lệ trong miền L_flare_1 [%g, %g] mm. Có thể mở rộng miền tìm kiếm.',bounds);
    root=fzero(@residual,xs(pair:pair+1),optimset('TolX',1e-10,'Display','off'));
end
after=p; after.L_flare_1=root;
[valid,errors,~,geom]=vivaldiValidateParams(after);
assert(valid,'Vivaldi:InvalidRoot','%s',strjoin(errors,newline));
assert(abs(geom.L_patch-target)<0.001,'Vivaldi:Residual','Sai số nghiệm vượt 0.001 mm.');
comparison=struct('before',before,'after',geom,'target',target, ...
    'beforeParams',p,'afterParams',after,'residual',geom.L_patch-target,'bounds',bounds);
    function y=residual(x)
        trial=p; trial.L_flare_1=x;
        [v,e,~,t]=vivaldiValidateParams(trial);
        assert(v,'Vivaldi:InvalidTrial','%s',strjoin(e,newline));
        y=t.L_patch-target;
    end
end
