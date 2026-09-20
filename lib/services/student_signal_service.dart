// File: lib/services/student_signal_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../models/student_signal.dart';
import '../models/student_timeline.dart';
import '../services/hoc_sinh_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/report_service.dart';
import '../utils/db.dart';

class StudentSignalService extends ChangeNotifier {
  static final StudentSignalService instance = StudentSignalService._internal();
  factory StudentSignalService() => instance;
  StudentSignalService._internal();

  final _dbHelper = DBHelper.instance;
  final _hsService = HocSinhService();
  final _lhsService = LopHocSinhService();
  final _reportService = ReportService();

  /// Đọc các signals theo học sinh
  Future<List<StudentSignal>> getSignalsForStudent(
    int studentId, {
    bool activeOnly = false,
  }) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps;

    if (activeOnly) {
      maps = await db.query(
        DBHelper.tenBangStudentSignals,
        where: 'student_id = ? AND status IN (?, ?, ?)',
        whereArgs: [studentId, 'ACTIVE', 'ACKNOWLEDGED', 'SNOOZED'],
        orderBy: 'updated_at DESC',
      );
    } else {
      maps = await db.query(
        DBHelper.tenBangStudentSignals,
        where: 'student_id = ?',
        whereArgs: [studentId],
        orderBy: 'updated_at DESC',
      );
    }

