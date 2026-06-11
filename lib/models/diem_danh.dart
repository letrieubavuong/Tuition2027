// lib/models/diem_danh.dart
class DiemDanh {
  int? id;
  final int idHocSinh;
  final int idLop; // <<< THÊM: ID của Lớp học
  final String gioDiemDanh; // Ví dụ: '2023-10-15 08:30:00'
  String trangThai; // 'coMat', 'nghiCoPhep', 'nghiKhongPhep'
  String? ghiChu;

  DiemDanh({
    this.id,
    required this.idHocSinh,
    required this.idLop, // <<< YÊU CẦU BẮT BUỘC
    required this.gioDiemDanh,
    required this.trangThai,
    this.ghiChu,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_hoc_sinh': idHocSinh,
      'id_lop': idLop, // <<< CẬP NHẬT
      'gio_diem_danh': gioDiemDanh,
      'trang_thai': trangThai,
      'ghi_chu': ghiChu,
    };
  }

  factory DiemDanh.fromMap(Map<String, dynamic> map) {
    return DiemDanh(
      id: map['id'],
      idHocSinh: map['id_hoc_sinh'],
      idLop: map['id_lop'], // <<< CẬP NHẬT
      gioDiemDanh: map['gio_diem_danh'],
      trangThai: map['trang_thai'],
      ghiChu: map['ghi_chu'],
    );
  }
}
