# MODEL RECONSTRUCTION SPEC — Vivaldi Dual-Pol Builder Pro

Tài liệu được lập **trước khi triển khai builder**, bằng cách đọc trực tiếp cấu trúc văn bản và lịch sử CAD của tệp nguồn. Phạm vi: **một phần tử dual-pol**, hai tấm trực giao ghép chung đế; không tạo mảng.

## 1. Nguồn bằng chứng và trạng thái xác minh

Nguồn chuẩn: `17_10_2026_vivaldi.aedt`, 669840 byte, SHA-256 **`631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619`**. Đường dẫn trong workspace: `/workspace/Vivaldi_Array_10_16_2026/17_10_2026_vivaldi.aedt`. Các số dòng dưới đây tính từ tệp nguyên bản này, không phải bản báo cáo. Dòng 6: `Version(2021, 2)`; dòng 641–658: design `dual_pol_vivaldi_patch_Wflare_20`, `SolutionType='DrivenModal'`. Design `HFSSDesign1` trước đó gần như rỗng và không phải nguồn dựng hình.

Đã đối chiếu tài liệu `Phan_tich_chi_tiet_Vivaldi_dual_pol_17_10_2026.md`, SHA-256 `49c5cbc0bc445e9bad6df008d9487f987c5db99cee7aca567fed0b205ad6e912`, cùng `MODEL_ANALYSIS_Vivaldi.md`, `vivaldiDefaultParams.m`, `vivaldiCalculateGeometry.m`, `vivaldiHFSSBridge.m`, GUI hiện có. Các nguồn cũ chỉ có vai trò tham khảo. Những khác biệt quan trọng của bản 17/10 được ghi rõ bên dưới.

**Đã xác minh tĩnh:** biểu thức gốc, phụ thuộc giữa operation/operand, parent CS và hướng trục, top-level inventory, vật liệu, port/boundary, nguồn, solver và far field. **Chưa xác minh thực thi HFSS:** khả năng COM của máy Windows đích, tái sinh ACIS, SheetThicken/Boolean trên mọi biến thể, tiếp xúc port, vector integration line sau rebuild, mesh/convergence và kết quả điện từ. Metadata `IsSolved`/report trong tệp không phải dữ liệu nghiệm có thể xuất; bộ `.aedtresults` không được cung cấp cùng tệp.

Trong tài liệu này, “nguồn” nghĩa là giá trị đọc trực tiếp; “suy ra” nghĩa là tính toán từ giá trị đó; “quyết định builder” là cách parameter hóa/phát sinh API cần kiểm chứng trên HFSS 2021 R2. Không dùng ID lưu trong tệp làm ID của dự án mới.

## 2. Biến thiết kế và đơn vị

GeometryCore dùng `mm`, ACIS, `EntityCheckLevel='Strict'`, `IgnoreUnclassifiedObjects=false`, `SkipIntersectionChecks=false` (dòng 750–763). Phải tạo **31 design variables** và **1 postprocessing variable**, giữ biểu thức phụ thuộc thay vì thay bằng số đã tính.

| # | Biến | Biểu thức nguyên văn | Dòng nguồn |
|---:|---|---|---:|
| 1 | `L_flare_1` | `40mm` | 699 |
| 2 | `slot_t_L` | `6.4mm+them` | 700 |
| 3 | `L_flare` | `L_flare_1+slot_t_L` | 701 |
| 4 | `aperture_w` | `20mm` | 702 |
| 5 | `slot_feed_w` | `0.5mm` | 703 |
| 6 | `r_flare` | `(1/L_flare)*ln(aperture_w/slot_feed_w)` | 704 |
| 7 | `deg_slot_t` | `21deg` | 705 |
| 8 | `z_feed` | `((slot_feed_w/2)*exp((slot_t_L)*r_flare) +slot_feed_w/2)*sin(deg_slot_t)+slot_t_L*(1-cos(deg_slot_t))` | 706 |
| 9 | `x_feed` | `((slot_feed_w/2)*exp((slot_t_L)*r_flare) +slot_feed_w/2)*cos(deg_slot_t)+slot_t_L*(sin(deg_slot_t))-(slot_feed_w/2)*exp((slot_t_L)*r_flare)` | 707 |
| 10 | `h3_slot_feed` | `1mm` | 708 |
| 11 | `h2` | `2.6mm` | 709 |
| 12 | `cavity_w` | `1.4mm` | 710 |
| 13 | `cavity_L` | `5mm` | 711 |
| 14 | `h_de` | `2mm` | 712 |
| 15 | `L_patch` | `L_flare_1+slot_t_L-z_feed+h3_slot_feed+slot_feed_w+h_de` | 713 |
| 16 | `r_cabin` | `0.15mm` | 714 |
| 17 | `h_cabin` | `h_de+slot_feed_w` | 715 |
| 18 | `positionx` | `0.15mm` | 716 |
| 19 | `r_cabmid` | `0.35mm` | 717 |
| 20 | `h_cabout` | `h_cabin-slot_feed_w` | 718 |
| 21 | `h_cabmid` | `h_cabin-slot_feed_w` | 719 |
| 22 | `r_cabout` | `0.5mm` | 720 |
| 23 | `de_L` | `aperture_w+thickness` | 721 |
| 24 | `de_W` | `aperture_w+thickness` | 722 |
| 25 | `lamda` | `60mm` | 723 |
| 26 | `h_box` | `lamda/2+L_patch` | 724 |
| 27 | `scan_phi` | `0deg` | 725 |
| 28 | `scan_theta` | `0deg` | 726 |
| 29 | `thickness` | `2mm` | 727 |
| 30 | `them` | `0mm` | 728 |
| 31 | `c2` | `0mm` | 729 |
| post | `alpha` | `0deg` — `PostProcessingVariableProp`, không phải design variable | 732 |

