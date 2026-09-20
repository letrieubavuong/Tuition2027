// File: lib/models/attendance_change_log.dart

class AttendanceChangeLogAction {
  static const String editStatus = 'EDIT_STATUS';
  static const String removeStudent = 'REMOVE_STUDENT';
  static const String editSession = 'EDIT_SESSION';
  static const String cancelSession = 'CANCEL_SESSION';
  static const String restoreSession = 'RESTORE_SESSION';
}

class AttendanceChangeLog {
  final int? id;
  final int? attendanceId;
  final int? studentId;
  final int? sessionId;
  final int classId;
  final String
  action; // EDIT_STATUS, REMOVE_STUDENT, EDIT_SESSION, CANCEL_SESSION, RESTORE_SESSION
  final String? oldStatus;
  final String? newStatus;
  final String? oldDatetime;
  final String? newDatetime;
  final String? reason;
  final DateTime changedAt;

  AttendanceChangeLog({
    this.id,
    this.attendanceId,
    this.studentId,
    this.sessionId,
    required this.classId,
    required this.action,
    this.oldStatus,
    this.newStatus,
    this.oldDatetime,
    this.newDatetime,
    this.reason,
    required this.changedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'attendance_id': attendanceId,
      'student_id': studentId,
      'session_id': sessionId,
      'class_id': classId,
      'action': action,
      'old_status': oldStatus,
      'new_status': newStatus,
      'old_datetime': oldDatetime,
      'new_datetime': newDatetime,
      'reason': reason,
      'changed_at': changedAt.toIso8601String(),
    };
  }

  factory AttendanceChangeLog.fromMap(Map<String, dynamic> map) {
    return AttendanceChangeLog(
      id: map['id'] as int?,
      attendanceId: map['attendance_id'] as int?,
      studentId: map['student_id'] as int?,
      sessionId: map['session_id'] as int?,
      classId: map['class_id'] as int,
      action: map['action'] as String,
      oldStatus: map['old_status'] as String?,
      newStatus: map['new_status'] as String?,
      oldDatetime: map['old_datetime'] as String?,
      newDatetime: map['new_datetime'] as String?,
      reason: map['reason'] as String?,
      changedAt: DateTime.parse(map['changed_at'] as String),
    );
  }
}
