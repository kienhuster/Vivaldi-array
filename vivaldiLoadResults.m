function result = vivaldiLoadResults(path,xColumn,yColumns)
%VIVALDILOADRESULTS Import actual exported CSV; no unit guessing or fake curves.
% Call with only path to inspect column names, then supply explicit columns.
T=readtable(path,'VariableNamingRule','preserve');
assert(height(T)>0,'Vivaldi:EmptyResults','Tệp không có dữ liệu.');
result=struct('path',path,'table',T,'columns',{T.Properties.VariableNames}, ...
    'x',[],'y',[],'labels',{{}},'status','Imported, not yet mapped');
if nargin<2, return; end
if nargin<3, yColumns=setdiff(T.Properties.VariableNames,{xColumn},'stable'); end
if ischar(yColumns), yColumns={yColumns}; end
assert(ismember(xColumn,T.Properties.VariableNames) && ...
    all(ismember(yColumns,T.Properties.VariableNames)) && ~isempty(yColumns), ...
    'Vivaldi:ResultColumns','Chọn cột X và ít nhất một cột Y tồn tại.');
x=T.(xColumn); y=T{:,yColumns};
assert(isnumeric(x) && isvector(x) && isnumeric(y) && isreal(x) && isreal(y) ...
    && all(isfinite(x(:))) && all(isfinite(y(:))), ...
    'Vivaldi:ResultValues','Các cột chọn phải là số thực hữu hạn; tách các sweep và bỏ dòng thiếu trước khi nạp.');
result.x=x; result.y=y; result.labels=yColumns; result.xLabel=xColumn;
result.status='Dữ liệu thực đã nhập; xem header để xác định đơn vị, sweep và polarization.';
end
