# Vivaldi Dual-Pol Builder Pro

**Implemented — HFSS Validation Pending.** Đây là ứng dụng MATLAB cho **một
phần tử dual-pol**, gồm hai tấm trực giao. Chưa được chạy trên MATLAB/Windows/HFSS
trong môi trường cloud này. Không đánh dấu Fully Verified, không có dữ liệu RF giả.

## Khởi chạy trên Windows

Yêu cầu MATLAB R2021a trở lên, Windows, Ansys Electronics Desktop **2021 R2
(2021.2)** và license HFSS hợp lệ. Dùng các thành phần MATLAB tích hợp, không cần
PyAEDT, Python hoặc toolbox anten. Để chạy GUI:

```matlab
cd('C:\path\to\Vivaldi-array\SingleElementBuilder')
Vivaldi_DualPol_Builder
```

Không có HFSS vẫn dùng được công thức, kiểm tra tham số, preview toán học,
giải chiều dài mục tiêu, JSON/CSV kích thước và xuất VBScript. Preview dùng
polyshape lấy mẫu đường loe; không phải CAD được xuất từ HFSS. Preview chưa áp
dụng ACIS Boolean coax lên thân nên không dùng làm bản vẽ chế tạo cuối cùng.

1. Tab **Geometry Parameters**: chỉnh giá trị hoặc slider; xem biến dẫn xuất.
   Reset Original khôi phục mô hình **17/10/2026**. Khoảng slider là tiện ích nhập,
   không phải bảo đảm giới hạn vật lý. Validate Parameters kiểm tra đại số.
2. Tab **Antenna Preview**: xem hai phân cực, flare/transition/slot/cavity, đế,
   Box1, vị trí coax và hệ tọa độ. Có các góc nhìn và lựa chọn hiển thị kích thước.
3. Tab **HFSS Builder**: chọn `ansysedt.exe`, phiên bản 2021.2, tên project/design,
   thư mục đầu ra, rồi Connect HFSS. Bản cài cần đăng ký COM ProgID
   `Ansoft.ElectronicsDesktop.2021.2`; nếu lỗi hãy kiểm tra cài đặt chính thức,
   quyền tiến trình và license, không tự sửa Registry hoặc bỏ qua lỗi.
4. Bấm **BUILD FULL ANTENNA IN HFSS**. Thao tác tạo project và CAD mới từ các
   primitive/Boolean, **không mở/copy CAD từ AEDT nguồn**. Không cần thư mục
   `reference/` khi dựng mới. Nếu không có executable/Windows, chỉ xuất script
   và giữ trạng thái `SCRIPT_GENERATED`; đây không phải build thành công.
5. Để sửa project có sẵn, **Load Project Params** chọn file, rồi **Update
   Existing Project**. Tiền kiểm đọc đúng design, công thức và tám đối tượng.
   Dự án phải đóng trong HFSS. Script OpenProject rồi **SaveAs trước mọi thay đổi**;
   chỉ đổi literal độc lập, giữ công thức phụ thuộc, cập nhật integration lines
   theo cạnh CAD mới và validate. Không cập nhật project mảng hoặc schema khác.
6. Mỗi job có thư mục mới duy nhất: `.aedt`, `automation.vbs`, `status.log`,
   `console.log`, `validation.log`, `job.mat`, và CSV khi có kết quả. Không tự xóa
   output cũ. Khi thành công, chỉ đóng project của job để gỡ lock cho lần chạy
   tiếp; Desktop vẫn có thể hoạt động. Job lỗi giữ CAD và cố lưu `_recovery.aedt`.
7. Mở output từ tab Builder để kiểm tra trong HFSS. Đóng file trước khi chạy
   Validate/Save/Analysis tiếp. Không tự xóa `.lock`. Nếu GUI và file khác tham số,
   cần Update hoặc Load Project Params trước khi phân tích.

## Solver và kết quả thật

**Setup1** giữ cấu hình gốc: DrivenModal/Single, adaptive 5 GHz, delta S 0.02,
5–50 passes, tối thiểu ba passes hội tụ; Discrete Sweep 5–20 GHz, bước 0.25 GHz,
lưu trường. Region vacuum padding 20 mm, Radiation Open1, NoArray. Hai Lumped
Port 50 Ω, mặc định port 1 = 1 W và port 2 = 0 W, pha 0°. Chọn port 2 sẽ đổi
nguồn sang 0 W/1 W, không tạo nguồn CP hoặc tự kích thích đồng thời.

**QuickTest** là setup riêng với delta S 0.1, 1–6 passes, một pass hội tụ.
GUI cho đổi band, mặc định 6–18 GHz/bước 1 GHz. Chỉ sweep QuickTest được sửa khi
chạy profile này; Setup1 không bị đổi. Đây là phép thử nhẹ, không thay nghiệm
chuẩn. Để chạy chuẩn dùng Setup1; các ô Quick Start/Stop/Step chỉ áp dụng QuickTest.

**Run Analysis** là hành động riêng do người dùng chọn. Build/Update/Validate/
Save/Export Script không chạy solver và không gọi AnalyzeAll/Optimetrics.
Trước khi chạy, chọn Pattern GHz nằm trên điểm sweep có lưu trường của profile.
Analyze trả về phải có dữ liệu S11 và S22 đủ số điểm mới được xuất báo cáo:

