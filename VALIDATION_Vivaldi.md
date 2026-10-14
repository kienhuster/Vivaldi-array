# Kiểm tra bàn giao

## Đã thực hiện trên môi trường Linux

- Parser MATLAB độc lập MISS_HIT Core 0.9.44, chế độ MATLAB 2020b, UTF-8, kiểm tra cú pháp 14 file MATLAB mới (12 module và 2 file test): không báo lỗi/cảnh báo cú pháp. Kiểm tra này **không** xác minh chữ ký GUI/API runtime.
- Phân tích đầy đủ các khối `$begin`/`$end` trong AEDT: cân bằng; 31 design variables, 8 top-level parts, 17 operands, hai Lumped Port và Radiation đã đối chiếu với nội dung nguồn.
- Đối chiếu số học độc lập dùng đúng công thức nguồn và phép lượng giác theo độ. Đây không phải kết quả chạy code bằng MATLAB.

| Trường hợp | Kết quả đối chiếu |
|---|---|
| L_flare_1=40 | L_flare=46.4; r_flare=0.07950171237314518; L_patch=49.23630329005893 mm |
| L_flare_1=45 | L_flare=51.4; r_flare=0.07176808276486257; L_patch=54.24349948436724 mm |
| Target=49 | L_flare_1≈39.76408469594185; residual≈−7.1×10⁻¹⁵ mm |
| Target=50 | L_flare_1≈40.762475911592205; residual≈−7.1×10⁻¹⁵ mm |

- Kiểm tra cấu trúc mã: SaveAs trước ChangeProperty; kiểm tra danh tính bản sao trước mutation; guard lỗi API thoát script thay vì tiếp tục; lệnh AnalyzeAll chỉ ở nhánh simulate; EditSources/DuplicateAlongLine không có trong script mới; cấu hình/CSV không eval nội dung nhập.
- `git diff` xác nhận hai file có sẵn không thay đổi. Hash SHA-256 trước bàn giao:

```text
Phased_Array_GUI_Linker.m:
78cbe266dec5e4575ac88353b3ec3eb2cd8f714e6ee714e9834f53cac0253352
Vivaldi_23_9_2026.aedt:
62670001ed4ced60d9a29255a885bc470c1ed4d53909cf1261bc40fd49450634
```

## Chưa chạy vì thiếu MATLAB/Ansys

- Bộ test trong `tests/testVivaldiElementDesigner.m`: đã viết, **chưa thực thi**, gồm default/45mm/49&50mm, miền không có nghiệm, invalid/NaN/Inf/complex, config roundtrip/schema, source inventory, script protection, unchanged variables, output conflict, formula mismatch, status failure/intermediate connection, CSV, dimensions và logger.
- `tests/testVivaldiGUI.m`: đã viết, **chưa thực thi**. Mở GUI offline và thay 40→45 mm để kiểm tra bảng/preview refresh; cần MATLAB desktop. Assumption skip không phải pass.
- Chưa chạy sinh VBScript bằng MATLAB, parse VBScript bằng Windows scripting engine, COM/APIs 2021 R2, license handling thật, SaveAs thật, ValidateDesign hoặc AnalyzeAll. Test status giả lập chỉ kiểm tra xử lý lỗi, không phải lỗi solver thật.
- Chưa kiểm chứng độ phản hồi GUI/timer khi solver chạy dài hoặc API không trả lời; bridge được thiết kế dùng tiến trình ngoài.
- Chưa xác minh port face/integration line sau thay đổi CAD, manifold/intersection, convergence/sweep completeness hoặc hiệu năng RF.
- Chưa xác nhận chiều dài CAD bằng HFSS hay đường bao chế tạo. Không xuất DXF chính xác; PNG/PDF là preview có chú thích.
- Nạp S/gain/pattern CSV có triển khai, chưa chạy bằng MATLAB với report HFSS thật. Mapping không tự gán kết quả cho thiết kế GUI.

## Nghiệm thu cần chạy trên máy đích

1. Chạy hai file test theo README, ghi rõ passed/failed/skipped và phiên bản MATLAB.
2. Mở GUI offline; đồng bộ slider/ô số, restore, save/load, invalid input, target 49/50, xuất CSV/PNG/PDF.
3. Với Windows/AEDT 2021 R2 được cấp phép, Connect và đối chiếu phiên bản thực COM.
4. Dùng một bản nguồn sạch, ghi hash trước; Update Geometry tạo tên mới; kiểm tra hash nguồn sau không đổi. Xác minh inventory và kích thước CAD bản sao.
5. Kiểm tra hai integration line, port/contact, vật liệu và Radiation/solution setup bằng HFSS, đọc validation report.
6. Chạy mô phỏng có xác nhận; kiểm tra timestamps, convergence, sweep completeness, S11/S22 thực; không coi PID/API return riêng lẻ là thành công.
7. Gây lỗi có kiểm soát trên bản sao hoặc API/license không sẵn có để kiểm tra FAILED/log và file nguồn; không thử phá file gốc.
8. Xuất report CSV thật một sweep/cut, kiểm tra số liệu vẽ khớp HFSS; chuyển bản sao phần tử đã chấp nhận sang công cụ mảng riêng.
