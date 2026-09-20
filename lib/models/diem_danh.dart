// lib/models/diem_danh.dart

enum AttendanceStatus {
  present,
  late,
  excusedAbsent,
  unexcusedAbsent,
  makeup,
  holiday,
  cancelled,
  noRecord;

  String get dbValue {
    switch (this) {
      case AttendanceStatus.present:
        return 'Có mặt';
      case AttendanceStatus.late:
        return 'Trễ';
      case AttendanceStatus.excusedAbsent:
        return 'Nghỉ có phép';
      case AttendanceStatus.unexcusedAbsent:
        return 'Nghỉ không phép';
      case AttendanceStatus.makeup:
        return 'Học bù';
      case AttendanceStatus.holiday:
        return 'Nghỉ lễ';
      case AttendanceStatus.cancelled:
        return 'Hủy';
      case AttendanceStatus.noRecord:
        return 'Chưa điểm danh';
    }
  }

  String get canonicalKey {
    switch (this) {
      case AttendanceStatus.present:
        return 'CO_MAT';
      case AttendanceStatus.late:
        return 'TRE';
      case AttendanceStatus.excusedAbsent:
        return 'VANG_CO_PHEP';
      case AttendanceStatus.unexcusedAbsent:
        return 'VANG_KHONG_PHEP';
      case AttendanceStatus.makeup:
        return 'HOC_BU';
      case AttendanceStatus.holiday:
        return 'HOLIDAY';
      case AttendanceStatus.cancelled:
        return 'CANCELLED';
      case AttendanceStatus.noRecord:
        return 'NO_RECORD';
    }
  }

  static AttendanceStatus fromString(String? raw) {
    if (raw == null || raw.trim().isEmpty) return AttendanceStatus.noRecord;
    final s = raw.trim().toLowerCase();
    if (s == 'comat' || s == 'có mặt' || s == 'co_mat' || s == 'có mặt')
      return AttendanceStatus.present;
    if (s == 'tre' || s == 'trễ') return AttendanceStatus.late;
    if (s == 'nghicophep' ||
        s == 'vắng có phép' ||
        s == 'vang_co_phep' ||
        s == 'nghỉ có phép')
      return AttendanceStatus.excusedAbsent;
    if (s == 'nghikhongphep' ||
        s == 'vắng không phép' ||
        s == 'vang_khong_phep' ||
        s == 'nghỉ không phép')
      return AttendanceStatus.unexcusedAbsent;
    if (s == 'hocbu' || s == 'học bù' || s == 'hoc_bu')
      return AttendanceStatus.makeup;
    if (s == 'holiday' ||
        s == 'nghỉ lễ' ||
        s == 'nghỉ hè' ||
        s == 'nghỉ tết' ||
        s == 'no_class')
      return AttendanceStatus.holiday;
    if (s == 'cancelled' || s == 'hủy' || s == 'huy')
      return AttendanceStatus.cancelled;
    return AttendanceStatus.noRecord;
  }
}

class DiemDanh {
  int? id;
  final int idHocSinh;
  final int idLop; // <<< THÊM: ID của Lớp học
  final String gioDiemDanh; // Ví dụ: '2023-10-15 08:30:00'
  String
  trangThai; // 'Có mặt', 'Nghỉ có phép', 'Nghỉ không phép', 'Trễ', 'Học bù'
  String? ghiChu;
  String? ngayVangGoc; // '2023-10-05' - Ngày vắng gốc (cho trường hợp Học bù)

  DiemDanh({
    this.id,
    required this.idHocSinh,
    required this.idLop,
    required this.gioDiemDanh,
    required this.trangThai,
    this.ghiChu,
    this.ngayVangGoc,
  });

  DiemDanh copyWith({
    int? id,
    int? idHocSinh,
    int? idLop,
    String? gioDiemDanh,
    String? trangThai,
    String? ghiChu,
    String? ngayVangGoc,
  }) {
    return DiemDanh(
      id: id ?? this.id,
      idHocSinh: idHocSinh ?? this.idHocSinh,
      idLop: idLop ?? this.idLop,
      gioDiemDanh: gioDiemDanh ?? this.gioDiemDanh,
      trangThai: trangThai ?? this.trangThai,
      ghiChu: ghiChu ?? this.ghiChu,
      ngayVangGoc: ngayVangGoc ?? this.ngayVangGoc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_hoc_sinh': idHocSinh,
      'id_lop': idLop,
      'gio_diem_danh': gioDiemDanh,
      'trang_thai': trangThai,
      'ghi_chu': ghiChu,
      'ngay_vang_goc': ngayVangGoc,
    };
  }

  factory DiemDanh.fromMap(Map<String, dynamic> map) {
    return DiemDanh(
      id: map['id'],
      idHocSinh: map['id_hoc_sinh'],
      idLop: map['id_lop'],
      gioDiemDanh: map['gio_diem_danh'],
      trangThai: map['trang_thai'],
      ghiChu: map['ghi_chu'],
      ngayVangGoc: map['ngay_vang_goc'],
    );
  }
}
