// File: lib/models/daily_brief.dart

import 'attention_item.dart';

class SessionBriefItem {
  final int classId;
  final String className;
  final int? sessionId;
  final String timeRange;
  final int totalStudents;
  final int attendedCount;
  final int excusedCount;
  final int unexcusedCount;
  final bool isCompleted;

  SessionBriefItem({
    required this.classId,
    required this.className,
    this.sessionId,
    required this.timeRange,
    required this.totalStudents,
    this.attendedCount = 0,
    this.excusedCount = 0,
    this.unexcusedCount = 0,
    this.isCompleted = false,
  });
}

class MorningBrief {
  final DateTime date;
  final List<SessionBriefItem> todaySessions;
  final List<AttentionItem> preClassStudentAlerts;
  final int tuitionRemindersDueCount;
  final int pendingPaymentReviewsCount;
  final int uncontactedParentsCount;
  final int unreviewedYesterdaySessionsCount;

  MorningBrief({
    required this.date,
    required this.todaySessions,
    required this.preClassStudentAlerts,
    required this.tuitionRemindersDueCount,
    required this.pendingPaymentReviewsCount,
    required this.uncontactedParentsCount,
    required this.unreviewedYesterdaySessionsCount,
  });

  bool get isEmpty =>
      todaySessions.isEmpty &&
      preClassStudentAlerts.isEmpty &&
      tuitionRemindersDueCount == 0 &&
      pendingPaymentReviewsCount == 0 &&
      uncontactedParentsCount == 0 &&
      unreviewedYesterdaySessionsCount == 0;
}

class EveningBrief {
  final DateTime date;
  final int totalSessionsCount;
  final int completedSessionsCount;
  final int totalAttended;
  final int totalExcused;
  final int totalUnexcused;
  final int totalLate;
  final int totalMakeup;
  final int completedReviewsCount;
  final int unreviewedSessionsCount;
  final int homeworkAssignedCount;
  final int parentContactsMadeCount;
  final int pendingParentContactsCount;
  final int confirmedPaymentsCount;
  final int needReviewPaymentsCount;
  final List<AttentionItem> studentsToWatchTomorrow;

  EveningBrief({
    required this.date,
    required this.totalSessionsCount,
    required this.completedSessionsCount,
    required this.totalAttended,
    required this.totalExcused,
    required this.totalUnexcused,
    required this.totalLate,
    required this.totalMakeup,
    required this.completedReviewsCount,
    required this.unreviewedSessionsCount,
    required this.homeworkAssignedCount,
    required this.parentContactsMadeCount,
    required this.pendingParentContactsCount,
    required this.confirmedPaymentsCount,
    required this.needReviewPaymentsCount,
    required this.studentsToWatchTomorrow,
  });

  bool get isClean =>
      unreviewedSessionsCount == 0 &&
      pendingParentContactsCount == 0 &&
      needReviewPaymentsCount == 0 &&
      studentsToWatchTomorrow.isEmpty;
}
