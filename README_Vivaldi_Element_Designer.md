# Vivaldi Element Designer Pro

Ứng dụng MATLAB chỉnh **một phần tử Vivaldi dual-polarized** dựa trên biến của `Vivaldi_23_9_2026.aedt`. Công cụ tạo mảng `Phased_Array_GUI_Linker.m` và dự án gốc được giữ nguyên.

**Trạng thái bàn giao:** đã viết mã GUI, công thức, tìm chiều dài mục tiêu, kiểm tra tham số, cấu hình JSON, bridge HFSS, nạp CSV và xuất dữ liệu. Kiểm tra cú pháp và đối chiếu số học độc lập đã chạy trên Linux. **Chưa chạy MATLAB GUI, bộ test MATLAB hoặc HFSS thực tế** vì môi trường không có MATLAB/Ansys. Không coi đây là bản đã nghiệm thu trên máy đích. Chi tiết cấu trúc mô hình nằm trong [MODEL_ANALYSIS_Vivaldi.md](MODEL_ANALYSIS_Vivaldi.md); kết quả kiểm tra trong [VALIDATION_Vivaldi.md](VALIDATION_Vivaldi.md).

## Khởi động

Khuyến nghị MATLAB R2020b hoặc mới hơn, có desktop để dùng `uifigure`, `uigridlayout`, `uiimage` và `exportgraphics`. Ứng dụng mới không dùng `uiimage`, nhưng công cụ mảng cũ có dùng. Không cần toolbox bổ sung, Python hay thư viện ngoài. MATLAB phải có JVM cho chức năng bridge. HFSS Automation của ứng dụng cần Windows và Ansys Electronics Desktop 2021 R2 có license phù hợp; offline không cần HFSS.

Trong MATLAB, chuyển Current Folder đến repository rồi chạy:

```matlab
Vivaldi_Element_Designer
```

Hoặc:

```matlab
addpath('C:\research\Vivaldi-array')
Vivaldi_Element_Designer
```

Không dùng `run` để chạy hàm từ một thư mục chưa có trên MATLAB path. Trên Linux có MATLAB GUI, các chức năng offline dự kiến sử dụng được; bridge VBScript/COM chủ động báo cần Windows. Chưa kiểm chứng nền tảng này bằng MATLAB thực tế.

## Thiết kế hình học

Tab 1 có các nhóm Flare & Aperture, Slot & Transition, Cavity & Feed, Coaxial Structure và Advanced Parameters. Chọn tab nhóm bên trái để thấy các biến. Slider và ô số cập nhật hai chiều; nút ↺ khôi phục riêng biến và **Restore Original Parameters** khôi phục toàn bộ bộ tham chiếu. Miền slider là miền thao tác tiện lợi; nhập số có thể mở rộng miền đó. Nó không phải giới hạn vật lý đã được chứng nhận.

Các biến phụ thuộc `slot_t_L`, `L_flare`, `r_flare`, `x_feed`, `z_feed`, `L_patch`, chiều cao coax và kích thước đế tự tính. Không cho nhập riêng các biến này. Phép lượng giác dùng `sind`/`cosd`, đơn vị mm và độ. Tần số trong dữ liệu HFSS theo header, thường GHz; GUI không tự thay sweep hay `lamda`.

Kết quả tham chiếu:

| Giá trị | Kết quả |
|---|---:|
| `L_flare` | 46.4 mm |
| `r_flare` | 0.0795017123731 mm⁻¹ |
| `x_feed` | 2.499330860779 mm |
| `z_feed` | 0.6636967099411 mm |
| `L_patch` | 49.236303290059 mm |

Preview có Top View (nhìn theo Y vào XZ), Side View (nhìn theo X vào YZ), 3D, zoom/pan/rotate và các lớp bật/tắt. Đường biên hàm mũ dùng đúng phương trình nguồn; cavity/feed biểu diễn các rectangle operand, coax biểu diễn vòng và trục. Phân cực 2 dùng phép quay −90° quanh Z tại `RelativeCS1` rồi tịnh tiến +`thickness` theo Y.

**Preview là sơ đồ phương trình/operand, không phải CAD kim loại hoàn chỉnh.** Chưa dựng đầy đủ phép cắt/hợp nhất, transition quay, làm dày, tiếp xúc và các lỗ Boolean. Miệng và chiều dài là kích thước danh nghĩa. Không dùng ảnh này như đường cắt laser hoặc để kết luận RF. Chọn mô hình mới không làm preview tự trở thành CAD của mô hình mới.

