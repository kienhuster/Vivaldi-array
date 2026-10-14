# Phân tích mô hình nguồn Vivaldi

Đã đọc toàn bộ cấu trúc text `Vivaldi_23_9_2026.aedt`, đối chiếu khối Properties, hệ tọa độ, ToplevelParts/OperandParts, Operations/CloneToOperation, BoundarySetup, AnalysisSetup và Solutions. Đây là phân tích dữ liệu lưu, **chưa tái sinh ACIS hoặc mở project bằng HFSS**. Workspace không có `Vivaldi_13_10_2026.aedt`.

Repository ban đầu chỉ có hai file: GUI tạo mảng và dự án AEDT; không có manifest, README, test hay AGENTS.md. GUI mảng cũ lấy mô hình có sẵn, tạo VBScript nhân bản X/Y, sửa nguồn rồi gọi AnalyzeAll. Công cụ mới không tái sử dụng các lệnh nhân bản/cấp nguồn đó.

## Nhận dạng

- AEDT `Version(2021, 2)`; một `HFSSModel`: `dual_pol_vivaldi_patch_Wflare_20`.
- `SolutionType='DrivenModal'`; GeometryCore Units `mm`, ACIS, strict validation; không bỏ kiểm tra intersection/Unclassified trong cấu hình lưu.
- 31 design variables + 1 postprocessing variable `alpha`.
- 8 top-level parts và 17 operand parts. Đây là phân loại từ cấu trúc lưu, không phải kiểm chứng vật thể cuối qua API.

## Toàn bộ biến nguồn

| Biến | Giá trị/công thức nguồn | Xử lý trong ứng dụng |
|---|---|---|
| L_flare_1 | 40mm | Nhập |
| slot_t_L | 6.4mm+them | Tự tính, giữ công thức HFSS |
| L_flare | L_flare_1+slot_t_L | Tự tính |
| aperture_w | 20mm | Nhập |
| slot_feed_w | 0.5mm | Nhập |
| r_flare | (1/L_flare)*ln(aperture_w/slot_feed_w) | Tự tính |
| deg_slot_t | 21deg | Nhập |
| z_feed | ((slot_feed_w/2)*exp((slot_t_L)*r_flare)+slot_feed_w/2)*sin(deg_slot_t)+slot_t_L*(1-cos(deg_slot_t)) | Tự tính |
| x_feed | ((slot_feed_w/2)*exp((slot_t_L)*r_flare)+slot_feed_w/2)*cos(deg_slot_t)+slot_t_L*sin(deg_slot_t)-(slot_feed_w/2)*exp((slot_t_L)*r_flare) | Tự tính |
| h3_slot_feed | 1mm | Nhập |
| h2 | 2.6mm | Nhập |
| cavity_w | 1.4mm | Nhập |
| cavity_L | 5mm | Nhập |
| h_de | 2mm | Nhập |
| L_patch | L_flare_1+slot_t_L-z_feed+h3_slot_feed+slot_feed_w+h_de | Tự tính |
| r_cabin | 0.15mm | Nhập nâng cao |
| h_cabin | h_de+slot_feed_w | Tự tính |
| positionx | 0.15mm | Nhập nâng cao |
| r_cabmid | 0.35mm | Nhập nâng cao |
| h_cabout | h_cabin-slot_feed_w | Tự tính |
| h_cabmid | h_cabin-slot_feed_w | Tự tính |
| r_cabout | 0.5mm | Nhập nâng cao |
| de_L | aperture_w+thickness | Tự tính |
| de_W | aperture_w+thickness | Tự tính |
| lamda | 16.6667mm | Không sửa; không tự suy ra từ sweep |
| h_box | lamda/2+L_patch | Giữ công thức; không đồng nhất với Region padding |
| scan_phi | 0deg | Không sửa |
| scan_theta | 30deg | Không sửa |
| thickness | 2mm | Nhập |
| them | 0mm | Nhập nâng cao |
| c2 | 0mm | Không sửa |
| alpha (postprocessing) | -237.6deg | Không sửa |

Trong MATLAB, mm biểu diễn bằng số, hệ số `r_flare` là mm⁻¹ và lượng giác chuyển sang `sind`/`cosd`. HFSS vẫn giữ chính các biểu thức trên, không gán kết quả số vào biến phụ thuộc. `h_box` có trong Properties nhưng region hiện tại dùng padding tuyệt đối 20 mm; không giả định sửa biến này sẽ thay kích thước region.

