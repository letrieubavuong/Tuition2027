// File: lib/models/v2/phan_ca_hoc_sinh_v2.dart

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
      id: map['id'] as int?,
      idHocSinh: map['id_hoc_sinh'] as int,
      idLop: map['id_lop'] as int,
      idLichHoc: map['id_lich_hoc'] as int,
      tuNgay: map['tu_ngay'] as String,
      denNgay: map['den_ngay'] as String?,
      nguon: map['nguon'] as String?,
      ghiChu: map['ghi_chu'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
