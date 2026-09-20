// File: lib/models/v2/diem_danh_v2.dart

import '../../utils/v2/db_value_parser.dart';

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
      id: DbValueParser.parseInt(map['id']),
      idBuoiHoc: DbValueParser.parseInt(map['id_buoi_hoc'])!,
      idHocSinh: DbValueParser.parseInt(map['id_hoc_sinh'])!,
      idLopGoc: DbValueParser.parseInt(map['id_lop_goc'])!,
      trangThai: DbValueParser.parseString(map['trang_thai']) ?? 'CHUA_DIEM_DANH',
      loaiThamGia: DbValueParser.parseString(map['loai_tham_gia']) ?? 'CHINH',
      idBuoiVangGoc: DbValueParser.parseInt(map['id_buoi_vang_goc']),
      ghiChu: DbValueParser.parseString(map['ghi_chu']),
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
