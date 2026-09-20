// File: lib/models/dashboard_action_item.dart

import 'dart:convert';

enum DashboardItemType {
  attendance,
  tuitionDebt,
  assignment,
  studentAttention,
  sessionReview,
  schedule,
  reminder,
  dataWarning,
  paymentReview,
  parentContact,
}

enum DashboardPriority {
  critical,
  high,
  medium,
  info,
}

class DashboardActionItem {
  final String id;
  final DashboardItemType type;
  final DashboardPriority priority;
  final String title;
  final String description;
  final int? classId;
  final String? className;
  final int? studentId;
  final String? studentName;
  final int? scheduleId;
  final DateTime? date;
  final DateTime? dueDate;
  final int? amount;
  final String actionType; // 'attendance', 'sessionReview', 'tuition', 'student', 'zalo', 'task', 'schedule', 'data_fix'
  final String actionLabel;
  final Map<String, dynamic> metadata;

  DashboardActionItem({
    required this.id,
    required this.type,
    this.priority = DashboardPriority.medium,
    required this.title,
    required this.description,
    this.classId,
    this.className,
    this.studentId,
    this.studentName,
    this.scheduleId,
    this.date,
    this.dueDate,
    this.amount,
    required this.actionType,
    required this.actionLabel,
    this.metadata = const {},
  });

  DashboardActionItem copyWith({
    String? id,
    DashboardItemType? type,
    DashboardPriority? priority,
    String? title,
    String? description,
    int? classId,
    String? className,
    int? studentId,
    String? studentName,
    int? scheduleId,
    DateTime? date,
    DateTime? dueDate,
    int? amount,
    String? actionType,
    String? actionLabel,
    Map<String, dynamic>? metadata,
  }) {
    return DashboardActionItem(
      id: id ?? this.id,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      description: description ?? this.description,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      scheduleId: scheduleId ?? this.scheduleId,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      amount: amount ?? this.amount,
      actionType: actionType ?? this.actionType,
      actionLabel: actionLabel ?? this.actionLabel,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'description': description,
      'classId': classId,
      'className': className,
      'studentId': studentId,
      'studentName': studentName,
      'scheduleId': scheduleId,
      'date': date?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'amount': amount,
      'actionType': actionType,
      'actionLabel': actionLabel,
      'metadata': jsonEncode(metadata),
    };
  }

  factory DashboardActionItem.fromMap(Map<String, dynamic> map) {
    return DashboardActionItem(
      id: map['id']?.toString() ?? '',
      type: DashboardItemType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DashboardItemType.reminder,
      ),
      priority: DashboardPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => DashboardPriority.medium,
      ),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      classId: map['classId'] as int?,
      className: map['className']?.toString(),
      studentId: map['studentId'] as int?,
      studentName: map['studentName']?.toString(),
      scheduleId: map['scheduleId'] as int?,
      date: map['date'] != null ? DateTime.tryParse(map['date'].toString()) : null,
      dueDate: map['dueDate'] != null ? DateTime.tryParse(map['dueDate'].toString()) : null,
      amount: map['amount'] as int?,
      actionType: map['actionType']?.toString() ?? 'detail',
      actionLabel: map['actionLabel']?.toString() ?? 'Xem',
      metadata: map['metadata'] is String
          ? (jsonDecode(map['metadata']) as Map<String, dynamic>? ?? {})
          : (map['metadata'] as Map<String, dynamic>? ?? {}),
    );
  }
}
