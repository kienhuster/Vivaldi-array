# Debug MATLAB Vivaldi Builder

Trạng thái: **Implemented — MATLAB Desktop / HFSS Validation Pending**.
Sửa trên nhánh `fix/vivaldi-matlab-gui-stability`, xuất phát từ `main` ở commit
`be59993`. Không thay tệp AEDT, công thức, lịch sử CAD hoặc cấu trúc vật lý anten.

## Nguyên nhân và cách sửa

### Lỗi uplevel variable `meta` khi xuất preview

`meta` được khai báo trong hàm chính và được `refresh()` dùng để đồng bộ control.
`exportPicture()` tạo `onCleanup(@refresh)`, làm callback dọn dẹp gọi lại trực tiếp
một nested function phụ thuộc vào workspace cha và hàng loạt handle GUI. Đây là
đường gọi gây lỗi scope được người dùng báo; đổi tên `meta` không sửa được thiết kế
này. Cleanup còn có thể chạy lúc đang xử lý một lỗi export, tạo lỗi thứ hai và che
nguyên nhân ban đầu.

Đã bỏ callback cleanup vào `refresh`. `vivaldiExportPreview` là hàm độc lập:
dựng preview vào axes của một figure tạm, xuất ảnh rồi dọn đúng figure đó. Cleanup
chỉ gọi local subfunction với một graphics handle; không đọc `meta`, không gọi
callback GUI, không đổi tiêu đề hoặc layer của preview đang hiển thị. Cả thành
công lẫn lỗi I/O đều dọn tài nguyên. `exportPicture` dùng try/catch để báo lỗi.

### Cảnh báo `try` / `end` quanh calculateTarget

Kiểm tra parser ban đầu không tìm thấy khối thiếu `end` ở phiên bản `main` đã đọc.
Đoạn này có `if/else/end`, nhiều phép gán và `catch err, fail(err); end` dồn trên
một dòng, khiến việc căn chỉnh/đối chiếu các khối khó theo dõi. Đã tách thành từng
câu lệnh, chuẩn hóa thụt lề toàn bộ hai GUI, hai bridge và parser liên quan. Không
thêm `end` tùy tiện, không đổi công thức tìm nghiệm. MATLAB Code Analyzer/checkcode
chưa chạy được trong cloud; không coi kết quả MISS_HIT là kết quả checkcode.

### Các lỗi liên quan được sửa

- Cả hai GUI có **Calculate**, cho nhập trực tiếp và không yêu cầu JSON. GUI cũ
  có **Build Antenna**, chuyển các kích thước sang bộ dựng từ đầu hiện có, dùng
  đúng reference 17/10. Save/Load Configuration chỉ là tiện ích tùy chọn.
- GUI chỉ hiện sau khi khởi tạo control và dữ liệu; có chế độ `Visible='off'`
  cho test. Callback báo lỗi kiểm tra figure còn tồn tại; slider chỉ commit khi
  thả, tránh vòng vẽ lại nặng và sửa Value trong lúc thumb đang kéo.
- Tự phát hiện executable từ `ANSYSEM_ROOT212`, thư mục Program Files và C:/D:;
  giữ Browse. Có đường dẫn tham khảo
  `D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe`. Chuẩn hóa đường dẫn
  dán có dấu nháy, dấu cách/dấu tiếng Việt. ProcessBuilder truyền các đối số riêng.
  Không tìm thấy executable thì báo lỗi, giữ GUI; offline generation không cần nó.
- `vivaldiInspectProject` hỗ trợ scope theo tên design. File ngày 17/10 có cả
  HFSSDesign1 rỗng và design thật; bridge cũ trước đây từ chối toàn bộ vì yêu cầu
  đúng một design. Nay chọn đúng design mà vẫn giữ full source cho guard chống
  thay đổi file sau Inspect. Không tự dùng thiết kế cũ khi thiếu reference 17/10.
- UTF-16 được ghi/đọc bằng byte và chuyển mã rõ ràng, có BOM. Khi đọc status đang
  được ghi, bỏ đuôi chưa hoàn chỉnh; việc chờ dòng đầy đủ vẫn phải đạt timeout.
- Job ID phải khớp một dòng acknowledgment hoàn chỉnh, không chấp nhận chỉ trùng
  prefix. Launcher thoát có thể là dispatch sang Desktop khác; không coi là đã
  dựng xong hay đã dừng. Lỗi đọc status/monitor và timeout giữ job đang chờ để
  tránh khởi động thêm tác vụ lên cùng project.
- Chỉ sau runtime acknowledgment **và** đọc lại AEDT thành công mới ghi sidecar
  working-copy ownership. Sinh script offline lặp lại không còn bị sidecar của
  lần trước chặn. Sidecar là dữ liệu tự động, không phải JSON người dùng phải nạp.
- Bridge cũ dùng COM version 2021.2 và kiểm tra phiên bản phản hồi; ValidateDesign
  chỉ báo VALIDATED với mã **1**, không coi mã lỗi 0 là thành công. Simulation
  chọn Setup1, không tự chạy mọi setup/Optimetrics. Update thickness bị từ chối
  nếu nguồn còn literal 2mm của cutter thứ hai; hướng dẫn dùng dựng từ đầu.
