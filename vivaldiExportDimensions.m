function T = vivaldiExportDimensions(p,g,path,tolerance)
%VIVALDIEXPORTDIMENSIONS Nominal parameter table, not a certified cutting outline.
if nargin<4, tolerance=0; end
validateattributes(tolerance,{'numeric'},{'scalar','finite','real','nonnegative'});
[ok,e,~,g]=vivaldiValidateParams(p); assert(ok,'Vivaldi:InvalidExport','%s',strjoin(e,newline));
[defaults,meta]=vivaldiDefaultParams(); names=fieldnames(p); values=zeros(numel(names),1);
original=values; units=repmat({'mm'},numel(names),1);
for k=1:numel(names)
    values(k)=p.(names{k}); original(k)=defaults.(names{k});
    idx=find(strcmp({meta.name},names{k}),1); units{k}=meta(idx).unit;
end
derived={'slot_t_L','L_flare','r_flare','x_feed','z_feed','L_patch','h_cabin','h_cabmid','h_cabout','de_L','de_W'};
gd=vivaldiCalculateGeometry(defaults);
for k=1:numel(derived)
    n=derived{k}; names{end+1,1}=n; values(end+1,1)=g.(n); original(end+1,1)=gd.(n);
    if strcmp(n,'r_flare'), units{end+1,1}='1/mm'; else, units{end+1,1}='mm'; end
end
tols=repmat(tolerance,numel(names),1); tols(~strcmp(units,'mm'))=NaN;
T=table(names,values,units,original,values-original,tols, ...
    'VariableNames',{'Variable','Nominal','Unit','Original','Delta','RequestedTolerance_mm'});
if nargin>=3 && ~isempty(path), writetable(T,path); end
end
