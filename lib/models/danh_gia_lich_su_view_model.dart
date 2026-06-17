// File: lib/models/danh_gia_lich_su_view_model.dart

import '../utils/number_parser.dart';

class DanhGiaLichSuViewModel {
  final String tenLop;
  final DateTime ngayHoc;
  final double? diemThaiDo;
  final double? diemHieuBai;
  final double? diemBaiTap;
  final String? nhanXet;

  DanhGiaLichSuViewModel({
    required this.tenLop,
    required this.ngayHoc,
    this.diemThaiDo,
    this.diemHieuBai,
    this.diemBaiTap,
    this.nhanXet,
  });

  factory DanhGiaLichSuViewModel.fromMap(Map<String, dynamic> map) {
    return DanhGiaLichSuViewModel(
      tenLop: map['tenLop'] as String,
      ngayHoc: DateTime.parse(map['ngayHoc'] as String),
      diemThaiDo: parseDoubleOrNullSafely(map['diem_thai_do']),
      diemHieuBai: parseDoubleOrNullSafely(map['diem_hieu_bai']),
      diemBaiTap: parseDoubleOrNullSafely(map['diem_bai_tap']),
      nhanXet: map['nhan_xet'] as String?,
    );
  }

  double get diemTrungBinh =>
      ((diemThaiDo ?? 0) + (diemHieuBai ?? 0) + (diemBaiTap ?? 0)) / 3;
}
