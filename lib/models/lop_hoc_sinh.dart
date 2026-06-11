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
    this.trangThai = 'Dang hoc', // Mặc định khớp với SQL
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_lop': idLop, // <-- ĐÃ SỬA
      'id_hoc_sinh': idHocSinh, // <-- ĐÃ SỬA
      'ngay_tham_gia': ngayThamGia, // <-- ĐÃ SỬA
      'trang_thai': trangThai, // <-- ĐÃ THÊM
    };
  }

  factory LopHocSinh.fromMap(Map<String, dynamic> map) {
    return LopHocSinh(
      id: map['id'] as int?,
      idLop: map['id_lop'] as int, // <-- ĐÃ SỬA
      idHocSinh: map['id_hoc_sinh'] as int, // <-- ĐÃ SỬA
      ngayThamGia: map['ngay_tham_gia'] as String, // <-- ĐÃ SỬA
      trangThai: map['trang_thai'] as String, // <-- ĐÃ THÊM
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