`lamda=60mm`, `scan_theta=0deg`, `alpha=0deg` khác mô hình 23/9; không chép các giá trị 16.6667mm, 30deg, −237.6deg của tài liệu cũ. `h_box` không điều khiển region hiện tại; region có offset riêng 20mm. `h_cabmid` phải tồn tại dù cylinder `cable_mid` thực tế dùng chiều cao `-h_cabout` (hai biểu thức bằng nhau trong nguồn).

Các scalar regression bắt buộc (MATLAB dùng `sind`/`cosd`, đơn vị mm): `L_flare=46.4`, `r_flare≈0.0795017124 mm^-1`, `x_feed≈2.499330860779`, `z_feed≈0.663696709941`, `L_patch≈49.236303290059`, `h_cabin=2.5`, `h_cabout=h_cabmid=2`, `de_L=de_W=22`. Sai số so sánh scalar gợi ý `1e-8 mm` và `1e-10 mm^-1`.

## 3. Hệ tọa độ và biến đổi

Mọi CS tương đối ở chế độ `Axis/Position`, vector X=(1mm,0mm,0mm), vector Y=(0mm,1mm,0mm), Z theo quy tắc bàn tay phải. Các trục cùng hướng Global; CS tương đối không có góc xoay sẵn. Phải tạo CS cha trước con và set WorkingCS đúng tên trước các operation.

| CS | ID nguồn | Parent | Origin trong parent | Origin Global mặc định (mm) | Dòng |
|---|---:|---|---|---|---:|
| Global | 1 | — | (0,0,0) | (0,0,0) | — |
| `slot_t_td` | 6207 | Global | `((slot_feed_w/2)*exp(slot_t_L*r_flare),0,slot_t_L)` | (0.415828068,0,6.4) | 782–808 |
| `slot_feed_td` | 6211 | Global | `(-x_feed,0mm,z_feed)` | (−2.499330861,0,0.663696710) | 809–835 |
| `patch_td` | 6215 | Global | `(aperture_w/2,0mm,L_flare)` | (10,0,46.4) | 836–862 |
| `RelativeCS1` | 6219 | `patch_td` | `(0mm,-thickness/2,0mm)` | (10,−1,46.4) | 863–889 |

`ReferenceCoordSystemID=6215` trên RelativeCS1 xác nhận đây là con của `patch_td`, không phải Global. Dấu của `slot_feed_td.OriginX` là **âm**.

Đặt `a=aperture_w/2`, `t=thickness`, `O=(a,-t/2,L_flare)`. Phép dựng phân cực thứ hai `T` là quay **−90deg quanh Z tại O**, sau đó Move `(0,t,0)` trong `RelativeCS1`. Với điểm Global `(x,y,z)`:

```text
T(x,y,z) = (a+y+t/2, a-x+t/2, z)
Rz(-90deg) = [0 1 0; -1 0 0; 0 0 1]
```

Áp dụng cùng `T` cho tấm, lõi, trụ ngoài chưa khoét, cutter giữa và port. Không quay quanh Global origin, không cộng origin `patch_td` hai lần.

**Khác biệt nguồn cần công khai:** Move `cable_mid_1` dòng 4532 lưu literal `2mm`, trong khi tất cả clone còn lại dùng `thickness`. Builder mới dùng `thickness` cho cutter giữa thứ hai để đáp ứng yêu cầu thay đổi độ dày 2→2.2mm và giữ đồng trục; đây là parameter hóa sửa một literal không liên kết, mặc định trùng chính xác nguồn. Chế độ Update Existing phải nhận diện literal này và báo nguy cơ lệch cutter nếu chỉ sửa biến thickness; không được tuyên bố mọi lịch sử cũ đã parameter hóa đúng.

