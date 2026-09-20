// File: lib/models/student_timeline.dart

import 'student_signal.dart';

enum StudentTimelineFilter {
  all,
  session,
  absence,
  homework,
  payment,
  parentContact,
  warning,
}

enum StudentTimelineSeverity { info, positive, attention, warning, critical }

abstract class StudentTimelineItem {
  final String id;
  final int studentId;
  final DateTime eventDateTime;
  final String title;
  final String summary;

  const StudentTimelineItem({
    required this.id,
    required this.studentId,
    required this.eventDateTime,
    required this.title,
    required this.summary,
  });
}

class StudentSessionTimelineItem extends StudentTimelineItem {
  final int? classId;
  final String? className;
  final int? sessionId;
  final DateTime sessionDate;
  final String? startTime;
  final String? endTime;
  final String
  attendanceStatus; // 'Có mặt', 'Trễ', 'Nghỉ có phép', 'Nghỉ không phép', 'Học bù'
  final double? diemThaiDo;
  final double? diemHieuBai;
  final double? diemBaiTap;
  final String? resultBtvn; // 'Đầy đủ', 'Thiếu', 'Không làm'
  final String? assignedHomework; // Bài tập được giao trong buổi
  final String? teacherComment; // Nhận xét của giáo viên

  const StudentSessionTimelineItem({
    required super.id,
    required super.studentId,
    required super.eventDateTime,
    required super.title,
    required super.summary,
    this.classId,
    this.className,
    this.sessionId,
    required this.sessionDate,
    this.startTime,
    this.endTime,
    required this.attendanceStatus,
    this.diemThaiDo,
    this.diemHieuBai,
    this.diemBaiTap,
    this.resultBtvn,
    this.assignedHomework,
    this.teacherComment,
  });
}

class StudentPaymentTimelineItem extends StudentTimelineItem {
  final int? transactionId;
  final int? classId;
  final String? className;
  final int amount;
  final String? month;
  final String? paymentMethod;
  final String? note;

  const StudentPaymentTimelineItem({
    required super.id,
    required super.studentId,
    required super.eventDateTime,
    required super.title,
    required super.summary,
    this.transactionId,
    this.classId,
    this.className,
    required this.amount,
    this.month,
    this.paymentMethod,
    this.note,
  });
}

class StudentParentContactTimelineItem extends StudentTimelineItem {
  final int? commId;
  final int? classId;
  final String? className;
  final String contactType;
  final String reason;
  final String content;
  final String status;

  const StudentParentContactTimelineItem({
    required super.id,
    required super.studentId,
    required super.eventDateTime,
    required super.title,
    required super.summary,
    this.commId,
    this.classId,
    this.className,
    required this.contactType,
    required this.reason,
    required this.content,
    required this.status,
  });
}

class StudentSignalTimelineItem extends StudentTimelineItem {
  final int? signalId;
  final StudentSignalType signalType;
  final StudentSignalStatus status;
  final StudentTimelineSeverity severity;
  final DateTime? snoozedUntil;
  final Map<String, dynamic> metadata;

  const StudentSignalTimelineItem({
    required super.id,
    required super.studentId,
    required super.eventDateTime,
    required super.title,
    required super.summary,
    this.signalId,
    required this.signalType,
    required this.status,
    required this.severity,
    this.snoozedUntil,
    this.metadata = const {},
  });
}

class StudentMembershipTimelineItem extends StudentTimelineItem {
  final int? classId;
  final String className;
  final bool isJoin;

  const StudentMembershipTimelineItem({
    required super.id,
    required super.studentId,
    required super.eventDateTime,
    required super.title,
    required super.summary,
    this.classId,
    required this.className,
    required this.isJoin,
  });
}

class StudentSummaryStatus {
  final String attendanceSummary;
  final String homeworkSummary;
  final String attitudeSummary;
  final String comprehensionSummary;
  final String tuitionStatus;
  final int parentContactCount;
  final int activeWarningsCount;
  final String? activeWarningMessage;

  StudentSummaryStatus({
    required this.attendanceSummary,
    required this.homeworkSummary,
    required this.attitudeSummary,
    required this.comprehensionSummary,
    required this.tuitionStatus,
    required this.parentContactCount,
    required this.activeWarningsCount,
    this.activeWarningMessage,
  });
}
