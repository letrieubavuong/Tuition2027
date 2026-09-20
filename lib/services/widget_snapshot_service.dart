// File: lib/services/widget_snapshot_service.dart

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../models/attention_item.dart';
import '../models/home_widget_snapshot.dart';
import '../services/attention_queue_service.dart';
import '../services/daily_brief_service.dart';
import '../services/session_ledger_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/db.dart';

class WidgetSnapshotService extends ChangeNotifier {
  static final WidgetSnapshotService instance =
      WidgetSnapshotService._internal();
  factory WidgetSnapshotService() => instance;
  WidgetSnapshotService._internal();

  final _dbHelper = DBHelper.instance;
  final _attentionService = AttentionQueueService.instance;
  final _dailyBriefService = DailyBriefService.instance;

  HomeWidgetSnapshot? _lastSnapshot;
  HomeWidgetSnapshot? get lastSnapshot => _lastSnapshot;

  /// Đọc dữ liệu từ SQLite DB và xây dựng snapshot nhẹ cho Widget
  Future<HomeWidgetSnapshot> buildSnapshot({DateTime? targetDate}) async {
    final now = DateTime.now();
    final date = targetDate ?? now;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dateFormatted = _formatDayOfWeekDate(date);

    final db = await _dbHelper.database;

    // 1. Đọc Privacy Settings
    String privacyMode = 'FULL';
    try {
      final settings = await db.query(
        DBHelper.tenBangCaiDat,
        where: 'khoa = ?',
        whereArgs: ['widget_privacy_mode'],
      );
      if (settings.isNotEmpty) {
        privacyMode = settings.first['gia_tri']?.toString() ?? 'FULL';
      }
    } catch (_) {}

    // 2. Đọc danh sách ca học hôm nay từ DB
    final dayOfWeek = _getDayOfWeekString(date);
    final sessionRows = await db.rawQuery(
      '''
      SELECT l.id as id_lop, l.ten as ten_lop, lhc.id as id_lich_hoc, lhc.gio_bat_dau, lhc.gio_ket_thuc
      FROM ${DBHelper.tenBangLichHocChung} lhc
      JOIN ${DBHelper.tenBangLop} l ON l.id = lhc.id_lop
      WHERE lhc.ngay_trong_tuan = ?
      ORDER BY lhc.gio_bat_dau ASC
      ''',
      [dayOfWeek],
    );

    final todaySessionCount = sessionRows.length;

    // Tính số ca đã hoàn tất hôm nay
    int completedSessionCount = 0;
    try {
      final ledgerRows = await db.query(
        'session_completion_ledger',
        where: 'session_date = ? AND status IN (?, ?)',
        whereArgs: [dateStr, 'COMPLETED', 'COMPLETED_WITH_WARNINGS'],
      );
      completedSessionCount = ledgerRows.length;
    } catch (_) {}

    int? currentClassId;
    int? currentScheduleId;
    String? currentSessionName;
    String? currentStart;
    String? currentEnd;
    int currentAttendedCount = 0;
    int currentResolvedCount = 0;
    int currentUnresolvedCount = 0;
    int currentTotalCount = 0;

    int? nextClassId;
    int? nextScheduleId;
    String? nextSessionName;
    String? nextStart;
    String? nextEnd;
    int nextTotalCount = 0;

    final currentTimeStr = DateFormat('HH:mm').format(now);

    int todayTotalStudents = 0;
    for (var row in sessionRows) {
      final classId = row['id_lop'] as int;
      final scheduleId = row['id_lich_hoc'] as int?;
      final className = row['ten_lop'] as String;
      final rawStart = row['gio_bat_dau']?.toString().trim();
      final rawEnd = row['gio_ket_thuc']?.toString().trim();

      final start = (rawStart != null && rawStart.isNotEmpty)
          ? (rawStart.length >= 5 ? rawStart.substring(0, 5) : rawStart)
          : null;
      final end = (rawEnd != null && rawEnd.isNotEmpty)
          ? (rawEnd.length >= 5 ? rawEnd.substring(0, 5) : rawEnd)
          : null;

      // Đếm sĩ số
      final hsRows = await db.query(
        DBHelper.tenBangLopHS,
        where:
            'id_lop = ? AND (trang_thai LIKE "%Đang học%" OR trang_thai LIKE "%DANG_HOC%")',
        whereArgs: [classId],
      );
      final totalHs = hsRows.length;
      todayTotalStudents += totalHs;

      if (start != null &&
          end != null &&
          currentTimeStr.compareTo(start) >= 0 &&
          currentTimeStr.compareTo(end) <= 0) {
        // Đang trong ca học này
        currentClassId = classId;
        currentScheduleId = scheduleId;
        currentSessionName = className;
        currentStart = start;
        currentEnd = end;
        currentTotalCount = totalHs;

        final attRows = await db.rawQuery(
          '''
          SELECT trang_thai FROM ${DBHelper.tenBangDiemDanh}
          WHERE id_lop = ? AND gio_diem_danh LIKE ?
          ''',
          [classId, '$dateStr%'],
        );

        int attended = 0;
        int resolved = 0;
        for (var r in attRows) {
          final st = r['trang_thai']?.toString() ?? '';
          final norm = SessionLedgerService.normalizeStatus(st);
          if (norm == 'CO_MAT' || norm == 'TRE' || norm == 'HOC_BU') {
            attended++;
            resolved++;
          } else if (norm == 'VANG_CO_PHEP' || norm == 'VANG_KHONG_PHEP') {
            resolved++;
          }
        }
        currentAttendedCount = attended;
        currentResolvedCount = resolved;
        currentUnresolvedCount = (totalHs - resolved) < 0
            ? 0
            : (totalHs - resolved);
      } else if (start != null &&
          currentTimeStr.compareTo(start) < 0 &&
          nextClassId == null) {
        // Ca tiếp theo sắp diễn ra
        nextClassId = classId;
        nextScheduleId = scheduleId;
        nextSessionName = className;
        nextStart = start;
        nextEnd = end;
        nextTotalCount = totalHs;
      }
    }

    // 3. Đọc Attention Summary
    final activeAttentionItems = await _attentionService.getAttentionQueue(
      activeOnly: true,
    );
    final attentionCount = activeAttentionItems.length;

    int criticalCount = 0;
    int unexcusedAbsenceCount = 0;
    int tuitionReminderCount = 0;
    int parentContactPendingCount = 0;
    int studentAttentionCount = 0;

    for (var item in activeAttentionItems) {
      if (item.severity == AttentionSeverity.critical ||
          item.priority == AttentionPriority.urgent) {
        criticalCount++;
      }
      if (item.type == AttentionType.UNEXCUSED_ABSENCE) unexcusedAbsenceCount++;
      if (item.type == AttentionType.TUITION_REMINDER_DUE)
        tuitionReminderCount++;
      if (item.type == AttentionType.PARENT_CONTACT_PENDING)
        parentContactPendingCount++;
      if (item.type == AttentionType.LEARNING_SUPPORT_NEEDED ||
          item.type == AttentionType.REPEATED_HOMEWORK_MISSING) {
        studentAttentionCount++;
      }
    }

    // 4. Daily Brief Summary
    String? dailyBriefSummary;
    try {
      if (now.hour < 12) {
        final morning = await _dailyBriefService.getMorningBrief(
          targetDate: date,
        );
        dailyBriefSummary = morning.preClassStudentAlerts.isEmpty
            ? 'Hôm nay không có việc cần xử lý.'
            : 'Hôm nay có ${morning.todaySessions.length} ca. ${morning.preClassStudentAlerts.length} HS cần lưu ý.';
      } else {
        final evening = await _dailyBriefService.getEveningBrief(
          targetDate: date,
        );
        dailyBriefSummary = evening.isClean
            ? 'Tất cả ca hôm nay đã hoàn tất.'
            : 'Đã hoàn tất ${evening.completedSessionsCount}/${evening.totalSessionsCount} ca. Có ${evening.needReviewPaymentsCount + evening.pendingParentContactsCount} việc tồn.';
      }
    } catch (_) {}

    // 5. Tính toán các cờ đánh giá thực tế cho ca học
    bool attendanceDone =
        currentTotalCount > 0 && currentResolvedCount >= currentTotalCount;
    bool reviewDone = false;
    bool homeworkDone = false;
    int parentActionPending = parentContactPendingCount;

    final targetClassId = currentClassId ?? nextClassId;
    if (targetClassId != null && targetClassId > 0) {
      try {
        final reviewRows = await db.query(
          'post_session_review',
          where: 'id_lop = ? AND date = ?',
          whereArgs: [targetClassId, dateStr],
        );
        if (reviewRows.isNotEmpty) {
          reviewDone = true;
          for (var r in reviewRows) {
            final hw = r['homework_content']?.toString();
            if (hw != null && hw.trim().isNotEmpty) {
              homeworkDone = true;
            }
          }
        }
      } catch (_) {}
    }

    // 6. Xác định widget state
    String widgetState = 'NO_SESSION';
    if (todaySessionCount == 0) {
      widgetState = 'NO_SESSION';
    } else if (currentClassId != null) {
      widgetState = 'CURRENT_SESSION';
    } else if (nextClassId != null) {
      widgetState = 'NEXT_SESSION';
    } else if (now.hour < 12) {
      widgetState = 'MORNING';
    } else if (completedSessionCount < todaySessionCount) {
      widgetState = 'SESSION_ENDED';
    } else {
      widgetState = 'EVENING_SUMMARY';
    }

    final snapshot = HomeWidgetSnapshot(
      date: dateStr,
      dateFormatted: dateFormatted,
      widgetState: widgetState,
      todaySessionCount: todaySessionCount,
      todayTotalStudents: todayTotalStudents,
      completedSessionCount: completedSessionCount,
      currentClassId: currentClassId,
      currentScheduleId: currentScheduleId,
      currentSessionDate: dateStr,
      currentSessionId: currentClassId,
      currentSessionName: currentSessionName,
      currentStart: currentStart,
      currentEnd: currentEnd,
      currentAttendedCount: currentAttendedCount,
      currentResolvedCount: currentResolvedCount,
      currentUnresolvedCount: currentUnresolvedCount,
      currentTotalCount: currentTotalCount,
      nextClassId: nextClassId,
      nextScheduleId: nextScheduleId,
      nextSessionDate: dateStr,
      nextSessionId: nextClassId,
      nextSessionName: nextSessionName,
      nextStart: nextStart,
      nextEnd: nextEnd,
      nextTotalCount: nextTotalCount,
      attendanceDone: attendanceDone,
      reviewDone: reviewDone,
      homeworkDone: homeworkDone,
      parentActionPending: parentActionPending,
      attentionCount: attentionCount,
      criticalCount: criticalCount,
      unexcusedAbsenceCount: unexcusedAbsenceCount,
      tuitionReminderCount: tuitionReminderCount,
      parentContactPendingCount: parentContactPendingCount,
      studentAttentionCount: studentAttentionCount,
      dailyBriefSummary: dailyBriefSummary,
      lastUpdatedAt: now,
      privacyMode: privacyMode,
    );

    _lastSnapshot = snapshot;
    return snapshot;
  }

