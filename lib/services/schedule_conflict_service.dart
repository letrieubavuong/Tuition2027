import '../models/schedule_suggestion.dart';
import '../models/student_busy_schedule.dart';

class ConflictResult {
  final ConflictLevel level;
  final List<String> reasons;
  final int minGapMinutes;

  ConflictResult({
    required this.level,
    required this.reasons,
    this.minGapMinutes = 999,
  });
}

class ScheduleConflictService {
  static final ScheduleConflictService instance =
      ScheduleConflictService._internal();
  ScheduleConflictService._internal();

  /// Converts "HH:mm" to total minutes from 00:00
  int _parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  ConflictResult checkConflict({
    required int candidateDayOfWeek, // 1..7
    required String candidateStartTime, // "18:00"
    required String candidateEndTime, // "19:30"
    required String dateStr, // YYYY-MM-DD
    required List<StudentBusySchedule> busySchedules,
    int minimumBufferMinutes = 30,
  }) {
    final candStart = _parseTimeToMinutes(candidateStartTime);
    final candEnd = _parseTimeToMinutes(candidateEndTime);

    ConflictLevel currentLevel = ConflictLevel.noConflict;
    final List<String> reasons = [];
    int minGap = 999;

    for (var busy in busySchedules) {
      // Check day matching for weekly or dateRange
      if (busy.recurrenceType == RecurrenceType.weekly ||
          busy.recurrenceType == RecurrenceType.dateRange) {
        if (busy.dayOfWeek != null && busy.dayOfWeek != candidateDayOfWeek) {
          continue;
        }
      } else if (busy.recurrenceType == RecurrenceType.oneTime) {
        if (busy.effectiveFrom != dateStr) {
          continue;
        }
      }

      final bStart = _parseTimeToMinutes(busy.startTime);
      final bEnd = _parseTimeToMinutes(busy.endTime);

      // 1. HARD OVERLAP CHECK
      if (candStart < bEnd && candEnd > bStart) {
        currentLevel = ConflictLevel.hardConflict;
        reasons.add(
          '✕ Trùng lịch ${busy.type.displayName}: ${busy.title} (${busy.startTime}–${busy.endTime})',
        );
      } else {
        // 2. BUFFER CHECK
        if (candStart >= bEnd) {
          final gapBefore = candStart - bEnd;
          if (gapBefore < minGap) minGap = gapBefore;
          if (gapBefore < minimumBufferMinutes) {
            if (currentLevel != ConflictLevel.hardConflict) {
              currentLevel = ConflictLevel.softConflict;
            }
            reasons.add(
              '⚠ Chỉ cách lịch tan ${busy.title} $gapBefore phút (khuyên dùng ≥ $minimumBufferMinutes phút)',
            );
          }
        } else if (bStart >= candEnd) {
          final gapAfter = bStart - candEnd;
          if (gapAfter < minGap) minGap = gapAfter;
          if (gapAfter < minimumBufferMinutes) {
            if (currentLevel != ConflictLevel.hardConflict) {
              currentLevel = ConflictLevel.softConflict;
            }
            reasons.add(
              '⚠ Sát giờ lịch kế tiếp ${busy.title} ($gapAfter phút)',
            );
          }
        }
      }
    }

    if (currentLevel == ConflictLevel.noConflict) {
      reasons.add('✓ Không trùng lịch bận');
    }

    return ConflictResult(
      level: currentLevel,
      reasons: reasons,
      minGapMinutes: minGap,
    );
  }
}
