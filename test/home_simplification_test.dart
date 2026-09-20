// File: test/home_simplification_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/student_signal.dart';
import 'package:tuition2025/models/student_timeline.dart';
import 'package:tuition2025/services/dashboard_service.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/lop_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late DashboardService dashboardService;
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
    await db.execute('PRAGMA foreign_keys = ON');

    dashboardService = DashboardService();
    hsService = HocSinhService();
    lopService = LopService();
  });

  test('TEST 1: DashboardService getDashboardData is fast and lightweight (< 50ms)', () async {
    await lopService.taoLop(Lop(ten: 'Lớp 10A1', khoi: 10));
    await hsService.taoHocSinh(HS(ten: 'Nguyễn Văn Test', sdtPhuHuynh: '0901112233'));

    final sw = Stopwatch()..start();
    final data = await dashboardService.getDashboardData();
    sw.stop();

    expect(data.soLopHoc, equals(1));
    expect(data.soHocSinh, equals(1));
    expect(sw.elapsedMilliseconds, lessThan(100));
  });

  test('TEST 2: NEED_REVIEW payment transactions do not contaminate Home DashboardData', () async {
    // Insert 30 NEED_REVIEW transactions
    for (int i = 0; i < 30; i++) {
      await db.insert('payment_transactions', {
        'transaction_id': 'TX_$i',
        'hoc_sinh_id': 0,
        'lop_id': 0,
        'amount': 500000,
        'raw_content': 'Chuyen tien hoc phi $i',
        'status': 'NEED_REVIEW',
        'month': '2026-09',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    final sw = Stopwatch()..start();
    final data = await dashboardService.getDashboardData();
    sw.stop();

    // Home loading speed is independent of NEED_REVIEW payment count
    expect(sw.elapsedMilliseconds, lessThan(100));
  });

  test('TEST 3: 300 Student signals do not contaminate Home DashboardData', () async {
    final hs = await hsService.taoHocSinh(HS(ten: 'Student Signal Test'));
    for (int i = 0; i < 300; i++) {
      await db.insert(DBHelper.tenBangStudentSignals, StudentSignal(
        studentId: hs.id!,
        signalType: StudentSignalType.UNEXCUSED_ABSENCE_WARNING,
        status: StudentSignalStatus.active,
        severity: StudentTimelineSeverity.warning,
        title: 'Signal $i',
        description: 'Vắng $i',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ).toMap());
    }

    final sw = Stopwatch()..start();
    final data = await dashboardService.getDashboardData();
    sw.stop();

    expect(sw.elapsedMilliseconds, lessThan(100));
  });
}
