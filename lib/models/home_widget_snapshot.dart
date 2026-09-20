// File: lib/models/home_widget_snapshot.dart

import 'dart:convert';

/// Enum đại diện cho trạng thái vận hành của Control Center Widget
enum HomeWidgetOperationalState {
  morning,
  nextSession,
  currentSession,
  sessionEnded,
  eveningSummary,
  noSession,
  stale;

  static HomeWidgetOperationalState fromString(String raw, bool isStaleData) {
    if (isStaleData) return HomeWidgetOperationalState.stale;
    switch (raw.toUpperCase()) {
      case 'MORNING':
        return HomeWidgetOperationalState.morning;
      case 'NEXT_SESSION':
        return HomeWidgetOperationalState.nextSession;
      case 'CURRENT_SESSION':
        return HomeWidgetOperationalState.currentSession;
      case 'SESSION_ENDED':
        return HomeWidgetOperationalState.sessionEnded;
      case 'EVENING_SUMMARY':
      case 'EVENING':
        return HomeWidgetOperationalState.eveningSummary;
      case 'STALE':
        return HomeWidgetOperationalState.stale;
      case 'NO_SESSION':
      default:
        return HomeWidgetOperationalState.noSession;
    }
  }

  String toRawString() {
    switch (this) {
      case HomeWidgetOperationalState.morning:
        return 'MORNING';
      case HomeWidgetOperationalState.nextSession:
        return 'NEXT_SESSION';
      case HomeWidgetOperationalState.currentSession:
        return 'CURRENT_SESSION';
      case HomeWidgetOperationalState.sessionEnded:
        return 'SESSION_ENDED';
      case HomeWidgetOperationalState.eveningSummary:
        return 'EVENING_SUMMARY';
      case HomeWidgetOperationalState.stale:
        return 'STALE';
      case HomeWidgetOperationalState.noSession:
        return 'NO_SESSION';
    }
  }
}

/// Domain model chứa thông tin chụp nhanh (snapshot) cho Control Center & Android Home Widget
class HomeWidgetSnapshot {
  final String date; // YYYY-MM-DD
  final String dateFormatted; // 'Thứ Sáu (18/09/2026)'
  final String
  widgetState; // MORNING, NEXT_SESSION, CURRENT_SESSION, SESSION_ENDED, EVENING_SUMMARY, NO_SESSION, STALE

  final int todaySessionCount;
  final int todayTotalStudents;
  final int completedSessionCount;

  // Identity ca hiện tại
  final int? currentClassId;
  final int? currentScheduleId;
  final String? currentSessionDate;
  final int? currentSessionId; // Alias/Legacy ID
  final String? currentSessionName;
  final String? currentStart;
  final String? currentEnd;
  final int currentAttendedCount; // Số HS đã có mặt
  final int
  currentResolvedCount; // Số HS đã được điểm danh (bất kỳ trạng thái nào)
  final int currentUnresolvedCount; // Số HS chưa điểm danh
  final int currentTotalCount;

  // Identity ca tiếp theo
  final int? nextClassId;
  final int? nextScheduleId;
  final String? nextSessionDate;
  final int? nextSessionId; // Alias/Legacy ID
  final String? nextSessionName;
  final String? nextStart;
  final String? nextEnd;
  final int nextTotalCount;

  // Trạng thái đánh giá ca học (Dynamic Real Data)
  final bool attendanceDone;
  final bool reviewDone;
  final bool homeworkDone;
  final int parentActionPending;

  final int attentionCount;
  final int criticalCount;
  final int unexcusedAbsenceCount;
  final int tuitionReminderCount;
  final int parentContactPendingCount;
  final int studentAttentionCount;

  final String? dailyBriefSummary;
  final DateTime lastUpdatedAt;
  final String privacyMode; // FULL, HIDE_NAMES, COUNTS_ONLY

