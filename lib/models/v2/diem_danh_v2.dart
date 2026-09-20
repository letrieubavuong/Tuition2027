// File: lib/models/v2/diem_danh_v2.dart

class DiemDanhV2 {
  final int? id;
  final int idBuoiHoc;
  final int idHocSinh;
  final int idLopGoc;
  final String trangThai; // CO_MAT, TRE, NGHI_CO_PHEP, NGHI_KHONG_PHEP, HOC_BU
  final String loaiThamGia; // CHINH, DOI_CA, HOC_BU
  final int? idBuoiVangGoc;
  final String? ghiChu;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiemDanhV2({
    this.id,
    required this.idBuoiHoc,
    required this.idHocSinh,
    required this.idLopGoc,
    required this.trangThai,
    required this.loaiThamGia,
    this.idBuoiVangGoc,
    this.ghiChu,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_buoi_hoc': idBuoiHoc,
      'id_hoc_sinh': idHocSinh,
      'id_lop_goc': idLopGoc,
      'trang_thai': trangThai,
      'loai_tham_gia': loaiThamGia,
      'id_buoi_vang_goc': idBuoiVangGoc,
      'ghi_chu': ghiChu,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DiemDanhV2.fromMap(Map<String, dynamic> map) {
    return DiemDanhV2(
      id: map['id'] as int?,
      idBuoiHoc: map['id_buoi_hoc'] as int,
      idHocSinh: map['id_hoc_sinh'] as int,
      idLopGoc: map['id_lop_goc'] as int,
      trangThai: map['trang_thai'] as String,
      loaiThamGia: map['loai_tham_gia'] as String,
      idBuoiVangGoc: map['id_buoi_vang_goc'] as int?,
      ghiChu: map['ghi_chu'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