Kích thước dương, `aperture_w > slot_feed_w`, coax có `0 < r_cabin < r_cabmid < r_cabout`, `slot_t_L >= 0`, mọi số phải thực hữu hạn. Miền transition được phần mềm hỗ trợ là `0 <= deg_slot_t < 90°`; ngoài miền này chưa triển khai, không phải tuyên bố không thể có anten vật lý. `them` và `positionx` được phép âm nếu các điều kiện liên quan còn hợp lệ. Va chạm và tính đúng port phải kiểm tra trong HFSS.

## Chỉnh anten đúng 49 mm hoặc 50 mm

1. Tab 1: giữ bộ tham số muốn dùng, kiểm tra cảnh báo.
2. Tab 2: nhập **49** hoặc **50** vào Target Antenna Length.
3. Miền tìm mặc định của `L_flare_1` là `[0.001, 200]` mm, có thể điều chỉnh. Đây là miền tìm kiếm do người dùng chọn.
4. Bấm **Calculate Dimensions**. Chương trình tìm đoạn hợp lệ rồi dùng `fzero`, chỉ cập nhật `L_flare_1`.
5. Xem bảng Before/After và sai số. Tab 1 vẽ lại và hiển thị `L_patch` mới.

Với các biến khác giữ mặc định, đối chiếu số học độc lập cho:

| Mục tiêu `L_patch` | `L_flare_1` gần đúng |
|---|---:|
| 49 mm | 39.764084695942 mm |
| 50 mm | 40.762475911592 mm |

Không làm tròn chiều dài cũ để giả thành chiều dài mục tiêu. Nếu không tìm thấy nghiệm trong miền đang chọn, chương trình báo lỗi và giữ tham số cũ. Quét 1001 điểm chỉ phát hiện các nghiệm được bracket trong miền hợp lệ; không chứng minh một hàm tùy ý không có mọi nghiệm. Với hệ công thức tham chiếu, đã đối chiếu hai mục tiêu trên. Nếu thay tham số sau khi giải, tab chế tạo báo lại sai lệch so với mục tiêu đã giải.

Save/Load Configuration lưu các biến độc lập vào JSON có schema `vivaldi-element-1`. Mở tệp phải qua kiểm tra schema/biến/giá trị trước khi áp dụng. Cấu hình không chứa license, đường dẫn Ansys hay dữ liệu RF.

## Kết nối Ansys Electronics Desktop 2021 R2

1. Cài MATLAB và AEDT 2021 R2 trên Windows; kiểm tra HFSS mở được và license giải mô hình hoạt động.
2. Tab 3: chọn `.aedt`, bấm **Inspect Project** và xem biến/design/đối tượng/boundary.
3. Chọn `ansysedt.exe`, thường là `C:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe`, hoặc đường dẫn D: của máy bạn. **Auto-detect** tìm trong các thư mục Ansys chuẩn; vẫn có thể chọn thủ công.
4. Chọn thư mục ghi được và **tên .aedt mới chưa tồn tại**.
5. Đóng dự án đầu vào trong HFSS trước khi cập nhật để tránh lock/phiên làm việc có thay đổi chưa lưu. Không xóa lock khi chưa biết nguyên nhân.
6. **Connect HFSS** chạy script ở tiến trình AEDT riêng và đọc phiên bản COM. Kết nối desktop không chứng minh có license solver; lỗi license khi mở/giải được ghi theo phản hồi API.

Bridge dùng `-RunScript` và ProgID `Ansoft.ElectronicsDesktop`. Nếu máy có nhiều phiên bản, COM có thể được đăng ký cho phiên bản khác executable đã chọn. Luôn xem `GetVersion` trong log và xác nhận COM registration theo cài đặt Ansys. Không tự đổi registry hay cấp license. Các chữ ký API được triển khai cho workflow 2021 R2 nhưng chưa chạy đối chiếu với AEDT thật.

### Tạo bản sao và cập nhật

**Update Geometry (Save As)**:

1. Kiểm tra tham số và schema biến/công thức của dự án nguồn. Chỉ hỗ trợ một HFSS design dạng text có các công thức tham chiếu tương thích.
2. Chụp danh sách solids/sheets, vật liệu, coordinate systems, boundary, hai Lumped Port và solution setups qua API.
3. `SaveAs` sang tên mới, kiểm tra file đã tồn tại và danh tính project/path đã chuyển sang bản sao, rồi mới thay đổi biến.
4. Chỉ ghi biến độc lập có giá trị số khác file nguồn; không viết đè công thức dẫn xuất hay biến độc lập chứa biểu thức không được hỗ trợ.
5. Đối chiếu inventory, chặn đối tượng Unclassified, lưu bản sao rồi đóng project vừa thao tác.

