# Đặc tả tái dựng Vivaldi dual-pol — 17/10/2026

Trạng thái: **dữ liệu nguồn đã đối chiếu; CAD và API HFSS 2021 R2 chưa chạy**.
Nguồn chuẩn: `reference/17_10_2026_vivaldi.aedt`, 669840 bytes,
SHA-256 `631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619`.
Đọc trực tiếp toàn bộ 3285 khối đóng/mở; chọn HFSSModel
`dual_pol_vivaldi_patch_Wflare_20`, DrivenModal, mm. HFSSDesign1 rỗng.
Các file MATLAB cũ và nguồn AEDT khác được giữ nguyên.

## Biến thiết kế xác nhận từ file

| Biến | Biểu thức gốc |
|---|---|
| `L_flare_1` | `40mm` |
| `slot_t_L` | `6.4mm+them` |
| `L_flare` | `L_flare_1+slot_t_L` |
| `aperture_w` | `20mm` |
| `slot_feed_w` | `0.5mm` |
| `r_flare` | `(1/L_flare)*ln(aperture_w/slot_feed_w)` |
| `deg_slot_t` | `21deg` |
| `z_feed` | `((slot_feed_w/2)*exp((slot_t_L)*r_flare) +slot_feed_w/2)*sin(deg_slot_t)+slot_t_L*(1-cos(deg_slot_t))` |
| `x_feed` | `((slot_feed_w/2)*exp((slot_t_L)*r_flare) +slot_feed_w/2)*cos(deg_slot_t)+slot_t_L*(sin(deg_slot_t))-(slot_feed_w/2)*exp((slot_t_L)*r_flare)` |
| `h3_slot_feed` | `1mm` |
| `h2` | `2.6mm` |
| `cavity_w` | `1.4mm` |
| `cavity_L` | `5mm` |
| `h_de` | `2mm` |
| `L_patch` | `L_flare_1+slot_t_L-z_feed+h3_slot_feed+slot_feed_w+h_de` |
| `r_cabin` | `0.15mm` |
| `h_cabin` | `h_de+slot_feed_w` |
| `positionx` | `0.15mm` |
| `r_cabmid` | `0.35mm` |
| `h_cabout` | `h_cabin-slot_feed_w` |
| `h_cabmid` | `h_cabin-slot_feed_w` |
| `r_cabout` | `0.5mm` |
| `de_L` | `aperture_w+thickness` |
| `de_W` | `aperture_w+thickness` |
| `lamda` | `60mm` |
| `h_box` | `lamda/2+L_patch` |
| `scan_phi` | `0deg` |
| `scan_theta` | `0deg` |
| `thickness` | `2mm` |
| `them` | `0mm` |
| `c2` | `0mm` |

Postprocessing variable `alpha=0deg` được giữ riêng. `scan_theta=scan_phi=0deg`,
`lamda=60mm`, `h_box=lamda/2+L_patch`; không dùng biến lamda thay padding Region.
Công thức MATLAB dùng sind/cosd; HFSS dùng biểu thức góc có đơn vị deg.
Mặc định L_flare=46.4, r_flare=0.0795017124, x_feed=2.499330861,
z_feed=0.663696710, L_patch=49.236303290 (mm, r_flare mm^-1).

## Hệ tọa độ

| CS | Parent | Origin local | Origin Global mặc định (mm) |
|---|---|---|---|
| slot_t_td | Global | ((slot_feed_w/2)*exp(slot_t_L*r_flare),0,slot_t_L) | (0.415828068,0,6.4) |
| slot_feed_td | Global | (-x_feed,0,z_feed) | (-2.499330861,0,0.663696710) |
| patch_td | Global | (aperture_w/2,0,L_flare) | (10,0,46.4) |
| RelativeCS1 | patch_td | (0,-thickness/2,0) | (10,-1,46.4) |