  const HomeWidgetSnapshot({
    required this.date,
    required this.dateFormatted,
    required this.widgetState,
    required this.todaySessionCount,
    this.todayTotalStudents = 0,
    required this.completedSessionCount,
    this.currentClassId,
    this.currentScheduleId,
    this.currentSessionDate,
    this.currentSessionId,
    this.currentSessionName,
    this.currentStart,
    this.currentEnd,
    this.currentAttendedCount = 0,
    this.currentResolvedCount = 0,
    this.currentUnresolvedCount = 0,
    this.currentTotalCount = 0,
    this.nextClassId,
    this.nextScheduleId,
    this.nextSessionDate,
    this.nextSessionId,
    this.nextSessionName,
    this.nextStart,
    this.nextEnd,
    this.nextTotalCount = 0,
    this.attendanceDone = false,
    this.reviewDone = false,
    this.homeworkDone = false,
    this.parentActionPending = 0,
    required this.attentionCount,
    required this.criticalCount,
    required this.unexcusedAbsenceCount,
    required this.tuitionReminderCount,
    required this.parentContactPendingCount,
    required this.studentAttentionCount,
    this.dailyBriefSummary,
    required this.lastUpdatedAt,
    this.privacyMode = 'FULL',
  });

  /// Trạng thái vận hành chuẩn hóa
  HomeWidgetOperationalState get operationalState =>
      HomeWidgetOperationalState.fromString(widgetState, isStale);

  /// Kiểm tra dữ liệu có bị cũ (quá 12 tiếng hoặc khác ngày) không
  bool get isStale {
    final now = DateTime.now();
    if (lastUpdatedAt.year != now.year ||
        lastUpdatedAt.month != now.month ||
        lastUpdatedAt.day != now.day) {
      return true;
    }
    return now.difference(lastUpdatedAt).inHours > 12;
  }

