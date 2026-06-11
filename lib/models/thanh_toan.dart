// File: lib/models/thanh_toan.dart

class ThanhToan {
  int? id;
  final int idHocSinh;
  final int idLop; // Khóa ngoại tới Lop
  final String thang; // Định dạng YYYY-MM
  final int tongSoBuoi;
  final int soBuoiMienGiam50;
  final int soBuoiMienGiam100;
  final int tongThanhToan;
  final int soTienDaDong;
  final String? ngayThanhToan;
  final String? ghiChu;
  final int soBuoiDuocBuTru;
  final int soBuoiDuConLai;

  ThanhToan({
    this.id,
    required this.idHocSinh,
    required this.idLop,
    required this.thang,
    required this.tongSoBuoi,
    this.soBuoiMienGiam50 = 0,
    this.soBuoiMienGiam100 = 0,
    required this.tongThanhToan,
    this.soTienDaDong = 0,
    this.ngayThanhToan,
    this.ghiChu,
    this.soBuoiDuocBuTru = 0,
    this.soBuoiDuConLai = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_hoc_sinh': idHocSinh,
      'id_lop': idLop,
      'thang': thang,
      'tong_so_buoi': tongSoBuoi,
      'so_buoi_mien_giam_50': soBuoiMienGiam50,
      'so_buoi_mien_giam_100': soBuoiMienGiam100,
      'tong_thanh_toan': tongThanhToan,
      'so_tien_da_dong': soTienDaDong,
      'ngay_thanh_toan': ngayThanhToan,
      'ghi_chu_thanh_toan': ghiChu,
      'so_buoi_duoc_bu_tru': soBuoiDuocBuTru,
      'so_buoi_du_con_lai': soBuoiDuConLai,
    };
  }

  factory ThanhToan.fromMap(Map<String, dynamic> map) {
    return ThanhToan(
      id: map['id'] as int?,
      idHocSinh: map['id_hoc_sinh'] as int,
      idLop: map['id_lop'] as int,
      thang: map['thang'] as String,
      tongSoBuoi: map['tong_so_buoi'] as int,
      soBuoiMienGiam50: map['so_buoi_mien_giam_50'] as int? ?? 0,
      soBuoiMienGiam100: map['so_buoi_mien_giam_100'] as int? ?? 0,
      tongThanhToan: map['tong_thanh_toan'] as int,
      soTienDaDong: map['so_tien_da_dong'] as int? ?? 0,
      ngayThanhToan: map['ngay_thanh_toan'] as String?,
      ghiChu: map['ghi_chu_thanh_toan'] as String?,
      soBuoiDuocBuTru: map['so_buoi_duoc_bu_tru'] as int? ?? 0,
      soBuoiDuConLai: map['so_buoi_du_con_lai'] as int? ?? 0,
    );
  }
}
