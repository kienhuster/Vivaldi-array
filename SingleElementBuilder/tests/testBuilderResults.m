function tests=testBuilderResults
% Offline result-processing tests. Mathematical fixtures are unit-test inputs,
% never presented as an HFSS simulation result.
tests=functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.builder=fileparts(fileparts(mfilename('fullpath')));
addpath(testCase.TestData.builder);
testCase.TestData.folder=tempname;
mkdir(testCase.TestData.folder);
end

function teardownOnce(testCase)
if isfolder(testCase.TestData.folder), rmdir(testCase.TestData.folder,'s'); end
end

function testCSVRetainsUnitsAndDoesNotClaimSimulation(testCase)
path=fixture(testCase,'network.csv',sprintf('Freq [GHz],S11 [dB],S22 [dB]\n5,-11,-12\n6,-13,-14\n'));
data=HFSSPostProcessing('load',path);
verifyEqual(testCase,data.x,[5;6]);
verifyEqual(testCase,data.y,[-11 -12;-13 -14]);
verifyEqual(testCase,data.xLabel,'Freq [GHz]');
verifyEqual(testCase,data.labels,{'S11 [dB]','S22 [dB]'});
verifyEqual(testCase,data.units,{'dB','dB'});
verifyFalse(testCase,data.metadata.simulationVerified);
verifyTrue(testCase,contains(data.status,'Imported actual CSV'));
end

function testMixedCoordinatesRequireExplicitCut(testCase)
path=fixture(testCase,'mixed.csv',sprintf(['Freq [GHz],Theta [deg],Gain [dB]\n' ...
    '5,-1,2\n5,1,3\n6,-1,4\n6,1,5\n']));
data=HFSSPostProcessing('load',path);
verifyEmpty(testCase,data.x);
verifyEmpty(testCase,data.y);
verifyEqual(testCase,height(data.table),4);
verifyTrue(testCase,contains(data.status,'multiple varying coordinates'));
verifyFalse(testCase,data.metadata.simulationVerified);
end

function testSingleFrequencyPatternChoosesAngle(testCase)
path=fixture(testCase,'cut.csv',sprintf(['Freq [GHz],Theta [deg],RealizedGainTotal [dB]\n' ...
    '5,-1,2\n5,0,3\n5,1,2\n']));
data=HFSSPostProcessing('load',path);
verifyEqual(testCase,data.x,[-1;0;1]);
verifyEqual(testCase,data.y,[2;3;2]);
verifyEqual(testCase,data.xLabel,'Theta [deg]');
end

function testMalformedNumericDataAreRejected(testCase)
path=fixture(testCase,'nonfinite.csv',sprintf('Freq [GHz],S11 [dB]\n5,-12\n6,NaN\n'));
verifyError(testCase,@()HFSSPostProcessing('load',path),'VivaldiBuilder:CSVValues');
path=fixture(testCase,'nonnumeric.csv',sprintf('Freq [GHz],Gain\n5,invalid\n6,missing\n'));
verifyError(testCase,@()HFSSPostProcessing('load',path),'VivaldiBuilder:CSVColumns');
end

function testMissingCSVDoesNotCreateResults(testCase)
path=fullfile(testCase.TestData.folder,'not-created.csv');
verifyError(testCase,@()HFSSPostProcessing('load',path),'VivaldiBuilder:CSVFile');
verifyFalse(testCase,isfile(path));
end

function testHPBWSymmetricAndAsymmetricMeasuredCrossings(testCase)
angle=-60:60;
data=HFSSPostProcessing('hpbw',angle,-3*(angle/10).^2);
verifyEqual(testCase,data.widthDeg,20,'AbsTol',1e-12);
verifyEqual(testCase,data.leftCrossingDeg,-10,'AbsTol',1e-12);
verifyEqual(testCase,data.rightCrossingDeg,10,'AbsTol',1e-12);
gain=-3*(angle/10).^2; gain(angle<0)=-3*(angle(angle<0)/25).^2;
data=HFSSPostProcessing('hpbw',angle,gain);
verifyEqual(testCase,data.widthDeg,35,'AbsTol',1e-12);
end

function testHPBWRequiresBothCrossings(testCase)
angle=0:30;
data=HFSSPostProcessing('hpbw',angle,-3*(angle/10).^2);
verifyTrue(testCase,isnan(data.widthDeg));
verifyTrue(testCase,contains(data.reason,'both -3dB crossings'));
data=HFSSPostProcessing('hpbw',-20:20,zeros(1,41));
verifyTrue(testCase,isnan(data.widthDeg));
end

function testHPBWWrapsAFullCircularCut(testCase)
angle=-180:180;
distance=mod(angle-175+180,360)-180;
data=HFSSPostProcessing('hpbw',angle,-3*(distance/10).^2);
verifyTrue(testCase,data.periodic);
verifyEqual(testCase,data.widthDeg,20,'AbsTol',1e-12);
verifyEqual(testCase,data.leftCrossingDeg,165,'AbsTol',1e-12);
verifyEqual(testCase,data.rightCrossingDeg,185,'AbsTol',1e-12);
end