## 4. Thứ tự CAD theo đồ thị phụ thuộc

Nguồn nhóm operation theo từng part; thứ tự ID không phải thứ tự thực thi tuyến tính. Bảng dưới đây là thứ tự có thể dựng từ đầu. ID chỉ dùng đối chiếu bằng chứng. Các `DuplicateAlongLine` lưu ở CloneToOperation, hướng Y=`aperture_w +thickness`, không tương ứng anten top-level đang hoạt động và **không được replay** cho single element.

### 4.1 Vùng khoét flare, transition, feed và cavity

1. Trong Global tạo `EquationSurface1`, `EquationBasedSurface` op5903, part5904 (dòng 3511–3551):

   ```text
   XuvFunction = _v*((slot_feed_w/2)*exp((_u)*r_flare))
   YuvFunction = 0
   ZuvFunction = _u
   uStart=0; uEnd=L_flare; vStart=-1; vEnd=1; Version=1
   ```

2. Trong Global tạo `EquationSurface2`, op5926, part5927, cùng phương trình nhưng `uEnd=slot_t_L` (3751–3791).
3. Copy **trước khi Rotate** EquationSurface2 thành `EquationSurface2_1`, CloneTo5937→CloneFrom5939, part5940 (3792–3802, 3862–3905). Bản sao không xoay là cutter cắt phần đầu của loe dài.
4. Subtract `EquationSurface1` blank với `EquationSurface2_1` tool, **KeepOriginals=true trong nguồn**, op5914 (3552–3622). Khi phát lệnh HFSS tên hàm là `Subtract`; chuỗi `OperationType='Substract'` là cách tệp nội bộ viết. **Quyết định builder:** dùng `KeepOriginals=false` trên riêng bản sao sacrificial `EquationSurface2_1` để HFSS giữ nó làm operand của Boolean và không để cutter top-level dư; `EquationSurface2` nguyên bản vẫn tồn tại để Rotate/Unite. Đây là khác biệt có chủ đích về lifetime của tool, không thay phần hình học bị trừ; ghi rõ trong log và kiểm tra runtime. Không được dùng EquationSurface2 nguyên bản thay bản sao rồi consume nó.
5. Set WCS=`slot_t_td`, Rotate **chỉ EquationSurface2** quanh Y, angle=`deg_slot_t`, op5938 (3803–3839). Đoạn ngắn quay quanh vị trí `(0.415828068,0,6.4)`, không quanh gốc toàn cục. Mép đầu quay suy ra `(−x_feed,0,z_feed)`, khớp origin feed.
6. Trong `slot_feed_td`, tạo ba **rectangle wire** có normal Y rồi `CoverLines` để tạo sheet. Khi dùng API `CreateRectangle`, dùng `IsCovered=false` trước `CoverLines`, hoặc `IsCovered=true` và không lặp CoverLines trên sheet đã covered. Phải kiểm tra wire→sheet thật; không bắt lỗi CoverLines rồi coi như đã thành công. Quy ước của rectangle Y ở nguồn: **Width theo Z, Height theo X**.

| Đối tượng | XStart | YStart | ZStart | Width (Z) | Height (X) | Op tạo/CoverLines; part | Dòng |
|---|---|---|---|---|---|---|---:|
| Rectangle1 | `0mm` | `0mm` | `0mm` | `-h3_slot_feed` | `slot_feed_w` | 5950/5960;5951 | 3928–4025 |
| Rectangle2 | `0mm` | `0mm` | `-h3_slot_feed` | `-slot_feed_w` | `slot_feed_w+h2+cavity_w` | 5962/5972;5963 | 4048–4145 |
| Rectangle3 | `slot_feed_w+h2` | `0mm` | `-(h3_slot_feed+slot_feed_w)` | `cavity_L` | `cavity_w` | 5974/5984;5975 | 4168–4265 |

7. Unite blank EquationSurface1 sau cắt với **EquationSurface2 sau Rotate + Rectangle1 + Rectangle2 + Rectangle3**, **KeepOriginals=false**, op5918 (3623–3728). Tool parts nguồn:5927,5951,5963,5975. Kết quả giữ tên `EquationSurface1`. Phải có flare dài, transition nghiêng, feed và cavity cùng một vùng khoét; lỗi không tiếp xúc/tự giao phải dừng tại bước này.
8. `EquationSurface2_1` giữ riêng ở bước4 là đồ dùng tạm; loại khỏi model hoạt động sau khi boolean không còn cần giữ đối tượng top-level. Không để một sheet trống vật liệu tồn tại trong mô hình EM.

