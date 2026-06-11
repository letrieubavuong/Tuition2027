// File: lib/models/nhan_xet_thang.dart

class NhanXetThang {
  int? id;
  final int idHocSinh;
  final int idLop;
  final String thang; // Format 'YYYY-MM'
  double diemChuyenCan;
  double diemThaiDo;
  double diemBaiTap;
  double diemKiemTra;
  String? nhanXetChung;
  String? xepHang; // Đồng, Bạc, Vàng, Bạch Kim, Kim Cương

  NhanXetThang({
    this.id,
    required this.idHocSinh,
    required this.idLop,
    required this.thang,
    this.diemChuyenCan = 10.0,
    this.diemThaiDo = 10.0,
    this.diemBaiTap = 10.0,
    this.diemKiemTra = 10.0,
    this.nhanXetChung,
    this.xepHang,
  });

  double get diemTrungBinh =>
      (diemChuyenCan + diemThaiDo + diemBaiTap + diemKiemTra) / 4;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_hoc_sinh': idHocSinh,
      'id_lop': idLop,
      'thang': thang,
      'diem_chuyen_can': diemChuyenCan,
      'diem_thai_do': diemThaiDo,
      'diem_bai_tap': diemBaiTap,
      'diem_kiem_tra': diemKiemTra,
      'nhan_xet_chung': nhanXetChung,
      'xep_hang': xepHang,
    };
  }

  factory NhanXetThang.fromMap(Map<String, dynamic> map) {
    return NhanXetThang(
      id: map['id'] as int?,
      idHocSinh: map['id_hoc_sinh'] as int,
      idLop: map['id_lop'] as int,
      thang: map['thang'] as String,
      diemChuyenCan: (map['diem_chuyen_can'] as num).toDouble(),
      diemThaiDo: (map['diem_thai_do'] as num).toDouble(),
      diemBaiTap: (map['diem_bai_tap'] as num).toDouble(),
      diemKiemTra: (map['diem_kiem_tra'] as num).toDouble(),
      nhanXetChung: map['nhan_xet_chung'] as String?,
      xepHang: map['xep_hang'] as String?,
    );
  }

  NhanXetThang copyWith({int? id, String? xepHang}) {
    return NhanXetThang(
      id: id ?? this.id,
      idHocSinh: idHocSinh,
      idLop: idLop,
      thang: thang,
      diemChuyenCan: diemChuyenCan,
      diemThaiDo: diemThaiDo,
      diemBaiTap: diemBaiTap,
      diemKiemTra: diemKiemTra,
      nhanXetChung: nhanXetChung,
      xepHang: xepHang ?? this.xepHang,
    );
  }
}
