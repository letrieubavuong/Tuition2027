import 'package:sqflite/sqflite.dart';
import '../models/lich_hoc_chung.dart';
import '../utils/db.dart';

class CandidateSession {
  final LichHocChung schedule;
  final int classId;
  final String className;
  final String grade;
  final int dayOfWeek; // 1 = Mon..7 = Sun
  final String startTime;
  final String endTime;
  final int currentCapacity;
  final int maxCapacity;

  CandidateSession({
    required this.schedule,
    required this.classId,
    required this.className,
    required this.grade,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.currentCapacity,
    this.maxCapacity = 30,
  });
}

class ScheduleCandidateService {
  static final ScheduleCandidateService instance =
      ScheduleCandidateService._internal();
  ScheduleCandidateService._internal();

  Future<Database> get _db async => await DBHelper.instance.database;

  int _convertNgayToDayOfWeek(String ngay) {
    final lower = ngay.toLowerCase().trim();
    if (lower.contains('hai') || lower.contains('t2') || lower.contains('2'))
      return 1;
    if (lower.contains('ba') || lower.contains('t3') || lower.contains('3'))
      return 2;
    if (lower.contains('tư') || lower.contains('t4') || lower.contains('4'))
      return 3;
    if (lower.contains('năm') || lower.contains('t5') || lower.contains('5'))
      return 4;
    if (lower.contains('sáu') || lower.contains('t6') || lower.contains('6'))
      return 5;
    if (lower.contains('bảy') || lower.contains('t7') || lower.contains('7'))
      return 6;
    if (lower.contains('nhật') || lower.contains('cn') || lower.contains('8'))
      return 7;
    return 1;
  }

  /// Gets all active candidate class physics schedules suitable for a student.
  Future<List<CandidateSession>> getCandidateSessionsForStudent({
    required int studentId,
    required String fromDate, // YYYY-MM-DD
    required String toDate, // YYYY-MM-DD
  }) async {
    final db = await _db;

    // 1. Get student's class grade/info
    final hsLopMaps = await db.rawQuery(
      '''
      SELECT L.id as lop_id, L.ten_lop, L.khoi
      FROM lop_hoc_sinh LHS
      JOIN lop L ON LHS.id_lop = L.id
      WHERE LHS.id_hoc_sinh = ?
    ''',
      [studentId],
    );

    String? studentGrade;
    if (hsLopMaps.isNotEmpty) {
      studentGrade = hsLopMaps.first['khoi']?.toString();
    }

    // 2. Query active LichHocChung for matching grade or all active classes
    final String query;
    final List<dynamic> args;
    if (studentGrade != null && studentGrade.isNotEmpty) {
      query =
          '''
        SELECT LHC.*, L.ten_lop, L.khoi
        FROM ${DBHelper.tenBangLichHocChung} LHC
        JOIN ${DBHelper.tenBangLop} L ON LHC.id_lop = L.id
        WHERE L.khoi = ? AND LHC.effective_from <= ? AND (LHC.effective_to IS NULL OR LHC.effective_to >= ?)
      ''';
      args = [studentGrade, toDate, fromDate];
    } else {
      query =
          '''
        SELECT LHC.*, L.ten_lop, L.khoi
        FROM ${DBHelper.tenBangLichHocChung} LHC
        JOIN ${DBHelper.tenBangLop} L ON LHC.id_lop = L.id
        WHERE LHC.effective_from <= ? AND (LHC.effective_to IS NULL OR LHC.effective_to >= ?)
      ''';
      args = [toDate, fromDate];
    }

    final lhcMaps = await db.rawQuery(query, args);
    final List<CandidateSession> candidates = [];

    for (var row in lhcMaps) {
      final lhc = LichHocChung.fromMap(row);
      final classId = row['id_lop'] as int;
      final className = row['ten_lop'] as String? ?? 'Lớp Vật lý';
      final grade = row['khoi'] as String? ?? '';
      final dayOfWeek = _convertNgayToDayOfWeek(lhc.ngayTrongTuan);

      // 3. Count capacity (students assigned to this class / schedule)
      final capMaps = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT student_id) as cnt
        FROM ${DBHelper.tenBangStudentScheduleAssignments}
        WHERE class_id = ? AND (schedule_id IS NULL OR schedule_id = ?)
          AND effective_from <= ? AND effective_to >= ?
      ''',
        [classId, lhc.id ?? 0, toDate, fromDate],
      );

      int capacity = 0;
      if (capMaps.isNotEmpty) {
        capacity = (capMaps.first['cnt'] as int?) ?? 0;
      }

      // If no assignments recorded yet, fall back to lop_hoc_sinh count
      if (capacity == 0) {
        final lhsCap = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM lop_hoc_sinh WHERE id_lop = ?',
          [classId],
        );
        if (lhsCap.isNotEmpty) {
          capacity = (lhsCap.first['cnt'] as int?) ?? 0;
        }
      }

      candidates.add(
        CandidateSession(
          schedule: lhc,
          classId: classId,
          className: className,
          grade: grade,
          dayOfWeek: dayOfWeek,
          startTime: lhc.gioBatDau,
          endTime: lhc.gioKetThuc,
          currentCapacity: capacity,
          maxCapacity: 30,
        ),
      );
    }

    return candidates;
  }
}
