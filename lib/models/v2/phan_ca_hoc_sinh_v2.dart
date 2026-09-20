// File: lib/models/v2/phan_ca_hoc_sinh_v2.dart

import '../../utils/v2/db_value_parser.dart';

class PhanCaHocSinhV2 {
  final int? id;
  final int idHocSinh;
  final int idLop;
  final int idLichHoc;
  final String tuNgay; // YYYY-MM-DD
  final String? denNgay; // YYYY-MM-DD
  final String? nguon;
  final String? ghiChu;
  final DateTime createdAt;
  final DateTime updatedAt;

  PhanCaHocSinhV2({
    this.id,
    required this.idHocSinh,
    required this.idLop,
    required this.idLichHoc,
    required this.tuNgay,
    this.denNgay,
    this.nguon,
    this.ghiChu,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_hoc_sinh': idHocSinh,
      'id_lop': idLop,
      'id_lich_hoc': idLichHoc,
      'tu_ngay': tuNgay,
      'den_ngay': denNgay,
      'nguon': nguon,
      'ghi_chu': ghiChu,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PhanCaHocSinhV2.fromMap(Map<String, dynamic> map) {
    return PhanCaHocSinhV2(
      id: DbValueParser.parseInt(map['id']),
      idHocSinh: DbValueParser.parseInt(map['id_hoc_sinh'])!,
      idLop: DbValueParser.parseInt(map['id_lop'])!,
      idLichHoc: DbValueParser.parseInt(map['id_lich_hoc'])!,
      tuNgay: DbValueParser.parseString(map['tu_ngay'])!,
      denNgay: DbValueParser.parseString(map['den_ngay']),
      nguon: DbValueParser.parseString(map['nguon']),
      ghiChu: DbValueParser.parseString(map['ghi_chu']),
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
