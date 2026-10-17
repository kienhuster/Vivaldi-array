function tests = testBuilderGeometry
% Run on MATLAB: results=runtests('tests/testBuilderGeometry.m'); assertSuccess(results)
% Delivered in a Linux environment without MATLAB: these tests are UNRUN there.
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;
addpath(fileparts(fileparts(mfilename('fullpath'))));
t.TestData.temp=tempname;mkdir(t.TestData.temp);
end
function teardownOnce(t)
path(t.TestData.oldPath);rmdir(t.TestData.temp,'s');
end
function testAllSourceIndependentVariables(t)
[p,meta]=vivaldiBuilderDefaultParams();
verifyEqual(t,numel(fieldnames(p)),19);
verifyEqual(t,{meta.name}',fieldnames(p));
verifyEqual(t,p.lamda,60);verifyEqual(t,p.scan_theta,0);verifyEqual(t,p.c2,0);
verifyEqual(t,{meta(strcmp({meta.name},'deg_slot_t')).unit},{'deg'});
verifyTrue(t,all(arrayfun(@(m)numel(m.range)==2 && m.range(1)<m.range(2),meta)));
g=vivaldiBuilderGeometry(p);
verifySize(t,g.expressions,[31 2]);
verifyEqual(t,numel(unique(g.expressions(:,1))),31);
verifyEqual(t,g.expressions(strcmp(g.expressions(:,1),'slot_t_L'),2),{'6.4mm+them'});
verifyEqual(t,g.expressions(strcmp(g.expressions(:,1),'r_flare'),2), ...
    {'(1/L_flare)*ln(aperture_w/slot_feed_w)'});
verifyEqual(t,g.postprocessingExpressions,{'alpha','0deg'});
verifyFalse(t,any(strcmp(g.expressions(:,1),'alpha')));
end
function testRequiredDefaultRegression(t)
p=vivaldiBuilderDefaultParams();[ok,errors,warnings,g]=vivaldiBuilderValidate(p);
verifyTrue(t,ok,strjoin(errors,newline));verifyNotEmpty(t,warnings);
verifyEqual(t,g.L_flare,46.4,'AbsTol',1e-12);
verifyEqual(t,g.r_flare,.07950171237314518,'AbsTol',1e-10);
verifyEqual(t,g.x_feed,2.499330860779,'AbsTol',1e-10);
verifyEqual(t,g.z_feed,.663696709941,'AbsTol',1e-10);
verifyEqual(t,g.L_patch,49.236303290059,'AbsTol',1e-10);
verifyEqual(t,[g.de_L g.de_W],[22 22],'AbsTol',1e-12);
verifyEqual(t,[g.h_cabin g.h_cabout g.h_cabmid],[2.5 2 2],'AbsTol',1e-12);
verifyEqual(t,2*g.flare.halfWidth(end),p.aperture_w,'AbsTol',1e-10);
end
function testCoordinateParentsSignsAndFeedContact(t)
p=vivaldiBuilderDefaultParams();g=vivaldiBuilderGeometry(p);
verifyEqual(t,g.cs.slot_t_td.origin,[.415828068 0 6.4],'AbsTol',1e-8);
verifyEqual(t,g.cs.slot_feed_td.origin,[-2.499330860779 0 .663696709941],'AbsTol',1e-10);
verifyLessThan(t,g.cs.slot_feed_td.origin(1),0);
verifyEqual(t,g.cs.patch_td.origin,[10 0 46.4],'AbsTol',1e-12);
verifyEqual(t,g.cs.RelativeCS1.parent,'patch_td');
verifyEqual(t,g.cs.RelativeCS1.localOrigin,[0 -1 0],'AbsTol',1e-12);
verifyEqual(t,g.cs.RelativeCS1.origin,[10 -1 46.4],'AbsTol',1e-12);
verifyEqual(t,g.transition.left(1,:),g.cs.slot_feed_td.origin,'AbsTol',1e-12);
verifyEqual(t,g.transition.right(end,:),g.cs.slot_t_td.origin,'AbsTol',1e-12);
verifyEqual(t,g.cs.slot_feed_td.originExpressions,{'-x_feed','0mm','z_feed'});
end
function testRectangleYConvention(t)
p=vivaldiBuilderDefaultParams();g=vivaldiBuilderGeometry(p);
c=g.slotRectangles(1).localCorners;
verifyEqual(t,max(c(:,1))-min(c(:,1)),p.slot_feed_w,'AbsTol',1e-12);
verifyEqual(t,max(c(:,3))-min(c(:,3)),p.h3_slot_feed,'AbsTol',1e-12);
c=g.slotRectangles(3).localCorners;
verifyEqual(t,max(c(:,1))-min(c(:,1)),p.cavity_w,'AbsTol',1e-12);
verifyEqual(t,max(c(:,3))-min(c(:,3)),p.cavity_L,'AbsTol',1e-12);
end
function testOrthogonalPlatesAndNominalEnvelopes(t)
p=vivaldiBuilderDefaultParams();g=vivaldiBuilderGeometry(p);
verifyEqual(t,dot(g.plates(1).normal,g.plates(2).normal),0,'AbsTol',1e-12);
verifyEqual(t,g.bounds.plate1,[-10 10;-1 1;-2.836303290059 46.4],'AbsTol',1e-10);
verifyEqual(t,g.bounds.plate2,[10 12;1 21;-2.836303290059 46.4],'AbsTol',1e-10);
verifyEqual(t,g.bounds.body,[-10 12;-1 21;-2.836303290059 46.4],'AbsTol',1e-10);
verifyEqual(t,g.bounds.base(1:2,:),g.bounds.body(1:2,:),'AbsTol',1e-12);
verifyEqual(t,g.bounds.region,g.bounds.body+repmat([-20 20],3,1),'AbsTol',1e-12);
verifyTrue(t,contains(g.bounds.description,'Nominal'));
end
function testCoaxPortTransformAndOuterToInnerLines(t)
p=vivaldiBuilderDefaultParams();g=vivaldiBuilderGeometry(p);
verifyEqual(t,g.ports(1).center,[.450669139221 0 -2.836303290059],'AbsTol',1e-10);
verifyEqual(t,g.ports(2).center,[11 10.549330860779 -2.836303290059],'AbsTol',1e-10);
verifyEqual(t,g.ports(1).end-g.ports(1).start,[.2 0 0],'AbsTol',1e-12);
verifyEqual(t,g.ports(2).end-g.ports(2).start,[0 -.2 0],'AbsTol',1e-12);
for k=1:2
    verifyEqual(t,norm(g.ports(k).start-g.ports(k).center),p.r_cabmid,'AbsTol',1e-12);
    verifyEqual(t,norm(g.ports(k).end-g.ports(k).center),p.r_cabin,'AbsTol',1e-12);
    verifyEqual(t,g.cables(k).innerEnd,g.ports(k).center,'AbsTol',1e-12);
    verifyEqual(t,g.cables(k).outerEnd,g.ports(k).center,'AbsTol',1e-12);
end
end
function testRequiredVariationsUpdateDependencies(t)
p=vivaldiBuilderDefaultParams();old=vivaldiBuilderGeometry(p);
changes={'L_flare_1',45;'aperture_w',22;'cavity_w',1.6; ...
    'cavity_L',5.5;'thickness',2.2;'slot_feed_w',.6};
for k=1:size(changes,1)
    q=p;q.(changes{k,1})=changes{k,2};
    [ok,errors,warnings,g]=vivaldiBuilderValidate(q);
    verifyTrue(t,ok,strjoin(errors,newline));verifyNotEmpty(t,warnings);
    verifyEqual(t,g.cs.slot_feed_td.origin,[-g.x_feed 0 g.z_feed],'AbsTol',1e-12);
    verifyEqual(t,g.cs.patch_td.origin,[q.aperture_w/2 0 g.L_flare],'AbsTol',1e-12);
    verifyEqual(t,g.cs.RelativeCS1.origin,[q.aperture_w/2 -q.thickness/2 g.L_flare],'AbsTol',1e-12);
    verifyEqual(t,g.cables(2).outerEnd,g.ports(2).center,'AbsTol',1e-12);
end
q=p;q.L_flare_1=45;g=vivaldiBuilderGeometry(q);
verifyGreaterThan(t,g.L_patch,old.L_patch);verifyLessThan(t,g.r_flare,old.r_flare);
q=p;q.thickness=2.2;g=vivaldiBuilderGeometry(q);
verifyEqual(t,g.ports(2).center(1),11.1,'AbsTol',1e-12);
verifyEqual(t,g.bounds.plate1(2,:),[-1.1 1.1],'AbsTol',1e-12);
end
function testMalformedInputsReturnDiagnosticsWithoutThrowing(t)
p=vivaldiBuilderDefaultParams();bad={[],42,{p},[p p],rmfield(p,'lamda')};
bad{end+1}=p;bad{end}.L_flare_1=NaN;
bad{end+1}=p;bad{end}.h2=Inf;
bad{end+1}=p;bad{end}.thickness=[2 3];
bad{end+1}=p;bad{end}.r_cabin=.15+1i;
bad{end+1}=p;bad{end}.slot_feed_w='0.5';
bad{end+1}=p;bad{end}.scan_phi=true;
bad{end+1}=p;bad{end}.unknown=1;
bad{end+1}=p;bad{end}.them=-6.4;
bad{end+1}=p;bad{end}.deg_slot_t=90;
bad{end+1}=p;bad{end}.r_cabmid=p.r_cabout;
bad{end+1}=p;bad{end}.aperture_w=p.slot_feed_w;
bad{end+1}=p;bad{end}.h_de=0;
bad{end+1}=p;bad{end}.aperture_w=realmax;bad{end}.slot_feed_w=realmin;
for k=1:numel(bad)
    [ok,errors]=vivaldiBuilderValidate(bad{k});verifyFalse(t,ok);verifyNotEmpty(t,errors);
end
end
function testSliderRangesDoNotActAsPhysicalLimits(t)
p=vivaldiBuilderDefaultParams();p.L_flare_1=250;p.positionx=-.1;
[ok,errors]=vivaldiBuilderValidate(p);verifyTrue(t,ok,strjoin(errors,newline));
end
function testTarget49And50PreservesAllOtherParameters(t)
p=vivaldiBuilderDefaultParams();names=setdiff(fieldnames(p),{'L_flare_1'});
for target=[49 50]
    [q,r]=vivaldiBuilderTargetLength(p,target);
    verifyLessThan(t,abs(r.after.L_patch-target),1e-6);
    verifyEqual(t,r.changedVariable,'L_flare_1');
    for k=1:numel(names),verifyEqual(t,q.(names{k}),p.(names{k}));end
end
verifyError(t,@()vivaldiBuilderTargetLength(p,500,[1 100]),'VivaldiBuilder:NoRoot');
verifyError(t,@()vivaldiBuilderTargetLength(p,NaN),'VivaldiBuilder:InvalidTarget');
verifyError(t,@()vivaldiBuilderTargetLength(p,49,[100 1]),'VivaldiBuilder:SearchDomain');
end
function testStrictConfigRoundtrip(t)
p=vivaldiBuilderDefaultParams();p.L_flare_1=45;p.them=.125;
file=fullfile(t.TestData.temp,'valid.json');
vivaldiBuilderConfig('save',file,p);q=vivaldiBuilderConfig('load',file);
verifyEqual(t,q,p);
payload=jsondecode(fileread(file));verifyEqual(t,payload.version,1);
verifyEqual(t,sort(fieldnames(payload)),sort({'schema';'version';'model';'units';'parameters'}));
payload.version=2;writeText(file,jsonencode(payload));
verifyError(t,@()vivaldiBuilderConfig('load',file),'VivaldiBuilder:ConfigSchema');
payload.version=1;payload.parameters.L_patch=49;writeText(file,jsonencode(payload));
verifyError(t,@()vivaldiBuilderConfig('load',file),'VivaldiBuilder:InvalidConfig');
payload.parameters=p;payload.parameters.h_de='system(''bad'')';writeText(file,jsonencode(payload));
verifyError(t,@()vivaldiBuilderConfig('load',file),'VivaldiBuilder:InvalidConfig');
writeText(file,'{broken');
verifyError(t,@()vivaldiBuilderConfig('load',file),'VivaldiBuilder:ConfigJSON');
end
function writeText(filename,body)
fid=fopen(filename,'w','n','UTF-8');c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',body);
end