### 4.2 Tấm thứ nhất và thân nhôm

9. Trong `patch_td`, CreateRectangle `Vivaldi_1`: X/Y/ZStart=`0mm`, Width=`-L_patch`, Height=`-aperture_w`, WhichAxis=`Y`, op5724 part5725 (1440–1478); CoverLines op5734 (1479–1537). Bounding box sheet mặc định trước khoét: X=−10..10, Y=0, Z=−2.836303290..46.4mm.
10. Subtract `EquationSurface1` tổng hợp khỏi `Vivaldi_1`, **KeepOriginals=false**, op5736 (1538–1748). ToolOperations(5918) xác nhận phải dùng vùng đã Unite, không chỉ equation surface ban đầu.
11. `ThickenSheet`/SheetThicken `Vivaldi_1`, Thickness=`thickness`, **BothSides=true**, op5758 (1749–2644). Theo bounding-box nguồn/yêu cầu, độ dày tổng mặc định 2mm, Y≈−1..1mm. Kiểm tra API HFSS thật trả bbox này; không dùng extrusion một phía.
12. Set WCS=`RelativeCS1`, `DuplicateAroundAxis(Vivaldi_1, Z, -90deg, NumClones=2, CreateNewObjects=true)`, source op5845 (2645–2659), clone op5997 part5998 (4376–4419), đổi tên clone thành `Vivaldi_2`. Chỉ một bản mới vì NumClones gồm bản gốc.
13. Move **chỉ Vivaldi_2** `(0mm,thickness,0mm)` trong RelativeCS1, op6085 (4420–4457). Bbox suy ra trước khoét: X=10..12, Y=1..21, Z như tấm1.
14. Trong RelativeCS1 tạo Box1, op6097 part6098 (4595–4633): Position=(0mm,0mm,0mm), Size=(thickness,thickness,−L_patch). Bbox mặc định X=10..12,Y=−1..1,Z=−2.836303290..46.4.
15. Trong Global tạo De, op6125 part6126 (4656–4694):

   ```text
   XPosition=(de_L+thickness)/2
   YPosition=-(de_W-aperture_w)/2
   ZPosition=z_feed-h3_slot_feed-slot_feed_w
   XSize=-de_L; YSize=de_W; ZSize=-h_de
   ```

   Đế 22×22×2mm, bbox X=−10..12,Y=−1..21,Z=−2.836303290..−0.836303290.
16. Unite `Vivaldi_1,Vivaldi_2,Box1,De`, **KeepOriginals=false**, op5846 (2660–2857); blank part5725, tool parts5998,6098,6126. Sau đó chỉ còn thân nhôm top-level `Vivaldi_1`, gồm cả hai phân cực. Source topology sau Unite ghi một lump; kiểm tra thật multiple body/non-manifold/contact, không che giấu lỗi.

### 4.3 Hai coax và hai port

Mọi cylinder tròn thật dùng `WhichAxis='Z'`, `NumSides='0'`. Khởi tạo các cylinder trong `slot_feed_td`. Thứ tự phải giữ được bản sao **trước hollowing** để final cutter là trụ đầy, không phải ống rỗng.

| Primitive | XCenter | YCenter | ZCenter | Radius | Height | Op;part | Dòng |
|---|---|---|---|---|---|---|---:|
| cable_in | `-positionx+slot_feed_w+h2` | `0mm` | `-h3_slot_feed` | `r_cabin` | `-h_cabin` | 5689;5690 | 990–1029 |
| cable_out (trước khoét) | `-positionx+h2+slot_feed_w` | `0mm` | `-h3_slot_feed-slot_feed_w` | `r_cabout` | `-h_cabout` | 5700;5701 | 1094–1133 |
| cable_mid (cutter) | `-positionx+h2+slot_feed_w` | `0mm` | `-h3_slot_feed-slot_feed_w` | `r_cabmid` | **`-h_cabout`** | 5986;5987 | 4288–4327 |
| port1 Circle | `-positionx+slot_feed_w+h2` | `0mm` | `-h3_slot_feed-h_cabin` | `r_cabmid` | sheet | 5717;5718 | 1292–1330 |

