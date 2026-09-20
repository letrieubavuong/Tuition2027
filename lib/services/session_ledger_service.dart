// File: lib/services/session_ledger_service.dart

import 'dart:developer' as developer;
import '../utils/db.dart';
import '../models/diem_danh.dart';
import '../models/lich_hoc_chung.dart';
import '../models/lop_hoc_sinh.dart';

/// Item trong Session Ledger của 1 buổi học (Session-Based)
class SessionLedgerItem {
  final String date; // 'YYYY-MM-DD'
  final String dayOfWeek; // 'Thứ Hai', 'Thứ Ba', ...
  final String? startTime; // '18:00', ... (Session identity)
  final int? scheduleId; // ID lịch học chung nếu có
  final bool
  isScheduledEligible; // Thuộc lịch hợp lệ & HS đang active trong lớp
  final String
  attendanceStatus; // 'CO_MAT', 'TRE', 'VANG_CO_PHEP', 'VANG_KHONG_PHEP', 'HOC_BU', 'CANCELLED', 'NO_RECORD'
  final String? ngayVangGoc; // Ngày vắng gốc nếu đây là buổi HOC_BU
  final bool isExtraCandidate; // Thuộc phần vượt chuẩn (> 12 buổi trong tháng)
  final bool isEarnedExtra; // Thực sự phát sinh buổi dư (+1)
  final List<String> warnings;

  SessionLedgerItem({
    required this.date,
    required this.dayOfWeek,
    this.startTime,
    this.scheduleId,
    required this.isScheduledEligible,
    required this.attendanceStatus,
    this.ngayVangGoc,
    this.isExtraCandidate = false,
    this.isEarnedExtra = false,
    this.warnings = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'scheduleId': scheduleId,
      'isScheduledEligible': isScheduledEligible,
      'attendanceStatus': attendanceStatus,
      'ngayVangGoc': ngayVangGoc,
      'isExtraCandidate': isExtraCandidate,
      'isEarnedExtra': isEarnedExtra,
      'warnings': warnings,
    };
  }
}

/// Ledger tính toán số buổi dư theo tháng
class MonthSessionLedger {
  final String yearMonth; // 'YYYY-MM'
  final String joinDate; // 'YYYY-MM-DD'
  final int scheduledEligibleCount;
  final int coMatCount;
  final int treCount;
  final int vangCoPhepCount;
  final int vangKhongPhepCount;
  final int hocBuCount;
  final int noRecordCount;
  final int earnedExtra;
  final int usedExtra;
  final int openingBalance;
  final int closingBalance;
  final List<SessionLedgerItem> sessions;
  final List<String> warnings;

  MonthSessionLedger({
    required this.yearMonth,
    required this.joinDate,
    required this.scheduledEligibleCount,
    required this.coMatCount,
    required this.treCount,
    required this.vangCoPhepCount,
    required this.vangKhongPhepCount,
    required this.hocBuCount,
    required this.noRecordCount,
    required this.earnedExtra,
    required this.usedExtra,
    required this.openingBalance,
    required this.closingBalance,
    required this.sessions,
    required this.warnings,
  });
}

/// Kết quả Rebuild tổng thể của Học sinh
class StudentSessionBalanceResult {
  final int studentId;
  final int classId;
  final String studentName;
  final String className;
  final String joinDate;
  final int currentBalance;
  final List<MonthSessionLedger> monthlyLedgers;
  final List<String> warnings;

  StudentSessionBalanceResult({
    required this.studentId,
    required this.classId,
    required this.studentName,
    required this.className,
    required this.joinDate,
    required this.currentBalance,
    required this.monthlyLedgers,
    required this.warnings,
  });
}

class SessionLedgerService {
  final DBHelper _dbHelper = DBHelper.instance;

  /// So sánh hai chuỗi thời gian (ví dụ '18:45' và '18:45:00' hoặc '18:00')
  /// Chuẩn hóa về phút trong ngày để so sánh chính xác hoặc cho phép tolerance <= 15 phút cho dữ liệu cũ.
  static bool isMatchingSessionTime(String ddTimeStr, String schTimeStr) {
    final ddMins = _parseTimeToMinutes(ddTimeStr);
    final schMins = _parseTimeToMinutes(schTimeStr);
    if (ddMins == null || schMins == null) return false;

    // Chênh lệch tối đa 15 phút cho dữ liệu legacy
    final diff = (ddMins - schMins).abs();
    return diff <= 15;
  }

