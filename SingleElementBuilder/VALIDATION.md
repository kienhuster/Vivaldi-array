# Báo cáo kiểm chứng

Trạng thái phát hành: **Implemented — HFSS Validation Pending**.

## Đã thực hiện trong cloud Linux

- Đọc trực tiếp AEDT ngày 17/10/2026: 669840 bytes, SHA-256
  `631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619`;
  cấu trúc 3285 khối cân bằng, 31 design variables, design DrivenModal chính,
  tám top-level parts và hai Lumped Port 50 Ω.
- MISS_HIT 0.9.44: parse/lint toàn bộ file MATLAB mới, không lỗi.
- GNU Octave **9.4.0**: **23 nhóm kiểm tra portable đạt**, exit code 0.
  Chạy chính các hàm MATLAB của sản phẩm cho default regression, rigid transforms,
  coax positions, tìm nghiệm 49/50 mm, đọc AEDT chuẩn, sáu biến thể tham số,
  sinh script scratch/update/QuickTest/validate/save/reports/connect, bảo vệ file
  nguồn, từ chối tham số GUI cũ, JSON round trip và HPBW trên fixture toán học.
  Kiểm tra status/launcher/timeout dùng mock được ghi rõ, không phải HFSS thật.
- Đọc lại script theo UTF-16LE; kiểm tra BOM, dòng vật lý dưới giới hạn VBScript,
  dấu nháy và ngoặc. Đây là kiểm tra định dạng, không phải chạy VBScript/COM.
- Đối chiếu API với nguồn Ansys PyAEDT như ghi trong đặc tả. PyAEDT không phải
  dependency của ứng dụng, và đối chiếu nguồn không chứng minh runtime 2021 R2.
- Các file cũ trong repository được giữ nguyên; không thay file tham chiếu.

Kết quả portable máy đọc được: [verification/portable-results.json](verification/portable-results.json).
Octave chỉ dùng làm runner kiểm tra lõi và sinh lệnh, **không phải chương trình chính**.
Các công cụ kiểm tra được cài ngoài checkout; không cần cài chúng để chạy MATLAB GUI.

## Chưa thực hiện — không báo Passed

| Kiểm tra | Lý do / bước tiếp theo |
|---|---|
| Bộ unit tests MATLAB | Không có MATLAB trong cloud; chạy runtests trên host MATLAB |
| Khởi chạy GUI uifigure và preview polyshape | Octave không thay thế được MATLAB UI; chạy testBuilderGUI trên desktop |
| table/readtable/writetable và nhập CSV trên MATLAB | Chạy testBuilderCore trong MATLAB |
| Thực thi VBScript, COM và mọi CAD API 2021 R2 | Cloud là Linux, không cài HFSS và license |
| Boolean, topology, bbox, vật liệu, hai port và radiation | Các guard runtime đã viết; chưa có CAD thật từ builder để đánh giá |
| Hướng integration line và pha khớp dự án gốc | Cần so sánh hai mô hình trực tiếp trong HFSS, không suy ra từ ID cũ |
| Bảy build integration và ValidateDesign | Suite opt-in đang để unrun; cần Windows + HFSS |
| Rebuild không có file nguồn | Generator đã độc lập với file gốc; bài thử thực tế HFSS chưa chạy |
| S11/S22/isolation/gain/pattern/efficiency | Không có nghiệm solver; không tạo đồ thị RF giả |
| HFSS CreateReport/ExportToFile và quantities | Đã triển khai, cần nghiệm và kiểm tra phiên bản API |
| Hội tụ nghiệm và tương đương mô hình tham chiếu | Cần chạy Setup1 và đánh giá kết quả thực nghiệm |

## Tiêu chí nghiệm thu trên host

1. Chạy unit/GUI tests; giữ riêng các integration test bị skipped/incomplete.
2. Bật integration theo README: default và từng biến thể L_flare_1=45,
   aperture_w=22,cavity_w=1.6,cavity_L=5.5,thickness=2.2,slot_feed_w=0.6.
3. Với default, log cần có `VALIDATE_RETURN|1`, đủ inventory, connectivity,
   bbox chuẩn và hai `PORT_LINE|...|OUTER_TO_INNER`. Kiểm tra thủ công geometry,
   port seam, integration-line direction; bbox một mình không đủ chứng minh hình học.
4. Mở riêng file tham chiếu để đối chiếu, xác nhận không có cutter/vật liệu thừa;
   thử build khi file nguồn đóng và không có file nguồn trong đường dẫn runtime.
5. Chạy riêng Run Analysis, xác minh số điểm và convergence, rồi kiểm tra CSV,
   patterns và hiệu suất. Nếu report API lỗi, lưu log, không thay bằng dữ liệu mẫu.

Không dùng kết quả kiểm tra số học/generator để suy diễn CAD hoặc hiệu năng RF.
