// File: lib/models/session_close_result.dart

enum SessionCloseStatus { completed, completedWithWarnings, failed }

class PipelineStepResult {
  final String stepName;
  final bool success;
  final String? message;
  final dynamic data;

  PipelineStepResult({
    required this.stepName,
    required this.success,
    this.message,
    this.data,
  });
}

class SessionCloseResult {
  final int classId;
  final String className;
  final int? sessionId;
  final DateTime sessionDate;
  final SessionCloseStatus status;
  final Map<String, PipelineStepResult> stepResults;
  final List<String> warnings;
  final int studentsCount;
  final int attendanceSavedCount;
  final int reviewSavedCount;
  final int homeworkAssignedCount;
  final int parentContactsGeneratedCount;
  final int attentionItemsUpdatedCount;

  SessionCloseResult({
    required this.classId,
    required this.className,
    this.sessionId,
    required this.sessionDate,
    required this.status,
    required this.stepResults,
    required this.warnings,
    required this.studentsCount,
    required this.attendanceSavedCount,
    required this.reviewSavedCount,
    required this.homeworkAssignedCount,
    required this.parentContactsGeneratedCount,
    required this.attentionItemsUpdatedCount,
  });

  bool get isSuccess =>
      status == SessionCloseStatus.completed ||
      status == SessionCloseStatus.completedWithWarnings;
}
