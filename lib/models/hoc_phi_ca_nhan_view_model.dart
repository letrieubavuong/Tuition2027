// File: lib/models/hoc_phi_ca_nhan_view_model.dart

import 'lich_su_thanh_toan_view_model.dart';

class HocPhiCaNhanViewModel {
  final int idHocSinh;
  final String tenHocSinh;
  final String thang;
  final int tongSoBuoiDuKien;
  final int soBuoiCoMat;
  final int soBuoiNghiCoPhep;
  final int soBuoiNghiKhongPhep;
  final int hocPhiBuoi;
  final int hocPhiThangToiDa;
  final int mienGiam; // % miễn giảm
  final int tongTienPhaiDong; // Tổng tiền cần nộp sau mọi tính toán
  final int soTienDaDong;
  final int soTienConNo;
  final List<LichSuThanhToanViewModel> dsLichSuThanhToan;

  HocPhiCaNhanViewModel({
    required this.idHocSinh,
    required this.tenHocSinh,
    required this.thang,
    required this.tongSoBuoiDuKien,
    required this.soBuoiCoMat,
    required this.soBuoiNghiCoPhep,
    required this.soBuoiNghiKhongPhep,
    required this.hocPhiBuoi,
    required this.hocPhiThangToiDa,
    required this.mienGiam,
    required this.tongTienPhaiDong,
    required this.soTienDaDong,
    required this.soTienConNo,
    required this.dsLichSuThanhToan,
  });
}
