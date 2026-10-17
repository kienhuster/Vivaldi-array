# Vivaldi Dual-Pol Builder Pro

**Implemented — HFSS Validation Pending.** Công cụ MATLAB dành cho **một phần tử Vivaldi dual-pol**, dựng CAD mới bằng HFSS Automation API hoặc cập nhật một project có sẵn qua bản sao bảo vệ. Trong môi trường phát triển hiện tại đã kiểm tra dữ liệu nguồn, số học và cú pháp; chưa chạy MATLAB, Windows COM, HFSS Validate hay solver. Xem [VALIDATION_REPORT.md](VALIDATION_REPORT.md) để phân biệt chức năng đã triển khai và bằng chứng đã thực thi.

## Khởi chạy

Yêu cầu MATLAB **R2020b trở lên**, có JVM; GUI cần MATLAB desktop hỗ trợ `uifigure`. Automation cần **Windows + ANSYS Electronics Desktop/HFSS 2021 R2 (2021.2)** và license HFSS hợp lệ. Không cần cài PyAEDT: ứng dụng MATLAB sinh VBScript và chạy `ansysedt.exe -RunScript` qua COM.

Từ thư mục gốc repository, chạy:

```matlab
addpath(fullfile(pwd,'SingleElementBuilder'));
Vivaldi_DualPol_Builder;
```

GUI, công thức và sinh script có thể dùng khi chưa có HFSS. Chế độ **Offline** chỉ tạo script cùng hồ sơ job; trạng thái `SCRIPT_GENERATED` không xác nhận CAD đã dựng hoặc mô phỏng đã hoàn tất. Tính tương thích GUI đa nền tảng vẫn cần kiểm thử MATLAB desktop thực tế.

## Nguồn chuẩn và phạm vi

Nguồn chuẩn là [reference/17_10_2026_vivaldi.aedt](reference/17_10_2026_vivaldi.aedt), design `dual_pol_vivaldi_patch_Wflare_20`, DrivenModal, không phải design gần rỗng `HFSSDesign1`. Tệp được giữ nguyên byte, SHA-256:

```text
631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619
```

Tài liệu đồng hành nằm trong `reference/Phan_tich_chi_tiet_Vivaldi_dual_pol_17_10_2026.md`. [MODEL_RECONSTRUCTION_SPEC.md](MODEL_RECONSTRUCTION_SPEC.md) được lập trước khi coding, truy dẫn dòng nguồn, 31 biến, CS, chuỗi Boolean, vật liệu, port và solver. [API_COMPATIBILITY.md](API_COMPATIBILITY.md) ghi các API đã đối chiếu tài liệu và các điểm vẫn cần chạy HFSS 2021 R2 để xác nhận.

Ứng dụng mới được tách riêng trong `SingleElementBuilder/`; không sửa GUI tạo mảng, MATLAB modules hoặc project cũ. Không tạo mảng 2×2/4×4, không chạy các Optimetrics lưu sẵn, không tự thêm FR4/PTFE hoặc lớp điện môi coax.

## Năm tab làm việc

| Tab | Chức năng |
|---|---|
| **Geometry Parameters** | Điều chỉnh tham số độc lập theo nhóm, reset từng biến/toàn bộ, load/save JSON, kiểm tra dữ liệu và xem các đại lượng dẫn xuất. |
| **Antenna Preview** | Preview toán học hai phân cực, flare/transition, slot/cavity, coax và hệ tọa độ; đổi góc nhìn, bật kích thước. Preview không phải CAD xuất từ HFSS. |
| **HFSS Builder** | Chọn `ansysedt.exe`, kiểm tra cài đặt/version, project/design/output, Build hoặc Update riêng biệt, theo dõi stage, Validate, Save và Analyze. |
| **Simulation & Results** | Chọn profile/band/port, chạy mô phỏng theo yêu cầu, tạo báo cáo HFSS/CSV thật, nhập CSV so sánh và đo HPBW khi đủ dữ liệu. |
| **Manufacturing & Logs** | Giải `L_flare_1` để đạt `L_patch=49/50mm` hoặc mục tiêu khác, xuất kích thước danh nghĩa, JSON cấu hình, báo cáo cấu hình và log. |