  int get effectiveCurrentClassId => currentClassId ?? currentSessionId ?? 0;
  int get effectiveNextClassId => nextClassId ?? nextSessionId ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'dateFormatted': dateFormatted,
      'widgetState': widgetState,
      'todaySessionCount': todaySessionCount,
      'todayTotalStudents': todayTotalStudents,
      'completedSessionCount': completedSessionCount,
      'currentClassId': currentClassId ?? currentSessionId,
      'currentScheduleId': currentScheduleId,
      'currentSessionDate': currentSessionDate ?? date,
      'currentSessionId': currentSessionId ?? currentClassId,
      'currentSessionName': currentSessionName,
      'currentStart': currentStart,
      'currentEnd': currentEnd,
      'currentAttendedCount': currentAttendedCount,
      'currentResolvedCount': currentResolvedCount,
      'currentUnresolvedCount': currentUnresolvedCount,
      'currentTotalCount': currentTotalCount,
      'nextClassId': nextClassId ?? nextSessionId,
      'nextScheduleId': nextScheduleId,
      'nextSessionDate': nextSessionDate ?? date,
      'nextSessionId': nextSessionId ?? nextClassId,
      'nextSessionName': nextSessionName,
      'nextStart': nextStart,
      'nextEnd': nextEnd,
      'nextTotalCount': nextTotalCount,
      'attendanceDone': attendanceDone,
      'reviewDone': reviewDone,
      'homeworkDone': homeworkDone,
      'parentActionPending': parentActionPending,
      'attentionCount': attentionCount,
      'criticalCount': criticalCount,
      'unexcusedAbsenceCount': unexcusedAbsenceCount,
      'tuitionReminderCount': tuitionReminderCount,
      'parentContactPendingCount': parentContactPendingCount,
      'studentAttentionCount': studentAttentionCount,
      'dailyBriefSummary': dailyBriefSummary,
      'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
      'privacyMode': privacyMode,
      'isStale': isStale,
    };
  }

  factory HomeWidgetSnapshot.fromMap(Map<String, dynamic> map) {
    final totalHsCurrent = (map['currentTotalCount'] as num?)?.toInt() ?? 0;
    final resolvedHsCurrent =
        (map['currentResolvedCount'] as num?)?.toInt() ??
        (map['currentAttendedCount'] as num?)?.toInt() ??
        0;

    return HomeWidgetSnapshot(
      date: map['date']?.toString() ?? '',
      dateFormatted: map['dateFormatted']?.toString() ?? 'Hôm nay',
      widgetState: map['widgetState']?.toString() ?? 'NO_SESSION',
      todaySessionCount: (map['todaySessionCount'] as num?)?.toInt() ?? 0,
      todayTotalStudents: (map['todayTotalStudents'] as num?)?.toInt() ?? 0,
      completedSessionCount:
          (map['completedSessionCount'] as num?)?.toInt() ?? 0,
      currentClassId:
          (map['currentClassId'] as num?)?.toInt() ??
          (map['currentSessionId'] as num?)?.toInt(),
      currentScheduleId: (map['currentScheduleId'] as num?)?.toInt(),
      currentSessionDate:
          map['currentSessionDate']?.toString() ?? map['date']?.toString(),
      currentSessionId:
          (map['currentSessionId'] as num?)?.toInt() ??
          (map['currentClassId'] as num?)?.toInt(),
      currentSessionName: map['currentSessionName']?.toString(),
      currentStart: map['currentStart']?.toString(),
      currentEnd: map['currentEnd']?.toString(),
      currentAttendedCount: (map['currentAttendedCount'] as num?)?.toInt() ?? 0,
      currentResolvedCount: resolvedHsCurrent,
      currentUnresolvedCount:
          (map['currentUnresolvedCount'] as num?)?.toInt() ??
          ((totalHsCurrent - resolvedHsCurrent) < 0
              ? 0
              : (totalHsCurrent - resolvedHsCurrent)),
      currentTotalCount: totalHsCurrent,
      nextClassId:
          (map['nextClassId'] as num?)?.toInt() ??
          (map['nextSessionId'] as num?)?.toInt(),
      nextScheduleId: (map['nextScheduleId'] as num?)?.toInt(),
      nextSessionDate:
          map['nextSessionDate']?.toString() ?? map['date']?.toString(),
      nextSessionId:
          (map['nextSessionId'] as num?)?.toInt() ??
          (map['nextClassId'] as num?)?.toInt(),
      nextSessionName: map['nextSessionName']?.toString(),
      nextStart: map['nextStart']?.toString(),
      nextEnd: map['nextEnd']?.toString(),
      nextTotalCount: (map['nextTotalCount'] as num?)?.toInt() ?? 0,
      attendanceDone:
          map['attendanceDone'] as bool? ??
          (resolvedHsCurrent >= totalHsCurrent && totalHsCurrent > 0),
      reviewDone: map['reviewDone'] as bool? ?? false,
      homeworkDone: map['homeworkDone'] as bool? ?? false,
      parentActionPending: (map['parentActionPending'] as num?)?.toInt() ?? 0,
      attentionCount: (map['attentionCount'] as num?)?.toInt() ?? 0,
      criticalCount: (map['criticalCount'] as num?)?.toInt() ?? 0,
      unexcusedAbsenceCount:
          (map['unexcusedAbsenceCount'] as num?)?.toInt() ?? 0,
      tuitionReminderCount: (map['tuitionReminderCount'] as num?)?.toInt() ?? 0,
      parentContactPendingCount:
          (map['parentContactPendingCount'] as num?)?.toInt() ?? 0,
      studentAttentionCount:
          (map['studentAttentionCount'] as num?)?.toInt() ?? 0,
      dailyBriefSummary: map['dailyBriefSummary']?.toString(),
      lastUpdatedAt:
          DateTime.tryParse(map['lastUpdatedAt']?.toString() ?? '') ??
          DateTime.now(),
      privacyMode: map['privacyMode']?.toString() ?? 'FULL',
    );
  }

  String toJson() => jsonEncode(toMap());

  factory HomeWidgetSnapshot.fromJson(String source) =>
      HomeWidgetSnapshot.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
