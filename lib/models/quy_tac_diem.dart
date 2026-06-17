import '../utils/number_parser.dart';

class QuyTacDiem {
  int? id;
  String loaiQuyTac; // 'CONG_DIEM' hoặc 'TRU_DIEM'
  String hangMuc; // 'THAI_DO', 'HIEU_BAI', 'BAI_TAP'
  String moTa;
  double diemThayDoi;
  int thuTuHienThi;

  QuyTacDiem({
    this.id,
    required this.loaiQuyTac,
    this.hangMuc = 'THAI_DO',
    required this.moTa,
    required this.diemThayDoi,
    this.thuTuHienThi = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'loai_quy_tac': loaiQuyTac,
      'hang_muc': hangMuc,
      'mo_ta': moTa,
      'diem_thay_doi': diemThayDoi,
      'thu_tu_hien_thi': thuTuHienThi,
    };
  }

  factory QuyTacDiem.fromMap(Map<String, dynamic> map) {
    return QuyTacDiem(
      id: map['id'] as int?,
      loaiQuyTac: map['loai_quy_tac'] as String,
      hangMuc: map['hang_muc'] as String? ?? 'THAI_DO',
      moTa: map['mo_ta'] as String,
      // Đọc an toàn kiểu số thực kể cả khi lưu chuỗi "9,5" hay "9.5"
      diemThayDoi: parseDoubleSafely(map['diem_thay_doi']),
      thuTuHienThi: map['thu_tu_hien_thi'] as int? ?? 0,
    );
  }

  QuyTacDiem copyWith({
    int? id,
    String? loaiQuyTac,
    String? hangMuc,
    String? moTa,
    double? diemThayDoi,
    int? thuTuHienThi,
  }) {
    return QuyTacDiem(
      id: id ?? this.id,
      loaiQuyTac: loaiQuyTac ?? this.loaiQuyTac,
      hangMuc: hangMuc ?? this.hangMuc,
      moTa: moTa ?? this.moTa,
      diemThayDoi: diemThayDoi ?? this.diemThayDoi,
      thuTuHienThi: thuTuHienThi ?? this.thuTuHienThi,
    );
  }
}
