// File: lib/models/nhiem_vu.dart

class NhiemVu {
  final int? id;
  final int idLop;
  final String tenNhiemVu;
  final String ngayGiao;
  final String ngayNop;
  final Map<int, String> trangThaiHocSinh; // THÊM: Map<idHocSinh, trangThai>

  NhiemVu({
    this.id,
    required this.idLop,
    required this.tenNhiemVu,
    required this.ngayGiao,
    required this.ngayNop,
    this.trangThaiHocSinh = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_lop': idLop,
      'ten_nhiem_vu': tenNhiemVu,
      'ngay_giao': ngayGiao,
      'ngay_nop': ngayNop,
    };
  }

  factory NhiemVu.fromMap(Map<String, dynamic> map) {
    return NhiemVu(
      id: map['id'] as int?,
      idLop: map['id_lop'] as int,
      tenNhiemVu: map['ten_nhiem_vu'] as String,
      ngayGiao: map['ngay_giao'] as String,
      ngayNop: map['ngay_nop'] as String,
      trangThaiHocSinh: const {}, // Sẽ được điền bởi service
    );
  }

  NhiemVu copyWith({
    int? id,
    int? idLop,
    String? tenNhiemVu,
    String? ngayGiao,
    String? ngayNop,
    Map<int, String>? trangThaiHocSinh,
  }) {
    return NhiemVu(
      id: id ?? this.id,
      idLop: idLop ?? this.idLop,
      tenNhiemVu: tenNhiemVu ?? this.tenNhiemVu,
      ngayGiao: ngayGiao ?? this.ngayGiao,
      ngayNop: ngayNop ?? this.ngayNop,
      trangThaiHocSinh: trangThaiHocSinh ?? this.trangThaiHocSinh,
    );
  }

  @override
  String toString() {
    return 'NhiemVu(id: $id, idLop: $idLop, tenNhiemVu: $tenNhiemVu, ngayGiao: $ngayGiao, ngayNop: $ngayNop, trangThaiHocSinh: $trangThaiHocSinh)';
  }
}