17. Tạo `cable_in`, `cable_out` đầy, `cable_mid`, `port1` wire→CoverLines op5721 (1331–1386, NumSegments=0). Vật liệu active cores/outers copper; ports vacuum.
18. Dùng DuplicateAroundAxis **trước khi khoét outer** trong RelativeCS1, Z=−90deg, NumClones=2; Move clone +thickness Y để tạo `cable_in_1`, `cable_out_1`, `cable_mid_1`, `port2`. Source placeholder ops5689→5698,5700→5709,5717/5721→5723,5986→5995; clone/move: cable_in_1 op5869/5878 (3033–3114), cable_out_1 op5880/5889 (3164–3245), port2 op5897/5902 (3389–3470), cable_mid_1 op6086/6095 (4480–4561). Literal 2mm của mid clone được parameter hóa như mục3.
19. Lưu copy nguyên trạng đầy của cả hai `cable_out` và `cable_mid` cho final cutters. Subtract cable_mid khỏi cable_out **KeepOriginals=false**, source op5711 (1160–1253), và cable_mid_1 khỏi cable_out_1 **KeepOriginals=false**, source op5891 (3257–3350). Tạo hai ống đồng rỗng, bán kính trong .35, ngoài .5mm; không tạo thêm PTFE/FR4/dielectric solid. Không khoét inner conductor hoặc port khỏi các sheet nguồn.

Đặt `c=-x_feed-positionx+slot_feed_w+h2`, `zb=z_feed-h3_slot_feed-h_cabin`. Tâm port1=`C1=(c,0,zb)`≈(0.450669139221,0,−2.836303290059). Tâm port2=`C2=T(C1)`≈(11,10.549330860779,−2.836303290059). Cả hai trục coax theo Z, inner Z=−2.836303290..−0.336303290, outer Z=−2.836303290..−0.836303290. Lower plane trùng đáy đế và port; lõi vươn .5mm cao hơn outer để đi vào cavity/feed.

### 4.4 Boolean cuối: sáu cutter bắt buộc

20. Tạo/giữ sáu **bản sao sacrificial**, tên có mapping xác định. Bản gốc active không được làm tool dùng một lần:

| Cutter nguồn | Part ID | CloneFrom op | SourceID | Placeholder | Hình học lấy tại thời điểm clone |
|---|---:|---:|---:|---:|---|
| cable_in_2 | 6154 | 6153 | 5690 | 5699 | Lõi1 đầy |
| cable_in_1_1 | 6163 | 6162 | 5870 | 5879 | Lõi2 sau Move |
| cable_mid_2 | 6172 | 6171 | 5987 | 5996 | Cutter giữa1 trước bị consume |
| cable_mid_1_1 | 6181 | 6180 | 6087 | 6096 | Cutter giữa2 sau Move, trước bị consume |
| cable_out_2 | 6190 | 6189 | 5701 | **5710** | Trụ ngoài1 **đầy, trước Subtract5711** |
| cable_out_1_1 | 6199 | 6198 | 5881 | **5890** | Trụ ngoài2 **đầy, trước Subtract5891** |

   Bằng chứng clone ở dòng 4697–5092; thứ tự placeholder CloneTo trước outer subtraction được lưu tại1149–1172 và3246–3269. Copy **ống đã khoét** vào cutter ngoài là sai lịch sử. Mặc dù cutter giữa/inner có vùng thể tích lồng nhau, không được tự giản lược sáu tool thành hai cylinder.
21. Subtract sáu bản sao khỏi thân `Vivaldi_1` đã Unite, source op**5858** (2858–2994): `KeepOriginals=true`, BlankPart5725, `NumToolParts=6`, ToolParts(6154,6163,6172,6181,6190,6199). Giữ bốn conductor active và hai port nguyên vẹn. Topology lưu sau bước này là **1 lump,1 shell,33 faces,89 edges,60 vertices** (2872–2882); số topology chỉ là dấu vết nguồn, không phải tiêu chí duy nhất khi HFSS/kernel tạo edge mới.
22. Cleanup chỉ những **cutter copy tạm** được giữ bởi KeepOriginals; xác minh chúng không còn là model top-level trước giải. Nguồn đặt cả sáu trong `OperandParts`, không trong `ToplevelParts`. Một triển khai dùng KeepOriginals=true phải kiểm tra việc Delete các copy giữ lại vẫn bảo toàn operand history và kết quả trừ; không xóa active cable_in/out. Nếu API không thể cleanup an toàn phải báo lỗi, không lặng lẽ để sáu model solid không vật liệu. **Quyết định builder:** dùng `KeepOriginals=false` trên sáu sacrificial copies để chúng được consume vào Boolean; cả bốn conductor active và hai port vẫn được giữ riêng. Cách này có cùng phép trừ hình học nhưng khác cờ lifetime của nguồn; phải công khai trong log/tài liệu, không nhận là replay cờ chính xác. Không thay sáu tool bằng bốn conductor active và không copy outer đã rỗng.

## 5. Danh sách hình học cuối và vật liệu

Nguồn xác nhận **8 top-level parts** (902–3488), **17 operands** (3491–5092). Không yêu cầu `Vivaldi_2`, Box1 hoặc De tồn tại top-level sau Unite.

