// File: lib/models/attention_item.dart

import 'dart:convert';
import 'student_timeline.dart';

enum AttentionType {
  UNEXCUSED_ABSENCE,
  REPEATED_HOMEWORK_MISSING,
  LEARNING_SUPPORT_NEEDED,
  BEHAVIOR_ATTENTION,
  PARENT_CONTACT_PENDING,
  TUITION_REMINDER_DUE,
  PAYMENT_NEEDS_REVIEW,
  SESSION_ATTENDANCE_MISSING,
  SESSION_REVIEW_MISSING,
  SESSION_HOMEWORK_MISSING,
  DATA_WARNING,
  STUDENT_PARTICIPATION_WARNING,
  SCHEDULE_CONFLICT,
}

enum AttentionStatus { active, acknowledged, snoozed, resolved, dismissed }

enum AttentionSeverity { info, attention, warning, critical }

enum AttentionPriority { low, normal, high, urgent }

class AttentionItem {
  final String id;
  final AttentionType type;
  final AttentionSeverity severity;
  final AttentionPriority priority;
  final AttentionStatus status;
  final String title;
  final String summary;
  final int? studentId;
  final String? studentName;
  final int? classId;
  final String? className;
  final int? sessionId;
  final String sourceType;
  final dynamic sourceId;
  final DateTime createdAt;
  final DateTime? dueAt;
  final DateTime? snoozedUntil;
  final String
  actionType; // 'timeline', 'zalo', 'payment', 'review', 'attendance', 'data_fix'
  final String actionLabel;
  final Map<String, dynamic> metadata;

  AttentionItem({
    required this.id,
    required this.type,
    this.severity = AttentionSeverity.warning,
    this.priority = AttentionPriority.normal,
    this.status = AttentionStatus.active,
    required this.title,
    required this.summary,
    this.studentId,
    this.studentName,
    this.classId,
    this.className,
    this.sessionId,
    required this.sourceType,
    this.sourceId,
    required this.createdAt,
    this.dueAt,
    this.snoozedUntil,
    required this.actionType,
    required this.actionLabel,
    this.metadata = const {},
  });

  AttentionItem copyWith({
    String? id,
    AttentionType? type,
    AttentionSeverity? severity,
    AttentionPriority? priority,
    AttentionStatus? status,
    String? title,
    String? summary,
    int? studentId,
    String? studentName,
    int? classId,
    String? className,
    int? sessionId,
    String? sourceType,
    dynamic sourceId,
    DateTime? createdAt,
    DateTime? dueAt,
    DateTime? snoozedUntil,
    String? actionType,
    String? actionLabel,
    Map<String, dynamic>? metadata,
  }) {
    return AttentionItem(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      sessionId: sessionId ?? this.sessionId,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      createdAt: createdAt ?? this.createdAt,
      dueAt: dueAt ?? this.dueAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      actionType: actionType ?? this.actionType,
      actionLabel: actionLabel ?? this.actionLabel,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'severity': severity.name.toUpperCase(),
      'priority': priority.name.toUpperCase(),
      'status': status.name.toUpperCase(),
      'title': title,
      'summary': summary,
      'student_id': studentId,
      'student_name': studentName,
      'class_id': classId,
      'class_name': className,
      'session_id': sessionId,
      'source_type': sourceType,
      'source_id': sourceId?.toString(),
      'created_at': createdAt.toIso8601String(),
      'due_at': dueAt?.toIso8601String(),
      'snoozed_until': snoozedUntil?.toIso8601String(),
      'action_type': actionType,
      'action_label': actionLabel,
      'metadata': jsonEncode(metadata),
    };
  }

  factory AttentionItem.fromMap(Map<String, dynamic> map) {
    AttentionType type;
    try {
      type = AttentionType.values.byName(map['type']);
    } catch (_) {
      type = AttentionType.DATA_WARNING;
    }

    AttentionSeverity severity;
    switch (map['severity']?.toString().toUpperCase()) {
      case 'INFO':
        severity = AttentionSeverity.info;
        break;
      case 'ATTENTION':
        severity = AttentionSeverity.attention;
        break;
      case 'CRITICAL':
        severity = AttentionSeverity.critical;
        break;
      default:
        severity = AttentionSeverity.warning;
    }

    AttentionPriority priority;
    switch (map['priority']?.toString().toUpperCase()) {
      case 'LOW':
        priority = AttentionPriority.low;
        break;
      case 'HIGH':
        priority = AttentionPriority.high;
        break;
      case 'URGENT':
        priority = AttentionPriority.urgent;
        break;
      default:
        priority = AttentionPriority.normal;
    }

    AttentionStatus status;
    switch (map['status']?.toString().toUpperCase()) {
      case 'ACKNOWLEDGED':
        status = AttentionStatus.acknowledged;
        break;
      case 'SNOOZED':
        status = AttentionStatus.snoozed;
        break;
      case 'RESOLVED':
        status = AttentionStatus.resolved;
        break;
      case 'DISMISSED':
        status = AttentionStatus.dismissed;
        break;
      default:
        status = AttentionStatus.active;
    }

    Map<String, dynamic> meta = {};
    if (map['metadata'] != null && map['metadata'].toString().isNotEmpty) {
      try {
        meta = jsonDecode(map['metadata']);
      } catch (_) {}
    }

    return AttentionItem(
      id: map['id']?.toString() ?? '',
      type: type,
      severity: severity,
      priority: priority,
      status: status,
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      studentId: map['student_id'] as int?,
      studentName: map['student_name'] as String?,
      classId: map['class_id'] as int?,
      className: map['class_name'] as String?,
      sessionId: map['session_id'] as int?,
      sourceType: map['source_type'] as String? ?? 'system',
      sourceId: map['source_id'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      dueAt: map['due_at'] != null ? DateTime.parse(map['due_at']) : null,
      snoozedUntil: map['snoozed_until'] != null
          ? DateTime.parse(map['snoozed_until'])
          : null,
      actionType: map['action_type'] as String? ?? 'timeline',
      actionLabel: map['action_label'] as String? ?? 'Xem Chi tiết',
      metadata: meta,
    );
  }
}
