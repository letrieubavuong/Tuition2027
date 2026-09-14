// File: lib/models/su_kien_hoc_tap.dart

import '../utils/number_parser.dart';

enum LoaiSuKien { tichCuc, tieuCuc, thaiDo, hieuBai, baiTap, khac }

class SuKienHocTap {
  int? id;
  final int idDiemDanh;
  final LoaiSuKien loaiSuKien;
  final String moTa;
  final double diemThayDoi;

  SuKienHocTap({
    this.id,
    required this.idDiemDanh,
    required this.loaiSuKien,
    required this.moTa,
    required this.diemThayDoi,
  });

  SuKienHocTap copyWith({
    int? id,
    int? idDiemDanh,
    LoaiSuKien? loaiSuKien,
    String? moTa,
    double? diemThayDoi,
  }) {
    return SuKienHocTap(
      id: id ?? this.id,
      idDiemDanh: idDiemDanh ?? this.idDiemDanh,
      loaiSuKien: loaiSuKien ?? this.loaiSuKien,
      moTa: moTa ?? this.moTa,
      diemThayDoi: diemThayDoi ?? this.diemThayDoi,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_diem_danh': idDiemDanh,
      'loai_su_kien': loaiSuKien.toString().split('.').last,
      'mo_ta': moTa,
      'diem_thay_doi': diemThayDoi,
    };
  }

  factory SuKienHocTap.fromMap(Map<String, dynamic> map) {
    return SuKienHocTap(
      id: map['id'] as int?,
      idDiemDanh: map['id_diem_danh'] as int,
      loaiSuKien: LoaiSuKien.values.firstWhere(
        (e) => e.toString().split('.').last == map['loai_su_kien'],
        orElse: () => LoaiSuKien.khac,
      ),
      moTa: map['mo_ta'] as String,
      diemThayDoi: parseDoubleSafely(map['diem_thay_doi']),
    );
  }
}