| Top-level cuối | Body ID nguồn | Dạng | Material | SolveInside | Dòng attributes |
|---|---:|---|---|---|---:|
| RadiatingSurface | 3471 | Region solid | vacuum | true | 903–920 |
| cable_in | 5690 | Cylinder solid | copper | false | 971–988 |
| cable_out | 5701 | Hollow cylinder solid | copper | false | 1075–1092 |
| port1 | 5718 | Circle sheet | vacuum | true | 1273–1290 |
| Vivaldi_1 | 5725 | United dual-pol body | aluminum | false | 1421–1438 |
| cable_in_1 | 5870 | Cylinder solid | copper | false | 3014–3031 |
| cable_out_1 | 5881 | Hollow cylinder solid | copper | false | 3145–3162 |
| port2 | 5898 | Circle sheet | vacuum | true | 3370–3387 |

17 operands: EquationSurface1,EquationSurface2,EquationSurface2_1,Rectangle1,Rectangle2,Rectangle3,cable_mid,Vivaldi_2,cable_mid_1,Box1,De,cable_in_2,cable_in_1_1,cable_mid_2,cable_mid_1_1,cable_out_2,cable_out_1_1. Đây là đồ thị lịch sử, không phải danh sách model solids bổ sung.

Material definitions tại94–169: vacuum εr=1; aluminum μr=1.000021, σ=38000000 S/m; copper μr=.999991, σ=58000000 S/m. Dùng material library tương ứng hoặc thêm định nghĩa EM rõ ràng nếu thiếu; không tự đổi sang perfect conductor. Các thuộc tính `ShellElement=false`, shell thickness0mm, surface material rỗng; metal SolveInside=false.

Bbox danh nghĩa toàn thân: X=−10..12,Y=−1..21,Z=−2.836303290..46.4mm. Cần kiểm tra từng phần/void, coax rỗng, tiếp xúc và hai tấm trực giao; bbox tổng một mình không chứng minh đúng CAD.

## 6. Hai Lumped Port và integration line

BoundarySetup dòng5625–5730: port tên **`1`** ID18 Objects(5718), port **`2`** ID19 Objects(5898), BoundType=`Lumped Port`, một Mode1; ModeNum1,UseIntLine=true,AlignmentGroup0,CharImp=`Zpi`,RenormImp=`50ohm`; Impedance=`50ohm`,DoDeembed=false,RenormalizeAllTerminals=true,ShowReporterFilter=false,ReporterFilter(true). Boundary tên1/2 khác tên sheet port1/port2.

Điểm tích phân lưu bằng **attachment đến cạnh**, PositionType=`EdgeCenter`, không phải các số XYZ=0 trong trường fallback:

| Port | Start (outer) | End (inner) | Bằng chứng ownership |
|---|---|---|---|
| 1 | Entity5719: biên circle port1 bán kính r_cabmid | Entity5694: cạnh tròn cable_in bán kính r_cabin | Circle StartEdgeID5719 (1321), cylinder StartEdgeID5694 (1021); IntLine5648–5673 |
| 2 | Entity5900: biên port2 | Entity5874: cạnh cable_in_1 | CloneEdges5719→5900 (3422),5694→5874 (3065); IntLine5695–5720 |

**Đã xác nhận:** hướng từ outer/port perimeter vào lõi; không phải inner→outer. **Suy ra hình học để rebuild không dùng ID:** tại mặt phẳng `zb`, chọn start trên circle r_cabmid và end trên circle r_cabin cùng bán kính vector. Nguồn Circle có seam +X tại(0.800669139221,0,zb), dòng1373. Metadata midpoint của cạnh tròn inner face outer conductor nằm ở −X, `(0.100669139221,≈0,zb)`, dòng1220, và midpoint các cạnh circular khác cũng ở phía đối diện seam. Điều này hỗ trợ quy ước EdgeCenter **−X cho port1**, quay thành **+Y cho port2**; azimuth chính xác của attachment chưa được ACIS evaluation trực tiếp chứng minh.

Builder dùng tọa độ biểu thức Global sau để tái dựng đường radial outer→inner theo suy luận midpoint này, rồi kiểm tra chúng chạm đúng biên/rim conductor và có vector không zero:

```text
Port1 Start = (c-r_cabmid, 0mm, zb)
Port1 End   = (c-r_cabin,  0mm, zb)       vector +X
Port2 Start = (a+thickness/2, a-c+thickness/2+r_cabmid, zb)
Port2 End   = (a+thickness/2, a-c+thickness/2+r_cabin,  zb)   vector -Y
```

