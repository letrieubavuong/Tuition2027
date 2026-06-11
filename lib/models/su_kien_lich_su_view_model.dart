// File: lib/models/su_kien_lich_su_view_model.dart

import 'su_kien_hoc_tap.dart';

class SuKienLichSuViewModel {
  final String tenLop;
  final DateTime ngayHoc;
  final String moTa;
  final double diemThayDoi;
  final LoaiSuKien loaiSuKien;

  SuKienLichSuViewModel({
    required this.tenLop,
    required this.ngayHoc,
    required this.moTa,
    required this.diemThayDoi,
    required this.loaiSuKien,
  });

  factory SuKienLichSuViewModel.fromMap(Map<String, dynamic> map) {
    return SuKienLichSuViewModel(
      tenLop: map['tenLop'] as String,
      ngayHoc: DateTime.parse(map['ngayHoc'] as String),
      moTa: map['mo_ta'] as String,
      diemThayDoi: (map['diem_thay_doi'] as num).toDouble(),
      loaiSuKien: LoaiSuKien.values.firstWhere(
        (e) => e.toString().split('.').last == map['loai_su_kien'],
        orElse: () => LoaiSuKien.khac,
      ),
    );
  }
}