- Entry function của GUI mảng khớp tên `Phased_Array_GUI_Linker.m`; giữ alias
  `Phased_Array_Vivaldi_GUI_Pro`. Chỉ thêm kiểm tra executable và sửa thông báo
  dispatch, không sửa công thức hay lệnh dựng mảng. Không còn báo “hoàn thành”
  ngay sau khi gửi script.

## Kết quả kiểm tra

- MISS_HIT 0.9.44 phân tích **42 file MATLAB**, không có check/warning/error.
- GNU Octave 9.4.0 chạy **20 nhóm kiểm tra hồi quy portable**: số học của hai lõi,
  tìm nghiệm 49/50 mm chỉ đổi L_flare_1, đọc đúng design 17/10, phát hiện/chuẩn hóa
  đường dẫn, lỗi executable thiếu, UTF-16, sinh script lặp lại/Original/QuickTest/
  StudyBand, và guard status/timeout/readback. Các status/process fixture được
  đánh dấu mock; không phải dữ liệu solver.
- Audit Python độc lập đối chiếu 31 biểu thức, 19 literal, 12 công thức scalar
  ở tám cấu hình với nguồn AEDT; kiểm tra parents/axes/tọa độ của bốn CS và setup
  metadata gốc. Đây là kiểm tra dữ liệu/công thức, không phải CAD execution.
- SHA-256 file 17/10 vẫn là
  `631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619`.
  Chín file reference/math/CAD được so sánh byte với baseline và không đổi.
- Kiểm tra encoding, dấu nháy/ngoặc, giới hạn dòng và guard build của bảy file
  UTF-16 từ run hồi quy (sáu script Automation và một fixture Unicode).
- `git diff --check` đạt. Các kiểm tra trên không chứng minh MATLAB GUI hoặc
  COM/HFSS tương thích runtime; không tuyên bố Fully Verified.

| Test yêu cầu | Cloud đã làm | Còn phải chạy trên MATLAB/Windows |
|---|---|---|
| A — mở hàm chính | Parse/lint mọi .m, kiểm tra tên entry function | Khởi chạy hai GUI và MATLAB Code Analyzer |
| B — chỉnh kích thước | Chạy lại công thức/tham số bằng Octave | Gọi callback edit/Calculate/slider trên GUI |
| C — mục tiêu 49/50 | Hai solver đạt sai số <1e-6 mm; biến khác giữ nguyên | Xác nhận bảng/preview cập nhật trên GUI |
| D — export preview | Bỏ hoàn toàn cleanup vào refresh, kiểm tra source | Xuất PNG/PDF và cố tình gây lỗi I/O; xác nhận GUI/figure không đổi/leak |
| E — sinh VBScript offline | Sinh script thực từ các hàm sản phẩm, không Ansys | Chạy lại unit suite trong MATLAB |
| F — executable thiếu | Helper trả lỗi có kiểm soát | Bấm Build với path sai và xác nhận GUI còn mở |
| G — script/API/log | Encoding, cấu trúc và status protocol đã kiểm tra | VBScript/COM và chữ ký API trên HFSS 2021 R2 thật |
| H — project mới và Validate | **UNRUN** | Windows + MATLAB + licensed HFSS; không báo Passed |

Kết quả máy đọc được: [tests/verification/debug-portable-results.json](tests/verification/debug-portable-results.json).

## Chạy kiểm tra trên máy người dùng

```matlab
cd('C:\path\to\Vivaldi-array')
addpath(pwd, fullfile(pwd,'SingleElementBuilder'))
results = runtests({'tests','SingleElementBuilder/tests'});
disp(table(results)) % xem riêng Passed/Failed/Incomplete; HFSS tests cần opt-in

% Chạy checkcode thật để đánh giá Code Analyzer của phiên bản MATLAB đang dùng:
checkcode('Vivaldi_Element_Designer.m','-id')
checkcode('SingleElementBuilder/Vivaldi_DualPol_Builder.m','-id')

Vivaldi_Element_Designer
% Nhập kích thước → Calculate → chọn executable → Build Antenna.
```

`tests/testVivaldiDebug.m` gồm regression UI cho edit/Calculate/target, export
thành công/thất bại mà không thay GUI, và path sai không đóng ứng dụng. Các test
này dùng assumption MATLAB desktop, không giả làm đã chạy trên Octave.

Kiểm tra HFSS thật: theo hướng dẫn opt-in trong
[SingleElementBuilder/README.md](SingleElementBuilder/README.md), dùng
`VIVALDI_RUN_HFSS_TESTS=1`, `VIVALDI_HFSS_EXE` và chạy `testHFSSIntegration`.
Kiểm tra CAD, hai port/integration lines, Validate, rồi solver/convergence trên
bản sao.

Kiểm tra portable và audit:

```matlab
addpath('tests')
runDebugPortableChecks(fullfile(tempdir,'VivaldiDebugChecks'))
```

```sh
python3 tests/debug_static_audit.py --scripts /path/to/VivaldiDebugChecks
python3 SingleElementBuilder/tests/static_audit.py
```