## Hệ tọa độ

Tất cả hệ tương đối được lưu ở chế độ Axis/Position, các trục ban đầu cùng hướng hệ tham chiếu:

| CS | ID | Tham chiếu | Origin trong hệ tham chiếu |
|---|---:|---:|---|
| Global | 1 | — | (0,0,0) |
| slot_t_td | 52 | 1 | ((slot_feed_w/2)*exp(slot_t_L*r_flare), 0, slot_t_L) |
| slot_feed_td | 69 | 1 | (-x_feed, 0, z_feed) |
| patch_td | 157 | 1 | (aperture_w/2, 0, L_flare) |
| RelativeCS1 | 2951 | 157 | (0, -thickness/2, 0) |

Vì vậy origin Global của `RelativeCS1` là `(aperture_w/2, -thickness/2, L_flare)`. Khi quay quanh Z, tọa độ Z của origin không ảnh hưởng X/Y, Z các điểm giữ nguyên. Preview dùng phép quay −90° trong hệ này và tịnh tiến +thickness theo Y cho phân cực thứ hai.

## Dựng hình và kim loại

`EquationSurface1` có `XuvFunction='_v*((slot_feed_w/2)*exp((_u)*r_flare))'`, `YuvFunction='0'`, `ZuvFunction='_u'`, `_u ∈ [0,L_flare]`, `_v ∈ [-1,1]`. Đây là **surface operand của khe/cắt**, không tự đồng nhất nó với toàn bộ tấm kim loại phát xạ.

`EquationSurface2` dùng phần `[0,slot_t_L]`, được clone và quay theo Y một góc `deg_slot_t` tại hệ transition; sau đó subtract/unite với surface khe. Các rectangle feed/cavity tham chiếu `slot_feed_td`:

| Operand | XStart / ZStart cục bộ | Width / Height (WhichAxis Y) |
|---|---|---|
| Rectangle1 | 0 / 0 | -h3_slot_feed / slot_feed_w |
| Rectangle2 | 0 / -h3_slot_feed | -slot_feed_w / slot_feed_w+h2+cavity_w |
| Rectangle3 | slot_feed_w+h2 / -(h3_slot_feed+slot_feed_w) | cavity_L / cavity_w |

Trong cấu hình này Width chạy theo Z và Height theo X. Preview thể hiện các rectangle operand theo origin nguồn; chưa tái tạo union với transition quay.

`Vivaldi_1` bắt đầu từ rectangle trên XZ tại `patch_td` (Width=-L_patch, Height=-aperture_w, normal Y), CoverLines, subtract surface khe, SheetThicken. Sau đó DuplicateAroundAxis Z góc −90° trong `RelativeCS1`, đối tượng clone được Move +thickness theo Y. Unite ghép các phần kim loại với `KeepOriginals=false`; tiếp tục subtract các operand coax. **Hai phần phân cực có thể thuộc cùng solid `Vivaldi_1` sau Unite.** Không được yêu cầu nhất thiết có hai solid tên Vivaldi_1/Vivaldi_2 để kết luận phân cực còn tồn tại.

Lịch sử có 287 `DuplicateAlongLine` trong các khối CloneToOperation và nhiều clone khác. Chúng không tương ứng 287 anten đang hoạt động: phải phân biệt placeholder/reference lịch sử và ToplevelParts. Công cụ mới không thêm, chạy lại hay thay các operation này; chỉ sửa biến theo lịch sử có sẵn. Trạng thái CAD thật vẫn phải được mở/kiểm tra bằng HFSS.

## Coaxial feed và vật liệu

Trục lõi coax nguồn là Z trong `slot_feed_td`, tâm X=`-positionx+slot_feed_w+h2`, Y=0, Z=`-h3_slot_feed`, radius=`r_cabin`, height=`-h_cabin`. Trong Global, X=`-x_feed-positionx+slot_feed_w+h2`, Z đầu=`z_feed-h3_slot_feed`.

Các cylinder giữa/ngoài bắt đầu thấp hơn đoạn slot: Z cục bộ `-h3_slot_feed-slot_feed_w`; `h_cabmid=h_cabout=h_de`. Port circle nằm tại Z cục bộ `-h3_slot_feed-h_cabin`, radius=`r_cabmid`, sau CoverLines tạo sheet. Các clone phân cực thứ hai có phép quay và dịch tương tự.

