// File: lib/models/v2/buoi_hoc_v2.dart

import '../../utils/v2/db_value_parser.dart';

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
      id: DbValueParser.parseInt(map['id']),
      idLop: DbValueParser.parseInt(map['id_lop'])!,
      idLichHoc: DbValueParser.parseInt(map['id_lich_hoc']),
      ngay: DbValueParser.parseString(map['ngay'])!,
      gioBatDau: DbValueParser.parseString(map['gio_bat_dau'])!,
      gioKetThuc: DbValueParser.parseString(map['gio_ket_thuc'])!,
      loai: DbValueParser.parseString(map['loai']) ?? 'CHINH',
      trangThai: DbValueParser.parseString(map['trang_thai']) ?? 'DU_KIEN',
      ghiChu: DbValueParser.parseString(map['ghi_chu']),
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
