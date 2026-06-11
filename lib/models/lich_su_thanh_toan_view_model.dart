// File: lib/models/lich_su_thanh_toan_view_model.dart

class LichSuThanhToanViewModel {
  final String tenLop;
  final String thang;
  final int soTienDaDong;
  final String? ngayThanhToan;
  final String? ghiChu;

  LichSuThanhToanViewModel({
    required this.tenLop,
    required this.thang,
    required this.soTienDaDong,
    this.ngayThanhToan,
    this.ghiChu,
  });
}
