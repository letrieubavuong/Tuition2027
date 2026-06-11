// File: lib/models/danh_gia_buoi_hoc.dart

class DanhGiaBuoiHoc {
  int? id;
  final int idDiemDanh;
  double? diemThaiDo;
  double? diemHieuBai;
  double? diemBaiTap;
  String? nhanXet;

  DanhGiaBuoiHoc({
    this.id,
    required this.idDiemDanh,
    this.diemThaiDo,
    this.diemHieuBai,
    this.diemBaiTap,
    this.nhanXet,
  });

  // Chuyển đổi đối tượng sang Map để lưu vào DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_diem_danh': idDiemDanh,
      'diem_thai_do': diemThaiDo,
      'diem_hieu_bai': diemHieuBai,
      'diem_bai_tap': diemBaiTap,
      'nhan_xet': nhanXet,
    };
  }

  // Tạo đối tượng từ Map đọc từ DB
  factory DanhGiaBuoiHoc.fromMap(Map<String, dynamic> map) {
    return DanhGiaBuoiHoc(
      id: map['id'] as int?,
      idDiemDanh: map['id_diem_danh'] as int,
      diemThaiDo: map['diem_thai_do'] as double?,
      diemHieuBai: map['diem_hieu_bai'] as double?,
      diemBaiTap: map['diem_bai_tap'] as double?,
      nhanXet: map['nhan_xet'] as String?,
    );
  }

  // Hàm copyWith tiện lợi
  DanhGiaBuoiHoc copyWith({
    int? id,
    int? idDiemDanh,
    double? diemThaiDo,
    double? diemHieuBai,
    double? diemBaiTap,
    String? nhanXet,
  }) {
    return DanhGiaBuoiHoc(
      id: id ?? this.id,
      idDiemDanh: idDiemDanh ?? this.idDiemDanh,
      diemThaiDo: diemThaiDo ?? this.diemThaiDo,
      diemHieuBai: diemHieuBai ?? this.diemHieuBai,
      diemBaiTap: diemBaiTap ?? this.diemBaiTap,
      nhanXet: nhanXet ?? this.nhanXet,
    );
  }
}
