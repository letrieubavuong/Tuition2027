// File: lib/utils/student_status.dart

enum StudentStatus {
  dangHoc,
  tamNgung,
  nghiHoc;

  String toDbString() {
    switch (this) {
      case StudentStatus.dangHoc:
        return 'DANG_HOC';
      case StudentStatus.tamNgung:
        return 'TAM_NGUNG';
      case StudentStatus.nghiHoc:
        return 'NGHI_HOC';
    }
  }

  String get displayName {
    switch (this) {
      case StudentStatus.dangHoc:
        return 'Đang học';
      case StudentStatus.tamNgung:
        return 'Tạm ngưng';
      case StudentStatus.nghiHoc:
        return 'Nghỉ học';
    }
  }

  bool get isStudying => this == StudentStatus.dangHoc;
  bool get isPaused => this == StudentStatus.tamNgung;
  bool get isStopped => this == StudentStatus.nghiHoc;

  static StudentStatus parse(dynamic rawValue) {
    if (rawValue == null) return StudentStatus.dangHoc;
    final str = rawValue.toString().trim().toUpperCase();
    if (str == 'TAM_NGUNG' || str == 'TAM NGUNG' || str == 'PAUSED') {
      return StudentStatus.tamNgung;
    }
    if (str == 'NGHI_HOC' ||
        str == 'DA_NGHI' ||
        str == 'NGHI HOC' ||
        str == 'STOPPED') {
      return StudentStatus.nghiHoc;
    }
    return StudentStatus.dangHoc;
  }

  /// Đoạn điều kiện SQL chuẩn hóa để lọc học sinh đang hoạt động (không bị tạm ngưng hay nghỉ hẳn)
  static const String activeSqlCondition =
      "(LHS.trang_thai IS NULL OR UPPER(LHS.trang_thai) NOT IN ('NGHI_HOC', 'DA_NGHI', 'TAM_NGUNG'))";
}
