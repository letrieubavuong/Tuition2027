// File: lib/models/v2/thanh_toan_v2.dart

class ThanhToanV2 {
  final int? id;
  final int idHocSinh;
  final int idLop;
  final String thang; // YYYY-MM
  final int soTien;
  final String ngayThanhToan; // YYYY-MM-DD
  final String phuongThuc; // TIEN_MAT, CHUYEN_KHOAN, KHAC
  final String? maGiaoDich;
  final String? ghiChu;
  final DateTime createdAt;

  ThanhToanV2({
    this.id,
    required this.idHocSinh,
    required this.idLop,
    required this.thang,
    required this.soTien,
    required this.ngayThanhToan,
    required this.phuongThuc,
    this.maGiaoDich,
    this.ghiChu,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_hoc_sinh': idHocSinh,
      'id_lop': idLop,
      'thang': thang,
      'so_tien': soTien,
      'ngay_thanh_toan': ngayThanhToan,
      'phuong_thuc': phuongThuc,
      'ma_giao_dich': maGiaoDich,
      'ghi_chu': ghiChu,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ThanhToanV2.fromMap(Map<String, dynamic> map) {
    return ThanhToanV2(
      id: map['id'] as int?,
      idHocSinh: map['id_hoc_sinh'] as int,
      idLop: map['id_lop'] as int,
      thang: map['thang'] as String,
      soTien: map['so_tien'] as int,
      ngayThanhToan: map['ngay_thanh_toan'] as String,
      phuongThuc: map['phuong_thuc'] as String,
      maGiaoDich: map['ma_giao_dich'] as String?,
      ghiChu: map['ghi_chu'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
