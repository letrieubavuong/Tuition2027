// File: lib/models/lop_hoc_sinh.dart (CẬP NHẬT THEO SQL)

class LopHocSinh {
  int? id;
  int idLop; // Tương ứng với cột 'id_lop'
  int idHocSinh; // Tương ứng với cột 'id_hoc_sinh'
  String ngayThamGia; // Tương ứng với cột 'ngay_tham_gia'
  String trangThai; // Tương ứng với cột 'trang_thai'

  LopHocSinh({
    this.id,
    required this.idLop,
    required this.idHocSinh,
    required this.ngayThamGia,
    this.trangThai = 'DANG_HOC',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_lop': idLop,
      'id_hoc_sinh': idHocSinh,
      'ngay_tham_gia': ngayThamGia,
      'trang_thai': trangThai,
    };
  }

  factory LopHocSinh.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    return LopHocSinh(
      id: parseInt(map['id']),
      idLop: parseInt(map['id_lop']) ?? 0,
      idHocSinh: parseInt(map['id_hoc_sinh']) ?? 0,
      ngayThamGia: map['ngay_tham_gia']?.toString() ?? '',
      trangThai: map['trang_thai']?.toString() ?? 'DANG_HOC',
    );
  }

  LopHocSinh copyWith({
    int? id,
    int? idLop,
    int? idHocSinh,
    String? ngayThamGia,
    String? trangThai,
  }) {
    return LopHocSinh(
      id: id ?? this.id,
      idLop: idLop ?? this.idLop,
      idHocSinh: idHocSinh ?? this.idHocSinh,
      ngayThamGia: ngayThamGia ?? this.ngayThamGia,
      trangThai: trangThai ?? this.trangThai,
    );
  }
}
