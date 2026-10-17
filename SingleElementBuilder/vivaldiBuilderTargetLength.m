function [q, report] = vivaldiBuilderTargetLength(p, target, bracket)
%VIVALDIBUILDERTARGETLENGTH Solve L_patch by changing only L_flare_1.
% fzero is in base MATLAB. Only connected valid intervals are bracketed.
[ok,errors,~,before]=vivaldiBuilderValidate(p);
assert(ok,'VivaldiBuilder:InvalidParameters','%s',strjoin(errors,newline));
assert(isnumeric(target) && isreal(target) && isscalar(target) && ...
    isfinite(target) && target>0,'VivaldiBuilder:InvalidTarget', ...
    'Chiều dài mục tiêu phải là số thực hữu hạn dương.');
target=double(target);
if nargin<3 || isempty(bracket),bracket=[.001 max(200,2*target)];end
assert(isnumeric(bracket) && isreal(bracket) && numel(bracket)==2 ...
    && all(isfinite(bracket(:))) && all(bracket(:)>0) ...
    && bracket(1)<bracket(2),'VivaldiBuilder:SearchDomain', ...
    'Miền tìm L_flare_1 cần hai số thực dương tăng dần.');
bracket=double(bracket(:)');
xs=linspace(bracket(1),bracket(2),401); ys=nan(size(xs));
for k=1:numel(xs)
    trial=p;trial.L_flare_1=xs(k);
    [valid,~,~,geom]=vivaldiBuilderValidate(trial);
    if valid,ys(k)=geom.L_patch-target;end
end
exact=find(abs(ys)<1e-10,1);
if ~isempty(exact)
    root=xs(exact);
else
    pair=find(isfinite(ys(1:end-1)) & isfinite(ys(2:end)) ...
        & sign(ys(1:end-1))~=sign(ys(2:end)),1);
    assert(~isempty(pair),'VivaldiBuilder:NoRoot', ...
        'Không có nghiệm hợp lệ trong miền L_flare_1 [%g, %g] mm.',bracket);
    root=fzero(@residual,xs(pair:pair+1),optimset('TolX',1e-10,'Display','off'));
end
q=p;q.L_flare_1=root;
[ok,errors,~,after]=vivaldiBuilderValidate(q);
assert(ok,'VivaldiBuilder:InvalidRoot','%s',strjoin(errors,newline));
assert(abs(after.L_patch-target)<1e-6,'VivaldiBuilder:Residual', ...
    'Sai số chiều dài sau tìm nghiệm vượt 1e-6 mm.');
report=struct('before',before,'after',after,'target',target, ...
    'beforeParams',p,'afterParams',q,'residual',after.L_patch-target, ...
    'bracket',bracket,'bounds',bracket,'changedVariable','L_flare_1', ...
    'verificationStatus','Numerical length only - HFSS Validation Pending');
    function y=residual(x)
        trial=p;trial.L_flare_1=x;
        [valid,err,~,geom]=vivaldiBuilderValidate(trial);
        assert(valid,'VivaldiBuilder:InvalidTrial','%s',strjoin(err,newline));
        y=geom.L_patch-target;
    end
end