Khoảng slider hỗ trợ thao tác, không chứng nhận mọi tổ hợp đều tạo CAD hợp lệ. Kiểm tra đại số chặn dữ liệu không hữu hạn, kích thước không dương, thứ tự bán kính sai và một số miền không hỗ trợ. Tiếp xúc, Boolean, mesh và hiệu năng RF phải kiểm tra trong HFSS.

## Build From Scratch

1. Chọn **Build From Scratch**, tên project mới, output directory và HFSS 2021.2. Chọn Offline nếu chỉ cần kiểm tra script.
2. Điều chỉnh hình học; giữ Original để đối chiếu nguồn. Bấm **Build From Scratch**.
3. Khi chạy thật, builder gọi `NewProject`, `InsertDesign`, tạo biến/CS rồi tạo từng primitive và Boolean. Build không mở project nguồn và không copy CAD từ file chuẩn.
4. Theo dõi stage/log. Thành công chỉ được nhận sau kiểm tra object/bounds/assignment, `ValidateDesign` trả **1**, báo cáo validation được tạo và file `.aedt` đã lưu được đọc lại. Việc có file hoặc script riêng lẻ chưa đủ.

Chuỗi CAD gồm hai Equation Based Surface, copy đoạn ngắn trước khi cắt, Rotate transition 21° quanh `slot_t_td`, ba rectangle feed/cavity, Unite vùng khoét, Subtract tấm, ThickenSheet hai phía, DuplicateAroundAxis −90° tại `RelativeCS1` rồi Move +thickness Y, Box1/De, Unite thân nhôm; hai coax rỗng và hai port; cuối cùng trừ **sáu cutter đầy** được snapshot trước hollowing. Sau cleanup, tám đối tượng active dự kiến là:

```text
Vivaldi_1, cable_in, cable_out, cable_in_1, cable_out_1,
port1, port2, RadiatingSurface
```

`Vivaldi_2` đã Unite vào `Vivaldi_1`, không cần còn solid top-level riêng. Region vacuum offset20mm sáu hướng có Radiation `Open1`.

Có hai khác biệt parameter hóa được ghi rõ trong log/spec: builder consume các **bản sao cutter tạm** bằng KeepOriginals=false thay cờ true lưu trong nguồn để không để model cutter dư; các conductor active được giữ riêng. Move `cable_mid_1` dùng biểu thức `thickness` thay literal `2mm` của nguồn để giữ coax thẳng trục khi đổi độ dày. Mặc định các phép trừ và vị trí tương ứng nguồn; sự tương đương CAD vẫn chờ nghiệm thu runtime.

## Update Existing Project và bảo vệ dữ liệu

Chọn **Update Existing Project**, chỉ định `.aedt`, tên output mới và thư mục đích. Builder kiểm tra đúng design/công thức, mở nguồn rồi **SaveAs trước khi sửa biến**. Không ghi đè source, output đã tồn tại, output có lock hoặc hồ sơ builder cũ; hãy chọn tên mới. Không tự xóa lock của project đang mở.

Mô hình nguồn có Move của `cable_mid_1` lưu literal `2mm`. Update với thickness khác2 bị từ chối khi phát hiện lịch sử không liên kết này; dùng **Build From Scratch** để dựng phiên bản đã parameter hóa. Không thể mặc định mọi file `.aedt` tùy ý có công thức/đồ thị đúng nguồn.

Các thao tác độc lập **Validate/Save/Analyze/Reports** chỉ sửa project có hồ sơ cạnh file `<project>.aedt.builder.json` do builder tạo. Hồ sơ này là dấu sở hữu bản làm việc, **không phải chứng nhận build thành công**. Để thao tác với project bên ngoài, dùng Update Existing tạo bản sao trước. Giữ file `.aedt` cùng sidecar khi quản lý bản làm việc và không tự tạo sidecar cho tệp nguồn để bỏ qua bảo vệ.