- S11/S22/S21/S12 và VSWR.
- Realized Gain cut, radiation pattern 2D/3D và Radiation Efficiency.
- CSV gốc do HFSS xuất; lỗi quantity/report của phiên bản HFSS được ghi rõ và
  dừng export, không thay bằng dữ liệu mô phỏng giả.

Các báo cáo cần nghiệm và far field thật; chữ ký/quantity còn chờ chạy trên
2021 R2. Trạng thái SIMULATED nghĩa là lời gọi solver đã trả về, có mẫu dữ liệu
và báo cáo đã xuất, **chưa chứng nhận hội tụ hoặc hiệu năng thiết kế**. Kiểm tra
convergence trong HFSS. Số điểm đủ cũng chưa chứng minh chất lượng nghiệm.

Tab Results cho nạp CSV, chọn cột X/Y và so sánh nhiều file cùng trục X/đơn vị.
CSV nạp ngoài không chứng minh hình học GUI đã được mô phỏng. HPBW cần một cut
gain dB theo góc độ, tần số/phi cố định, góc không trùng nhau và hai điểm cắt
-3 dB bao quanh cực đại. Không đủ dữ liệu sẽ trả NaN kèm lý do; không tự ngoại
suy cut vòng. Dữ liệu tần số GHz không được dùng làm góc.

## Manufacturing & Logs

Nhập chiều dài đích 49 hoặc 50 mm để giải nghiệm `L_flare_1` bằng fzero; giữ nguyên
các tham số khác. Xuất Dimensions CSV, cấu hình JSON và báo cáo có công thức/
tọa độ. Đây là kích thước danh nghĩa; cần kiểm tra/xuất CAD chế tạo trong HFSS.
Export HFSS Logs ghi nhật ký MATLAB JSONL và sao chép log job bằng tên mới.

Mỗi lời gọi Automation có xử lý lỗi ngay tại lệnh. Boolean lỗi hoặc validation
khác mã thành công **1** sẽ dừng. Sau Unite và khoét coax có kiểm tra connectivity
bằng SeparateBody trên bản sao chẩn đoán rồi xóa bản sao; không chỉnh lịch sử thân.
Bbox được kiểm tra bằng GetModelBoundingBox trước Region; không dùng API
GetObjectBoundingBox chỉ có ở các phiên bản mới. Port tìm midpoint thật của
cạnh port và vòng đáy lõi, kiểm tra Z/bán kính/đồng phương; không chép Edge ID cũ.
Hướng seam và quy ước pha vẫn cần đối chiếu bằng HFSS với nguồn chuẩn.

Nếu timeout, HFSS có thể vẫn đang chạy; GUI tiếp tục theo dõi và khóa job mới.
Không coi launcher thoát là script hoàn thành. Đóng GUI không hủy HFSS hay xóa
kết quả; cần kiểm tra tiến trình cũ trước khi mở frontend khác.

## Kiểm thử

Đọc [VALIDATION.md](VALIDATION.md) để phân biệt kiểm tra đã chạy và chưa chạy.

MATLAB unit tests (không cần license HFSS; GUI test cần desktop):

```matlab
cd('C:\path\to\Vivaldi-array\SingleElementBuilder')
addpath(pwd)
results = runtests('tests');
disp(table(results)) % integration tests được đánh dấu incomplete nếu chưa opt in
```

Kiểm tra portable, độc lập với MATLAB test framework:

```matlab
addpath('tests')
summary = runPortableChecks(fullfile(tempdir,'VivaldiPortableChecks'));
```

HFSS integration **chỉ bật chủ động trên máy có license**. Chạy bảy build (mặc định
và sáu thay đổi riêng), mỗi job giữ lại CAD/log. Không chạy sweep solver trong suite:

```matlab
setenv('VIVALDI_RUN_HFSS_TESTS','1')
setenv('VIVALDI_HFSS_EXE','C:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe')
results = runtests('tests/testHFSSIntegration.m');
assertSuccess(results)
```

Sau đó kiểm tra trực quan khe/cavity/transition, contacts, Boolean, integration-line
direction và so sánh nguồn `reference/17_10_2026_vivaldi.aedt`. Chạy nghiệm chuẩn
riêng để đánh giá S-parameters/gain/convergence. Chỉ sau các bước thực nghiệm này
mới có cơ sở nâng trạng thái thành Fully Verified.

## Mã nguồn và tài liệu

- [MODEL_RECONSTRUCTION_SPEC.md](MODEL_RECONSTRUCTION_SPEC.md): dữ liệu nguồn và
  thứ tự CAD đã đối chiếu trước khi coding, nguồn tham khảo API và giới hạn.
- `HFSSScript`: encoder typed Array/string/boolean, UTF-16LE BOM, kiểm tra lỗi.
- `HFSSAutomationBridge` + `hfss_runtime.vbs`: job, launch, timeout, recovery,
  validation, inventory và kiểm tra dữ liệu solver.
- Geometry/Coax/Setup/PostProcessing tách biệt; `vivaldiBuilder*` là lõi toán học,
  preview, đọc/lưu cấu hình, preflight và tính chiều dài.
- `reference/`: bản sao byte-for-byte nguồn ngày 17/10 và báo cáo đi kèm.

Các file MATLAB cũ ở root, GUI mảng và AEDT tháng 9 không bị sửa. Không cần chép
tool vào chương trình tạo mảng hiện có.