function testHPBWRejectsMixedOrInadequateSamples(testCase)
data=HFSSPostProcessing('hpbw',[0 1 1 2],[0 -1 -2 -3]);
verifyTrue(testCase,isnan(data.widthDeg));
verifyTrue(testCase,contains(data.reason,'unique'));
data=HFSSPostProcessing('hpbw',[-180 -90 0 90 180],[-5 -4 0 -4 -5]);
verifyTrue(testCase,isnan(data.widthDeg));
verifyTrue(testCase,contains(data.reason,'large gap'));
data=HFSSPostProcessing('hpbw',[-1 0 1],[-3 NaN -3]);
verifyTrue(testCase,isnan(data.widthDeg));
angle=-180:180; gain=-3*(angle/30).^2; gain(end)=gain(1)+1;
data=HFSSPostProcessing('hpbw',angle,gain);
verifyTrue(testCase,isnan(data.widthDeg));
verifyTrue(testCase,contains(data.reason,'endpoints disagree'));
end

function testReportGenerationRequiresRuntimeSolutionEvidence(testCase)
w=HFSSScriptWriter();
cfg=struct('outputDir',testCase.TestData.folder,'solution','Setup1 : Sweep', ...
    'resultFrequencyGHz',5,'excitedPort',2,'reportPrefix','UnitTestReports');
out=HFSSPostProcessing('emit',w,cfg);
body=strjoin(w.Lines,newline); helpers=strjoin(w.Helpers,newline);
verifyTrue(testCase,contains(helpers,'GetSolutionDataPerVariation'));
verifyTrue(testCase,contains(helpers,'GetRealDataValues'));
verifyTrue(testCase,contains(helpers,'GetSweepValues("Freq", False)'));
verifyTrue(testCase,contains(helpers,'GetSweepUnits("Freq")'));
verifyTrue(testCase,contains(helpers,'SBRNominalFamilies(families)'));
verifyTrue(testCase,contains(helpers,'result(k + 1) = Array("Nominal")'));
verifyTrue(testCase,contains(helpers,'"L_flare_1"'));
verifyTrue(testCase,contains(helpers,'"c2"'));
verifyTrue(testCase,contains(body,'SBRNominalFamilies(Array("Freq:="'));
verifyTrue(testCase,contains(body,'sbCondition = (sbrHasData)'));
verifyTrue(testCase,contains(body,'If Not sbCondition Then Fail'));
verifyTrue(testCase,contains(body,'"Name:=", "2:1", "Magnitude:=", "1W"'));
verifyFalse(testCase,contains(body,'AnalyzeAll'));
verifyFalse(testCase,contains(body,'SIMULATED'));
verifyTrue(testCase,contains(out.status,'commands generated'));
verifyTrue(testCase,all(cellfun(@(path)~isfile(path),out.csvPaths)));
end

function testLoggerReadsActualUTF16RecordsIdempotently(testCase)
path=fullfile(testCase.TestData.folder,'runtime.status');
raw=sprintf(['STAGE|Assign Ports|10/16/2026 12:34:56\r\n' ...
    'NOTE|10/16/2026 12:34:57|port1|outer-to-inner\r\n' ...
    'STATE|FAILED|10/16/2026 12:34:58|Boolean did not complete\r\n']);
writeutf16(path,raw,false);
logger=HFSSBuildLogger();
verifyEqual(testCase,logger.ingest(path),3);
verifyEqual(testCase,numel(logger.Entries),3);
verifyEqual(testCase,logger.Entries(1).details.stage,'Assign Ports');
verifyEqual(testCase,logger.Entries(2).details.message,'port1|outer-to-inner');
verifyEqual(testCase,logger.LastError,'Boolean did not complete');
verifyEqual(testCase,logger.ingest(path),0);
verifyEqual(testCase,numel(logger.Entries),3);
writeutf16(path,'STATE|VALIDATED|10/16/2026 12:35:00|pending',true);
verifyEqual(testCase,logger.ingest(path),0);
writeutf16(path,sprintf('\r\n'),true);
verifyEqual(testCase,logger.ingest(path),1);
verifyEqual(testCase,logger.Entries(end).event,'VALIDATED');
verifyTrue(testCase,logger.Entries(end).details.runtimeVerified);
end

function testLoggerSeparatesRequestsAndPreservesOldExport(testCase)
logger=HFSSBuildLogger();
logger.stage('Build Full Antenna');
verifyEqual(testCase,logger.Entries(1).event,'STAGE_REQUESTED');
verifyFalse(testCase,logger.Entries(1).details.runtimeVerified);
path=fullfile(testCase.TestData.folder,'evidence.json');
logger.export(path);
saved=fileread(path); decoded=jsondecode(saved);
verifyEqual(testCase,decoded.format,'VivaldiDualPolBuildLog-v1');
verifyError(testCase,@()logger.export(path),'VivaldiBuilder:ExistingLog');
verifyEqual(testCase,fileread(path),saved);
end

function path=fixture(testCase,name,content)
path=fullfile(testCase.TestData.folder,name);
fid=fopen(path,'w','n','UTF-8');
assert(fid>=0); cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',content);
end

function writeutf16(path,content,append)
if append, mode='a'; else, mode='w'; end
fid=fopen(path,mode); assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
if ~append, fwrite(fid,uint8([255 254]),'uint8'); end
fwrite(fid,unicode2native(content,'UTF-16LE'),'uint8');
end
