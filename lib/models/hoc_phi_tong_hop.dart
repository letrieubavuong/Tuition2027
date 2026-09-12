// File: lib/models/hoc_phi_tong_hop.dart

// Model chi tiết về một học sinh còn nợ học phí
class HocSinhNoHocPhi {
  final int idHocSinh;
  final String tenHocSinh;
  final int soTienCanNop;
  final int soTienDaDong;
  final int soTienConNo;
  final int mienGiam; // THÊM: Mức miễn giảm của học sinh
  final int soBuoiDu; // THÊM: Số buổi dư còn lại
  final int tongSoBuoi; // THÊM: Số buổi dự kiến trong tháng
  final String? sdt; // Số điện thoại

  HocSinhNoHocPhi({
    required this.idHocSinh,
    required this.tenHocSinh,
    required this.soTienCanNop,
    required this.soTienDaDong,
    required this.soTienConNo,
    required this.mienGiam,
    required this.soBuoiDu,
    this.tongSoBuoi = 12,
    this.sdt,
  });
}

// Model tổng hợp báo cáo học phí của một Lớp trong một Tháng
class HocPhiTongHop {
  final int tongSoBuoi;
  final int tongSoHocSinh;
  final int tongSoTienCanThu;
  final int tongSoTienDaThu;
  final int tongSoTienConNo;
  final List<HocSinhNoHocPhi> dsHocSinhConNo;

  HocPhiTongHop({
    required this.tongSoBuoi,
    required this.tongSoHocSinh,
    required this.tongSoTienCanThu,
    required this.tongSoTienDaThu,
    required this.tongSoTienConNo,
    required this.dsHocSinhConNo,
  });
}