Mặc định P1 `(0.100669139221,0,−2.836303290059)`→`(0.300669139221,0,−2.836303290059)`; P2 `(11,10.899330860779,−2.836303290059)`→`(11,10.699330860779,−2.836303290059)`. Chiều dài line .2mm. Đây là suy luận có ghi nguồn, **không gắn nhãn đã kiểm chứng hướng phase nguyên bản**. HFSS integration test phải query geometry/mode assignment, kiểm tra vector sau rebuild, quan sát E-field port khi có nghiệm; chỉ hai tên port/impedance chưa đủ. Khi cần so pha với project gốc, phải query endpoint gốc trực tiếp trên HFSS rồi đối chiếu, không suy luận từ ID hoặc fallback XYZ.

## 7. Region và Radiation Boundary

`RadiatingSurface` Region op6470, ReferenceCoordSystemID=**1 (Global)**, ParentPartID3471, dòng922–943. Mỗi +X,−X,+Y,−Y,+Z,−Z có PaddingType=`Absolute Offset`, Padding=`20mm`. **Không dùng RelativeCS1 theo báo cáo mô hình cũ.** Tạo region sau cleanup để kích thước bao đúng hình học hoạt động. Bbox suy ra mặc định: X=−30..32,Y=−21..41,Z=−22.836303290..66.4mm.

Boundary `Open1` ID22, BoundType=`Radiation`, Objects(3471),IsComponent=false,ParentBndID=−1,UseAdaptiveIE=false,IsFssReference=false,IsForPML=false (5625–5635). API AssignRadiation phải gắn region object thực; không Unite region vào kim loại. Vật liệu môi trường vacuum,UseTotalFieldFormulation=false (5614–5623).

## 8. Adaptive Setup, Sweep, Mesh và Far Field

`Setup1` **Single**, HfssDriven, DrivenModal; không phải Broadband của mô hình tháng9. Dữ liệu đầy đủ dòng5796–5833:

```text
SolveType=Single; Frequency=5GHz; MaxDeltaS=.02; UseMatrixConv=false
MaximumPasses=50; MinimumPasses=5; MinimumConvergedPasses=3
PercentRefinement=10; IsEnabled=true; MeshLink.ImportMesh=false
BasisOrder=1; DoLambdaRefine=true; DoMaterialLambda=true
SetLambdaTarget=false; Target=.3333; UseMaxTetIncrease=false
PortAccuracy=2; UseABCOnPort=false; SetPortMinMaxTri=false
PortMinTri=100; PortMaxTri=500; UseDomains=false; UseIterativeSolver=false
EnhancedLowFreqAccuracy=false; SaveRadFieldsOnly=false; SaveAnyFields=true
IESolverType=Auto; LambdaTargetForIESolver=.15
UseDefaultLambdaTgtForIESolver=true; IE Solver Accuracy=Balanced
InfiniteSphereSetup=-1
```

Các field nội bộ không chắc được InsertSetup nhận phải được map sang schema Automation HFSS 2021 R2 được hỗ trợ, không giả sử mọi tên serialization là tham số COM. Khi cần fallback schema, phải ghi rõ và runtime verify bằng readback/saved project.

Sweep tên **`Sweep`** thuộc Setup1 (5834–5848): IsEnabled=true,RangeType=`LinearStep`,RangeStart=`5GHz`,RangeEnd=`20GHz`,RangeStep=`0.25GHz`,Type=`Discrete`,SaveFields=true,SaveRadFields=true; tổng61 điểm. GUI có thể chọn 6–18GHz nhưng Original mặc định vẫn5–20GHz. Quick Test dùng **setup riêng**, không ghi đè Setup1; kết quả không thay thế hồ sơ Original.

MeshSettings dòng5764–5788: CurvedSurfaceApproxChoice=`UseSlider`,SliderMeshSettings=5,GlobalCurvilinear.Apply=false,GlobalModelRes.UseAutoLength=true,MeshMethod=`Auto`,UseLegacyFaceterForTauVolumeMesh=false,DynamicSurfaceResolution=false,UseFlexMeshingForTAUvolumeMesh=false,UseAlternativeMeshMethodsAsFallBack=true,AllowPhiForLayeredGeometry=true. Không có MeshOperations riêng. Không tự nhập mesh cũ.

Far field dòng6113–6161, cả ba Type=`Infinite Sphere`,CSDefinition=`Theta-Phi`,Polarization=`Linear`,UseCustomRadiationSurface=false,UseLocalCS=false (Global):

| Tên | Theta start/stop/step | Phi start/stop/step |
|---|---|---|
| `3D` | `0deg / 180deg / 2deg` | `-180deg / 180deg / 2deg` |
| `Elevation` | `-180deg / 180deg / 1deg` | `0deg / 90deg / 90deg` |
| `Azimuth` | `90deg / 90deg / 0deg` | `-180deg / 180deg / 1deg` |