Trục X=(1,0,0), Y=(0,1,0) ở cả bốn CS. Tạo RelativeCS1 rồi gán lại
Reference CS qua thuộc tính để bảo đảm parent (API có khác biệt ở các phiên bản).
Quay Rz(-90) quanh C=(aperture_w/2,-thickness/2,L_flare) rồi dịch (0,thickness,0):
P2=C+Rz(-90)*(P1-C)+(0,thickness,0). Không quay quanh Global.

## Chuỗi phụ thuộc CAD

1. Global: EquationSurface1 và EquationSurface2 có x=_v*(slot_feed_w/2)*exp(_u*r_flare),
   y=0,z=_u; v=-1..1, u=0..L_flare hoặc 0..slot_t_L.
2. Copy EquationSurface2 thành EquationSurface2_1 trước xoay. Subtract khỏi
   EquationSurface1, KeepOriginals=true (source op 5914). Xóa cutter phụ khi không còn cần.
3. Rotate EquationSurface2 quanh Y của slot_t_td, deg_slot_t (op 5938).
4. slot_feed_td: rectangles normal Y, tọa độ local:
   R1 (X=0,Z=0,W=-h3_slot_feed,H=slot_feed_w);
   R2 (X=0,Z=-h3_slot_feed,W=-slot_feed_w,H=slot_feed_w+h2+cavity_w);
   R3 (X=slot_feed_w+h2,Z=-h3_slot_feed-slot_feed_w,W=cavity_L,H=cavity_w).
   W theo Z, H theo X. Dựng uncovered rectangle rồi CoverLines như lịch sử nguồn.
5. Unite EquationSurface1,EquationSurface2,R1,R2,R3; KeepOriginals=false (op 5918).
6. patch_td: Vivaldi_1 rectangle X=Y=Z=0,W=-L_patch,H=-aperture_w,normal Y;
   CoverLines; Subtract tool tổng hợp, KeepOriginals=false (op 5736);
   ThickenSheet thickness,BothSides=true (op 5758).
   Bbox tấm thứ nhất trước khoét: X=-10..10,Y=-1..1,Z=-2.836303290..46.4.
7. RelativeCS1: DuplicateAroundAxis Vivaldi_1,Z,-90deg,NumClones=2;
   Move clone (0,thickness,0), đặt tên Vivaldi_2.
   Bbox trước khoét: X=10..12,Y=1..21,Z=-2.836303290..46.4.
8. RelativeCS1 Box1 position(0,0,0),size(thickness,thickness,-L_patch).
9. Global De position((de_L+thickness)/2,-(de_W-aperture_w)/2,z_feed-h3_slot_feed-slot_feed_w),
   size(-de_L,de_W,-h_de).
10. Unite Vivaldi_1,Vivaldi_2,Box1,De; KeepOriginals=false (op 5846).
11. Tạo coax và hai circular sheets như dưới. Copy sáu cutter từ hai inner,
    hai mid và hai outer, Subtract khỏi thân, KeepOriginals=true (op 5858).
    Xóa cutter còn hoạt động, giữ các conductor gốc.

## Coax và port

slot_feed_td, axis Z, X=-positionx+slot_feed_w+h2,Y=0:
inner radius r_cabin,Z=-h3_slot_feed,height=-h_cabin;
outer radius r_cabout,Z=-h3_slot_feed-slot_feed_w,height=-h_cabout;
mid cùng vị trí outer,radius r_cabmid,height=-h_cabmid.
Subtract mid khỏi outer (giữ mid làm cutter). Không thêm dielectric.
port1: circle radius r_cabmid,Z=-h3_slot_feed-h_cabin; CoverLines.
Clone inner/outer/mid/port theo phép biến đổi phân cực ở trên.
Port1 center Global=(0.450669139,0,-2.836303290),
Port2 center=(11,10.549330861,-2.836303290).