Nếu thay tham số/profile/band sau build, GUI đánh dấu **STALE MODEL** và yêu cầu Build/Update phù hợp trước Analyze. Timeout dừng theo dõi, không tắt HFSS; dùng **Recheck timed-out HFSS job**, xem desktop/log và tránh khởi chạy job trùng. Khi lỗi, bản làm việc một phần được giữ để chẩn đoán, không được gắn nhãn build hoàn tất.

## Tham số và cấu hình solver

Có **19 biến độc lập + 12 biểu thức phụ thuộc = 31 design variables**, cùng postprocessing `alpha=0deg`. Toàn bộ biểu thức chính xác nằm trong spec; HFSS giữ biểu thức, không thay biến dẫn xuất bằng số đã tính.

| Nhóm | Mặc định chính |
|---|---|
| Flare/transition | `L_flare_1=40mm`, `them=0mm`, `slot_t_L=6.4mm+them`, `aperture_w=20mm`, `slot_feed_w=.5mm`, `deg_slot_t=21deg` |
| Feed/cavity/metal | `h3_slot_feed=1mm`, `h2=2.6mm`, `cavity_w=1.4mm`, `cavity_L=5mm`, `h_de=2mm`, `thickness=2mm` |
| Coax | `r_cabin=.15mm`, `r_cabmid=.35mm`, `r_cabout=.5mm`, `positionx=.15mm`; copper, không có solid dielectric riêng |
| Biến tương thích nguồn | `lamda=60mm`, `scan_phi=0deg`, `scan_theta=0deg`, `c2=0mm`; không bật array |

Regression mặc định: `L_flare=46.4mm`, `r_flare≈.0795017124mm^-1`, `x_feed≈2.499330861mm`, `z_feed≈.663696710mm`, `L_patch≈49.236303290mm`. Origin `slot_feed_td.X=-x_feed`. Bbox danh nghĩa thân: X=−10..12,Y=−1..21,Z≈−2.836303290..46.4mm. Target49/50mm chỉ đổi `L_flare_1`, không scale toàn hình học.

| Lựa chọn | Adaptive | Sweep | Ý nghĩa |
|---|---|---|---|
| **Original** | Setup1,5GHz,ΔS=.02,min5/max50,converged3 | Discrete5–20GHz,bước.25GHz,SaveFields/SaveRadFields | Cấu hình chuẩn;61 điểm. |
| **QuickTest** | Setup riêng,5GHz,ΔS=.1,min1/max3 | Discrete5–20GHz,bước5GHz | Kiểm tra nhẹ; không thay thế Original hoặc chứng minh hội tụ. |
| **Study6–18GHz** | StudyBand1,độ chính xác Original | Discrete6–18GHz,bước.25GHz | Setup riêng; không đổi Setup1. |

QuickTest và StudyBand được chọn riêng; GUI tự bỏ lựa chọn xung đột, API từ chối cấu hình kết hợp. Cả hai Lumped Port50Ω luôn tồn tại. Mặc định port1=1W,port2=0W,pha0°; có thể đổi port hoạt động nhưng không tự cấp cả hai. Ba far fields **3D/Elevation/Azimuth** dùng Global, NoArray.

Hướng integration line outer→inner được xác nhận từ attachment nguồn. Ray azimuth được suy ra từ circular midpoint: port1 vector+X,port2 vector−Y; builder dùng tọa độ phụ thuộc thay numeric Edge ID. Phải đối chiếu geometry/port E-field HFSS trước khi nhận là khớp phase nguyên bản.

## Sinh lệnh và chạy không qua GUI

Ví dụ MATLAB sau chỉ sinh script; output dùng thư mục duy nhất và tên chưa tồn tại:

