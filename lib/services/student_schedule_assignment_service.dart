import 'package:sqflite/sqflite.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc.dart';
import '../models/student_busy_schedule.dart';
import '../models/student_schedule_assignment.dart';
import '../utils/db.dart';
import '../utils/schedule_helpers.dart';

class ClassScheduleRoster {
  final List<LichHoc> schedules;
  final List<HSLopViewModel> activeStudents;
  final Map<int, StudentScheduleAssignment> activeAssignmentByStudentId;
  final Map<int, List<int>> studentIdsByScheduleId;
  final Set<int> unassignedStudentIds;

  ClassScheduleRoster({
    required this.schedules,
    required this.activeStudents,
    required this.activeAssignmentByStudentId,
    required this.studentIdsByScheduleId,
    required this.unassignedStudentIds,
  });
}

class StudentScheduleAssignmentService {
  static final StudentScheduleAssignmentService instance =
      StudentScheduleAssignmentService._internal();
  StudentScheduleAssignmentService._internal();

  int _parseWeekday(dynamic val) {
    if (val == null) return 2;
    if (val is int) return val;
    final str = val.toString().trim();
    switch (str) {
      case 'Chủ Nhật':
      case 'CN':
      case '1':
        return 1;
      case 'Thứ Hai':
      case 'T2':
      case '2':
        return 2;
      case 'Thứ Ba':
      case 'T3':
      case '3':
        return 3;
      case 'Thứ Tư':
      case 'T4':
      case '4':
        return 4;
      case 'Thứ Năm':
      case 'T5':
      case '5':
        return 5;
      case 'Thứ Sáu':
      case 'T6':
      case '6':
        return 6;
      case 'Thứ Bảy':
      case 'T7':
      case '7':
        return 7;
      default:
        return int.tryParse(str) ?? 2;
    }
  }

  Future<Database> get _db async => await DBHelper.instance.database;

  Future<int> insertAssignment(StudentScheduleAssignment assignment) async {
    final db = await _db;
    return await db.insert(
      DBHelper.tenBangStudentScheduleAssignments,
      assignment.toMap(),
    );
  }

  Future<int> updateAssignment(StudentScheduleAssignment assignment) async {
    final db = await _db;
    if (assignment.id == null) return 0;
    return await db.update(
      DBHelper.tenBangStudentScheduleAssignments,
      assignment.toMap(),
      where: 'id = ?',
      whereArgs: [assignment.id],
    );
  }