  static int? _parseTimeToMinutes(String timeStr) {
    if (timeStr.trim().isEmpty) return null;
    final clean = timeStr.trim();
    final parts = clean.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        return h * 60 + m;
      }
    }
    return null;
  }

  /// Chuẩn hóa trạng thái điểm danh sang canonical key
  static String normalizeStatus(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'NO_RECORD';
    final s = raw.trim().toLowerCase();
    if (s == 'comat' || s == 'có mặt' || s == 'co_mat') return 'CO_MAT';
    if (s == 'tre' || s == 'trễ') return 'TRE';
    if (s == 'nghicophep' ||
        s == 'vắng có phép' ||
        s == 'vang_co_phep' ||
        s == 'nghỉ có phép')
      return 'VANG_CO_PHEP';
    if (s == 'nghikhongphep' ||
        s == 'vắng không phép' ||
        s == 'vang_khong_phep' ||
        s == 'nghỉ không phép')
      return 'VANG_KHONG_PHEP';
    if (s == 'hocbu' || s == 'học bù' || s == 'hoc_bu') return 'HOC_BU';
    if (s == 'holiday' ||
        s == 'nghỉ lễ' ||
        s == 'nghỉ hè' ||
        s == 'nghỉ tết' ||
        s == 'no_class')
      return 'HOLIDAY';
    if (s == 'cancelled' || s == 'hủy' || s == 'huy') return 'CANCELLED';
    if (s == 'chuadiemdanh' || s == 'chưa điểm danh' || s == 'no_record')
      return 'NO_RECORD';
    return raw;
  }

  /// Tên thứ trong tuần chuẩn bằng tiếng Việt từ DateTime
  static String getDayOfWeekText(DateTime dt) {
    switch (dt.weekday) {
      case DateTime.monday:
        return 'Thứ Hai';
      case DateTime.tuesday:
        return 'Thứ Ba';
      case DateTime.wednesday:
        return 'Thứ Tư';
      case DateTime.thursday:
        return 'Thứ Năm';
      case DateTime.friday:
        return 'Thứ Sáu';
      case DateTime.saturday:
        return 'Thứ Bảy';
      case DateTime.sunday:
        return 'Chủ Nhật';
      default:
        return '';
    }
  }

  /// Kiểm tra xem học sinh có đang active trong lớp tại ngày targetDate hay không
  static bool isStudentActiveOnDate({
    required DateTime targetDate,
    required DateTime? joinDate,
    required DateTime? tamNgungDate,
    required DateTime? hocLaiThucTeDate,
    required DateTime? duKienHocLaiDate,
    required DateTime? nghiHocDate,
    required DateTime? hocLaiSauNghiDate,
  }) {
    if (joinDate == null) return false;
    final targetStr = _formatDate(targetDate);
    final joinStr = _formatDate(joinDate);

    if (targetStr.compareTo(joinStr) < 0) return false;

    if (tamNgungDate != null) {
      final tamNgungStr = _formatDate(tamNgungDate);
      final resumeDate = hocLaiThucTeDate ?? duKienHocLaiDate;
      if (resumeDate != null) {
        final resumeStr = _formatDate(resumeDate);
        if (targetStr.compareTo(tamNgungStr) >= 0 &&
            targetStr.compareTo(resumeStr) < 0) {
          return false;
        }
      } else {
        if (targetStr.compareTo(tamNgungStr) >= 0) return false;
      }
    }

    if (nghiHocDate != null) {
      final nghiHocStr = _formatDate(nghiHocDate);
      if (hocLaiSauNghiDate != null) {
        final hocLaiStr = _formatDate(hocLaiSauNghiDate);
        if (targetStr.compareTo(nghiHocStr) >= 0 &&
            targetStr.compareTo(hocLaiStr) < 0) {
          return false;
        }
      } else {
        if (targetStr.compareTo(nghiHocStr) >= 0) return false;
      }
    }

    return true;
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime? _parseDate(String? str) {
    if (str == null || str.trim().isEmpty) return null;
    try {
      final clean = str.trim().split(' ')[0];
      final parts = clean.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
    } catch (_) {}
    return null;
  }

  /// TÁI TẠO SỐ DƯ BUỔI DƯ TÍCH LŨY DỰA TRÊN SESSION LEDGER (SESSION-BASED 100%)
  Future<StudentSessionBalanceResult> rebuildStudentSessionBalance(
    int studentId,
    int classId, {
    DateTime? untilDate,
    bool updateCacheInDb = true,
  }) async {
    final db = await _dbHelper.database;
    final warnings = <String>[];

    // 1. Lấy thông tin học sinh
    final hsRows = await db.query(
      DBHelper.tenBangHS,
      where: 'id = ?',
      whereArgs: [studentId],
    );
    final hsName = hsRows.isNotEmpty
        ? (hsRows.first['ten'] as String? ?? 'Học sinh #$studentId')
        : 'Học sinh #$studentId';

    // 2. Lấy thông tin lớp
    final lopRows = await db.query(
      DBHelper.tenBangLop,
      where: 'id = ?',
      whereArgs: [classId],
    );
    final className = lopRows.isNotEmpty
        ? (lopRows.first['ten'] as String? ?? 'Lớp #$classId')
        : 'Lớp #$classId';

    // 3. Lấy thông tin liên kết lop_hoc_sinh
    final lhsRows = await db.query(
      DBHelper.tenBangLopHS,
      where: 'id_hoc_sinh = ? AND id_lop = ?',
      whereArgs: [studentId, classId],
    );

    if (lhsRows.isEmpty) {
      warnings.add(
        'DATA_WARNING: Học sinh #$studentId chưa từng thuộc lớp #$classId',
      );
      return StudentSessionBalanceResult(
        studentId: studentId,
        classId: classId,
        studentName: hsName,
        className: className,
        joinDate: '',
        currentBalance: 0,
        monthlyLedgers: [],
        warnings: warnings,
      );
    }

    final lhsMap = lhsRows.first;
    final joinDateStr = (lhsMap['ngay_tham_gia'] as String?)?.trim() ?? '';
    final tamNgungStr = lhsMap['ngay_tam_ngung'] as String?;
    final duKienHocLaiStr = lhsMap['ngay_du_kien_hoc_lai'] as String?;
    final hocLaiThucTeStr = lhsMap['ngay_hoc_lai_thuc_te'] as String?;
    final nghiHocStr = lhsMap['ngay_nghi_hoc'] as String?;
    final hocLaiSauNghiStr = lhsMap['ngay_hoc_lai_sau_nghi'] as String?;

    if (joinDateStr.isEmpty) {
      warnings.add(
        'DATA_WARNING: Học sinh không có ngày tham gia lớp (ngay_tham_gia empty). Không tự đoán ngày.',
      );
      return StudentSessionBalanceResult(
        studentId: studentId,
        classId: classId,
        studentName: hsName,
        className: className,
        joinDate: '',
        currentBalance: 0,
        monthlyLedgers: [],
        warnings: warnings,
      );
    }

    final joinDate = _parseDate(joinDateStr);
    if (joinDate == null) {
      warnings.add(
        'DATA_WARNING: Định dạng ngay_tham_gia không hợp lệ: "$joinDateStr"',
      );
      return StudentSessionBalanceResult(
        studentId: studentId,
        classId: classId,
        studentName: hsName,
        className: className,
        joinDate: joinDateStr,
        currentBalance: 0,
        monthlyLedgers: [],
        warnings: warnings,
      );
    }

    final tamNgungDate = _parseDate(tamNgungStr);
    final duKienHocLaiDate = _parseDate(duKienHocLaiStr);
    final hocLaiThucTeDate = _parseDate(hocLaiThucTeStr);
    final nghiHocDate = _parseDate(nghiHocStr);
    final hocLaiSauNghiDate = _parseDate(hocLaiSauNghiStr);

    // 4. Lấy toàn bộ lịch học chung của lớp
    final lhcRows = await db.query(
      DBHelper.tenBangLichHocChung,
      where: 'id_lop = ?',
      whereArgs: [classId],
    );
    final listLichHocChung = lhcRows
        .map((m) => LichHocChung.fromMap(m))
        .toList();

    // 5. Lấy toàn bộ điểm danh của HS trong lớp
    final ddRows = await db.query(
      DBHelper.tenBangDiemDanh,
      where: 'id_hoc_sinh = ? AND id_lop = ?',
      whereArgs: [studentId, classId],
    );
    final listDiemDanh = ddRows.map((m) => DiemDanh.fromMap(m)).toList();

    // Group điểm danh theo ngày 'YYYY-MM-DD' -> List<DiemDanh> để hỗ trợ nhiều ca cùng ngày
    final attendanceByDate = <String, List<DiemDanh>>{};
    for (final dd in listDiemDanh) {
      final dateKey = dd.gioDiemDanh.trim().split(' ')[0];
      attendanceByDate.putIfAbsent(dateKey, () => []).add(dd);
    }

    // Lấy toàn bộ đơn nghỉ học / nghỉ lễ của lớp
    final donNghiRows = await db.query(
      DBHelper.tenBangDonNghiHoc,
      where: 'id_lop = ?',
      whereArgs: [classId],
    );

    final Set<String> classHolidayDates = {};
    final Set<String> individualLeaveDates = {};

    for (var row in donNghiRows) {
      final tuStr = row['tu_ngay'] as String?;
      final denStr = row['den_ngay'] as String?;
      final loaiNghi = row['loai_nghi'] as String? ?? 'CANHAN';
      final hsId = row['id_hoc_sinh'] as int?;

      if (tuStr != null && denStr != null) {
        final tuDt = _parseDate(tuStr);
        final denDt = _parseDate(denStr);
        if (tuDt != null && denDt != null) {
          DateTime cur = tuDt;
          while (!cur.isAfter(denDt)) {
            final dateKey = _formatDate(cur);
            if (loaiNghi == 'TOANLOP') {
              classHolidayDates.add(dateKey);
            } else if (hsId == studentId) {
              individualLeaveDates.add(dateKey);
            }
            cur = cur.add(const Duration(days: 1));
          }
        }
      }
    }

    final cutoff = untilDate ?? DateTime.now();
    final startYear = joinDate.year;
    final startMonth = joinDate.month;
    final endYear = cutoff.year;
    final endMonth = cutoff.month;

    int runningBalance = 0;
    final monthlyLedgers = <MonthSessionLedger>[];

    int curY = startYear;
    int curM = startMonth;

    while (curY < endYear || (curY == endYear && curM <= endMonth)) {
      final ymStr = '$curY-${curM.toString().padLeft(2, '0')}';
      final daysInMonth = DateTime(curY, curM + 1, 0).day;
      final monthWarnings = <String>[];
      final monthSessions = <SessionLedgerItem>[];

      for (int day = 1; day <= daysInMonth; day++) {
        final dateObj = DateTime(curY, curM, day);
        final dateStr = _formatDate(dateObj);

        if (dateObj.isAfter(cutoff)) continue;

        final dowText = getDayOfWeekText(dateObj);

        // Lấy tất cả khung lịch học áp dụng cho ngày này
        final applicableSchedules = listLichHocChung.where((sch) {
          if (sch.ngayTrongTuan.trim() != dowText) return false;
          final effFrom = sch.effectiveFrom.trim();
          if (effFrom.isNotEmpty && dateStr.compareTo(effFrom) < 0)
            return false;
          if (sch.effectiveTo != null && sch.effectiveTo!.trim().isNotEmpty) {
            final effTo = sch.effectiveTo!.trim();
            if (dateStr.compareTo(effTo) > 0) return false;
          }
          return true;
        }).toList();

        final isActiveMember = isStudentActiveOnDate(
          targetDate: dateObj,
          joinDate: joinDate,
          tamNgungDate: tamNgungDate,
          hocLaiThucTeDate: hocLaiThucTeDate,
          duKienHocLaiDate: duKienHocLaiDate,
          nghiHocDate: nghiHocDate,
          hocLaiSauNghiDate: hocLaiSauNghiDate,
        );

        final isClassHoliday = classHolidayDates.contains(dateStr);
        final isIndividualLeave = individualLeaveDates.contains(dateStr);

        final dayAttendanceRecords = List<DiemDanh>.from(
          attendanceByDate[dateStr] ?? [],
        );
        final usedRecords = <DiemDanh>{};

        if (applicableSchedules.isNotEmpty) {
          // Xử lý từng SESSION theo lịch học của ngày
          for (var sch in applicableSchedules) {
            final isScheduledEligible = isActiveMember && !isClassHoliday;

            // Tìm điểm danh khớp ca theo gioBatDau hoặc ID lịch (Session-based)
            DiemDanh? matchedDd;
            for (var dd in dayAttendanceRecords) {
              if (usedRecords.contains(dd)) continue;
              final ddTime = dd.gioDiemDanh.trim().split(' ').length > 1
                  ? dd.gioDiemDanh.trim().split(' ')[1]
                  : dd.gioDiemDanh.trim();

              if (isMatchingSessionTime(ddTime, sch.gioBatDau)) {
                matchedDd = dd;
                break;
              }
            }

            if (matchedDd != null) {
              usedRecords.add(matchedDd);
            }

            String status = normalizeStatus(matchedDd?.trangThai);
            if (isClassHoliday) {
              status = 'HOLIDAY';
            } else if (matchedDd == null &&
                isIndividualLeave &&
                isScheduledEligible) {
              status = 'VANG_CO_PHEP';
            }

            final itemWarnings = <String>[];
            if (isScheduledEligible && matchedDd == null) {
              itemWarnings.add(
                'DATA_WARNING: Ca học ${sch.gioBatDau} ngày $dateStr chưa có điểm danh',
              );
            }

            monthSessions.add(
              SessionLedgerItem(
                date: dateStr,
                dayOfWeek: dowText,
                startTime: sch.gioBatDau,
                scheduleId: sch.id,
                isScheduledEligible: isScheduledEligible,
                attendanceStatus: status,
                ngayVangGoc: matchedDd?.ngayVangGoc,
                warnings: itemWarnings,
              ),
            );
          }
        }

        // Xử lý các điểm danh phát sinh ngoài lịch (học bù, ca phát sinh)
        for (var dd in dayAttendanceRecords) {
          if (usedRecords.contains(dd)) continue;
          final status = normalizeStatus(dd.trangThai);
          final itemWarnings = <String>[];
          if (applicableSchedules.isEmpty && status != 'CANCELLED') {
            itemWarnings.add(
              'DATA_WARNING: Có bản ghi điểm danh ($status) ngoài khung lịch học chính thức ngày $dateStr',
            );
          }

          monthSessions.add(
            SessionLedgerItem(
              date: dateStr,
              dayOfWeek: dowText,
              startTime: dd.gioDiemDanh.trim().split(' ').length > 1
                  ? dd.gioDiemDanh.trim().split(' ')[1]
                  : null,
              isScheduledEligible: false,
              attendanceStatus: status,
              ngayVangGoc: dd.ngayVangGoc,
              warnings: itemWarnings,
            ),
          );
        }
      }

      // Lọc các SESSION thuộc lịch hợp lệ để tính số buổi vượt chuẩn 12
      final scheduledEligibleSessions = monthSessions
          .where((s) => s.isScheduledEligible)
          .toList();
      final eligibleCount = scheduledEligibleSessions.length;

      int earnedExtraInMonth = 0;

      // Đánh dấu phần dư vượt chuẩn 12 SESSION
      for (int i = 0; i < monthSessions.length; i++) {
        final item = monthSessions[i];
        if (!item.isScheduledEligible) continue;

        final idx = scheduledEligibleSessions.indexOf(item);
        if (idx >= 12) {
          final isEarned =
              (item.attendanceStatus == 'CO_MAT' ||
              item.attendanceStatus == 'TRE');

          if (isEarned) {
            earnedExtraInMonth++;
          } else if (item.attendanceStatus == 'VANG_CO_PHEP' ||
              item.attendanceStatus == 'VANG_KHONG_PHEP') {
            monthWarnings.add(
              'NGHIỆP VỤ: Session thứ ${idx + 1} (${item.date} ${item.startTime ?? ""}) thuộc phần dư vượt chuẩn nhưng học sinh VẮNG -> KHÔNG TÍNH THÀNH BUỔI DƯ',
            );
          }

          monthSessions[i] = SessionLedgerItem(
            date: item.date,
            dayOfWeek: item.dayOfWeek,
            startTime: item.startTime,
            scheduleId: item.scheduleId,
            isScheduledEligible: item.isScheduledEligible,
            attendanceStatus: item.attendanceStatus,
            ngayVangGoc: item.ngayVangGoc,
            isExtraCandidate: true,
            isEarnedExtra: isEarned,
            warnings: item.warnings,
          );
        }
      }

      final coMatCount = monthSessions
          .where((s) => s.attendanceStatus == 'CO_MAT')
          .length;
      final treCount = monthSessions
          .where((s) => s.attendanceStatus == 'TRE')
          .length;
      final vangCoPhepCount = monthSessions
          .where((s) => s.attendanceStatus == 'VANG_CO_PHEP')
          .length;
      final vangKhongPhepCount = monthSessions
          .where((s) => s.attendanceStatus == 'VANG_KHONG_PHEP')
          .length;
      final hocBuCount = monthSessions
          .where((s) => s.attendanceStatus == 'HOC_BU')
          .length;
      final noRecordCount = monthSessions
          .where((s) => s.attendanceStatus == 'NO_RECORD')
          .length;

      // Tính chính xác số lượng buổi nghỉ có phép CHƯA ĐƯỢC HỌC BÙ theo từng session
      final makeupAttendanceRecords = listDiemDanh
          .where((dd) => normalizeStatus(dd.trangThai) == 'HOC_BU')
          .toList();

      final usedMakeupRecords = <DiemDanh>{};
      int uncompensatedExcusedCount = 0;

      for (final s in monthSessions) {
        if (s.attendanceStatus == 'VANG_CO_PHEP') {
          DiemDanh? matchedMakeup;

          // Pass 1: Khớp theo ngay_vang_goc chứa date VÀ startTime (hoặc trùng giờ)
          for (final mk in makeupAttendanceRecords) {
            if (usedMakeupRecords.contains(mk)) continue;
            final nvg = mk.ngayVangGoc?.trim() ?? '';
            if (nvg.isNotEmpty && nvg.contains(s.date)) {
              if (s.startTime != null &&
                  s.startTime!.isNotEmpty &&
                  nvg.contains(s.startTime!)) {
                matchedMakeup = mk;
                break;
              }
            }
          }

          // Pass 2: Khớp theo ngay_vang_goc chứa date (mỗi HOC_BU chỉ bù cho 1 VANG_CO_PHEP)
          if (matchedMakeup == null) {
            for (final mk in makeupAttendanceRecords) {
              if (usedMakeupRecords.contains(mk)) continue;
              final nvg = mk.ngayVangGoc?.trim() ?? '';
              if (nvg.isNotEmpty && nvg.startsWith(s.date)) {
                matchedMakeup = mk;
                break;
              }
            }
          }

          if (matchedMakeup != null) {
            usedMakeupRecords.add(matchedMakeup);
          } else {
            uncompensatedExcusedCount++;
          }
        }
      }

      final openingBal = runningBalance;
      final availableCredit = openingBal + earnedExtraInMonth;
      final usedExtraInMonth = (uncompensatedExcusedCount < availableCredit)
          ? uncompensatedExcusedCount
          : availableCredit;

      final closingBal = openingBal + earnedExtraInMonth - usedExtraInMonth;
      runningBalance = closingBal;

      monthlyLedgers.add(
        MonthSessionLedger(
          yearMonth: ymStr,
          joinDate: joinDateStr,
          scheduledEligibleCount: eligibleCount,
          coMatCount: coMatCount,
          treCount: treCount,
          vangCoPhepCount: vangCoPhepCount,
          vangKhongPhepCount: vangKhongPhepCount,
          hocBuCount: hocBuCount,
          noRecordCount: noRecordCount,
          earnedExtra: earnedExtraInMonth,
          usedExtra: usedExtraInMonth,
          openingBalance: openingBal,
          closingBalance: closingBal,
          sessions: monthSessions,
          warnings: monthWarnings,
        ),
      );

      curM++;
      if (curM > 12) {
        curM = 1;
        curY++;
      }
    }

    if (updateCacheInDb) {
      try {
        await db.update(
          DBHelper.tenBangHS,
          {'so_buoi_du': runningBalance},
          where: 'id = ?',
          whereArgs: [studentId],
        );
      } catch (e) {
        developer.log(
          'Lỗi cập nhật cache so_buoi_du: $e',
          name: 'SessionLedgerService',
        );
      }
    }

    return StudentSessionBalanceResult(
      studentId: studentId,
      classId: classId,
      studentName: hsName,
      className: className,
      joinDate: joinDateStr,
      currentBalance: runningBalance,
      monthlyLedgers: monthlyLedgers,
      warnings: warnings,
    );
  }

  /// Tái tạo lại toàn bộ số buổi dư cho tất cả học sinh từ ngày tham gia lớp (100% từ lịch sử)
  Future<void> recalculateAllStudentsSessionBalance({
    bool syncFirebase = false,
  }) async {
    final db = await _dbHelper.database;

    await db.update(DBHelper.tenBangHS, {'so_buoi_du': 0});

    final lhsRows = await db.query(DBHelper.tenBangLopHS);

    for (final row in lhsRows) {
      final studentId = row['id_hoc_sinh'] as int?;
      final classId = row['id_lop'] as int?;
      if (studentId != null && classId != null) {
        await rebuildStudentSessionBalance(
          studentId,
          classId,
          updateCacheInDb: true,
        );
      }
    }
  }
}