Azimuth nguồn lưu ThetaStep0 cho fixed theta. Nếu HFSS Automation không nhận zero step, chỉ dùng giá trị step dương với start=stop qua fallback được ghi log (sampling vẫn đúng một theta) và kiểm tra readback; không tự đổi range. ArraySetup `UseOption='NoArray'` tại6163; không replay cấu hình array/scan lưu kế đó. Sáu OptimetricsSetup dòng5850–6034 là lịch sử nghiên cứu; không tự chạy hoặc dựng tất cả khi xây một phần tử.

## 9. Nguồn kích thích và kết quả

Solutions dòng6036–6046: `FieldType='NoIncidentWave'`, **IncludePortPostProcessing=false**,UseSpecifiedIncidentPower=false. SourceEntry ID18 (boundary1) = Magnitude1W,Phase0deg; ID19(boundary2)=0W,0deg; Index0,Terminal=false,Terminated=false. Khi dùng EditSources API, tên mode là `1:1`,`2:1`; map theo boundary đang có, không hardcode ID18/19. GUI chỉ chọn một port hoạt động mỗi lần theo mặc định: Port1 1W/Port2 0W hoặc Port1 0W/Port2 1W, đều0deg. Không tự kích đồng thời.

Postprocessing chỉ xuất báo cáo khi HFSS có nghiệm thực và context phù hợp: S11,S22,S21,S12, VSWR từ |Sii| hợp lệ, realized gain, elevation/azimuth/3D pattern, efficiency khi quantity có trong solver. HPBW chỉ tính từ pattern thật có cực đại và hai giao điểm −3dB quanh main lobe; không dựng đường cong mẫu. Source settings ảnh hưởng realized gain/pattern, không dùng để suy luận single-port S-parameter thiếu dữ liệu. CSV phải chứa tần số, đơn vị, nguồn, setup/sweep/context và tham số để biết kết quả thuộc hình học nào.

## 10. Giao kèo kiểm chứng và chế độ cập nhật

Build From Scratch phải gọi NewProject+InsertDesign HFSS DrivenModal, tạo biến/CS/primitives/Boolean/setup như trên. Không OpenProject/SaveAs/copy CAD từ nguồn để gọi là build. Đóng/mất tệp nguồn không được làm build default hỏng; source dùng cho provenance và kiểm tra tĩnh, không là runtime template.

Update Existing mở project do người dùng chọn, chọn đúng design, **SaveAs đích mới trước mutation**, xác minh biến/công thức thiết kế rồi đổi literal độc lập; không ghi đè source. Đặc biệt kiểm tra `cable_mid_1` Move literal2mm khi đổi thickness. Nếu không có supported history-property override đã kiểm chứng, cảnh báo/dừng thay đổi thickness trong Update thay vì làm lệch coax; Build mới dùng parameterization nhất quán. Không tuyên bố đã rebuild/validate chỉ vì ChangeProperty thành công.

Kiểm chứng offline cần scalar/default/CS/transform/bbox, validation dữ liệu, sáu tool có cả hai full outer cylinders và đúng thứ tự snapshot, đúng build/update separation, setup/sweep/far-field/source command plans. Các biến thể tối thiểu theo yêu cầu: L_flare_1=45,aperture_w=22,cavity_w=1.6,cavity_L=5.5,thickness=2.2,slot_feed_w=.6mm, thử riêng từng thay đổi và cấu hình phối hợp có báo lỗi rõ. Kiểm chứng kế hoạch/số học không được báo là CAD passed.

Integration trên **MATLAB Windows + HFSS2021 R2 có license**: build default không mở nguồn, theo dõi từng operation, query ObjectGroups/Solids/Sheets và bbox, kiểm tra không có Unclassified, exactly8 active names có mapping, hollow outers bằng volume/face geometry, không có cutter dư, hai tấm vuông góc + vùng transition/feed/cavity, model/material/SolveInside, đủ2 port50ohm cùng radial line đúng hướng, Open1+region, Setup1/Sweep/3far fields+NoArray, SaveAs `.aedt`, `ValidateDesign` thật và kiểm tra messages/return code theo API. Lặp cùng các biến thể. Analyze chỉ khi người dùng yêu cầu; kiểm tra dữ liệu nghiệm có thật trước export.

Nếu máy hiện tại thiếu MATLAB/HFSS/COM/license, báo riêng **chưa chạy** integration/solver và cung cấp runner tái lập; không tạo evidence giả, không gắn Passed cho solver, không xem static inspection là tương đương HFSS Validate.
