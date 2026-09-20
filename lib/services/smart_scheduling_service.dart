import 'package:sqflite/sqflite.dart';
import '../models/schedule_suggestion.dart';
import '../models/student_busy_schedule.dart';
import '../models/student_schedule_assignment.dart';
import '../utils/db.dart';
import 'schedule_candidate_service.dart';
import 'schedule_scoring_service.dart';
import 'student_busy_schedule_service.dart';
import 'student_schedule_assignment_service.dart';

class FinancialLockException implements Exception {
  final String message;
  FinancialLockException(this.message);
  @override
  String toString() => message;
}

class SmartSchedulingConfig {
  static const int attendanceHistoryLookbackDays = 42; // 6 weeks
  static const int minimumFrequentAttendanceCount = 3;
  static const double frequentAttendanceRatio = 0.4;
}

class SmartSchedulingService {
  static final SmartSchedulingService instance =
      SmartSchedulingService._internal();
  SmartSchedulingService._internal();

  Future<Database> get _db async => await DBHelper.instance.database;

  /// Helper to fetch attendance history frequency map for a student or set of students.
  /// Returns Map of studentId to slotKey to attendedCount.
  Future<Map<int, Map<String, int>>> _getAttendanceFrequencyMap({
    required List<int> studentIds,
    required String weekStartDate,
  }) async {
    if (studentIds.isEmpty) return {};
    final db = await _db;
    final startDt = DateTime.parse(weekStartDate);
    final lookbackStart = startDt
        .subtract(
          const Duration(
            days: SmartSchedulingConfig.attendanceHistoryLookbackDays,
          ),
        )
        .toIso8601String()
        .substring(0, 10);

    final placeholders = List.filled(studentIds.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT id_hoc_sinh, gio_diem_danh, trang_thai
      FROM ${DBHelper.tenBangDiemDanh}
      WHERE id_hoc_sinh IN ($placeholders)
        AND gio_diem_danh >= ?
        AND trang_thai IN ('Có mặt', 'Trễ', 'Học bù')
    ''',
      [...studentIds, lookbackStart],
    );

    // Result structure: studentId -> slotKey (e.g. "2_17:30") -> attendedCount
    final Map<int, Map<String, int>> resultMap = {};
    for (var row in rows) {
      final sId = row['id_hoc_sinh'] as int;
      final gioStr = row['gio_diem_danh'] as String;
      DateTime? dt = DateTime.tryParse(gioStr);
      if (dt == null) continue;

      final dayOfWeek = dt.weekday; // 1 = Mon..7 = Sun
      final hourStr = dt.hour.toString().padLeft(2, '0');
      final minStr = dt.minute.toString().padLeft(2, '0');
      final timeStr = '$hourStr:$minStr';

      final slotKey = '${dayOfWeek}_$timeStr';
      resultMap.putIfAbsent(sId, () => {});
      final studentSlots = resultMap[sId]!;
      studentSlots[slotKey] = (studentSlots[slotKey] ?? 0) + 1;
    }

    return resultMap;
  }

  /// Generate scheduling suggestions for a single student for a specific week starting on weekStartDate (YYYY-MM-DD).
  /// FIREWALL: Returns proposals only; DOES NOT modify database or tuition/ledger tables.
  Future<List<ScheduleSuggestion>> getSuggestionsForStudent({
    required int studentId,
    required String weekStartDate, // YYYY-MM-DD (e.g. Monday)
    int bufferMinutes = 30,
  }) async {
    final startDt = DateTime.parse(weekStartDate);
    final endDt = startDt.add(const Duration(days: 6));
    final weekEndDate = endDt.toIso8601String().substring(0, 10);

    // 1. Fetch active busy schedules for student
    final busySchedules = await StudentBusyScheduleService.instance
        .getBusySchedulesForStudentInRange(
          studentId,
          weekStartDate,
          weekEndDate,
        );

    // 2. Fetch candidate physics sessions
    final candidates = await ScheduleCandidateService.instance
        .getCandidateSessionsForStudent(
          studentId: studentId,
          fromDate: weekStartDate,
          toDate: weekEndDate,
        );

    // 3. Fetch active current assignment
    final currentAssignment = await StudentScheduleAssignmentService.instance
        .getActiveAssignmentForStudentOnDate(studentId, weekStartDate);

    // 4. Fetch attendance history
    final historyMap = await _getAttendanceFrequencyMap(
      studentIds: [studentId],
      weekStartDate: weekStartDate,
    );
    final studentHistory = historyMap[studentId] ?? {};
    int totalAttendedSessions = studentHistory.values.fold(
      0,
      (sum, cnt) => sum + cnt,
    );

    // 5. Score each candidate
    final List<ScheduleSuggestion> suggestions = [];
    for (var candidate in candidates) {
      final isCurrent =
          (currentAssignment != null &&
          currentAssignment.classId == candidate.classId &&
          (currentAssignment.scheduleId == null ||
              currentAssignment.scheduleId == candidate.schedule.id));

      // Match candidate slot key in history
      final candidateHour = candidate.startTime.substring(0, 2);
      final slotKeyPrefix = '${candidate.dayOfWeek}_$candidateHour';

      int candidateAttendedCount = 0;
      studentHistory.forEach((key, count) {
        if (key.startsWith(slotKeyPrefix) ||
            key.startsWith('${candidate.dayOfWeek}_')) {
          // Check if time matches candidate start time within ~45 mins
          final parts = key.split('_');
          if (parts.length == 2) {
            final tParts = parts[1].split(':');
            if (tParts.length == 2) {
              final h = int.tryParse(tParts[0]) ?? 0;
              final m = int.tryParse(tParts[1]) ?? 0;
              final candH =
                  int.tryParse(candidate.startTime.split(':')[0]) ?? 0;
              final candM =
                  int.tryParse(candidate.startTime.split(':')[1]) ?? 0;
              final diffMins = ((h * 60 + m) - (candH * 60 + candM)).abs();
              if (diffMins <= 45) {
                candidateAttendedCount += count;
              }
            }
          }
        }
      });

      final bool isFrequentlyAttended =
          candidateAttendedCount >=
              SmartSchedulingConfig.minimumFrequentAttendanceCount &&
          (totalAttendedSessions > 0 &&
              (candidateAttendedCount / totalAttendedSessions) >=
                  SmartSchedulingConfig.frequentAttendanceRatio);

      final String? historyEvidence = isFrequentlyAttended
          ? '$candidateAttendedCount/$totalAttendedSessions buổi gần đây'
          : null;

      final suggestion = ScheduleScoringService.instance.scoreCandidate(
        studentId: studentId,
        candidate: candidate,
        dateStr: weekStartDate,
        busySchedules: busySchedules,
        isCurrentAssignment: isCurrent,
        isFrequentlyAttended: isFrequentlyAttended,
        historyEvidence: historyEvidence,
        minimumBufferMinutes: bufferMinutes,
      );
      suggestions.add(suggestion);
    }

    // Sort by score DESC
    suggestions.sort((a, b) => b.score.compareTo(a.score));
    return suggestions;
  }

  /// Exception-First Batch Analysis for an entire class for a specific week.
  /// Performance optimized: Loads batch data in bulk and computes analysis in-memory.
  Future<BatchWeeklyAnalysisResult> analyzeBatchWeeklySchedules({
    required int classId,
    required String weekStartDate,
  }) async {
    final db = await _db;
    final startDt = DateTime.parse(weekStartDate);
    final endDt = startDt.add(const Duration(days: 6));
    final weekEndDate = endDt.toIso8601String().substring(0, 10);
    final weekRangeLabel =
        '${startDt.day.toString().padLeft(2, '0')}/${startDt.month.toString().padLeft(2, '0')}–'
        '${endDt.day.toString().padLeft(2, '0')}/${endDt.month.toString().padLeft(2, '0')}';

    // 1. Batch load students in class
    final studentRows = await db.rawQuery(
      '''
      SELECT HS.id, HS.ten AS ho_ten
      FROM lop_hoc_sinh LHS
      JOIN hoc_sinh HS ON LHS.id_hoc_sinh = HS.id
      WHERE LHS.id_lop = ?
    ''',
      [classId],
    );

    if (studentRows.isEmpty) {
      return BatchWeeklyAnalysisResult(
        weekRange: weekRangeLabel,
        totalStudents: 0,
        unchangedStudents: [],
        conflictedStudents: [],
        suggestedChanges: [],
        unresolvedStudents: [],
      );
    }

    final List<int> studentIds = studentRows
        .map((r) => r['id'] as int)
        .toList();
    final placeholders = List.filled(studentIds.length, '?').join(',');

    // 2. Preload busy schedules for all students in bulk
    final busyRows = await db.rawQuery(
      '''
      SELECT * FROM ${DBHelper.tenBangStudentBusySchedules}
      WHERE student_id IN ($placeholders)
        AND effective_from <= ? AND effective_to >= ?
    ''',
      [...studentIds, weekEndDate, weekStartDate],
    );

    final Map<int, List<StudentBusySchedule>> busyMap = {};
    for (var r in busyRows) {
      final s = StudentBusySchedule.fromMap(r);
      busyMap.putIfAbsent(s.studentId, () => []).add(s);
    }

    // 3. Preload active assignments for all students in bulk for weekStartDate
    final assignmentRows = await db.rawQuery(
      '''
      SELECT * FROM ${DBHelper.tenBangStudentScheduleAssignments}
      WHERE student_id IN ($placeholders)
        AND effective_from <= ? AND effective_to >= ?
      ORDER BY priority DESC, id DESC
    ''',
      [...studentIds, weekStartDate, weekStartDate],
    );

    final Map<int, StudentScheduleAssignment> currentAssignmentMap = {};
    for (var r in assignmentRows) {
      final a = StudentScheduleAssignment.fromMap(r);
      if (!currentAssignmentMap.containsKey(a.studentId)) {
        currentAssignmentMap[a.studentId] = a;
      }
    }

    // 4. Preload candidates for studentId
    final candidates = await ScheduleCandidateService.instance
        .getCandidateSessionsForStudent(
          studentId: studentIds.first,
          fromDate: weekStartDate,
          toDate: weekEndDate,
        );

    // 5. Preload attendance history for all students
    final historyMap = await _getAttendanceFrequencyMap(
      studentIds: studentIds,
      weekStartDate: weekStartDate,
    );

    final List<StudentWeeklyAnalysis> unchanged = [];
    final List<StudentWeeklyAnalysis> conflicted = [];
    final List<StudentWeeklyAnalysis> suggestedChanges = [];
    final List<StudentWeeklyAnalysis> unresolved = [];

    for (var row in studentRows) {
      final sId = row['id'] as int;
      final sName = row['ho_ten'] as String? ?? 'Học sinh';

      final busySchedules = busyMap[sId] ?? [];
      final currentAssignment = currentAssignmentMap[sId];
      final studentHistory = historyMap[sId] ?? {};

      final List<ScheduleSuggestion> suggestions = [];
      for (final cand in candidates) {
        final isCurrent = currentAssignment != null &&
            (cand.classId == currentAssignment.classId &&
                (currentAssignment.scheduleId == null ||
                    currentAssignment.scheduleId == cand.schedule.id));

        final historyCount = cand.schedule.id != null
            ? (studentHistory[cand.schedule.id!.toString()] ?? 0)
            : 0;

        final isFrequentlyAttended = historyCount >=
            SmartSchedulingConfig.minimumFrequentAttendanceCount;
        final historyEvidence = isFrequentlyAttended
            ? '✓ Thường học ca này: $historyCount/7 buổi gần đây'
            : null;

        final scoreResult = ScheduleScoringService.instance.scoreCandidate(
          studentId: sId,
          candidate: cand,
          dateStr: weekStartDate,
          busySchedules: busySchedules,
          isCurrentAssignment: isCurrent,
          isFrequentlyAttended: isFrequentlyAttended,
          historyEvidence: historyEvidence,
        );

        suggestions.add(
          ScheduleSuggestion(
            studentId: sId,
            classId: cand.classId,
            scheduleId: cand.schedule.id ?? 0,
            dayOfWeek: cand.dayOfWeek,
            dayName: cand.schedule.ngayTrongTuan,
            startTime: cand.startTime,
            endTime: cand.endTime,
            className: cand.className,
            score: scoreResult.score,
            conflictLevel: scoreResult.conflictLevel,
            reasons: scoreResult.reasons,
            isCurrentAssignment: isCurrent,
            currentCapacity: cand.currentCapacity,
            maxCapacity: cand.maxCapacity,
          ),
        );
      }

      suggestions.sort((a, b) => b.score.compareTo(a.score));

      // Fix P0 bug: Do NOT fall back to top suggestion if current assignment is missing
      ScheduleSuggestion? currentS;
      for (final s in suggestions) {
        if (s.isCurrentAssignment) {
          currentS = s;
          break;
        }
      }

      final hasCurrentAssignment = currentS != null;
      final hasConflict = hasCurrentAssignment &&
          currentS.conflictLevel != ConflictLevel.noConflict;

      ScheduleSuggestion? topS =
          suggestions.isNotEmpty ? suggestions.first : null;

      final String conflictSummary;
      if (!hasCurrentAssignment) {
        conflictSummary = 'Chưa có ca hiện tại';
      } else if (hasConflict) {
        conflictSummary = currentS.reasons.firstWhere(
          (r) => r.startsWith('✕') || r.startsWith('⚠') || r.startsWith('•'),
          orElse: () => 'Xung đột lịch bận',
        );
      } else {
        conflictSummary = 'Lịch ổn định';
      }

      final analysis = StudentWeeklyAnalysis(
        studentId: sId,
        studentName: sName,
        suggestions: suggestions,
        currentAssignment: currentS,
        topSuggestion: topS,
        hasConflict: hasConflict,
        conflictSummary: conflictSummary,
      );

      // CLASSIFICATION LOGIC V2
      if (topS == null || topS.conflictLevel == ConflictLevel.hardConflict) {
        unresolved.add(analysis);
      } else if (!hasCurrentAssignment) {
        // Student has NO active assignment -> needs assignment
        suggestedChanges.add(analysis);
      } else if (hasConflict) {
        conflicted.add(analysis);
      } else if (topS != currentS &&
          (topS.score - currentS.score) >= ScoringWeights.switchingThreshold) {
        suggestedChanges.add(analysis);
      } else {
        unchanged.add(analysis);
      }
    }

    return BatchWeeklyAnalysisResult(
      weekRange: weekRangeLabel,
      totalStudents: studentRows.length,
      unchangedStudents: unchanged,
      conflictedStudents: conflicted,
      suggestedChanges: suggestedChanges,
      unresolvedStudents: unresolved,
    );
  }

  /// Applies a confirmed suggestion by creating a temporal assignment.
  /// FIREWALL ENFORCEMENT: Rejects changes to locked financial months.
  /// Returns newly created or existing assignment ID.
  Future<int> confirmAndApplySuggestion({
    required ScheduleSuggestion suggestion,
    required String effectiveFrom, // YYYY-MM-DD
    required String effectiveTo, // YYYY-MM-DD
    required AssignmentSource source,
    int priority = 2, // 2 = TEMPORARY, 3 = ONE_TIME, 1 = REGULAR
  }) async {
    // 1. Protection against editing past locked financial months
    final isLocked = await StudentScheduleAssignmentService.instance
        .isMonthLocked(effectiveFrom);
    if (isLocked) {
      throw FinancialLockException(
        '⚠ Thay đổi này ảnh hưởng lịch sử đã dùng tính học phí (Tháng $effectiveFrom đã khóa). Không thể tự động thay đổi!',
      );
    }

    // 2. Create temporal assignment
    final assignment = StudentScheduleAssignment(
      studentId: suggestion.studentId,
      classId: suggestion.classId,
      scheduleId: suggestion.scheduleId,
      effectiveFrom: effectiveFrom,
      effectiveTo: effectiveTo,
      source: source,
      recurrenceType: RecurrenceType.weekly,
      dayOfWeek: suggestion.dayOfWeek,
      startTime: suggestion.startTime,
      endTime: suggestion.endTime,
      priority: priority,
    );

    return await StudentScheduleAssignmentService.instance
        .insertAssignmentSafely(assignment);
  }

  /// Reverts/deletes an assignment created by user confirmation (Undo feature).
  Future<bool> revertAssignment(int assignmentId) async {
    final db = await _db;
    final maps = await db.query(
      DBHelper.tenBangStudentScheduleAssignments,
      where: 'id = ?',
      whereArgs: [assignmentId],
    );
    if (maps.isEmpty) return false;
    final assignment = StudentScheduleAssignment.fromMap(maps.first);

    final isLocked = await StudentScheduleAssignmentService.instance
        .isMonthLocked(assignment.effectiveFrom);
    if (isLocked) {
      throw FinancialLockException(
        '⚠ Tháng ${assignment.effectiveFrom} đã khóa tài chính. Không thể hoàn tác!',
      );
    }

    final deleted = await StudentScheduleAssignmentService.instance
        .deleteAssignment(assignmentId);
    return deleted > 0;
  }
}
