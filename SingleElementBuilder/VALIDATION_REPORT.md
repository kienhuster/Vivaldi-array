# Báo cáo kiểm chứng — Vivaldi Dual-Pol Builder Pro

**Trạng thái bàn giao: Implemented — HFSS Validation Pending.** Báo cáo này phân biệt kiểm tra đã thực thi trên Linux cloud, test MATLAB đã viết và nghiệm thu HFSS chưa chạy. Không có tuyên bố CAD/solver Passed khi chưa chạy công cụ tương ứng.

## Bằng chứng đã thực thi

| Hạng mục | Kết quả và giới hạn |
|---|---|
| Đọc nguồn AEDT | Đã truy dấu trực tiếp design dual_pol_vivaldi_patch_Wflare_20,31design variables+alpha,CS,operations/operands,tám top-level,materials,ports,sources,solver/far fields. Chưa tái sinh ACIS. |
| Provenance | Tệp reference giữ SHA-256 `631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619`; companion analysis đi kèm để đối chiếu. Spec có line refs được lập trước coding. |
| Python static audit | Đã chạy `tests/static_audit.py` thành công: parse source, kiểm tra dimension/biểu thức độc lập, mặc định và sáu biến thể, cấu hình phối hợp, CS/transform/bounds/port, targets49/50mm, script source markers. Đây là static/source-data audit; không thực thi MATLAB hay CAD. |
| Cú pháp và lint MATLAB | Đã chạy MISS_HIT Core parser và MISS_HIT lint với `--matlab 2020b --input-encoding utf-8` trên đủ **22 tệp MATLAB mới**, không có lỗi/cảnh báo. Parse/lint không chứng minh GUI, COM hoặc MATLAB runtime đúng. |
| Bảo toàn mã cũ | Đã so nội dung các tệp có sẵn:19tệp legacy giữ nguyên; code/documentation mới nằm trong SingleElementBuilder/. Không ghi đè các `.aedt` nguồn hoặc GUI mảng cũ. |
| Review CAD tĩnh | Đã đối chiếu short-copy-before-Rotate,pivotCS,thicken hai phía,dual-pol transform,six full-cylinder snapshots trước hollowing và cleanup. Các sai khác lifetime/parameterization được ghi rõ trong spec/log. |

Các kiểm tra trên không bao gồm việc chạy các hàm MATLAB. Số lượng tệp/check được cập nhật theo lần kiểm tra cuối của nhánh; nội dung từng loại bằng chứng mới là phạm vi xác minh, không suy từ số lượng sang độ đúng CAD.

Lệnh audit tái lập từ repository root:

```bash
python3 SingleElementBuilder/tests/static_audit.py --reference SingleElementBuilder/reference/17_10_2026_vivaldi.aedt
```

Nếu cài MISS_HIT core, có thể tái lập kiểm tra parser bằng:

```bash
mh_style --matlab 2020b --input-encoding utf-8 --no-style SingleElementBuilder
```

MISS_HIT là công cụ kiểm tra phát triển, không phải dependency để chạy ứng dụng.

## Đã triển khai, chưa thực thi MATLAB/HFSS

| Chức năng/test | Trạng thái thực thi |
|---|---|
| GUIuifigure,năm tab,validation,state machine/stale model,timeout/recheck | Đã triển khai; desktop smoke tests đã viết, chưa chạy MATLAB desktop. |
| Công thức31biến,JSON,target49/50,preview | Đã triển khai; kiểm tra số học độc lập đã chạy; MATLAB unit tests chưa chạy. |
| ScratchNewProject/InsertDesign,tạo CAD/Boolean từ đầu | Đã phát sinh API và test kế hoạch lệnh; chưa chạy HFSS2021R2. |
| Update SaveAs trước mutation,nguồn bất biến,sidecar protection | Đã triển khai; integration hash preservation test đã viết; chưa thực thi trên HFSS. |
| Hai coax rỗng,six cutters,tám active objects,material/SolveInside | Đã đối chiếu nguồn/script; topology/contact thật chưa được kiểm chứng. |
| Port/region/setup/sweep/NoArray | Đã triển khai cùng readback/assertions; chưa chạy assignment hoặc ValidateDesign thật. |
| Analyze selected setup và lưới S11/S22/S21/S12 nominal | Đã triển khai gate dữ liệu đầy đủ; chưa có nghiệm thật. SIMULATED không đồng nghĩa hội tụ. |
| HFSS reports,CSV,VSWR/HPBW/efficiency | Đã triển khai với data checks; CSV/logger/HPBW tests đã viết, chưa chạy MATLAB/HFSS. Không có đồ thị RF thật từ cloud này. |

