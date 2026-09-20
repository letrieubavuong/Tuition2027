enum ConflictLevel {
  noConflict,
  softConflict,
  hardConflict;

  String get displayName {
    switch (this) {
      case ConflictLevel.noConflict:
        return 'Không xung đột';
      case ConflictLevel.softConflict:
        return 'Xung đột nhẹ / Sát giờ';
      case ConflictLevel.hardConflict:
        return 'Trùng lịch (Cương quyết)';
    }
  }
}

class ScheduleSuggestion {
  final int studentId;
  final int classId;
  final int scheduleId;
  final int dayOfWeek; // 1 = Mon..7 = Sun
  final String dayName; // "T2", "T3"...
  final String startTime; // "19:00"
  final String endTime; // "20:30"
  final String className;
  final double score;
  final ConflictLevel conflictLevel;
  final List<String> reasons;
  final bool isCurrentAssignment;
  final int currentCapacity;
  final int maxCapacity;

  ScheduleSuggestion({
    required this.studentId,
    required this.classId,
    required this.scheduleId,
    required this.dayOfWeek,
    required this.dayName,
    required this.startTime,
    required this.endTime,
    required this.className,
    required this.score,
    required this.conflictLevel,
    required this.reasons,
    this.isCurrentAssignment = false,
    this.currentCapacity = 0,
    this.maxCapacity = 30,
  });

  String get fitLabel {
    if (conflictLevel == ConflictLevel.hardConflict) {
      return 'Không phù hợp';
    }
    if (score >= 85) {
      return 'Rất phù hợp';
    } else if (score >= 70) {
      return 'Phù hợp';
    } else if (score >= 50) {
      return 'Cần cân nhắc';
    } else {
      return 'Không phù hợp';
    }
  }

  bool get isRecommended =>
      conflictLevel != ConflictLevel.hardConflict && score >= 50;
}

class StudentWeeklyAnalysis {
  final int studentId;
  final String studentName;
  final List<ScheduleSuggestion> suggestions;
  final ScheduleSuggestion? currentAssignment;
  final ScheduleSuggestion? topSuggestion;
  final bool hasConflict;
  final String conflictSummary;

  StudentWeeklyAnalysis({
    required this.studentId,
    required this.studentName,
    required this.suggestions,
    this.currentAssignment,
    this.topSuggestion,
    required this.hasConflict,
    required this.conflictSummary,
  });
}

class BatchWeeklyAnalysisResult {
  final String weekRange; // "21/09–27/09"
  final int totalStudents;
  final List<StudentWeeklyAnalysis> unchangedStudents;
  final List<StudentWeeklyAnalysis> conflictedStudents;
  final List<StudentWeeklyAnalysis> suggestedChanges;
  final List<StudentWeeklyAnalysis> unresolvedStudents;

  BatchWeeklyAnalysisResult({
    required this.weekRange,
    required this.totalStudents,
    required this.unchangedStudents,
    required this.conflictedStudents,
    required this.suggestedChanges,
    required this.unresolvedStudents,
  });
}
