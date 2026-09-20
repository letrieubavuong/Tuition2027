enum BusyType {
  school,
  extraMath,
  extraEnglish,
  extraOther,
  personal,
  temporary,
  other;

  String toDbString() {
    switch (this) {
      case BusyType.school:
        return 'SCHOOL';
      case BusyType.extraMath:
        return 'EXTRA_MATH';
      case BusyType.extraEnglish:
        return 'EXTRA_ENGLISH';
      case BusyType.extraOther:
        return 'EXTRA_OTHER';
      case BusyType.personal:
        return 'PERSONAL';
      case BusyType.temporary:
        return 'TEMPORARY';
      case BusyType.other:
        return 'OTHER';
    }
  }

  static BusyType fromDbString(String val) {
    switch (val.toUpperCase()) {
      case 'SCHOOL':
        return BusyType.school;
      case 'EXTRA_MATH':
        return BusyType.extraMath;
      case 'EXTRA_ENGLISH':
        return BusyType.extraEnglish;
      case 'EXTRA_OTHER':
        return BusyType.extraOther;
      case 'PERSONAL':
        return BusyType.personal;
      case 'TEMPORARY':
        return BusyType.temporary;
      default:
        return BusyType.other;
    }
  }

  String get displayName {
    switch (this) {
      case BusyType.school:
        return 'Trường (Chính khóa / Buổi 2)';
      case BusyType.extraMath:
        return 'Học thêm Toán';
      case BusyType.extraEnglish:
        return 'Học thêm Anh';
      case BusyType.extraOther:
        return 'Học thêm môn khác';
      case BusyType.personal:
        return 'Cá nhân / Cố định';
      case BusyType.temporary:
        return 'Lịch bận tạm thời';
      case BusyType.other:
        return 'Khác';
    }
  }
}

enum RecurrenceType {
  weekly,
  dateRange,
  oneTime;

  String toDbString() {
    switch (this) {
      case RecurrenceType.weekly:
        return 'WEEKLY';
      case RecurrenceType.dateRange:
        return 'DATE_RANGE';
      case RecurrenceType.oneTime:
        return 'ONE_TIME';
    }
  }

  static RecurrenceType fromDbString(String val) {
    switch (val.toUpperCase()) {
      case 'WEEKLY':
        return RecurrenceType.weekly;
      case 'DATE_RANGE':
        return RecurrenceType.dateRange;
      case 'ONE_TIME':
        return RecurrenceType.oneTime;
      default:
        return RecurrenceType.weekly;
    }
  }

  String get displayName {
    switch (this) {
      case RecurrenceType.weekly:
        return 'Hàng tuần';
      case RecurrenceType.dateRange:
        return 'Khoảng ngày';
      case RecurrenceType.oneTime:
        return 'Một lần';
    }
  }
}

class StudentBusySchedule {
  final int? id;
  final int studentId;
  final BusyType type;
  final String title;
  final String? subject;
  final int? dayOfWeek; // 1 = Mon, ..., 7 = Sun
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final String effectiveFrom; // YYYY-MM-DD
  final String effectiveTo; // YYYY-MM-DD
  final RecurrenceType recurrenceType;
  final int priority;
  final String? note;
  final String? createdAt;
  final String? updatedAt;

  StudentBusySchedule({
    this.id,
    required this.studentId,
    required this.type,
    required this.title,
    this.subject,
    this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.effectiveFrom,
    required this.effectiveTo,
    this.recurrenceType = RecurrenceType.weekly,
    this.priority = 1,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'student_id': studentId,
      'type': type.toDbString(),
      'title': title,
      'subject': subject,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'effective_from': effectiveFrom,
      'effective_to': effectiveTo,
      'recurrence_type': recurrenceType.toDbString(),
      'priority': priority,
      'note': note,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    };
  }

  factory StudentBusySchedule.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic v) =>
        v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    return StudentBusySchedule(
      id: parseInt(map['id']),
      studentId: parseInt(map['student_id']) ?? 0,
      type: BusyType.fromDbString(map['type'] as String? ?? 'OTHER'),
      title: map['title'] as String? ?? '',
      subject: map['subject'] as String?,
      dayOfWeek: parseInt(map['day_of_week']),
      startTime: map['start_time'] as String? ?? '00:00',
      endTime: map['end_time'] as String? ?? '23:59',
      effectiveFrom: map['effective_from'] as String? ?? '',
      effectiveTo: map['effective_to'] as String? ?? '9999-12-31',
      recurrenceType: RecurrenceType.fromDbString(
        map['recurrence_type'] as String? ?? 'WEEKLY',
      ),
      priority: parseInt(map['priority']) ?? 1,
      note: map['note'] as String?,
      createdAt: map['created_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  StudentBusySchedule copyWith({
    int? id,
    int? studentId,
    BusyType? type,
    String? title,
    String? subject,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? effectiveFrom,
    String? effectiveTo,
    RecurrenceType? recurrenceType,
    int? priority,
    String? note,
    String? createdAt,
    String? updatedAt,
  }) {
    return StudentBusySchedule(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      type: type ?? this.type,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      priority: priority ?? this.priority,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
