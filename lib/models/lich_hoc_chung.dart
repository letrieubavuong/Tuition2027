// File: lib/models/lich_hoc_chung.dart

class LichHocChung {
  final int? id;
  final int idLop;
  final String ngayTrongTuan; // 'Thứ Hai', 'Thứ Ba', etc.
  final String gioBatDau; // '18:00'
  final String gioKetThuc; // '20:00'
  final String effectiveFrom; // 'YYYY-MM-DD'
  final String? effectiveTo; // 'YYYY-MM-DD' or null

  LichHocChung({
    this.id,
    required this.idLop,
    required this.ngayTrongTuan,
    required this.gioBatDau,
    required this.gioKetThuc,
    this.effectiveFrom = '2000-01-01',
    this.effectiveTo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_lop': idLop,
      'ngay_trong_tuan': ngayTrongTuan,
      'gio_bat_dau': gioBatDau,
      'gio_ket_thuc': gioKetThuc,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
    };
  }

  factory LichHocChung.fromMap(Map<String, dynamic> map) {
    return LichHocChung(
      id: map['id'] as int?,
      idLop: map['id_lop'] as int,
      ngayTrongTuan: map['ngay_trong_tuan'] as String,
      gioBatDau: map['gio_bat_dau'] as String,
      gioKetThuc: map['gio_ket_thuc'] as String,
      effectiveFrom: (map['effective_from'] as String?) ?? '2000-01-01',
      effectiveTo: map['effective_to'] as String?,
    );
  }

  LichHocChung copyWith({
    int? id,
    int? idLop,
    String? ngayTrongTuan,
    String? gioBatDau,
    String? gioKetThuc,
    String? effectiveFrom,
    String? effectiveTo,
  }) {
    return LichHocChung(
      id: id ?? this.id,
      idLop: idLop ?? this.idLop,
      ngayTrongTuan: ngayTrongTuan ?? this.ngayTrongTuan,
      gioBatDau: gioBatDau ?? this.gioBatDau,
      gioKetThuc: gioKetThuc ?? this.gioKetThuc,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
    );
  }

  @override
  String toString() {
    return 'LichHocChung(id: $id, idLop: $idLop, ngayTrongTuan: $ngayTrongTuan, gioBatDau: $gioBatDau, gioKetThuc: $gioKetThuc, effectiveFrom: $effectiveFrom, effectiveTo: $effectiveTo)';
  }
}
