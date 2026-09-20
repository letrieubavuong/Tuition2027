import 'student_busy_schedule.dart';

enum AssignmentSource {
  manual,
  smartSuggestionAccepted,
  makeup,
  temporaryOverride;

  String toDbString() {
    switch (this) {
      case AssignmentSource.manual:
        return 'MANUAL';
      case AssignmentSource.smartSuggestionAccepted:
        return 'SMART_SUGGESTION_ACCEPTED';
      case AssignmentSource.makeup:
        return 'MAKEUP';
      case AssignmentSource.temporaryOverride:
        return 'TEMPORARY_OVERRIDE';
    }
  }

  static AssignmentSource fromDbString(String val) {
    switch (val.toUpperCase()) {
      case 'MANUAL':
        return AssignmentSource.manual;
      case 'SMART_SUGGESTION_ACCEPTED':
        return AssignmentSource.smartSuggestionAccepted;
      case 'MAKEUP':
        return AssignmentSource.makeup;
      case 'TEMPORARY_OVERRIDE':
        return AssignmentSource.temporaryOverride;
      default:
        return AssignmentSource.manual;
    }
  }

  String get displayName {
    switch (this) {
      case AssignmentSource.manual:
        return 'Thủ công';
      case AssignmentSource.smartSuggestionAccepted:
        return 'Gợi ý thông minh';
      case AssignmentSource.makeup:
        return 'Học bù';
      case AssignmentSource.temporaryOverride:
        return 'Tạm thời';
    }
  }
}

class StudentScheduleAssignment {
  final int? id;
  final int studentId;
  final int classId;
  final int? scheduleId;
  final String effectiveFrom; // YYYY-MM-DD
  final String effectiveTo; // YYYY-MM-DD
  final AssignmentSource source;
  final RecurrenceType recurrenceType;
  final int? dayOfWeek; // 1=Mon, ..., 7=Sun
  final String? startTime; // HH:mm
  final String? endTime; // HH:mm
  final int priority; // 1=REGULAR, 2=TEMPORARY, 3=ONE_TIME
  final String? createdAt;
  final String? updatedAt;

  StudentScheduleAssignment({
    this.id,
    required this.studentId,
    required this.classId,
    this.scheduleId,
    required this.effectiveFrom,
    required this.effectiveTo,
    this.source = AssignmentSource.manual,
    this.recurrenceType = RecurrenceType.weekly,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.priority = 1,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'student_id': studentId,
      'class_id': classId,
      'schedule_id': scheduleId,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
      'source': source.toDbString(),
      'recurrence_type': recurrenceType.toDbString(),
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'priority': priority,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory StudentScheduleAssignment.fromMap(Map<String, dynamic> map) {
    return StudentScheduleAssignment(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      classId: map['class_id'] as int,
      scheduleId: map['schedule_id'] as int?,
      effectiveFrom: map['effective_from'] as String? ?? '',
      effectiveTo: map['effective_to'] as String? ?? '9999-12-31',
      source: AssignmentSource.fromDbString(
        map['source'] as String? ?? 'MANUAL',
      ),
      recurrenceType: RecurrenceType.fromDbString(
        map['recurrence_type'] as String? ?? 'WEEKLY',
      ),
      dayOfWeek: map['day_of_week'] as int?,
      startTime: map['start_time'] as String?,
      endTime: map['end_time'] as String?,
      priority: map['priority'] as int? ?? 1,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  StudentScheduleAssignment copyWith({
    int? id,
    int? studentId,
    int? classId,
    int? scheduleId,
    String? effectiveFrom,
    String? effectiveTo,
    AssignmentSource? source,
    RecurrenceType? recurrenceType,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    int? priority,
    String? createdAt,
    String? updatedAt,
  }) {
    return StudentScheduleAssignment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      classId: classId ?? this.classId,
      scheduleId: scheduleId ?? this.scheduleId,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      source: source ?? this.source,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
