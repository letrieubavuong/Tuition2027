// File: lib/models/v2/buoi_du_ledger_v2.dart

import '../../utils/v2/db_value_parser.dart';

class BuoiDuLedgerV2 {
  final int? id;
  final int idHocSinh;
  final int idLop;
  final int? idBuoiHoc;
  final String ngayHieuLuc; // YYYY-MM-DD
  final int delta;
  final String lyDo; // VUOT_SO_BUOI_CHUAN, BU_TRU_NGHI_CO_PHEP, etc.
  final String? ghiChu;
  final DateTime createdAt;

  BuoiDuLedgerV2({
    this.id,
    required this.idHocSinh,
    required this.idLop,
    this.idBuoiHoc,
    required this.ngayHieuLuc,
    required this.delta,
    required this.lyDo,
    this.ghiChu,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_hoc_sinh': idHocSinh,
      'id_lop': idLop,
      'id_buoi_hoc': idBuoiHoc,
      'ngay_hieu_luc': ngayHieuLuc,
      'delta': delta,
      'ly_do': lyDo,
      'ghi_chu': ghiChu,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory BuoiDuLedgerV2.fromMap(Map<String, dynamic> map) {
    return BuoiDuLedgerV2(
      id: DbValueParser.parseInt(map['id']),
      idHocSinh: DbValueParser.parseInt(map['id_hoc_sinh'])!,
      idLop: DbValueParser.parseInt(map['id_lop'])!,
      idBuoiHoc: DbValueParser.parseInt(map['id_buoi_hoc']),
      ngayHieuLuc: DbValueParser.parseString(map['ngay_hieu_luc'])!,
      delta: DbValueParser.parseInt(map['delta']) ?? 0,
      lyDo: DbValueParser.parseString(map['ly_do']) ?? 'UNKNOWN',
      ghiChu: DbValueParser.parseString(map['ghi_chu']),
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
