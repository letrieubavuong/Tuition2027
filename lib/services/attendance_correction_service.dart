// File: lib/services/attendance_correction_service.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/attendance_change_log.dart';
import '../models/diem_danh.dart';
import '../services/attention_queue_service.dart';
import '../services/diem_danh_service.dart';
import '../services/student_signal_service.dart';
import '../utils/db.dart';

class SessionImpactSummary {
  final int attendanceCount;
  final int reviewCount;
  final int homeworkCount;
  final int affectedStudentCount;

  SessionImpactSummary({
    required this.attendanceCount,
    required this.reviewCount,
    required this.homeworkCount,
    required this.affectedStudentCount,
  });
}

class AttendanceCorrectionService extends ChangeNotifier {
  static final AttendanceCorrectionService instance =
      AttendanceCorrectionService._internal();
  factory AttendanceCorrectionService() => instance;
  AttendanceCorrectionService._internal();

  final _dbHelper = DBHelper.instance;

  final _correctionStreamController = StreamController<void>.broadcast();
  Stream<void> get onCorrectionCompleted => _correctionStreamController.stream;

  /// Lấy danh sách lịch sử chỉnh sửa (Audit Logs) cho 1 buổi học
  Future<List<AttendanceChangeLog>> getAuditLogsForSession({
    required int classId,
    required String dateStr,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBHelper.tenBangAttendanceChangeLog,
      where: 'class_id = ? AND old_datetime LIKE ?',
      whereArgs: [classId, '$dateStr%'],
      orderBy: 'changed_at DESC',
    );
    return maps.map((m) => AttendanceChangeLog.fromMap(m)).toList();
  }