Không chỉnh text AEDT, không nhân bản anten, không đổi vật liệu, không gọi `EditSources`, không xóa port/boundary/setup và không gọi `AnalyzeAll` trong cập nhật. Bridge đọc AEDT để kiểm tra schema; mọi thay đổi mô hình thực hiện qua API.

**Generate Update Script** cho phép tạo script offline để xem xét; nó không kết nối, lưu project hay chạy mô phỏng. Script, status và console log có tên riêng trong thư mục kết quả. Các giá trị/path trong script là cấu hình được chọn, không có credentials. Nếu muốn chạy script thủ công bằng AEDT, đọc script trước và kiểm tra trạng thái/log sau; GUI không tự nhận bản sao chạy thủ công là tác vụ thành công của nó.

Nếu một API inventory không hoạt động, script dừng, ghi FAILED và không tiếp tục chỉnh biến. Nếu lỗi xảy ra sau Save As, có thể còn bản sao từng phần và project đang mở; kiểm tra/đóng trong HFSS, chọn tên mới khi thử lại. File nguồn không được script lưu hoặc thay biến.

Kiểm tra inventory không chứng minh mọi face/edge gán port, integration line, giao cắt hay kích thước CAD còn đúng. Đó là phần kiểm tra HFSS bắt buộc sau thay đổi lớn.

### File mới hơn

Nếu có `Vivaldi_13_10_2026.aedt` trong thư mục repository, GUI ưu tiên chọn nó để inspect; hiện workspace chỉ có bản 23/9. Có thể chọn file trên máy Windows bằng nút Chọn HFSS. Không giả định các phiên bản cùng hình học.

Với file khác nội dung bản tham chiếu, cần kiểm tra CAD/biến trong HFSS và đánh dấu xác nhận trên GUI. Bridge vẫn yêu cầu các công thức dẫn xuất đúng schema đã hỗ trợ. Các biến khác của file mới không được tự sửa. Các giá trị GUI là bộ thiết kế mà bạn muốn áp dụng, mặc định là bản 23/9; **không tự nhập mọi biểu thức của file mới vào GUI**. Xem bảng Inspect, đặt giá trị GUI có chủ đích trước khi Update. Nếu công thức thay đổi, bridge báo FormulaMismatch và không cập nhật; cần phân tích/triển khai hỗ trợ riêng cho phiên bản đó.

### Validate và mô phỏng

**Validate Model** chỉ thao tác bản sao vừa được Update thành công với đúng bộ biến GUI. API `ValidateDesign` ghi báo cáo `.validation.log`; mã trả về được giữ nguyên, không tự diễn giải thành “model pass”. Xem báo cáo và HFSS Messages. Nếu API không có/không hỗ trợ chữ ký, trạng thái là `VALIDATION_UNVERIFIED`.

**Run Simulation** có xác nhận riêng trước `AnalyzeAll`. Đổi slider không chạy HFSS. Trước khi chạy thật, xem validation, hai integration line, sweep và nguồn kích thích. Workflow giữ nguyên hai cổng 50 Ω, Driven Modal, Discrete 5–20 GHz/0.25 GHz và nguồn gốc cổng 1 = 1 W, cổng 2 = 0 W.

GUI dùng timer để đọc status, không chờ đồng bộ COM hoặc `system`. AEDT/license có thể mất nhiều thời gian; theo dõi status và console log. Đóng GUI chỉ dừng theo dõi, không giết HFSS đang chạy. Khi đóng trong lúc chạy có thông báo rõ.

| Trạng thái | Ý nghĩa |
|---|---|
| SCRIPT_GENERATED (log GUI) | Chỉ tạo file VBScript |
| LAUNCHED / STARTING | Tiến trình được gọi; chưa chứng minh kết nối |
| CONNECTED | COM desktop trả phiên bản, chưa chứng minh solver license |
| OPENING / UPDATING | Đang mở nguồn hoặc sửa bản sao |
| UPDATED | Bản sao đã lưu và inventory không đổi; chưa mô phỏng |
| VALIDATED | API validation đã trả về; phải xem báo cáo, không đồng nghĩa pass |
| VALIDATION_UNVERIFIED | Không kiểm chứng được validation qua API |
| RUNNING / CHECKING_RESULTS | Đang giải hoặc kiểm tra dữ liệu sau giải |
| SIMULATED | AnalyzeAll trả về và API tìm được mẫu S11/S22; chưa khẳng định hội tụ hay đủ toàn sweep |
| SOLVE_RETURNED_UNVERIFIED | Lệnh giải trả về nhưng chưa xác minh dữ liệu |
| FAILED | API/script hoặc tiến trình kết thúc báo lỗi; xem log |

