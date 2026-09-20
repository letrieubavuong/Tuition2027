// File: lib/models/v2/thanh_toan_v2.dart

import '../../utils/v2/db_value_parser.dart';

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
      id: DbValueParser.parseInt(map['id']),
      idHocSinh: DbValueParser.parseInt(map['id_hoc_sinh'])!,
      idLop: DbValueParser.parseInt(map['id_lop'])!,
      thang: DbValueParser.parseString(map['thang'])!,
      soTien: DbValueParser.parseInt(map['so_tien']) ?? 0,
      ngayThanhToan: DbValueParser.parseString(map['ngay_thanh_toan'])!,
      phuongThuc: DbValueParser.parseString(map['phuong_thuc']) ?? 'KHAC',
      maGiaoDich: DbValueParser.parseString(map['ma_giao_dich']),
      ghiChu: DbValueParser.parseString(map['ghi_chu']),
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