```matlab
addpath(fullfile(pwd,'SingleElementBuilder'));
p = vivaldiBuilderDefaultParams();
cfg = struct('exe','C:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe', ...
    'version','2021.2','projectName','Vivaldi_default', ...
    'designName','dual_pol_vivaldi_patch_Wflare_20', ...
    'outputDir',tempname,'sourcePath','','originalPath','', ...
    'profile','Original','excitedPort',1,'studyBand',[], ...
    'resultFrequencyGHz',5,'timeoutSeconds',1200);
job = HFSSAutomationBridge('generate','build',cfg,p);
disp(job.scriptPath); % SCRIPT_GENERATED, chưa thực thi HFSS
```

Chỉ trên Windows có HFSS/license:

```matlab
job = HFSSAutomationBridge('launch',job,cfg.exe);
state = HFSSAutomationBridge('poll',job);
while ~state.terminal
    pause(1);
    state = HFSSAutomationBridge('poll',job);
end
disp(state.log);
assert(state.success,'HFSS chưa xác nhận hoàn tất; xem status/validation/console.');
```

Update dùng `cfg.sourcePath=<file nguồn>`, `cfg.originalPath=cfg.sourcePath`, tên output mới và action `'update'`. Build và Update không tự Analyze. Khi đã có project verified, đặt `cfg.projectPath=job.projectPath` và phát job `'validate'`, `'save'`, `'analyze'` hoặc `'reports'`; giữ nguyên `p` và profile/band tương ứng. Analyze thường cần timeout lớn hơn, ví dụ14400s. Mỗi job phải được generate rồi launch một lần; không tái sử dụng job/status cũ. CLI cần kiểm tra kết quả từng job như trên.

JSON tham số có schema/version/model/units và đủ19 trường độc lập:

```matlab
vivaldiBuilderConfig('save','my_parameters.json',p);
p = vivaldiBuilderConfig('load','my_parameters.json');
```

## Kết quả thật, CSV và HPBW

Nút Analyze chỉ giải setup đã chọn, không gọi AnalyzeAll/Optimetrics. Trạng thái **SIMULATED** yêu cầu dữ liệu S11/S22/S21/S12 thật của **nominal variation hiện tại**, đủ lưới tần số dự kiến; quá trình HFSS kết thúc không đủ chứng minh nghiệm. Trạng thái này cũng không thay thế kiểm tra convergence/pass.

Reports kiểm tra dữ liệu context/tần số trước khi xuất S-parameters, VSWR, realized gain, pattern2D/3D; efficiency chỉ có khi solver trả mẫu hợp lệ. Thiếu trường ở tần số yêu cầu sẽ báo thiếu dữ liệu; không tạo đường cong mẫu. CSV đi kèm metadata về project/design/setup/nguồn/tần số/biểu thức biến. CSV nạp ngoài được ghi nguồn so sánh và không đổi trạng thái phiên thành đã mô phỏng.

HPBW dùng một angular cut dB ở một tần số: cần cực đại và đủ hai giao điểm−3dB quanh main lobe, xử lý cut tròn khi đủ miền. Thiếu dữ liệu trả lý do unavailable; không suy HPBW từ hình học. Kích thước xuất cho gia công là danh nghĩa; chưa chứng nhận dung sai sản xuất hoặc xuất CAD chế tạo.

## Kiểm thử

Từ repository root, chạy các unit test và kiểm tra sinh lệnh bằng MATLAB:

```matlab
addpath(fullfile(pwd,'SingleElementBuilder'));
testDir = fullfile(pwd,'SingleElementBuilder','tests');
unitFiles = {fullfile(testDir,'testBuilderGeometry.m'), ...
    fullfile(testDir,'testBuilderBridge.m'), ...
    fullfile(testDir,'testBuilderResults.m'), ...
    fullfile(testDir,'testHFSSGeneration.m')};
unitResults = runtests(unitFiles);
assertSuccess(unitResults);
```

Đây là test số học/CSV/logger/script; không cần HFSS và không chứng minh Boolean thật. Desktop smoke test chạy riêng trên MATLAB desktop:

```matlab
guiResults = runtests(fullfile(testDir,'testBuilderGUI.m'));
assert(all([guiResults.Passed]),'GUI tests failed or were filtered/incomplete.');
```

