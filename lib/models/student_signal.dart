// File: lib/models/student_signal.dart

import 'dart:convert';
import 'student_timeline.dart';

enum StudentSignalType {
  UNEXCUSED_ABSENCE_WARNING,
  HOMEWORK_REPEATED_WARNING,
  LEARNING_SUPPORT_WARNING,
  POSITIVE_STREAK,
  PAYMENT_OVERDUE,
}

enum StudentSignalStatus { active, acknowledged, resolved, snoozed }

class StudentSignal {
  final int? id;
  final int studentId;
  final StudentSignalType signalType;
  final StudentSignalStatus status;
  final StudentTimelineSeverity severity;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? snoozedUntil;
  final Map<String, dynamic> metadata;

  StudentSignal({
    this.id,
    required this.studentId,
    required this.signalType,
    this.status = StudentSignalStatus.active,
    this.severity = StudentTimelineSeverity.warning,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.snoozedUntil,
    this.metadata = const {},
  });

  StudentSignal copyWith({
    int? id,
    int? studentId,
    StudentSignalType? signalType,
    StudentSignalStatus? status,
    StudentTimelineSeverity? severity,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? snoozedUntil,
    Map<String, dynamic>? metadata,
  }) {
    return StudentSignal(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      signalType: signalType ?? this.signalType,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'signal_type': signalType.name,
      'status': status.name.toUpperCase(),
      'severity': severity.name.toUpperCase(),
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'snoozed_until': snoozedUntil?.toIso8601String(),
      'metadata': jsonEncode(metadata),
    };
  }

  factory StudentSignal.fromMap(Map<String, dynamic> map) {
    StudentSignalStatus status;
    switch (map['status']?.toString().toUpperCase()) {
      case 'ACKNOWLEDGED':
        status = StudentSignalStatus.acknowledged;
        break;
      case 'RESOLVED':
        status = StudentSignalStatus.resolved;
        break;
      case 'SNOOZED':
        status = StudentSignalStatus.snoozed;
        break;
      default:
        status = StudentSignalStatus.active;
    }

    StudentTimelineSeverity severity;
    switch (map['severity']?.toString().toUpperCase()) {
      case 'INFO':
        severity = StudentTimelineSeverity.info;
        break;
      case 'POSITIVE':
        severity = StudentTimelineSeverity.positive;
        break;
      case 'ATTENTION':
        severity = StudentTimelineSeverity.attention;
        break;
      case 'CRITICAL':
        severity = StudentTimelineSeverity.critical;
        break;
      default:
        severity = StudentTimelineSeverity.warning;
    }

    StudentSignalType signalType;
    try {
      signalType = StudentSignalType.values.byName(map['signal_type']);
    } catch (_) {
      signalType = StudentSignalType.UNEXCUSED_ABSENCE_WARNING;
    }

    Map<String, dynamic> metadataMap = {};
    if (map['metadata'] != null && map['metadata'].toString().isNotEmpty) {
      try {
        metadataMap = jsonDecode(map['metadata']);
      } catch (_) {}
    }

    return StudentSignal(
      id: map['id'] as int?,
      studentId: map['student_id'] as int,
      signalType: signalType,
      status: status,
      severity: severity,
      title: map['title'] as String,
      description: map['description'] as String,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      snoozedUntil: map['snoozed_until'] != null
          ? DateTime.parse(map['snoozed_until'])
          : null,
      metadata: metadataMap,
    );
  }
}