Chỉ có PID hoặc lệnh mở HFSS không tạo trạng thái hoàn thành. Dữ liệu cũ có thể tồn tại trong dự án; kiểm tra timestamp, trạng thái solution và hội tụ trong AEDT trước khi dùng kết quả cho đồ án. Bridge chưa xuất toàn bộ report RF tự động.

## Nạp kết quả RF thực

Xuất report CSV từ HFSS rồi bấm **Import Results CSV**. Chọn rõ cột X và các cột Y; tên cột được giữ nguyên để thấy đơn vị như `Freq [GHz]`, `dB(S(1,1))`, `dB(S(2,2))`, `dB(S(2,1))`, RealizedGain hoặc Theta/Phi.

Ứng dụng hỗ trợ đồ thị Cartesian theo cột đã chọn, gồm pattern cắt theo góc. Không tự chuyển S tuyến tính sang dB, đổi Hz sang GHz, trộn gain và S thành cùng đơn vị, hoặc xử lý Touchstone/đồ thị pattern 3D. Chọn các đại lượng cùng đơn vị khi vẽ chung. Với nhiều sweep/tần số/góc trong cùng tệp, xuất riêng từng trace/cut hoặc lọc trước để tránh nối các nhóm không liên quan. Dữ liệu phải là số thực hữu hạn; tệp rỗng, text, NaN/Inf hoặc cột không tồn tại bị chặn.

Khi chưa nạp dữ liệu, hiển thị **Not Simulated**, không sinh đường S11/gain giả. Dữ liệu nhập chỉ được gắn với file CSV; chưa tự xác nhận nó thuộc bộ tham số GUI hiện tại. `S21` dB là truyền qua; nếu muốn isolation dương `-S21_dB`, xuất/biến đổi dữ liệu có chủ đích, không đổi dấu âm thầm.

## Chế tạo và xuất dữ liệu

Nhập vật liệu, dung sai ± theo mỗi mép và khe tối thiểu do nhà gia công cung cấp. Chiều dày dùng biến `thickness`. Giá trị vật liệu trong tab là mô tả chế tạo do người dùng xác nhận, không đổi material trong HFSS.

Kiểm tra bảo thủ khe slot/cavity lấy `min(slot_feed_w,cavity_w) - 2*tolerance`; chưa tìm khe nhỏ nhất trên toàn CAD hoặc mô phỏng kerf/coax. Cảnh báo màu đỏ nếu nhỏ hơn khe tối thiểu đã nhập. Kết quả không phải bảo đảm nhà máy cắt được: cần thống nhất vật liệu, độ dày, kerf, hướng lắp, bề mặt và dung sai thực tế.

CSV có biến độc lập, kích thước dẫn xuất, đơn vị, giá trị gốc, delta và dung sai tuyến tính yêu cầu. File `.notes.json` đi kèm ghi vật liệu/chiều dày/khe tối thiểu/mục tiêu. Dung sai trên `deg` hoặc `1/mm` để trống (NaN), không gán mm cho đại lượng khác.

PNG/PDF xuất sơ đồ có đường đo và nhãn “KHÔNG phải CAD hoàn chỉnh”, kèm vật liệu/chiều dày/dung sai. **DXF chưa triển khai**: phải lấy đường bao đúng từ CAD HFSS và đối chiếu đầy đủ trước khi tạo đường cắt. Không dùng preview hiện tại như DXF chính xác.

## Chuyển phần tử sang công cụ tạo mảng

Sau khi bản sao phần tử được Validate và mô phỏng chấp nhận trên máy đích, lưu/đóng file. Mở công cụ mảng cũ độc lập và dùng **Chọn File** chọn bản sao `.aedt` này. Đặt kích thước mảng, khoảng cách, tần số và góc theo nghiên cứu tiếp theo. Không đưa file gốc vào thao tác ghi đè.

Mã mảng cũ có tên hàm `Phased_Array_Vivaldi_GUI_Pro` khác tên file. File đó không được sửa trong tác vụ này. Nếu MATLAB của bạn không gọi được `Phased_Array_GUI_Linker`, tạo **bản sao bên ngoài repository** tên `Phased_Array_Vivaldi_GUI_Pro.m`, thêm thư mục đó vào MATLAB path và gọi `Phased_Array_Vivaldi_GUI_Pro`. Đường dẫn Ansys D: trong mã cũ cần phù hợp máy thực tế; mọi điều chỉnh công cụ cũ cần thực hiện riêng, giữ bản gốc. Việc chỉnh một phần tử không bảo đảm beam steering, coupling hay isolation của mảng.

