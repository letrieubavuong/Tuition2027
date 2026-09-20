// File: test/stability_v2_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/attention_item.dart';
import 'package:tuition2025/models/diem_danh.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/student_signal.dart';
import 'package:tuition2025/models/student_timeline.dart';
import 'package:tuition2025/services/attention_queue_service.dart';
import 'package:tuition2025/services/attendance_correction_service.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/lop_service.dart';
import 'package:tuition2025/services/student_signal_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late AttentionQueueService aqService;
  late AttendanceCorrectionService acService;
  late StudentSignalService signalService;
  late HocSinhService hsService;
  late LopService lopService;

  setUp(() async {
    final dbHelper = DBHelper.instance;
    db = await dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.delete(DBHelper.tenBangAttentionItems);
    await db.delete(DBHelper.tenBangStudentSignals);
    await db.delete(DBHelper.tenBangDanhGiaBuoiHoc);
    await db.delete(DBHelper.tenBangDiemDanh);
    await db.delete(DBHelper.tenBangLopHS);
    await db.delete(DBHelper.tenBangLop);
    await db.delete(DBHelper.tenBangHS);
    await db.delete('payment_transactions');
    await db.delete('parent_communications');
    await db.delete('session_completion_ledger');
    await db.delete('session_homework');
    await db.delete(DBHelper.tenBangAttendanceChangeLog);
    await db.execute('PRAGMA foreign_keys = ON');

    aqService = AttentionQueueService.instance;
    acService = AttendanceCorrectionService.instance;
    signalService = StudentSignalService.instance;
    hsService = HocSinhService();
    lopService = LopService();
  });

  test('TEST 1 & 2: readAttentionQueue and getSummaryCounts are fast & lightweight', () async {
    final savedHs = await hsService.taoHocSinh(HS(ten: 'Nguyễn Văn A', sdtPhuHuynh: '0901234567'));
    final signal = StudentSignal(
      studentId: savedHs.id!,
      signalType: StudentSignalType.UNEXCUSED_ABSENCE_WARNING,
      status: StudentSignalStatus.active,
      severity: StudentTimelineSeverity.warning,
      title: 'Cảnh báo vắng',
      description: 'Nghỉ 2 buổi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert(DBHelper.tenBangStudentSignals, signal.toMap());

    // Refresh sources once
    await aqService.refreshAttentionSources(force: true);

    final swRead = Stopwatch()..start();
    final items = await aqService.readAttentionQueue(activeOnly: true);
    swRead.stop();

    expect(items.length, greaterThanOrEqualTo(1));
    expect(swRead.elapsedMilliseconds, lessThan(200));

    final swSummary = Stopwatch()..start();
    final counts = await aqService.getSummaryCounts();
    swSummary.stop();

    expect(counts['total'], equals(items.length));
    expect(swSummary.elapsedMilliseconds, lessThan(100));
  });

  test('TEST 3: Single-flight refresh prevents duplicate parallel runs', () async {
    final f1 = aqService.refreshAttentionSources(force: true);
    final f2 = aqService.refreshAttentionSources(force: true);

    // Concurrent call should reuse in-flight future
    expect(identical(f1, f2), isTrue);
    await f1;
  });

  test('TEST 4, 5: Acknowledge & Snooze status update semantics', () async {
    final savedHs = await hsService.taoHocSinh(HS(ten: 'Trần Văn B'));
    final signal = StudentSignal(
      studentId: savedHs.id!,
      signalType: StudentSignalType.HOMEWORK_REPEATED_WARNING,
      status: StudentSignalStatus.active,
      severity: StudentTimelineSeverity.warning,
      title: 'Thiếu BTVN',
      description: 'Thiếu BTVN 3 buổi',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await db.insert(DBHelper.tenBangStudentSignals, signal.toMap());
    await aqService.refreshAttentionSources(force: true);

    final items = await aqService.readAttentionQueue(activeOnly: true);
    final targetId = items.first.id;

    // Acknowledge
    await aqService.acknowledge(targetId);
    var updated = await aqService.readAttentionQueue(activeOnly: true);
    var ackedItem = updated.firstWhere((x) => x.id == targetId);
    expect(ackedItem.status, equals(AttentionStatus.acknowledged));

    // Snooze 24 hours (should be excluded when activeOnly=true)
    await aqService.snooze(targetId, duration: const Duration(hours: 24));
    updated = await aqService.readAttentionQueue(activeOnly: true);
    expect(updated.any((x) => x.id == targetId), isFalse);
  });

  test('TEST 6: Source reconciliation auto-resolves AttentionItem when domain signal resolves', () async {
    final savedHs = await hsService.taoHocSinh(HS(ten: 'Lê Văn C'));
    final sigId = await db.insert(DBHelper.tenBangStudentSignals, StudentSignal(
      studentId: savedHs.id!,
      signalType: StudentSignalType.UNEXCUSED_ABSENCE_WARNING,
      status: StudentSignalStatus.active,
      severity: StudentTimelineSeverity.warning,
      title: 'Vắng mặt',
      description: 'Vắng',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ).toMap());

    await aqService.refreshAttentionSources(force: true);
    var items = await aqService.readAttentionQueue(activeOnly: true);
    expect(items.any((x) => x.sourceId.toString() == sigId.toString()), isTrue);

    // Resolve signal in DB
    await db.update(
      DBHelper.tenBangStudentSignals,
      {'status': 'RESOLVED'},
      where: 'id = ?',
      whereArgs: [sigId],
    );

    // Refresh attention sources
    await aqService.refreshAttentionSources(force: true);
    items = await aqService.readAttentionQueue(activeOnly: true);
    expect(items.any((x) => x.sourceId.toString() == sigId.toString()), isFalse);
  });

  test('TEST 14: Multi-slot session cancellation isolation on same day', () async {
    final savedLop = await lopService.taoLop(Lop(ten: 'Lớp Lập Trình', khoi: 10));
    final classId = savedLop.id!;
    final savedHs = await hsService.taoHocSinh(HS(ten: 'Phạm Văn D'));
    final hsId = savedHs.id!;

    // Create 2 sessions on same day (Ca 1: 08:00, Ca 2: 14:00)
    final dd1 = await db.insert(DBHelper.tenBangDiemDanh, DiemDanh(
      idLop: classId,
      idHocSinh: hsId,
      trangThai: 'Có mặt',
      gioDiemDanh: '2026-09-20 08:00:00',
    ).toMap());
    final dd2 = await db.insert(DBHelper.tenBangDiemDanh, DiemDanh(
      idLop: classId,
      idHocSinh: hsId,
      trangThai: 'Có mặt',
      gioDiemDanh: '2026-09-20 14:00:00',
    ).toMap());

    // Cancel Ca 2 (14:00) only
    await acService.cancelSession(
      classId: classId,
      dateStr: '2026-09-20',
      startTime: '14:00',
      reason: 'Hủy ca chiều',
    );

    // Ca 1 (08:00) attendance record should remain untouched
    final att1Map = await db.query(DBHelper.tenBangDiemDanh, where: 'id = ?', whereArgs: [dd1]);
    expect(att1Map.isNotEmpty, isTrue);

    // Session impact for Ca 1 (08:00) should return 1 attendance record
    final impactCa1 = await acService.getSessionImpact(
      classId: classId,
      dateStr: '2026-09-20',
      startTime: '08:00',
    );
    expect(impactCa1.attendanceCount, equals(1));
  });

  test('TEST 17: Attendance edit commits DB before signal recomputation', () async {
    final savedLop = await lopService.taoLop(Lop(ten: 'Lớp Toán', khoi: 10));
    final classId = savedLop.id!;
    final savedHs = await hsService.taoHocSinh(HS(ten: 'Hoàng Văn E'));
    final hsId = savedHs.id!;

    final ddId = await db.insert(DBHelper.tenBangDiemDanh, DiemDanh(
      idLop: classId,
      idHocSinh: hsId,
      trangThai: 'Vắng không phép',
      gioDiemDanh: '2026-09-20 10:00:00',
    ).toMap());

    await acService.editStudentStatus(
      attendanceId: ddId,
      newStatus: 'Có mặt',
      reason: 'Điểm danh nhầm',
    );

    final row = await db.query(DBHelper.tenBangDiemDanh, where: 'id = ?', whereArgs: [ddId]);
    expect(row.first['trang_thai'], equals('Có mặt'));
  });
}
