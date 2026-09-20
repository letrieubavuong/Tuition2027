// File: lib/utils/attendance_calculator.dart

import 'package:intl/intl.dart';

class AttendanceCalculator {
  /// Kiểm tra trạng thái tạm ngưng từ chuỗi trạng thái (chuẩn hóa các biến thể legacy)
  static bool isStudentPaused(String? trangThai) {
    if (trangThai == null) return false;
    final stUpper = trangThai.toUpperCase().trim();
    return stUpper == 'TAM_NGUNG' ||
        stUpper == 'TAM_NGHI' ||
        stUpper == 'TẠM NGỪNG' ||
        stUpper == 'TẠM NGHỈ';
  }

  /// Công thức tính điểm chuyên cần thống nhất (10.0 - số buổi nghỉ không phép)
  static double tinhDiemChuyenCan({
    required int coMat,
    required int nghiCP,
    required int nghiKP,
  }) {
    final diem = 10.0 - nghiKP;
    return diem.clamp(0.0, 10.0);
  }

  /// Kiểm tra một ngày cụ thể có nằm trong mốc thời gian học sinh đang tham gia lớp hay không.
  /// Xử lý đầy đủ 5 mốc: ngay_tham_gia, ngay_tam_ngung, ngay_hoc_lai, ngay_nghi_hoc, ngay_hoc_lai_sau_nghi.
  static bool isDateInParticipationWindow({
    required DateTime date,
    DateTime? ngayThamGia,
    DateTime? ngayTamNgung,
    DateTime? ngayHocLai,
    DateTime? ngayNghiHoc,
    DateTime? ngayHocLaiSauNghi,
  }) {
    final dateOnly = DateTime(date.year, date.month, date.day);

    // 1. Nếu ngày kiểm tra trước ngày tham gia -> Không tính
    if (ngayThamGia != null) {
      final joinOnly = DateTime(
        ngayThamGia.year,
        ngayThamGia.month,
        ngayThamGia.day,
      );
      if (dateOnly.isBefore(joinOnly)) return false;
    }

    // 2. Kiểm tra mốc Nghỉ hẳn
    if (ngayNghiHoc != null) {
      final stopOnly = DateTime(
        ngayNghiHoc.year,
        ngayNghiHoc.month,
        ngayNghiHoc.day,
      );
      if (dateOnly.isAfter(stopOnly)) {
        // Trừ khi có mốc Học lại sau nghỉ và dateOnly >= mốc đó
        if (ngayHocLaiSauNghi != null) {
          final resumeAfterStop = DateTime(
            ngayHocLaiSauNghi.year,
            ngayHocLaiSauNghi.month,
            ngayHocLaiSauNghi.day,
          );
          if (dateOnly.isBefore(resumeAfterStop)) return false;
        } else {
          return false;
        }
      }
    }

    // 3. Kiểm tra mốc Tạm ngưng
    if (ngayTamNgung != null) {
      final pauseOnly = DateTime(
        ngayTamNgung.year,
        ngayTamNgung.month,
        ngayTamNgung.day,
      );
      if (!dateOnly.isBefore(pauseOnly)) {
        // Nếu dateOnly >= ngayTamNgung, phải kiểm tra xem đã học lại chưa
        if (ngayHocLai != null) {
          final resumeOnly = DateTime(
            ngayHocLai.year,
            ngayHocLai.month,
            ngayHocLai.day,
          );
          if (dateOnly.isBefore(resumeOnly)) return false;
        } else {
          return false;
        }
      }
    }

    return true;
  }

  /// Parse chuỗi ngày ISO / YYYY-MM-DD an toàn sang DateTime
  static DateTime? parseDateSafely(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    try {
      if (str.length >= 10) {
        return DateTime.parse(str.substring(0, 10));
      }
      return DateTime.parse(str);
    } catch (_) {
      return null;
    }
  }

  /// Format DateTime sang chuỗi YYYY-MM-DD
  static String formatDateToDb(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