Môi trường hiện tại không có MATLAB executable, Windows COM hoặc HFSS/license. Vì vậy **không** chạy được MATLAB unit tests, GUI launch, ANSYS Validate/mesh/solver, export field data hay golden solution comparison. Các integration test được opt-in rõ ràng; skip/incomplete không được báo Passed.

## Bộ test có sẵn

- `testBuilderGeometry.m`: independent/default/dependent expressions,CS/signs,RectangleY,dual-pol transform,coax/ports,biến thể,target và strict JSON.
- `testBuilderBridge.m`: source/output protection, SaveAs trước sửa biến, thứ tự independent/dependent variables, job identity/status, timeout và từ chối lịch sử Move không liên kết.
- `testBuilderResults.m`: CSVunits/cut selection,invalid data,HPBWcrossings/wrap,report-gates và loggerUTF16; dữ liệu test chỉ kiểm thuật toán, không là kết quả anten.
- `testHFSSGeneration.m`: thứ tự CAD,short snapshot,local rotations,six full cutters,guard từngoperation và scratch/update separation; không thực thi API.
- `testBuilderGUI.m`: desktop smoke/behavior,stale/invalid state và offline không nhận buildsuccess; bị filtered nếu thiếu desktop.
- `testHFSSIntegration.m`: Windows/HFSSopt-in,source-absent scratch,Update hash preservation,sáu biến thể opt-in,ValidateDesign1 và actual saved-file inspection; không tự Analyze.

Lệnh chạy và điều kiện opt-in đầy đủ ở [README.md](README.md). Chạy unit test theo danh sách riêng để không nhầm integration skipped với unit pass; khi nghiệm thu thật phải yêu cầu `all([results.Passed])` cho toàn bộ integration/desktop suite được chọn.

Có **52 test functions đã viết**: 39 unit/generation tests, 5 GUI tests và 8 HFSS integration tests. **Chưa thực thi test nào bằng MATLAB** tại môi trường này; các số trên là số test được định nghĩa, không phải số Passed/Skipped của một lần chạy.

## Khác biệt có chủ đích và rủi ro chưa giải quyết bằng runtime

1. Nguồn lưu KeepOriginals=true cho short cutter và final six-tool subtraction. Builder consume **sacrificial copies** với false, giữ active originals riêng và lưu Boolean operands, tránh cutter top-level dư. Chưa xác nhận bằng ACIS rằng toàn bộ topology tương ứng; không quảng cáo replay cờ nguồn tuyệt đối.
2. Nguồn Move `cable_mid_1` literal2mm; scratch dùng `thickness` để biến thể2.2mm đồng trục. Update nguồn cũ với thickness khác2 bị từ chối khi phát hiện literal không liên kết.
3. Integration line source outer→inner xác nhận bằng edge ownership; ray midpoint port1−X/port2+Y là suy luận có bằng chứng seam/midpoint. Cần query geometry/port E-field trực tiếp để xác nhận phase convention nguyên bản.
4. API EquationSurface/far-field/setup/report đã nghiên cứu theo tài liệu, nhưng một số bằng chứng wrapper có phiên bản khác. HFSS2021R2 phải kiểm từng method/schema và readback; lỗi phải dừng rõ, không bỏ qua.
5. Readback names,bbox,port count và saved variables tăng khả năng phát hiện sai nhưng không chứng minh cavity/transition/contact chính xác. Cần golden CAD comparison cùng tham số, kiểm tra volume/connectivity/voids,Validate và mở lại file.
6. Có nghiệm S-parameter đầy đủ chưa chứng minh hội tụ, độ chính xác mesh,efficiency/gain hoặc khớp mô hình chuẩn. Convergence/pass,complex phase và kết quả nguồn phải nghiệm thu riêng.

## Điều kiện để chuyển sang HFSS validated

Chạy trên Windows/MATLAB/HFSS2021R2 với license, hoàn thành mọi integration test default+biến thể, giữ log/validation/AEDT thực; kiểm tra thủ công hình học,cavity,coax rỗng,port contact/phase và golden CAD như README. Sau đó, khi người dùng yêu cầu, AnalyzeOriginal phải hoàn thành và cung cấp đủ61điểm5–20GHz cho cả bốn S-parameters ở nominal hiện tại; kiểm convergence và field contexts trước reports. Lưu CSV/metadata thật và đối chiếu kết quả nguồn nếu có `.aedtresults` phù hợp.

Đến khi có các bằng chứng đó, trạng thái vẫn là **Implemented — HFSS Validation Pending**.
