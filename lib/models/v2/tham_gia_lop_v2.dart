// File: lib/models/v2/tham_gia_lop_v2.dart

import '../../utils/v2/db_value_parser.dart';

class ThamGiaLopV2 {
  final int? id;
  final int idHocSinh;
  final int idLop;
  final String tuNgay; // YYYY-MM-DD
  final String? denNgay; // YYYY-MM-DD
  final String? lyDoKetThuc;
  final int mienGiamPhanTram;
  final String? ghiChu;
  final DateTime createdAt;
  final DateTime updatedAt;

  ThamGiaLopV2({
    this.id,
    required this.idHocSinh,
    required this.idLop,
    required this.tuNgay,
    this.denNgay,
    this.lyDoKetThuc,
    this.mienGiamPhanTram = 0,
    this.ghiChu,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_hoc_sinh': idHocSinh,
      'id_lop': idLop,
      'tu_ngay': tuNgay,
      'den_ngay': denNgay,
      'ly_do_ket_thuc': lyDoKetThuc,
      'mien_giam_phan_tram': mienGiamPhanTram,
      'ghi_chu': ghiChu,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ThamGiaLopV2.fromMap(Map<String, dynamic> map) {
    return ThamGiaLopV2(
      id: DbValueParser.parseInt(map['id']),
      idHocSinh: DbValueParser.parseInt(map['id_hoc_sinh'])!,
      idLop: DbValueParser.parseInt(map['id_lop'])!,
      tuNgay: DbValueParser.parseString(map['tu_ngay'])!,
      denNgay: DbValueParser.parseString(map['den_ngay']),
      lyDoKetThuc: DbValueParser.parseString(map['ly_do_ket_thuc']),
      mienGiamPhanTram: DbValueParser.parseInt(map['mien_giam_phan_tram']) ?? 0,
      ghiChu: DbValueParser.parseString(map['ghi_chu']),
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