  /// Lấy danh sách lịch sử chỉnh sửa (Audit Logs) cho 1 học sinh
  Future<List<AttendanceChangeLog>> getAuditLogsForStudent(
    int studentId,
  ) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBHelper.tenBangAttendanceChangeLog,
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'changed_at DESC',
    );
    return maps.map((m) => AttendanceChangeLog.fromMap(m)).toList();
  }

  /// Tính toán mức độ ảnh hưởng (Impact) trước khi Xóa/Hủy buổi học
  Future<SessionImpactSummary> getSessionImpact({
    required int classId,
    required String dateStr,
    String? startTime,
    int? sessionId,
  }) async {
    final sw = Stopwatch()..start();
    developer.log('[AttendanceCorrection] getSessionImpact START classId=$classId dateStr=$dateStr startTime=$startTime', name: 'AttendanceCorrectionService');

    final db = await _dbHelper.database;
    String whereStr = 'id_lop = ? AND gio_diem_danh LIKE ?';
    List<dynamic> whereArgs = [classId, '$dateStr%'];

    if (startTime != null && startTime.isNotEmpty) {
      whereStr = 'id_lop = ? AND gio_diem_danh LIKE ?';
      whereArgs = [classId, '$dateStr $startTime%'];
    }

    final attRows = await db.query(
      DBHelper.tenBangDiemDanh,
      where: whereStr,
      whereArgs: whereArgs,
    );

    final attIds = attRows.map((r) => r['id'] as int).toList();
    final studentIds = attRows.map((r) => r['id_hoc_sinh'] as int).toSet();

    int reviewCount = 0;
    if (attIds.isNotEmpty) {
      final placeholders = List.filled(attIds.length, '?').join(',');
      final reviewRows = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DBHelper.tenBangDanhGiaBuoiHoc} WHERE id_diem_danh IN ($placeholders)',
        attIds,
      );
      if (reviewRows.isNotEmpty) {
        reviewCount = (reviewRows.first['cnt'] as num?)?.toInt() ?? 0;
      }
    }

    int homeworkCount = 0;
    try {
      final hwRows = await db.query(
        'session_homework',
        where: 'class_id = ? AND session_date = ?',
        whereArgs: [classId, dateStr],
      );
      homeworkCount = hwRows.length;
    } catch (e, st) {
      developer.log('[AttendanceCorrection] session_homework query skipped: $e', name: 'AttendanceCorrectionService', error: e, stackTrace: st);
    }

    sw.stop();
    developer.log('[AttendanceCorrection] getSessionImpact END durationMs=${sw.elapsedMilliseconds} attCount=${attRows.length} affectedStudents=${studentIds.length}', name: 'AttendanceCorrectionService');

    return SessionImpactSummary(
      attendanceCount: attRows.length,
      reviewCount: reviewCount,
      homeworkCount: homeworkCount,
      affectedStudentCount: studentIds.length,
    );
  }

  /// CHỨC NĂNG 1: SỬA ĐIỂM DANH MỘT HỌC SINH
  Future<void> editStudentStatus({
    required int attendanceId,
    required String newStatus,
    String? reason,
  }) async {
    final sw = Stopwatch()..start();
    developer.log('[AttendanceCorrection] editStudentStatus START attendanceId=$attendanceId newStatus=$newStatus', name: 'AttendanceCorrectionService');

    final db = await _dbHelper.database;

    final attMap = await db.query(
      DBHelper.tenBangDiemDanh,
      where: 'id = ?',
      whereArgs: [attendanceId],
    );

    if (attMap.isEmpty) {
      throw ArgumentError('Không tìm thấy điểm danh với ID: $attendanceId');
    }

    final oldRecord = DiemDanh.fromMap(attMap.first);
    if (oldRecord.trangThai == newStatus) {
      return;
    }

    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        DBHelper.tenBangDiemDanh,
        {'trang_thai': newStatus},
        where: 'id = ?',
        whereArgs: [attendanceId],
      );

      final changeLog = AttendanceChangeLog(
        attendanceId: attendanceId,
        studentId: oldRecord.idHocSinh,
        classId: oldRecord.idLop,
        action: AttendanceChangeLogAction.editStatus,
        oldStatus: oldRecord.trangThai,
        newStatus: newStatus,
        oldDatetime: oldRecord.gioDiemDanh,
        newDatetime: oldRecord.gioDiemDanh,
        reason: reason ?? 'Giáo viên điều chỉnh trạng thái',
        changedAt: now,
      );

      await txn.insert(DBHelper.tenBangAttendanceChangeLog, changeLog.toMap());
    });

    await _runRecomputePipeline(
      affectedStudentIds: [oldRecord.idHocSinh],
      classId: oldRecord.idLop,
    );

    sw.stop();
    developer.log('[AttendanceCorrection] editStudentStatus END durationMs=${sw.elapsedMilliseconds}', name: 'AttendanceCorrectionService');
  }

  /// CHỨC NĂNG 2: XÓA ĐIỂM DANH CỦA MỘT HỌC SINH (KHI THÊM NHẦM)
  Future<void> removeStudentFromSession({
    required int attendanceId,
    required String reason,
  }) async {
    final sw = Stopwatch()..start();
    developer.log('[AttendanceCorrection] removeStudentFromSession START attendanceId=$attendanceId', name: 'AttendanceCorrectionService');

    final db = await _dbHelper.database;

    final attMap = await db.query(
      DBHelper.tenBangDiemDanh,
      where: 'id = ?',
      whereArgs: [attendanceId],
    );

    if (attMap.isEmpty) {
      throw ArgumentError('Không tìm thấy điểm danh để xóa: $attendanceId');
    }

    final oldRecord = DiemDanh.fromMap(attMap.first);
    final now = DateTime.now();

    await db.transaction((txn) async {
      final changeLog = AttendanceChangeLog(
        attendanceId: attendanceId,
        studentId: oldRecord.idHocSinh,
        classId: oldRecord.idLop,
        action: AttendanceChangeLogAction.removeStudent,
        oldStatus: oldRecord.trangThai,
        newStatus: 'REMOVED',
        oldDatetime: oldRecord.gioDiemDanh,
        reason: reason,
        changedAt: now,
      );

      await txn.insert(DBHelper.tenBangAttendanceChangeLog, changeLog.toMap());

      await txn.delete(
        DBHelper.tenBangDanhGiaBuoiHoc,
        where: 'id_diem_danh = ?',
        whereArgs: [attendanceId],
      );

      await txn.delete(
        DBHelper.tenBangSuKienHocTap,
        where: 'id_diem_danh = ?',
        whereArgs: [attendanceId],
      );

      await txn.delete(
        DBHelper.tenBangDiemDanh,
        where: 'id = ?',
        whereArgs: [attendanceId],
      );
    });

    await _runRecomputePipeline(
      affectedStudentIds: [oldRecord.idHocSinh],
      classId: oldRecord.idLop,
    );

    sw.stop();
    developer.log('[AttendanceCorrection] removeStudentFromSession END durationMs=${sw.elapsedMilliseconds}', name: 'AttendanceCorrectionService');
  }

  /// CHỨC NĂNG 3: SỬA THÔNG TIN BUỔI HỌC (NGÀY / GIỜ CẢ BUỔI)
  Future<void> updateSessionDetails({
    required int classId,
    required String oldDateStr,
    required String newDateStr,
    String? oldStartTime,
    String? newStartTime,
    String? oldEndTime,
    String? newEndTime,
    int? sessionId,
    required String reason,
  }) async {
    final sw = Stopwatch()..start();
    developer.log('[AttendanceCorrection] updateSessionDetails START classId=$classId oldDate=$oldDateStr newDate=$newDateStr startTime=$oldStartTime', name: 'AttendanceCorrectionService');

    final db = await _dbHelper.database;

    if (oldDateStr != newDateStr ||
        (oldStartTime != newStartTime && newStartTime != null)) {
      final conflictWhereStr = oldStartTime != null && oldStartTime.isNotEmpty
          ? 'id_lop = ? AND gio_diem_danh LIKE ?'
          : 'id_lop = ? AND gio_diem_danh LIKE ?';
      final conflictArgs = oldStartTime != null && oldStartTime.isNotEmpty
          ? [classId, '$newDateStr ${newStartTime ?? ''}%']
          : [classId, '$newDateStr%'];

      final conflictRows = await db.rawQuery(
        '''
        SELECT COUNT(*) as cnt FROM ${DBHelper.tenBangDiemDanh}
        WHERE $conflictWhereStr
        ''',
        conflictArgs,
      );

      final conflictCount = (conflictRows.first['cnt'] as num?)?.toInt() ?? 0;
      if (oldDateStr != newDateStr && conflictCount > 0) {
        throw StateError(
          'Đã tồn tại buổi học cùng lớp/ca/ngày ($newDateStr). Không thể chuyển trực tiếp.',
        );
      }
    }

    String attWhereStr = 'id_lop = ? AND gio_diem_danh LIKE ?';
    List<dynamic> attWhereArgs = [classId, '$oldDateStr%'];
    if (oldStartTime != null && oldStartTime.isNotEmpty) {
      attWhereStr = 'id_lop = ? AND gio_diem_danh LIKE ?';
      attWhereArgs = [classId, '$oldDateStr $oldStartTime%'];
    }

    final attRows = await db.query(
      DBHelper.tenBangDiemDanh,
      where: attWhereStr,
      whereArgs: attWhereArgs,
    );

    if (attRows.isEmpty) {
      throw ArgumentError(
        'Không tìm thấy dữ liệu điểm danh buổi ngày $oldDateStr',
      );
    }

    final affectedStudentIds = attRows
        .map((r) => r['id_hoc_sinh'] as int)
        .toSet()
        .toList();

    final now = DateTime.now();

    await db.transaction((txn) async {
      for (var row in attRows) {
        final id = row['id'] as int;
        final oldGio = row['gio_diem_danh'] as String;

        final oldDt = DateTime.tryParse(oldGio) ?? DateTime.now();
        final timePart =
            newStartTime ??
            '${oldDt.hour.toString().padLeft(2, '0')}:${oldDt.minute.toString().padLeft(2, '0')}:${oldDt.second.toString().padLeft(2, '0')}';

        final newGio = '$newDateStr $timePart';

        await txn.update(
          DBHelper.tenBangDiemDanh,
          {'gio_diem_danh': newGio},
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      try {
        await txn.update(
          'session_homework',
          {'session_date': newDateStr},
          where: 'class_id = ? AND session_date = ?',
          whereArgs: [classId, oldDateStr],
        );
      } catch (e, st) {
        developer.log('[AttendanceCorrection] session_homework update skipped: $e', name: 'AttendanceCorrectionService', error: e, stackTrace: st);
      }

      try {
        await txn.update(
          'session_completion_ledger',
          {'session_date': newDateStr},
          where: 'class_id = ? AND session_date = ?',
          whereArgs: [classId, oldDateStr],
        );
      } catch (e, st) {
        developer.log('[AttendanceCorrection] session_completion_ledger update skipped: $e', name: 'AttendanceCorrectionService', error: e, stackTrace: st);
      }

      try {
        await txn.update(
          'parent_communications',
          {'ngay_hoc': newDateStr},
          where: 'id_lop = ? AND ngay_hoc = ?',
          whereArgs: [classId, oldDateStr],
        );
      } catch (e, st) {
        developer.log('[AttendanceCorrection] parent_communications update skipped: $e', name: 'AttendanceCorrectionService', error: e, stackTrace: st);
      }

      final changeLog = AttendanceChangeLog(
        sessionId: sessionId,
        classId: classId,
        action: AttendanceChangeLogAction.editSession,
        oldDatetime: oldDateStr,
        newDatetime: newDateStr,
        reason: reason,
        changedAt: now,
      );

      await txn.insert(DBHelper.tenBangAttendanceChangeLog, changeLog.toMap());
    });

    await _runRecomputePipeline(
      affectedStudentIds: affectedStudentIds,
      classId: classId,
    );

    sw.stop();
    developer.log('[AttendanceCorrection] updateSessionDetails END durationMs=${sw.elapsedMilliseconds}', name: 'AttendanceCorrectionService');
  }

  /// CHỨC NĂNG 4: HỦY BUỔI ĐIỂM DANH (SOFT DELETE)
  Future<void> cancelSession({
    required int classId,
    required String dateStr,
    String? startTime,
    int? sessionId,
    required String reason,
  }) async {
    final sw = Stopwatch()..start();
    developer.log('[AttendanceCorrection] cancelSession START classId=$classId dateStr=$dateStr startTime=$startTime', name: 'AttendanceCorrectionService');

    final db = await _dbHelper.database;

    String attWhereStr = 'id_lop = ? AND gio_diem_danh LIKE ?';
    List<dynamic> attWhereArgs = [classId, '$dateStr%'];
    if (startTime != null && startTime.isNotEmpty) {
      attWhereStr = 'id_lop = ? AND gio_diem_danh LIKE ?';
      attWhereArgs = [classId, '$dateStr $startTime%'];
    }

    final attRows = await db.query(
      DBHelper.tenBangDiemDanh,
      where: attWhereStr,
      whereArgs: attWhereArgs,
    );

    final affectedStudentIds = attRows
        .map((r) => r['id_hoc_sinh'] as int)
        .toSet()
        .toList();

    final now = DateTime.now();

    await db.transaction((txn) async {
      final ledgerRows = await txn.query(
        'session_completion_ledger',
        where: 'class_id = ? AND session_date = ?',
        whereArgs: [classId, dateStr],
      );

      final sessionKey = '${classId}_${sessionId ?? 0}_$dateStr';

      if (ledgerRows.isNotEmpty) {
        await txn.update(
          'session_completion_ledger',
          {'status': 'CANCELLED', 'session_status': 'CANCELLED'},
          where: 'class_id = ? AND session_date = ?',
          whereArgs: [classId, dateStr],
        );
      } else {
        await txn.insert('session_completion_ledger', {
          'id': sessionKey,
          'class_id': classId,
          'session_id': sessionId,
          'session_date': dateStr,
          'status': 'CANCELLED',
          'session_status': 'CANCELLED',
          'completed_at': now.toIso8601String(),
        });
      }

      final changeLog = AttendanceChangeLog(
        sessionId: sessionId,
        classId: classId,
        action: AttendanceChangeLogAction.cancelSession,
        oldStatus: 'ACTIVE',
        newStatus: 'CANCELLED',
        oldDatetime: dateStr,
        reason: reason,
        changedAt: now,
      );

      await txn.insert(DBHelper.tenBangAttendanceChangeLog, changeLog.toMap());
    });

    await _runRecomputePipeline(
      affectedStudentIds: affectedStudentIds,
      classId: classId,
    );

    sw.stop();
    developer.log('[AttendanceCorrection] cancelSession END durationMs=${sw.elapsedMilliseconds}', name: 'AttendanceCorrectionService');
  }

  /// CHỨC NĂNG 5: KHÔI PHỤC BUỔI HỌC ĐÃ HỦY
  Future<void> restoreSession({
    required int classId,
    required String dateStr,
    String? startTime,
    int? sessionId,
    required String reason,
  }) async {
    final sw = Stopwatch()..start();
    developer.log('[AttendanceCorrection] restoreSession START classId=$classId dateStr=$dateStr startTime=$startTime', name: 'AttendanceCorrectionService');

    final db = await _dbHelper.database;

    String attWhereStr = 'id_lop = ? AND gio_diem_danh LIKE ?';
    List<dynamic> attWhereArgs = [classId, '$dateStr%'];
    if (startTime != null && startTime.isNotEmpty) {
      attWhereStr = 'id_lop = ? AND gio_diem_danh LIKE ?';
      attWhereArgs = [classId, '$dateStr $startTime%'];
    }

    final attRows = await db.query(
      DBHelper.tenBangDiemDanh,
      where: attWhereStr,
      whereArgs: attWhereArgs,
    );

    final affectedStudentIds = attRows
        .map((r) => r['id_hoc_sinh'] as int)
        .toSet()
        .toList();

    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        'session_completion_ledger',
        {'status': 'COMPLETED', 'session_status': 'ACTIVE'},
        where: 'class_id = ? AND session_date = ?',
        whereArgs: [classId, dateStr],
      );

      final changeLog = AttendanceChangeLog(
        sessionId: sessionId,
        classId: classId,
        action: AttendanceChangeLogAction.restoreSession,
        oldStatus: 'CANCELLED',
        newStatus: 'ACTIVE',
        oldDatetime: dateStr,
        reason: reason,
        changedAt: now,
      );

      await txn.insert(DBHelper.tenBangAttendanceChangeLog, changeLog.toMap());
    });

    await _runRecomputePipeline(
      affectedStudentIds: affectedStudentIds,
      classId: classId,
    );

    sw.stop();
    developer.log('[AttendanceCorrection] restoreSession END durationMs=${sw.elapsedMilliseconds}', name: 'AttendanceCorrectionService');
  }

  /// Targeted Recompute Pipeline after DB Commit
  Future<void> _runRecomputePipeline({
    required List<int> affectedStudentIds,
    required int classId,
  }) async {
    try {
      final sw = Stopwatch()..start();

      // 1. Recompute Student Signals for affected students
      for (final studentId in affectedStudentIds) {
        await StudentSignalService.instance.recomputeSignalsForStudent(
          studentId,
        );
      }

      // 2. Trigger lightweight refresh of Attention Queue sources (does not scan all classes)
      await AttentionQueueService.instance.refreshAttentionSources();

      // 3. Notify UI listeners
      _correctionStreamController.add(null);
      notifyListeners();

      sw.stop();
      developer.log('[AttendanceCorrection] _runRecomputePipeline completed in ${sw.elapsedMilliseconds}ms for ${affectedStudentIds.length} students', name: 'AttendanceCorrectionService');
    } catch (e, stack) {
      developer.log(
        'Lỗi khi chạy Recompute Pipeline sau Attendance Correction: $e',
        name: 'AttendanceCorrectionService',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
