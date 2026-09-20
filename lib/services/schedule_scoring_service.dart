import '../models/schedule_suggestion.dart';
import '../models/student_busy_schedule.dart';
import 'schedule_candidate_service.dart';
import 'schedule_conflict_service.dart';

class ScoringWeights {
  static const double baseScore = 60.0;
  static const double hardConflictPenalty = 1000.0;
  static const double bufferLessThanMinPenalty = 50.0;
  static const double buffer30To60Penalty = 20.0;
  static const double lateSessionPenalty = 15.0;
  static const double differentDayPenalty = 10.0;
  static const double nearCapacityPenalty = 15.0;
  static const double overCapacityPenalty = 100.0;
  static const double stabilityBonus = 20.0;
  static const double historyFrequencyBonus = 15.0;
  static const double plentyCapacityBonus = 10.0;
  static const double cleanScheduleBonus = 10.0;

  // Minimum score difference required to recommend switching away from current assignment
  static const double switchingThreshold = 15.0;
}

class ScheduleScoringService {
  static final ScheduleScoringService instance =
      ScheduleScoringService._internal();
  ScheduleScoringService._internal();

  ScheduleSuggestion scoreCandidate({
    required int studentId,
    required CandidateSession candidate,
    required String dateStr,
    required List<StudentBusySchedule> busySchedules,
    required bool isCurrentAssignment,
    bool isFrequentlyAttended = false,
    String? historyEvidence,
    int minimumBufferMinutes = 30,
  }) {
    const dayNameMap = {
      1: 'T2',
      2: 'T3',
      3: 'T4',
      4: 'T5',
      5: 'T6',
      6: 'T7',
      7: 'CN',
    };
    double score = ScoringWeights.baseScore;
    final List<String> reasons = [];

    // 1. Conflict evaluation
    final conflictRes = ScheduleConflictService.instance.checkConflict(
      candidateDayOfWeek: candidate.dayOfWeek,
      candidateStartTime: candidate.startTime,
      candidateEndTime: candidate.endTime,
      dateStr: dateStr,
      busySchedules: busySchedules,
      minimumBufferMinutes: minimumBufferMinutes,
    );

    // Merge conflict reasons
    reasons.addAll(conflictRes.reasons);

    if (conflictRes.level == ConflictLevel.hardConflict) {
      score -= ScoringWeights.hardConflictPenalty;
    } else if (conflictRes.level == ConflictLevel.softConflict) {
      score -= ScoringWeights.bufferLessThanMinPenalty;
    } else {
      // Buffer between 30 and 60 minutes
      if (conflictRes.minGapMinutes >= 30 && conflictRes.minGapMinutes < 60) {
        score -= ScoringWeights.buffer30To60Penalty;
        reasons.add(
          '• Nghỉ giữa hai ca là ${conflictRes.minGapMinutes} phút (-20đ)',
        );
      } else if (conflictRes.minGapMinutes >= 60 && busySchedules.isNotEmpty) {
        score += ScoringWeights.cleanScheduleBonus;
        reasons.add('✓ Không conflict cả trước và sau (+10đ)');
      }
    }

    // 2. Late session check
    final startHour = int.tryParse(candidate.startTime.split(':')[0]) ?? 0;
    if (startHour >= 20) {
      score -= ScoringWeights.lateSessionPenalty;
      reasons.add('• Ca khá muộn (${candidate.startTime}) (-15đ)');
    }

    // 3. Capacity check
    if (candidate.currentCapacity >= candidate.maxCapacity) {
      score -= ScoringWeights.overCapacityPenalty;
      reasons.add(
        '✕ Lớp đã đầy (${candidate.currentCapacity}/${candidate.maxCapacity}) (-100đ)',
      );
    } else if (candidate.currentCapacity >= (candidate.maxCapacity * 0.85)) {
      score -= ScoringWeights.nearCapacityPenalty;
      reasons.add(
        '• Ca gần full (${candidate.currentCapacity}/${candidate.maxCapacity}) (-15đ)',
      );
    } else if (candidate.currentCapacity <= (candidate.maxCapacity * 0.5)) {
      score += ScoringWeights.plentyCapacityBonus;
      reasons.add(
        '✓ Còn nhiều chỗ (${candidate.currentCapacity}/${candidate.maxCapacity}) (+10đ)',
      );
    }

    // 4. Stability Bonus & Disruption Minimization
    if (isCurrentAssignment) {
      score += ScoringWeights.stabilityBonus;
      reasons.add('★ Giữ đúng ca hiện tại (+20đ)');
    }

    // 5. Attendance history frequency bonus
    if (isFrequentlyAttended) {
      score += ScoringWeights.historyFrequencyBonus;
      if (historyEvidence != null && historyEvidence.isNotEmpty) {
        reasons.add('✓ Thường học ca này: $historyEvidence (+15đ)');
      } else {
        reasons.add('✓ Ca HS thường xuyên tham gia (+15đ)');
      }
    }

    // Hard constraints check: If hard conflict or over capacity, clamp score to 0
    if (conflictRes.level == ConflictLevel.hardConflict ||
        candidate.currentCapacity >= candidate.maxCapacity) {
      return ScheduleSuggestion(
        studentId: studentId,
        classId: candidate.classId,
        scheduleId: candidate.schedule.id ?? 0,
        dayOfWeek: candidate.dayOfWeek,
        dayName: dayNameMap[candidate.dayOfWeek] ?? 'T2',
        startTime: candidate.startTime,
        endTime: candidate.endTime,
        className: candidate.className,
        score: 0.0,
        conflictLevel: candidate.currentCapacity >= candidate.maxCapacity
            ? ConflictLevel.hardConflict
            : conflictRes.level,
        reasons: reasons,
        isCurrentAssignment: isCurrentAssignment,
        currentCapacity: candidate.currentCapacity,
        maxCapacity: candidate.maxCapacity,
      );
    }

    // Clamp score to range [0, 100]
    final finalScore = score.clamp(0.0, 100.0);

    final dayName = dayNameMap[candidate.dayOfWeek] ?? 'T2';

    return ScheduleSuggestion(
      studentId: studentId,
      classId: candidate.classId,
      scheduleId: candidate.schedule.id ?? 0,
      dayOfWeek: candidate.dayOfWeek,
      dayName: dayName,
      startTime: candidate.startTime,
      endTime: candidate.endTime,
      className: candidate.className,
      score: finalScore,
      conflictLevel: conflictRes.level,
      reasons: reasons,
      isCurrentAssignment: isCurrentAssignment,
      currentCapacity: candidate.currentCapacity,
      maxCapacity: candidate.maxCapacity,
    );
  }
}
