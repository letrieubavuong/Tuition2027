// File: lib/services/daily_brief_service.dart

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/daily_brief.dart';
import '../models/attention_item.dart';
import '../services/attention_queue_service.dart';
import '../services/hoc_sinh_service.dart';
import '../services/lop_service.dart';
import '../services/student_signal_service.dart';
import '../utils/db.dart';

class DailyBriefService extends ChangeNotifier {
  static final DailyBriefService instance = DailyBriefService._internal();
  factory DailyBriefService() => instance;
  DailyBriefService._internal();

  final _dbHelper = DBHelper.instance;
  final _attentionService = AttentionQueueService();
  final _signalService = StudentSignalService();
  final _hsService = HocSinhService();
  final _lopService = LopService();

  /// Cache memory nhẹ cho Brief trong ngày
  MorningBrief? _cachedMorningBrief;
  EveningBrief? _cachedEveningBrief;
  DateTime? _lastFetchDate;

  /// Build Morning Brief (Bản buổi sáng)
  Future<MorningBrief> getMorningBrief({
    DateTime? targetDate,
    bool forceRefresh = false,
  }) async {
    final date = targetDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    if (!forceRefresh &&
        _cachedMorningBrief != null &&
        _lastFetchDate != null &&
        _lastFetchDate!.year == date.year &&
        _lastFetchDate!.month == date.month &&
        _lastFetchDate!.day == date.day) {
      return _cachedMorningBrief!;
    }

    final db = await _dbHelper.database;

    // 1. Các ca dạy hôm nay
    final dayOfWeek = _getDayOfWeekString(date);
    final sessionRows = await db.rawQuery(
      '''
      SELECT l.id as id_lop, l.ten as ten_lop, lhc.id as id_lich_hoc_chung, lhc.gio_bat_dau, lhc.gio_ket_thuc
      FROM ${DBHelper.tenBangLichHocChung} lhc
      JOIN ${DBHelper.tenBangLop} l ON l.id = lhc.id_lop
      WHERE lhc.ngay_trong_tuan = ?
      ORDER BY lhc.gio_bat_dau ASC
      ''',
      [dayOfWeek],
    );

    final todaySessions = <SessionBriefItem>[];
    for (var row in sessionRows) {
      final classId = row['id_lop'] as int;
      final className = row['ten_lop'] as String;
      final startTime = row['gio_bat_dau'] as String? ?? '17:30';
      final endTime = row['gio_ket_thuc'] as String? ?? '19:00';

      // Sĩ số lớp
      final hsRows = await db.query(
        DBHelper.tenBangLopHS,
        where:
            'id_lop = ? AND (trang_thai LIKE "%Đang học%" OR trang_thai LIKE "%DANG_HOC%")',
        whereArgs: [classId],
      );

      todaySessions.add(
        SessionBriefItem(
          classId: classId,
          className: className,
          timeRange: '$startTime–$endTime',
          totalStudents: hsRows.length,
        ),
      );
    }

    // 2. Pre-class student alerts & Attention Items
    final activeAttentionItems = await _attentionService.getAttentionQueue(
      activeOnly: true,
    );
    final preClassStudentAlerts = activeAttentionItems
        .where(
          (item) =>
              item.type == AttentionType.UNEXCUSED_ABSENCE ||
              item.type == AttentionType.REPEATED_HOMEWORK_MISSING ||
              item.type == AttentionType.LEARNING_SUPPORT_NEEDED,
        )
        .toList();

    // 3. Dem hoc phi reminders
    final tuitionRemindersDueCount = activeAttentionItems
        .where((item) => item.type == AttentionType.TUITION_REMINDER_DUE)
        .length;

    // 4. Giao dich ngan hang can duyet
    final pendingPaymentReviewsCount = activeAttentionItems
        .where((item) => item.type == AttentionType.PAYMENT_NEEDS_REVIEW)
        .length;

    // 5. PH chua lien he
    final uncontactedParentsCount = activeAttentionItems
        .where((item) => item.type == AttentionType.PARENT_CONTACT_PENDING)
        .length;

    // 6. Ca hom qua chua danh gia
    final yesterdayStr = DateFormat(
      'yyyy-MM-dd',
    ).format(date.subtract(const Duration(days: 1)));
    final unreviewedYesterdayRows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT d.id_lop) as total
      FROM ${DBHelper.tenBangDiemDanh} d
      LEFT JOIN ${DBHelper.tenBangDanhGiaBuoiHoc} r ON r.id_diem_danh = d.id
      WHERE d.gio_diem_danh LIKE ? AND (r.id IS NULL OR r.diem_thai_do IS NULL)
      ''',
      ['$yesterdayStr%'],
    );
    final unreviewedYesterdayCount =
        (unreviewedYesterdayRows.first['total'] as num?)?.toInt() ?? 0;

    final brief = MorningBrief(
      date: date,
      todaySessions: todaySessions,
      preClassStudentAlerts: preClassStudentAlerts,
      tuitionRemindersDueCount: tuitionRemindersDueCount,
      pendingPaymentReviewsCount: pendingPaymentReviewsCount,
      uncontactedParentsCount: uncontactedParentsCount,
      unreviewedYesterdaySessionsCount: unreviewedYesterdayCount,
    );

    _cachedMorningBrief = brief;
    _lastFetchDate = date;
    return brief;
  }

  /// Build Evening Brief (Bản cuối ngày)
  Future<EveningBrief> getEveningBrief({
    DateTime? targetDate,
    bool forceRefresh = false,
  }) async {
    final date = targetDate ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    if (!forceRefresh &&
        _cachedEveningBrief != null &&
        _lastFetchDate != null &&
        _lastFetchDate!.year == date.year &&
        _lastFetchDate!.month == date.month &&
        _lastFetchDate!.day == date.day) {
      return _cachedEveningBrief!;
    }

    final db = await _dbHelper.database;
    final morning = await getMorningBrief(
      targetDate: date,
      forceRefresh: forceRefresh,
    );

    // 1. Thống kê điểm danh hôm nay
    final attRows = await db.rawQuery(
      '''
      SELECT trang_thai, COUNT(*) as count
      FROM ${DBHelper.tenBangDiemDanh}
      WHERE gio_diem_danh LIKE ?
      GROUP BY trang_thai
      ''',
      ['$dateStr%'],
    );

    int totalAttended = 0;
    int totalExcused = 0;
    int totalUnexcused = 0;
    int totalLate = 0;
    int totalMakeup = 0;

    for (var row in attRows) {
      final st = row['trang_thai'] as String?;
      final cnt = (row['count'] as num).toInt();
      if (st == 'Có mặt') {
        totalAttended += cnt;
      } else if (st == 'Trễ') {
        totalLate += cnt;
        totalAttended += cnt;
      } else if (st == 'Học bù') {
        totalMakeup += cnt;
        totalAttended += cnt;
      } else if (st == 'Nghỉ có phép') {
        totalExcused += cnt;
      } else if (st == 'Nghỉ không phép') {
        totalUnexcused += cnt;
      }
    }

    // 2. So ca da hoan tat diem danh & review
    final classSessionRows = await db.rawQuery(
      '''
      SELECT DISTINCT id_lop
      FROM ${DBHelper.tenBangDiemDanh}
      WHERE gio_diem_danh LIKE ?
      ''',
      ['$dateStr%'],
    );
    final completedSessionsCount = classSessionRows.length;
    final totalSessionsCount = morning.todaySessions.isNotEmpty
        ? morning.todaySessions.length
        : completedSessionsCount;

    // 3. Session review count
    final reviewRows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT d.id_lop) as total
      FROM ${DBHelper.tenBangDiemDanh} d
      JOIN ${DBHelper.tenBangDanhGiaBuoiHoc} r ON r.id_diem_danh = d.id
      WHERE d.gio_diem_danh LIKE ? AND r.diem_thai_do IS NOT NULL
      ''',
      ['$dateStr%'],
    );
    final completedReviewsCount =
        (reviewRows.first['total'] as num?)?.toInt() ?? 0;
    final unreviewedSessionsCount =
        totalSessionsCount - completedReviewsCount > 0
        ? totalSessionsCount - completedReviewsCount
        : 0;

    // 4. BTVN giao hom nay
    final hwRows = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT id_lop) as total
      FROM ${DBHelper.tenBangDanhGiaBuoiHoc} r
      JOIN ${DBHelper.tenBangDiemDanh} d ON d.id = r.id_diem_danh
      WHERE d.gio_diem_danh LIKE ? AND r.nhan_xet LIKE '%BTVN%'
      ''',
      ['$dateStr%'],
    );
    final homeworkAssignedCount = (hwRows.first['total'] as num?)?.toInt() ?? 0;

    // 5. Lien he PH hom nay
    int commMadeCount = 0;
    int commPendingCount = 0;
    try {
      final commMadeRows = await db.query(
        'parent_communications',
        where: 'created_at LIKE ? AND trang_thai IN (?, ?)',
        whereArgs: ['$dateStr%', 'SENT_MANUALLY_CONFIRMED', 'DELIVERED'],
      );
      commMadeCount = commMadeRows.length;
      final commPendingRows = await db.query(
        'parent_communications',
        where: 'trang_thai = ?',
        whereArgs: ['READY'],
      );
      commPendingCount = commPendingRows.length;
    } catch (_) {}

    // 6. Thanh toan hom nay
    int confirmedPaymentsCount = 0;
    int needReviewPaymentsCount = 0;
    try {
      final payRows = await db.query(
        'payment_transactions',
        where: 'created_at LIKE ?',
        whereArgs: ['$dateStr%'],
      );
      for (var p in payRows) {
        final st = p['status'] ?? p['trang_thai'];
        if (st == 'CONFIRMED' || st == 'DA_XAC_NHAN') confirmedPaymentsCount++;
        if (st == 'NEED_REVIEW' || st == 'CHO_DUYET') needReviewPaymentsCount++;
      }
    } catch (_) {}

    // 7. Hoc sinh can theo doi ngay mai
    final activeAttentions = await _attentionService.getAttentionQueue(
      activeOnly: true,
    );
    final studentsToWatchTomorrow = activeAttentions.take(5).toList();

    final brief = EveningBrief(
      date: date,
      totalSessionsCount: totalSessionsCount,
      completedSessionsCount: completedSessionsCount,
      totalAttended: totalAttended,
      totalExcused: totalExcused,
      totalUnexcused: totalUnexcused,
      totalLate: totalLate,
      totalMakeup: totalMakeup,
      completedReviewsCount: completedReviewsCount,
      unreviewedSessionsCount: unreviewedSessionsCount,
      homeworkAssignedCount: homeworkAssignedCount,
      parentContactsMadeCount: commMadeCount,
      pendingParentContactsCount: commPendingCount,
      confirmedPaymentsCount: confirmedPaymentsCount,
      needReviewPaymentsCount: needReviewPaymentsCount,
      studentsToWatchTomorrow: studentsToWatchTomorrow,
    );

    _cachedEveningBrief = brief;
    _lastFetchDate = date;
    return brief;
  }

  /// Clear memory cache on data mutations
  void invalidateCache() {
    _cachedMorningBrief = null;
    _cachedEveningBrief = null;
    _lastFetchDate = null;
    notifyListeners();
  }

  String _getDayOfWeekString(DateTime dt) {
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
      default:
        return 'Chủ Nhật';
    }
  }
}