Trên Windows/HFSS2021R2/license, bật integration thật:

```matlab
setenv('VIVALDI_RUN_HFSS_TESTS','1');
setenv('VIVALDI_HFSS_EXE',cfg.exe); % đường dẫn ansysedt.exe của máy
setenv('VIVALDI_RUN_VARIATIONS','1');
hfssResults = runtests(fullfile(testDir,'testHFSSIntegration.m'));
disp(table(hfssResults));
assert(all([hfssResults.Passed]),'HFSS tests failed or were filtered/incomplete.');
```

Không có opt-in/Windows thì integration **Incomplete/Filtered**, không được tính là Passed. Bật opt-in nhưng executable sai là lỗi. Bộ test thực chạy scratch với source không tồn tại, Update so SHA source trước/sau và sáu build thay đổi riêng từng biến theo yêu cầu. Không Analyze tự động. Evidence được giữ trong tempdir và in đường dẫn.

Kiểm tra tĩnh độc lập dùng Python chuẩn, không thay thế MATLAB:

```bash
python3 SingleElementBuilder/tests/static_audit.py --reference SingleElementBuilder/reference/17_10_2026_vivaldi.aedt
```

## Nghiệm thu HFSS còn phải thực hiện

1. Mở CAD default/biến thể, kiểm tra hai tấm trực giao, transition21° đúng pivot, ba rectangle feed/cavity, connector/đế liên tục; đối chiếu CAD nguồn ở cùng nominal params. Không chỉ so bbox tổng.
2. Kiểm tra hai outer rỗng và hai inner copper, thân aluminum, SolveInside metal=false, không có cutter dư/Unclassified. Tâm port1≈(.450669139,0,−2.836303290), port2≈(11,10.549330861,−2.836303290)mm; xác nhận radial line chạm conductor và đúng quy ước phase.
3. ValidateDesign phải trả1; xem Messages/validation report, kiểm tra Open1/region, Setup1/Sweep, ba far fields/NoArray và mở lại `.aedt` đã lưu.
4. Lặp từng biến thể: L_flare_1=45,aperture_w=22,cavity_w=1.6,cavity_L=5.5,thickness=2.2,slot_feed_w=.6mm. Không mặc định mọi tổ hợp sẽ hợp lệ.
5. Khi được yêu cầu, chạy Original, kiểm tra convergence/pass, đủ lưới S-parameters hiện tại và dữ liệu trường thật. Đối chiếu golden CAD/solution nguồn, complex phase và port E-field trước khi xác nhận tương đương RF.

Lưu script `.vbs`, `.status`, `.console.log`, `.validation.log`, `.aedt`, sidecar và CSV/metadata. Nếu API2021R2 không hỗ trợ một method hoặc CAD thất bại, log chỉ ra stage; giữ project một phần, sửa theo API được hỗ trợ rồi chạy lại tên output mới. Không nới kiểm tra vật liệu/port/Boolean hoặc vô hiệu hóa xác minh để nhận thành công.

## Cấu trúc mã

| Nhóm | Tệp |
|---|---|
| GUI và mô hình | Vivaldi_DualPol_Builder, vivaldiBuilderDefaultParams/Geometry/Validate/Preview/TargetLength/Config |
| Automation | HFSSAutomationBridge, HFSSScriptWriter, HFSSCADHelpers |
| CAD và solver | HFSSGeometryBuilder, HFSSCoaxBuilder, HFSSSetupBuilder |
| Dữ liệu và log | HFSSPostProcessing, HFSSBuildLogger, vivaldiBuilderInspect |
| Bằng chứng và test | MODEL_RECONSTRUCTION_SPEC, API_COMPATIBILITY, VALIDATION_REPORT, reference/, tests/ |

Không cần package MATLAB bên thứ ba. Các phiên bản hỗ trợ/API đã nghiên cứu được ghi rõ; **khả năng chạy MATLAB/HFSS thực tế vẫn đang chờ xác nhận**, không có S11/gain/HPBW mô phỏng để công bố từ môi trường này.