| Top-level | Vật liệu lưu |
|---|---|
| cable_in, cable_out | copper |
| cable_in_1, cable_out_1 | copper |
| Vivaldi_1 | aluminum |
| port1, port2 | vacuum |
| RadiatingSurface | vacuum |

Operand `cable_mid`/`cable_mid_1` không phải hai solid dielectric đang hoạt động được liệt kê riêng. Không suy diễn lớp giữa là PTFE hoặc nền PCB; ứng dụng không thay vật liệu. Preview chỉ vẽ bán kính/trục, chưa biểu diễn tiếp xúc/điện môi hoặc loại bỏ các cylinder theo Boolean.

17 operands: EquationSurface1, EquationSurface2, EquationSurface2_1, Rectangle1/2/3, cable_mid, Vivaldi_2, cable_mid_1, Box1, De, cable_in_2, cable_in_1_1, cable_mid_2, cable_mid_1_1, cable_out_2, cable_out_1_1. Box/De và các clone đã tham gia Boolean không được đưa thành anten mới.

## Ports, integration lines và boundary

- Port `1`: `BoundType='Lumped Port'`, Objects(357) tương ứng port1, một mode, Impedance/RenormImp 50ohm.
- Port `2`: Objects(3229) tương ứng port2 clone quay/dịch, cấu hình tương tự.
- Integration line port 1: thứ tự entity **358 → 188**, đều PositionType EdgeCenter, IsAttachedToEntity=true. 358 thuộc đường tròn port ở `r_cabmid`, 188 thuộc cylinder lõi `r_cabin`; line được gắn từ biên port ngoài vào lõi theo thứ tự lưu.
- Port 2: entity **3231 → 3202**; cùng kiểu gắn trên các clone. Hướng tương ứng phân cực quay, không thể đọc tọa độ toàn cục từ các trường XPosition/YPosition/ZPosition=0. Các trường đó không phải hai endpoint nằm tại gốc.
- Chưa xác minh orientation endpoint thực tế sau ACIS evaluation. Cần HFSS UI/API geometry để kiểm tra vector tích phân thực và quy ước pha.
- `Open1`: Radiation, Objects(3471) tương ứng RadiatingSurface. Region có padding tuyệt đối ±X/±Y/±Z đều 20mm trong RelativeCS1; không tự retune region theo tần số.

API inventory trong bridge bảo vệ tên/type ports và boundary trước/sau, không chứng minh face/edge attachment bất biến. Không tái gán hoặc sửa integration line trong ứng dụng.

## Solution setup và nguồn

- Setup1: HfssDriven/Broadband, MultipleAdaptiveFreqs Low=5GHz, High=20GHz, MaxDeltaS=0.02, MaximumPasses=50, MinimumPasses=5, MinimumConvergedPasses=3; SaveAnyFields=true.
- Sweep: enabled, LinearStep 5GHz → 20GHz, bước 0.25GHz, Type Discrete, SaveFields/SaveRadFields=true.
- Solutions: IncludePortPostProcessing=true, UseSpecifiedIncidentPower=false; SourceEntry ID0/cổng 1 = 1W, 0deg; ID6/cổng 2 = 0W, 0deg.
- File có metadata report S11/S21, gain/pattern và lưu solution history. Metadata/report setup không thay thế dữ liệu CSV thực, không chứng minh kết quả thuộc hình học GUI hiện tại.

Giữ các thiết lập này qua SaveAs/ChangeProperty. Không gọi EditSources hoặc dựng setup mới.

## Biến điều chỉnh và mức an toàn

16 biến GUI là literal độc lập trong bản nguồn. “Có thể điều chỉnh” nghĩa là biểu thức được hỗ trợ và cập nhật qua biến, **không** nghĩa là mọi giá trị tạo CAD hợp lệ hay hiệu năng tốt. Các biến dẫn xuất tự tính để tránh mâu thuẫn. Geometry validation đại số chặn số không hợp lệ và cảnh báo coax/cavity; giao cắt/tính kín solid/port contact vẫn thuộc HFSS.

Với dự án mới hơn: inspect riêng, không eval tùy ý biểu thức tệp, yêu cầu xác nhận người dùng đã kiểm tra CAD, đối chiếu công thức nguồn. Công thức khác hoặc biến độc lập không còn literal khiến cập nhật tự động dừng. Không tự chuyển về hình học cũ hoặc thay mô hình mới bằng preview.