  Future<int> deleteAssignment(int id) async {
    final db = await _db;
    return await db.delete(
      DBHelper.tenBangStudentScheduleAssignments,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAssignmentsForSchedule(int scheduleId) async {
    final db = await _db;
    return await db.delete(
      DBHelper.tenBangStudentScheduleAssignments,
      where: 'schedule_id = ?',
      whereArgs: [scheduleId],
    );
  }

  /// Unassign specified students from all schedule slots of a class cleanly,
  /// removing records from both student_schedule_assignments and legacy lich_hoc_ca_nhan.
  Future<int> unassignStudentsFromClassSchedules({
    required int classId,
    required List<int> studentIds,
  }) async {
    final db = await _db;
    if (studentIds.isEmpty) return 0;
    final placeholders = List.filled(studentIds.length, '?').join(',');

    try {
      final lhcRows = await db.query(
        DBHelper.tenBangLichHocChung,
        columns: ['id'],
        where: 'id_lop = ?',
        whereArgs: [classId],
      );
      if (lhcRows.isNotEmpty) {
        final lhcIds = lhcRows.map((r) => r['id'] as int).toList();
        final lhcPlaceholders = List.filled(lhcIds.length, '?').join(',');
        await db.delete(
          DBHelper.tenBangLichHocCaNhan,
          where:
              'id_hoc_sinh IN ($placeholders) AND id_lich_hoc_chung IN ($lhcPlaceholders)',
          whereArgs: [...studentIds, ...lhcIds],
        );
      }
    } catch (_) {}

    return await db.delete(
      DBHelper.tenBangStudentScheduleAssignments,
      where: 'class_id = ? AND student_id IN ($placeholders)',
      whereArgs: [classId, ...studentIds],
    );
  }

  Future<List<StudentScheduleAssignment>> getAssignmentsForStudent(
    int studentId,
  ) async {
    final db = await _db;
    final maps = await db.query(
      DBHelper.tenBangStudentScheduleAssignments,
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'priority DESC, effective_from DESC',
    );
    return maps.map((m) => StudentScheduleAssignment.fromMap(m)).toList();
  }

  Future<List<StudentScheduleAssignment>> getAssignmentsForStudentInRange(
    int studentId,
    String fromDate,
    String toDate,
  ) async {
    final db = await _db;
    final maps = await db.query(
      DBHelper.tenBangStudentScheduleAssignments,
      where: 'student_id = ? AND effective_from <= ? AND effective_to >= ?',
      whereArgs: [studentId, toDate, fromDate],
      orderBy: 'priority DESC, effective_from DESC',
    );
    return maps.map((m) => StudentScheduleAssignment.fromMap(m)).toList();
  }

  /// Resolves the single active assignment for a student on a specific date (YYYY-MM-DD).
  /// Precedence rules:
  /// ONE_TIME OVERRIDE (priority 3) > TEMPORARY DATE-RANGE (priority 2) > REGULAR ASSIGNMENT (priority 1)
  Future<StudentScheduleAssignment?> getActiveAssignmentForStudentOnDate(
    int studentId,
    String dateStr, // YYYY-MM-DD
  ) async {
    final list = await getAssignmentsForStudentInRange(
      studentId,
      dateStr,
      dateStr,
    );
    if (list.isEmpty) return null;

    // Sort strictly by priority DESC, then ID DESC
    list.sort((a, b) {
      final pComp = b.priority.compareTo(a.priority);
      if (pComp != 0) return pComp;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });

    return list.first;
  }

  /// Checks if an equivalent assignment already exists in the database.
  Future<StudentScheduleAssignment?> findEquivalentAssignment(
    StudentScheduleAssignment assignment,
  ) async {
    final db = await _db;
    final String query =
        '''
      SELECT * FROM ${DBHelper.tenBangStudentScheduleAssignments}
      WHERE student_id = ?
        AND class_id = ?
        AND (schedule_id = ? OR (schedule_id IS NULL AND ? IS NULL))
        AND effective_from = ?
        AND effective_to = ?
        AND day_of_week = ?
        AND start_time = ?
        AND end_time = ?
        AND priority = ?
      LIMIT 1
    ''';

    final maps = await db.rawQuery(query, [
      assignment.studentId,
      assignment.classId,
      assignment.scheduleId,
      assignment.scheduleId,
      assignment.effectiveFrom,
      assignment.effectiveTo,
      assignment.dayOfWeek,
      assignment.startTime,
      assignment.endTime,
      assignment.priority,
    ]);

    if (maps.isNotEmpty) {
      return StudentScheduleAssignment.fromMap(maps.first);
    }
    return null;
  }

  /// Cancels or trims existing temporary assignments (priority = 2) that overlap with the new assignment range
  /// for the same student and class.
  Future<void> handleOverlappingTemporaryAssignments(
    StudentScheduleAssignment newAssignment,
  ) async {
    if (newAssignment.priority != 2) {
      return; // Only for temporary weekly overrides
    }
    final db = await _db;

    final existingList = await db.query(
      DBHelper.tenBangStudentScheduleAssignments,
      where:
          'student_id = ? AND class_id = ? AND priority = 2 AND effective_from <= ? AND effective_to >= ?',
      whereArgs: [
        newAssignment.studentId,
        newAssignment.classId,
        newAssignment.effectiveTo,
        newAssignment.effectiveFrom,
      ],
    );

    for (var map in existingList) {
      final existing = StudentScheduleAssignment.fromMap(map);
      if (existing.id != null) {
        // If exact match of dates & times, ignore (it will be caught by findEquivalentAssignment)
        if (existing.dayOfWeek == newAssignment.dayOfWeek &&
            existing.startTime == newAssignment.startTime &&
            existing.effectiveFrom == newAssignment.effectiveFrom &&
            existing.effectiveTo == newAssignment.effectiveTo) {
          continue;
        }

        // Delete older conflicting temporary assignment for the same week range
        await deleteAssignment(existing.id!);
      }
    }
  }

  /// Safe idempotent insert with overlap cleanup
  Future<int> insertAssignmentSafely(
    StudentScheduleAssignment assignment,
  ) async {
    final existing = await findEquivalentAssignment(assignment);
    if (existing != null) {
      return existing.id ?? 1; // Idempotent success
    }

    await handleOverlappingTemporaryAssignments(assignment);
    return await insertAssignment(assignment);
  }

  /// Checks if a date belongs to a locked tuition month (financial safety firewall).
  Future<bool> isMonthLocked(String dateStr) async {
    final db = await _db;
    // Extract YYYY-MM
    if (dateStr.length < 7) return false;
    final monthKey = dateStr.substring(0, 7); // "YYYY-MM"
    final currentMonthKey = DateTime.now().toIso8601String().substring(0, 7);

    // If attempting to modify a past month that already has payments, it is locked
    if (monthKey.compareTo(currentMonthKey) < 0) {
      final paymentMaps = await db.query(
        DBHelper.tenBangThanhToan,
        where: 'thang LIKE ?',
        whereArgs: ['$monthKey%'],
      );
      if (paymentMaps.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Batch assign a list of students to a schedule slot atomically.
  /// Handles switching: updates or replaces regular assignments for the same student/class.
  Future<Map<String, int>> batchAssignStudentsToSchedule({
    required int classId,
    required int scheduleId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required List<int> studentIds,
    String? effectiveFrom,
  }) async {
    int successCount = 0;
    int skippedCount = 0;
    final effFrom =
        effectiveFrom ?? DateTime.now().toIso8601String().substring(0, 10);

    for (final sId in studentIds) {
      try {
        final db = await _db;
        // Check if student already has a regular assignment for this class
        final existingRegulars = await db.query(
          DBHelper.tenBangStudentScheduleAssignments,
          where: 'student_id = ? AND class_id = ? AND priority = 1',
          whereArgs: [sId, classId],
        );

        final newAssignment = StudentScheduleAssignment(
          studentId: sId,
          classId: classId,
          scheduleId: scheduleId,
          dayOfWeek: dayOfWeek,
          startTime: startTime,
          endTime: endTime,
          effectiveFrom: effFrom,
          effectiveTo: '9999-12-31',
          priority: 1, // REGULAR
          recurrenceType: RecurrenceType.weekly,
        );

        if (existingRegulars.isNotEmpty) {
          final first = StudentScheduleAssignment.fromMap(
            existingRegulars.first,
          );
          if (first.scheduleId == scheduleId &&
              first.dayOfWeek == dayOfWeek &&
              first.startTime == startTime) {
            skippedCount++;
            continue;
          }
          // Remove old regular assignment so student is switched cleanly to new slot
          await db.delete(
            DBHelper.tenBangStudentScheduleAssignments,
            where: 'student_id = ? AND class_id = ? AND priority = 1',
            whereArgs: [sId, classId],
          );
        }

        await insertAssignmentSafely(newAssignment);
        successCount++;
      } catch (_) {
        skippedCount++;
      }
    }

    return {'success': successCount, 'skipped': skippedCount};
  }

  /// Batch load roster and active assignments for a class on an effective date.
  /// Integrates fallback migration for legacy `lich_hoc_ca_nhan` records.
  Future<ClassScheduleRoster> getClassScheduleRoster({
    required int classId,
    required List<LichHoc> schedules,
    required List<HSLopViewModel> activeStudents,
    DateTime? effectiveDate,
  }) async {
    final dateStr =
        (effectiveDate ?? DateTime.now()).toIso8601String().substring(0, 10);
    final db = await _db;

    try {
      // 1. Query all active assignments for this class on effective date
      final assignmentMaps = await db.query(
        DBHelper.tenBangStudentScheduleAssignments,
        where: 'class_id = ? AND effective_from <= ? AND effective_to >= ?',
        whereArgs: [classId, dateStr, dateStr],
        orderBy: 'priority DESC, effective_from DESC, id DESC',
      );

    final allAssignments =
        assignmentMaps
            .map((m) => StudentScheduleAssignment.fromMap(m))
            .toList();

    // 2. Check legacy mappings in `lich_hoc_ca_nhan` for active students without canonical assignment
    final assignedStudentIdsInDb =
        allAssignments.map((a) => a.studentId).toSet();
    for (final studentVm in activeStudents) {
      final sId = studentVm.id;
      if (sId != null && !assignedStudentIdsInDb.contains(sId)) {
        try {
          final legacyMaps = await db.rawQuery('''
            SELECT lhc.ngay_trong_tuan, lhc.gio_bat_dau, lhc.gio_ket_thuc
            FROM ${DBHelper.tenBangLichHocCaNhan} lhcn
            JOIN ${DBHelper.tenBangLichHocChung} lhc ON lhcn.id_lich_hoc_chung = lhc.id
            WHERE lhcn.id_hoc_sinh = ? AND lhc.id_lop = ?
          ''', [sId, classId]);

          if (legacyMaps.isNotEmpty) {
            final leg = legacyMaps.first;
            final legThu = _parseWeekday(leg['ngay_trong_tuan']);
            final legStart = normalizeTime(leg['gio_bat_dau']?.toString() ?? '');
            final legEnd = normalizeTime(leg['gio_ket_thuc']?.toString() ?? '');

            final matchingSchedule = schedules.firstWhere(
              (sch) =>
                  sch.thuTrongTuan == legThu &&
                  normalizeTime(sch.gioBatDau) == legStart,
              orElse: () => schedules.firstWhere(
                (sch) => sch.thuTrongTuan == legThu,
                orElse: () => schedules.isNotEmpty
                    ? schedules.first
                    : LichHoc(
                        idLop: classId,
                        thuTrongTuan: legThu,
                        gioBatDau: legStart,
                        gioKetThuc: legEnd,
                      ),
              ),
            );

            if (matchingSchedule.id != null) {
              final legacyAssignment = StudentScheduleAssignment(
                studentId: sId,
                classId: classId,
                scheduleId: matchingSchedule.id,
                dayOfWeek: matchingSchedule.thuTrongTuan,
                startTime: matchingSchedule.gioBatDau,
                endTime: matchingSchedule.gioKetThuc,
                effectiveFrom: '2000-01-01',
                effectiveTo: '9999-12-31',
                priority: 1, // REGULAR
                recurrenceType: RecurrenceType.weekly,
                source: AssignmentSource.manual,
              );

              final insertedId = await insertAssignmentSafely(
                legacyAssignment,
              );
              final createdAssignment = legacyAssignment.copyWith(
                id: insertedId,
              );
              allAssignments.add(createdAssignment);
            }
          }
        } catch (_) {
          // Ignore legacy query errors if tables don't exist
        }
      }
    }

    // 3. Group effective active assignments per student
    final Map<int, StudentScheduleAssignment> activeAssignmentByStudentId = {};
    for (final studentVm in activeStudents) {
      final sId = studentVm.id;
      if (sId == null) continue;
      final studentAssignments =
          allAssignments.where((a) => a.studentId == sId).toList();
      if (studentAssignments.isNotEmpty) {
        studentAssignments.sort((a, b) {
          final pComp = b.priority.compareTo(a.priority);
          if (pComp != 0) return pComp;
          return (b.id ?? 0).compareTo(a.id ?? 0);
        });
        activeAssignmentByStudentId[sId] = studentAssignments.first;
      }
    }

    // 4. Map student IDs by scheduleId
    final Map<int, List<int>> studentIdsByScheduleId = {};
    for (final sch in schedules) {
      if (sch.id != null) {
        studentIdsByScheduleId[sch.id!] = [];
      }
    }

    final Set<int> unassignedStudentIds = {};
    for (final studentVm in activeStudents) {
      final sId = studentVm.id;
      if (sId == null) continue;
      final activeAsgn = activeAssignmentByStudentId[sId];
      if (activeAsgn != null) {
        int? targetSchId = activeAsgn.scheduleId;
        if (targetSchId == null || !studentIdsByScheduleId.containsKey(targetSchId)) {
          final matchedSch = schedules.firstWhere(
            (sch) =>
                sch.thuTrongTuan == activeAsgn.dayOfWeek &&
                (activeAsgn.startTime == null ||
                    normalizeTime(sch.gioBatDau) == normalizeTime(activeAsgn.startTime!)),
            orElse: () => LichHoc(idLop: classId, thuTrongTuan: 0, gioBatDau: '', gioKetThuc: ''),
          );
          targetSchId = matchedSch.id;
        }

        if (targetSchId != null && studentIdsByScheduleId.containsKey(targetSchId)) {
          studentIdsByScheduleId[targetSchId]!.add(sId);
        } else {
          unassignedStudentIds.add(sId);
        }
      } else {
        unassignedStudentIds.add(sId);
      }
    }

      return ClassScheduleRoster(
        schedules: schedules,
        activeStudents: activeStudents,
        activeAssignmentByStudentId: activeAssignmentByStudentId,
        studentIdsByScheduleId: studentIdsByScheduleId,
        unassignedStudentIds: unassignedStudentIds,
      );
    } catch (_) {
      final Map<int, List<int>> fallbackStudentIds = {};
      for (final sch in schedules) {
        if (sch.id != null) fallbackStudentIds[sch.id!] = [];
      }
      return ClassScheduleRoster(
        schedules: schedules,
        activeStudents: activeStudents,
        activeAssignmentByStudentId: {},
        studentIdsByScheduleId: fallbackStudentIds,
        unassignedStudentIds: activeStudents.map((e) => e.id).whereType<int>().toSet(),
      );
    }
  }
}