## Kiểm thử trên MATLAB

Chạy các test không mở GUI:

```matlab
addpath(pwd)
results = runtests('tests/testVivaldiElementDesigner.m');
disp(table(results))
assertSuccess(results)
```

Test GUI riêng (MATLAB desktop có display):

```matlab
results = runtests('tests/testVivaldiGUI.m');
disp(table(results))
assertSuccess(results)
```

GUI test được skipped bằng assumption nếu không có desktop; không coi skipped là pass. Test script thất bại dùng **status giả lập**, không chứng minh COM/HFSS thật. Các test bridge generate chỉ tạo script trong thư mục tạm, không chạy solver. Nghiệm, config, parser, CSV, log và các điều kiện an toàn có test riêng. Nghiệm RF và license chỉ kiểm được trên HFSS thật.

Nghiệm thu thủ công cần: mặc định/45 mm và preview cập nhật; target 49/50; nhập số lỗi và kiểm tra Update bị chặn; offline khi không có HFSS; license/API thất bại có log; SaveAs không thay file gốc (đối chiếu hash); hai cổng/integration line/material/boundary/setup giữ nguyên; validation, giải và dữ liệu thực đúng cấu hình.

## Xử lý lỗi

| Lỗi | Hành động |
|---|---|
| Không nhận `uifigure`/`uigridlayout`/`exportgraphics` | Kiểm tra phiên bản MATLAB và desktop; dùng R2020b+ |
| Không tìm thấy hàm | Current Folder/path phải chứa file chính và các module |
| HFSSUnavailable | Dùng offline; trên Windows chọn đúng `ansysedt.exe` và kiểm tra cài đặt |
| CreateObject / GetVersion lỗi | Kiểm tra COM registration, phiên bản AEDT, license; không sửa registry tự động |
| ProjectLocked | Đóng dự án đúng cách; giữ thay đổi chưa lưu trước, không xóa lock đang dùng |
| ExistingOutput | Chọn tên mới; không ghi đè bản sao/user file đã có |
| FormulaMismatch / IndependentFormula | File khác schema/biến chứa biểu thức; cần phân tích phiên bản đó trước |
| Inventory/Unclassified lỗi | Mở bản sao trong HFSS, kiểm tra geometry và Messages; không dùng bản sao từng phần để chế tạo |
| ValidateDesign không hỗ trợ | Validate bằng HFSS UI; xem raw return và báo cáo nếu có |
| HFSS đứng ở LAUNCHED/STARTING | Kiểm tra `.console.log`, license dialog, script/phiên bản; tiến trình còn sống không chứng minh script chạy |
| SOLVE_RETURNED_UNVERIFIED | Kiểm tra Solution Data/Reports trong HFSS; xuất CSV thực và nạp riêng |
| Không có nghiệm | Kiểm tra các biến khác và miền tìm `L_flare_1`; không thay chiều dài bằng làm tròn |
| CSV lỗi | Xuất dữ liệu số có header, một sweep/cut, chọn đúng X/Y và đơn vị |

Log JSON chứa thời điểm theo timezone của máy MATLAB, file, tham số Before/After, hình học, script, lỗi và trạng thái API. **Copy Error** sao chép lỗi cuối; `.status`, `.console.log`, `.validation.log` giữ phản hồi tiến trình ngoài. Không xóa các file này trước khi chẩn đoán.

## Kiến trúc

| File | Vai trò |
|---|---|
| `Vivaldi_Element_Designer.m` | GUI và điều phối timer/state |
| `vivaldiDefaultParams.m` | Giá trị/nhãn/đơn vị/tooltip/miền slider |
| `vivaldiCalculateGeometry.m` | Công thức nguồn, không sửa CAD |
| `vivaldiValidateParams.m` | Validation đại số và cảnh báo |
| `vivaldiSolveTargetLength.m` | Tìm miền hợp lệ và giải `fzero` |
| `vivaldiPlotPreview.m` | Sơ đồ phương trình/operand hai phân cực |
| `vivaldiInspectProject.m` | Inventory AEDT text chỉ đọc |
| `vivaldiHFSSBridge.m` | Script SaveAs/API, launch/poll ngoài tiến trình |
| `vivaldiLoadResults.m` | CSV thực với mapping cột rõ ràng |
| `vivaldiSaveConfig.m` | Save/load JSON có kiểm tra |
| `vivaldiExportDimensions.m` | CSV danh nghĩa |
| `vivaldiLogger.m` | Log có cấu trúc và lỗi cuối |

Ứng dụng không đưa ra bảo đảm S11/gain/isolation từ hình học và không thay mô hình gốc bằng anten tự thiết kế.