  /// Làm mới snapshot và đẩy dữ liệu sang Android AppWidget
  Future<void> refresh({bool force = false}) async {
    try {
      final snapshot = await buildSnapshot();

      // Save keys into HomeWidget SharedPreferences
      await HomeWidget.saveWidgetData<String>(
        'snapshot_json',
        snapshot.toJson(),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_date',
        snapshot.dateFormatted,
      );
      await HomeWidget.saveWidgetData<bool>(
        'widget_empty',
        snapshot.todaySessionCount == 0,
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_state',
        snapshot.widgetState,
      );
      await HomeWidget.saveWidgetData<int>(
        'today_session_count',
        snapshot.todaySessionCount,
      );
      await HomeWidget.saveWidgetData<int>(
        'today_total_students',
        snapshot.todayTotalStudents,
      );
      await HomeWidget.saveWidgetData<int>(
        'completed_session_count',
        snapshot.completedSessionCount,
      );

      if (snapshot.currentSessionName != null) {
        final displayName = snapshot.privacyMode == 'COUNTS_ONLY'
            ? 'Lớp #${snapshot.currentSessionId}'
            : snapshot.currentSessionName;
        await HomeWidget.saveWidgetData<String>(
          'current_session_name',
          displayName!,
        );
        await HomeWidget.saveWidgetData<String>(
          'current_time',
          _formatTimeDisplay(snapshot.currentStart, snapshot.currentEnd),
        );
        await HomeWidget.saveWidgetData<int>(
          'current_total_count',
          snapshot.currentTotalCount,
        );
        await HomeWidget.saveWidgetData<int>(
          'current_attended_count',
          snapshot.currentAttendedCount,
        );
        await HomeWidget.saveWidgetData<int>(
          'current_resolved_count',
          snapshot.currentResolvedCount,
        );
        await HomeWidget.saveWidgetData<String>(
          'current_attendance',
          '${snapshot.currentAttendedCount}/${snapshot.currentTotalCount} có mặt',
        );
      } else {
        await HomeWidget.saveWidgetData<String>('current_session_name', '');
        await HomeWidget.saveWidgetData<String>('current_time', '');
        await HomeWidget.saveWidgetData<String>('current_attendance', '');
        await HomeWidget.saveWidgetData<int>('current_total_count', 0);
        await HomeWidget.saveWidgetData<int>('current_attended_count', 0);
        await HomeWidget.saveWidgetData<int>('current_resolved_count', 0);
      }

      if (snapshot.nextSessionName != null) {
        final displayName = snapshot.privacyMode == 'COUNTS_ONLY'
            ? 'Lớp #${snapshot.nextSessionId}'
            : snapshot.nextSessionName;
        await HomeWidget.saveWidgetData<String>(
          'next_session_name',
          displayName!,
        );
        await HomeWidget.saveWidgetData<String>(
          'next_time',
          _formatTimeDisplay(snapshot.nextStart, snapshot.nextEnd),
        );
        await HomeWidget.saveWidgetData<int>(
          'next_total_count',
          snapshot.nextTotalCount,
        );
      } else {
        await HomeWidget.saveWidgetData<String>('next_session_name', '');
        await HomeWidget.saveWidgetData<String>('next_time', '');
        await HomeWidget.saveWidgetData<int>('next_total_count', 0);
      }

      await HomeWidget.saveWidgetData<int>(
        'attention_count',
        snapshot.attentionCount,
      );
      await HomeWidget.saveWidgetData<int>(
        'critical_count',
        snapshot.criticalCount,
      );
      await HomeWidget.saveWidgetData<int>(
        'unexcused_count',
        snapshot.unexcusedAbsenceCount,
      );
      await HomeWidget.saveWidgetData<int>(
        'tuition_count',
        snapshot.tuitionReminderCount,
      );
      await HomeWidget.saveWidgetData<int>(
        'parent_count',
        snapshot.parentContactPendingCount,
      );
      await HomeWidget.saveWidgetData<int>(
        'student_attention_count',
        snapshot.studentAttentionCount,
      );
      await HomeWidget.saveWidgetData<String>(
        'daily_brief_summary',
        snapshot.dailyBriefSummary ?? '',
      );
      await HomeWidget.saveWidgetData<String>(
        'last_updated_at',
        DateFormat('HH:mm').format(snapshot.lastUpdatedAt),
      );
      await HomeWidget.saveWidgetData<String>(
        'privacy_mode',
        snapshot.privacyMode,
      );
      await HomeWidget.saveWidgetData<bool>('is_stale', snapshot.isStale);

      // Yêu cầu Android AppWidget Provider cập nhật UI
      await HomeWidget.updateWidget(
        name: 'TuitionWidgetProvider',
        androidName: 'TuitionWidgetProvider',
        qualifiedAndroidName: 'com.example.tuition2025.TuitionWidgetProvider',
      );

      // Đồng bộ QR Widget cho Bank
      await WidgetSyncService.syncBankQRWidget();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing WidgetSnapshotService: $e');
      }
    }
  }

  String _formatTimeDisplay(String? start, String? end) {
    final cleanStart = start?.trim();
    final cleanEnd = end?.trim();
    final hasStart = cleanStart != null && cleanStart.isNotEmpty;
    final hasEnd = cleanEnd != null && cleanEnd.isNotEmpty;

    if (hasStart && hasEnd) {
      return '$cleanStart–$cleanEnd';
    } else if (hasStart) {
      return 'Bắt đầu $cleanStart';
    } else if (hasEnd) {
      return 'Kết thúc $cleanEnd';
    } else {
      return 'Chưa có thời gian';
    }
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

  String _formatDayOfWeekDate(DateTime dt) {
    final dayName = _getDayOfWeekString(dt);
    final dateStr = DateFormat('dd/MM/yyyy').format(dt);
    return '$dayName ($dateStr)';
  }
}
