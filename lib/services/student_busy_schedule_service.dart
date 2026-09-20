import 'package:sqflite/sqflite.dart';
import '../models/student_busy_schedule.dart';
import '../utils/db.dart';

class StudentBusyScheduleService {
  static final StudentBusyScheduleService instance =
      StudentBusyScheduleService._internal();
  StudentBusyScheduleService._internal();

  Future<Database> get _db async => await DBHelper.instance.database;

  Future<int> insertBusySchedule(StudentBusySchedule schedule) async {
    final db = await _db;
    return await db.insert(
      DBHelper.tenBangStudentBusySchedules,
      schedule.toMap(),
    );
  }

  Future<int> updateBusySchedule(StudentBusySchedule schedule) async {
    final db = await _db;
    if (schedule.id == null) return 0;
    return await db.update(
      DBHelper.tenBangStudentBusySchedules,
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<int> deleteBusySchedule(int id) async {
    final db = await _db;
    return await db.delete(
      DBHelper.tenBangStudentBusySchedules,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<StudentBusySchedule>> getBusySchedulesForStudent(
    int studentId,
  ) async {
    final db = await _db;
    final maps = await db.query(
      DBHelper.tenBangStudentBusySchedules,
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'day_of_week ASC, start_time ASC',
    );
    return maps.map((m) => StudentBusySchedule.fromMap(m)).toList();
  }

  Future<List<StudentBusySchedule>> getBusySchedulesForStudentInRange(
    int studentId,
    String fromDate, // YYYY-MM-DD
    String toDate, // YYYY-MM-DD
  ) async {
    final db = await _db;
    // Overlap condition: effective_from <= toDate AND effective_to >= fromDate
    final maps = await db.query(
      DBHelper.tenBangStudentBusySchedules,
      where: 'student_id = ? AND effective_from <= ? AND effective_to >= ?',
      whereArgs: [studentId, toDate, fromDate],
      orderBy: 'day_of_week ASC, start_time ASC',
    );
    return maps.map((m) => StudentBusySchedule.fromMap(m)).toList();
  }

  /// Copies busy schedules from a source week (sourceStart e.g. "2026-09-14")
  /// to a target week (targetStart e.g. "2026-09-21").
  Future<int> copyWeekSchedules(
    int studentId,
    String sourceStart, // YYYY-MM-DD
    String targetStart, // YYYY-MM-DD
  ) async {
    final sourceStartDate = DateTime.parse(sourceStart);
    final sourceEndDate = sourceStartDate.add(const Duration(days: 6));
    final targetStartDate = DateTime.parse(targetStart);
    final targetEndDate = targetStartDate.add(const Duration(days: 6));

    final sourceStrStart = sourceStart;
    final sourceStrEnd = sourceEndDate.toIso8601String().substring(0, 10);
    final targetStrStart = targetStart;
    final targetStrEnd = targetEndDate.toIso8601String().substring(0, 10);

    final existingSchedules = await getBusySchedulesForStudentInRange(
      studentId,
      sourceStrStart,
      sourceStrEnd,
    );

    int count = 0;
    for (var sched in existingSchedules) {
      // Create a copy effective for target week
      final copySched = sched.copyWith(
        id: null,
        effectiveFrom: targetStrStart,
        effectiveTo: targetStrEnd,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );
      await insertBusySchedule(copySched);
      count++;
    }
    return count;
  }
}