Nguồn lưu integration line bằng EdgeCenter: port1 5719→5694,
port2 5900→5874, từ đường tròn bán kính r_cabmid về lõi r_cabin.
Các trường tọa độ 0 không phải endpoint Global. Không tái sử dụng các ID.
Implementation tìm midpoint tại tham số 0.5 trên cạnh tròn thật của port và cạnh
vòng đáy conductor; kiểm tra Z, bán kính và đồng phương trước khi gán tọa độ.
Cần HFSS để xác nhận seam/orientation/pha giống nguồn, không thể suy ra chắc chắn
chỉ từ text. Nếu không tìm được cặp cạnh hợp lệ phải dừng, không đoán hướng.
Hai Lumped Port 1 mode, 50ohm, renormalized. Nguồn mặc định 1:1W/0deg,2:0W/0deg.

## Vật liệu, solver và đối tượng cuối

Vivaldi_1 aluminum SolveInside=false; bốn conductor copper SolveInside=false.
port1/port2 và RadiatingSurface vacuum. Region absolute padding 20mm mọi hướng,
Radiation Open1. Chỉ một phần tử, NoArray, không tạo Optimetrics.
Setup1 HfssDriven,Single,5GHz,MaxDeltaS=.02,MinimumPasses=5,MaximumPasses=50,
MinimumConvergedPasses=3,PercentRefinement=10,BasisOrder=1,DoLambdaRefine=true,
DoMaterialLambda=true,PortAccuracy=2,UseIterativeSolver=false,SaveAnyFields=true.
Sweep LinearStep 5–20GHz/.25GHz,Discrete,SaveFields/SaveRadFields=true.
Farfield 3D Theta 0..180/2,Phi -180..180/2;
Elevation Theta -180..180/1,Phi 0..90/90;
Azimuth Theta 90..90/0,Phi -180..180/1 (dùng đúng định nghĩa lưu).
QuickTest tách riêng, không sửa Setup1 và không đại diện nghiệm chuẩn.

Inventory cuối: Vivaldi_1,cable_in,cable_out,cable_in_1,cable_out_1,
port1,port2,RadiatingSurface (6 solids,2 sheets); không cutter thừa.
Bbox thân tổng X=-10..12,Y=-1..21,Z=-2.836303290..46.4 mm.

## Chữ ký API và giới hạn chứng cứ

Đã đối chiếu nguồn chính thức Ansys PyAEDT **chỉ làm tài liệu**, không phải runtime:
- v0.6.94 pyaedt/modeler/cad/Primitives3D.py: CreateRectangle, CreateCircle,
  CreateCylinder; Modeler.py: ThickenSheet, DuplicateAroundAxis, CreateRelativeCS.
- v0.6.94 pyaedt/hfss.py: AssignLumpedPort modes/IntLine, Solutions.EditSources.
- main src/ansys/aedt/core/modeler/cad/primitives_3d.py: CreateEquationSurface
  với EquationBasedSurfaceParameters,XuvFunction/YuvFunction/ZuvFunction,uStart/uEnd,
  vStart/vEnd,Version=1. Tên gọi không phải CreateEquationBasedSurface.
Nguồn: https://github.com/ansys/pyaedt/tree/v0.6.94/pyaedt và
https://github.com/ansys/pyaedt/blob/main/src/ansys/aedt/core/modeler/cad/primitives_3d.py
Tài liệu ansyshelp phiên bản 212 bị proxy chặn; chưa có script recorder chạy trên 2021 R2.
Các đối chiếu này không phải chứng nhận tương thích runtime 2021 R2.

## Các điều kiện chưa thể xác nhận trong cloud Linux

MATLAB GUI, COM Windows, mọi lệnh CAD/Boolean, ký hiệu API theo đúng build 2021 R2,
port contact/integration-line orientation, manifold/connectivity, adaptive convergence,
S11/S22/S21/gain/pattern và HPBW đều cần chạy trên máy MATLAB + HFSS có license.
Không có .aedtresults đi kèm nguồn. Không coi IsSolved=true trong ProjectPreview là nghiệm.
Các bài test integration phải bỏ qua có lý do nếu không có host; không báo Passed giả.
