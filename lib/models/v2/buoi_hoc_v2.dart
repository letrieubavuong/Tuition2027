// File: lib/models/v2/buoi_hoc_v2.dart

class BuoiHocV2 {
  final int? id;
  final int idLop;
  final int? idLichHoc;
  final String ngay; // YYYY-MM-DD
  final String gioBatDau; // HH:mm
  final String gioKetThuc; // HH:mm
  final String loai; // CHINH, HOC_BU, PHAT_SINH
  final String trangThai; // DU_KIEN, DA_HOC, HUY, NGHI_LE
  final String? ghiChu;
  final DateTime createdAt;
  final DateTime updatedAt;

  BuoiHocV2({
    this.id,
    required this.idLop,
    this.idLichHoc,
    required this.ngay,
    required this.gioBatDau,
    required this.gioKetThuc,
    required this.loai,
    required this.trangThai,
    this.ghiChu,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_lop': idLop,
      'id_lich_hoc': idLichHoc,
      'ngay': ngay,
      'gio_bat_dau': gioBatDau,
      'gio_ket_thuc': gioKetThuc,
      'loai': loai,
      'trang_thai': trangThai,
      'ghi_chu': ghiChu,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory BuoiHocV2.fromMap(Map<String, dynamic> map) {
    return BuoiHocV2(
      id: map['id'] as int?,
      idLop: map['id_lop'] as int,
      idLichHoc: map['id_lich_hoc'] as int?,
      ngay: map['ngay'] as String,
      gioBatDau: map['gio_bat_dau'] as String,
      gioKetThuc: map['gio_ket_thuc'] as String,
      loai: map['loai'] as String,
      trangThai: map['trang_thai'] as String,
      ghiChu: map['ghi_chu'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