    return maps.map((m) => StudentSignal.fromMap(m)).toList();
  }

  /// Đọc tất cả signals chưa giải quyết trên toàn app
  Future<List<StudentSignal>> getAllActiveSignals() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DBHelper.tenBangStudentSignals,
      where: 'status IN (?, ?, ?)',
      whereArgs: ['ACTIVE', 'ACKNOWLEDGED', 'SNOOZED'],
      orderBy: 'severity DESC, updated_at DESC',
    );
    return maps.map((m) => StudentSignal.fromMap(m)).toList();
  }

  /// Cập nhật trạng thái Signal (ACTIVE -> ACKNOWLEDGED / RESOLVED / SNOOZED)
  Future<void> updateSignalStatus(
    int signalId,
    StudentSignalStatus newStatus, {
    DateTime? snoozedUntil,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final Map<String, dynamic> updates = {
      'status': newStatus.name.toUpperCase(),
      'updated_at': now,
    };
    if (snoozedUntil != null) {
      updates['snoozed_until'] = snoozedUntil.toIso8601String();
    }

    await db.update(
      DBHelper.tenBangStudentSignals,
      updates,
      where: 'id = ?',
      whereArgs: [signalId],
    );
    notifyListeners();
  }

  /// Tự động đánh giá và tái tính toán Signal cho một học sinh cụ thể
  Future<List<StudentSignal>> recomputeSignalsForStudent(int studentId) async {
    final hs = await _hsService.docHocSinhTheoId(studentId);
    if (hs == null) return [];

    final db = await _dbHelper.database;
    final now = DateTime.now();
    final existingSignals = await getSignalsForStudent(studentId);
    final activeSignalsMap = <StudentSignalType, StudentSignal>{};

    for (var sig in existingSignals) {
      if (sig.status != StudentSignalStatus.resolved) {
        activeSignalsMap[sig.signalType] = sig;
      }
    }

    // ------------------------------------------------------------------
    // RULE 1: UNEXCUSED_ABSENCE_WARNING (Nghỉ KP >= 2 buổi trong 14 ngày)
    // ------------------------------------------------------------------
    final fourteenDaysAgoStr = now
        .subtract(const Duration(days: 14))
        .toIso8601String()
        .substring(0, 10);
    final absRows = await db.rawQuery(
      '''
      SELECT d.*
      FROM ${DBHelper.tenBangDiemDanh} d
      LEFT JOIN session_completion_ledger scl ON scl.class_id = d.id_lop AND scl.session_date = SUBSTR(d.gio_diem_danh, 1, 10)
      WHERE d.id_hoc_sinh = ?
        AND d.trang_thai = 'Nghỉ không phép'
        AND d.gio_diem_danh >= ?
        AND (scl.session_status IS NULL OR scl.session_status != 'CANCELLED')
      ORDER BY d.gio_diem_danh DESC
      ''',
      [studentId, fourteenDaysAgoStr],
    );

    // Lọc theo participation window
    int validUnexcusedCount = 0;
    for (var row in absRows) {
      final dateStr = (row['gio_diem_danh'] as String).substring(0, 10);
      final date = DateTime.tryParse(dateStr) ?? now;
      final classId = row['id_lop'] as int?;
      if (classId != null) {
        final activeInWindow = await _lhsService.isStudentActiveOnDate(
          studentId,
          classId,
          date,
        );
        if (activeInWindow) validUnexcusedCount++;
      } else {
        validUnexcusedCount++;
      }
    }

    await _processRuleResult(
      studentId: studentId,
      signalType: StudentSignalType.UNEXCUSED_ABSENCE_WARNING,
      isTriggered: validUnexcusedCount >= 2,
      existingSignal:
          activeSignalsMap[StudentSignalType.UNEXCUSED_ABSENCE_WARNING],
      title: 'Cảnh báo: Nghỉ không phép $validUnexcusedCount buổi',
      description:
          'Học sinh có $validUnexcusedCount buổi nghỉ không phép trong 14 ngày gần nhất.',
      severity: StudentTimelineSeverity.warning,
      metadata: {'unexcusedCount': validUnexcusedCount},
    );

    // ------------------------------------------------------------------
    // Lấy N buổi học gần nhất (Attendance + Review)
    // ------------------------------------------------------------------
    final recentSessions = await db.rawQuery(
      '''
      SELECT d.id as id_diem_danh, d.id_lop, d.gio_diem_danh, d.trang_thai,
             r.diem_thai_do, r.diem_hieu_bai, r.diem_bai_tap, r.nhan_xet
      FROM ${DBHelper.tenBangDiemDanh} d
      LEFT JOIN ${DBHelper.tenBangDanhGiaBuoiHoc} r ON r.id_diem_danh = d.id
      LEFT JOIN session_completion_ledger scl ON scl.class_id = d.id_lop AND scl.session_date = SUBSTR(d.gio_diem_danh, 1, 10)
      WHERE d.id_hoc_sinh = ?
        AND d.trang_thai IN ('Có mặt', 'Trễ', 'Học bù')
        AND (scl.session_status IS NULL OR scl.session_status != 'CANCELLED')
      ORDER BY d.gio_diem_danh DESC
      LIMIT 10
      ''',
      [studentId],
    );

    // ------------------------------------------------------------------
    // RULE 2: HOMEWORK_REPEATED_WARNING (Thiếu/không làm BTVN >= 3 trong 5 buổi gần nhất)
    // ------------------------------------------------------------------
    int missingHwCount = 0;
    final last5 = recentSessions.take(5).toList();
    for (var row in last5) {
      final hwScore = row['diem_bai_tap'];
      final nhanXet = (row['nhan_xet'] as String?) ?? '';
      if (hwScore != null && (hwScore as num) < 6.0) {
        missingHwCount++;
      } else if (nhanXet.contains('Thiếu BTVN') ||
          nhanXet.contains('Không làm BTVN') ||
          nhanXet.contains('chưa làm BTVN')) {
        missingHwCount++;
      }
    }

    await _processRuleResult(
      studentId: studentId,
      signalType: StudentSignalType.HOMEWORK_REPEATED_WARNING,
      isTriggered: missingHwCount >= 3,
      existingSignal:
          activeSignalsMap[StudentSignalType.HOMEWORK_REPEATED_WARNING],
      title: 'Cảnh báo BTVN: Chưa làm $missingHwCount/5 buổi gần đây',
      description:
          'Học sinh thiếu hoặc không làm bài tập ở $missingHwCount trong 5 buổi học gần nhất.',
      severity: StudentTimelineSeverity.warning,
      metadata: {'missingHwCount': missingHwCount},
    );

    // ------------------------------------------------------------------
    // RULE 3: LEARNING_SUPPORT_WARNING (Tiếp thu cần củng cố >= 3 trong 5 buổi)
    // ------------------------------------------------------------------
    int needSupportCount = 0;
    for (var row in last5) {
      final hieuBaiScore = row['diem_hieu_bai'];
      final nhanXet = (row['nhan_xet'] as String?) ?? '';
      if (hieuBaiScore != null && (hieuBaiScore as num) < 6.0) {
        needSupportCount++;
      } else if (nhanXet.contains('Cần củng cố') ||
          nhanXet.contains('chưa hiểu bài') ||
          nhanXet.contains('cần kèm thêm')) {
        needSupportCount++;
      }
    }

    await _processRuleResult(
      studentId: studentId,
      signalType: StudentSignalType.LEARNING_SUPPORT_WARNING,
      isTriggered: needSupportCount >= 3,
      existingSignal:
          activeSignalsMap[StudentSignalType.LEARNING_SUPPORT_WARNING],
      title: 'Cần hỗ trợ học tập: $needSupportCount/5 buổi',
      description:
          'Học sinh có kết quả tiếp thu/hiểu bài cần củng cố ở $needSupportCount buổi trong 5 buổi gần đây.',
      severity: StudentTimelineSeverity.attention,
      metadata: {'needSupportCount': needSupportCount},
    );

    // ------------------------------------------------------------------
    // RULE 4: POSITIVE_STREAK (Khen thưởng: Thái độ tốt & BTVN đầy đủ >= 5 buổi liên tiếp)
    // ------------------------------------------------------------------
    int positiveStreak = 0;
    for (var row in recentSessions) {
      final thaiDo = row['diem_thai_do'];
      final hw = row['diem_bai_tap'];
      final nhanXet = (row['nhan_xet'] as String?) ?? '';

      bool isGood = false;
      if (thaiDo != null &&
          (thaiDo as num) >= 8.0 &&
          (hw == null || (hw as num) >= 8.0)) {
        isGood = true;
      } else if (nhanXet.contains('Tốt') ||
          nhanXet.contains('Tích cực') ||
          nhanXet.contains('Khen')) {
        isGood = true;
      }

      if (isGood) {
        positiveStreak++;
      } else {
        break;
      }
    }

    await _processRuleResult(
      studentId: studentId,
      signalType: StudentSignalType.POSITIVE_STREAK,
      isTriggered: positiveStreak >= 5,
      existingSignal: activeSignalsMap[StudentSignalType.POSITIVE_STREAK],
      title: '⭐ Chuỗi học tập tích cực: $positiveStreak buổi liên tiếp',
      description:
          'Học sinh duy trì thái độ tốt và làm bài đầy đủ $positiveStreak buổi học liên tiếp!',
      severity: StudentTimelineSeverity.positive,
      metadata: {'positiveStreak': positiveStreak},
    );

    // ------------------------------------------------------------------
    // RULE 5: PAYMENT_OVERDUE (Học phí nợ/quá hạn theo quy tắc canonical)
    // ------------------------------------------------------------------
    bool isOverdue = false;
    int debtAmount = 0;

    final studentClasses = await _lhsService.docDSLopCuaHS(studentId);
    final nowMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    for (var lop in studentClasses) {
      if (lop.id != null) {
        final rpt = await _reportService.layBaoCaoHocPhiThang(
          lop.id!,
          nowMonthStr,
          persist: false,
        );
        final debtItem = rpt.dsHocSinhConNo.firstWhere(
          (x) => x.idHocSinh == studentId,
          orElse: () => HocSinhNoHocPhi(
            idHocSinh: studentId,
            tenHocSinh: hs.ten,
            soTienCanNop: 0,
            soTienDaDong: 0,
            soTienConNo: 0,
            mienGiam: 0,
            soBuoiDu: 0,
          ),
        );
        if (debtItem.soTienConNo > 0) {
          isOverdue = true;
          debtAmount += debtItem.soTienConNo;
        }
      }
    }

    await _processRuleResult(
      studentId: studentId,
      signalType: StudentSignalType.PAYMENT_OVERDUE,
      isTriggered: isOverdue,
      existingSignal: activeSignalsMap[StudentSignalType.PAYMENT_OVERDUE],
      title: 'Cảnh báo: Học phí chưa hoàn tất',
      description:
          'Học sinh còn học phí chưa nộp với tổng số tiền nợ là $debtAmount VNĐ.',
      severity: StudentTimelineSeverity.warning,
      metadata: {'debtAmount': debtAmount},
    );

    notifyListeners();
    return getSignalsForStudent(studentId, activeOnly: true);
  }

  /// Cập nhật hoặc thêm/xóa signal mà không tạo bản sao duplicate
  Future<void> _processRuleResult({
    required int studentId,
    required StudentSignalType signalType,
    required bool isTriggered,
    required StudentSignal? existingSignal,
    required String title,
    required String description,
    required StudentTimelineSeverity severity,
    required Map<String, dynamic> metadata,
  }) async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toIso8601String();

    // Query DB trực tiếp để tránh race conditions gây duplicate
    final existingMaps = await db.query(
      DBHelper.tenBangStudentSignals,
      where: 'student_id = ? AND signal_type = ? AND status IN (?, ?, ?)',
      whereArgs: [
        studentId,
        signalType.name,
        'ACTIVE',
        'ACKNOWLEDGED',
        'SNOOZED',
      ],
      orderBy: 'id DESC',
    );

    StudentSignal? targetSignal = existingMaps.isNotEmpty
        ? StudentSignal.fromMap(existingMaps.first)
        : existingSignal;

    if (isTriggered) {
      if (targetSignal == null) {
        // Tạo mới Signal ở trạng thái ACTIVE
        final newSignal = StudentSignal(
          studentId: studentId,
          signalType: signalType,
          status: StudentSignalStatus.active,
          severity: severity,
          title: title,
          description: description,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: metadata,
        );
        await db.insert(DBHelper.tenBangStudentSignals, newSignal.toMap());
      } else {
        // Cập nhật signal hiện có (CẬP NHẬT UPDATE_AT, GIỮ TRẠNG THÁI HIỆN TẠI NẾU ĐÃ ACKNOWLEDGED)
        await db.update(
          DBHelper.tenBangStudentSignals,
          {
            'title': title,
            'description': description,
            'severity': severity.name.toUpperCase(),
            'updated_at': nowStr,
            'metadata': jsonEncode(metadata),
          },
          where: 'id = ?',
          whereArgs: [targetSignal.id],
        );
      }
    } else {
      // Nếu điều kiện không còn đúng -> Tự động RESOLVED signal đang active/snoozed/acknowledged
      if (targetSignal != null &&
          targetSignal.status != StudentSignalStatus.resolved) {
        await db.update(
          DBHelper.tenBangStudentSignals,
          {'status': 'RESOLVED', 'updated_at': nowStr},
          where: 'id = ?',
          whereArgs: [targetSignal.id],
        );
      }
    }
  }
}
