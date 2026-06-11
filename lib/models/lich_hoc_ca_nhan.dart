// File: lib/models/lich_hoc_ca_nhan.dart

class LichHocCaNhan {
  final int idHocSinh;
  final int idLichHocChung;

  LichHocCaNhan({required this.idHocSinh, required this.idLichHocChung});

  Map<String, dynamic> toMap() {
    return {'id_hoc_sinh': idHocSinh, 'id_lich_hoc_chung': idLichHocChung};
  }

  factory LichHocCaNhan.fromMap(Map<String, dynamic> map) {
    return LichHocCaNhan(
      idHocSinh: map['id_hoc_sinh'] as int,
      idLichHocChung: map['id_lich_hoc_chung'] as int,
    );
  }

  @override
  String toString() {
    return 'LichHocCaNhan(idHocSinh: $idHocSinh, idLichHocChung: $idLichHocChung)';
  }
}
