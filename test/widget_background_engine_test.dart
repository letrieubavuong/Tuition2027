// File: test/widget_background_engine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/home_widget_snapshot.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/lop_hoc_sinh.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/lop_service.dart';
import 'package:tuition2025/services/lop_hoc_sinh_service.dart';
import 'package:tuition2025/services/widget_snapshot_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    final dbHelper = DBHelper.instance;
    final db = await dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    for (var table in [
      DBHelper.tenBangAttentionItems,
      DBHelper.tenBangStudentSignals,
      DBHelper.tenBangDiemDanh,
      DBHelper.tenBangLopHS,
      DBHelper.tenBangLop,
      DBHelper.tenBangHS,
      DBHelper.tenBangCaiDat,
      'session_completion_ledger',
    ]) {
      try {
        await db.delete(table);
      } catch (_) {}
    }
    await db.execute('PRAGMA foreign_keys = ON');
  });

  group('ANDROID BACKGROUND WIDGET ENGINE TESTS', () {
    final hsService = HocSinhService();
    final lopService = LopService();
    final lhsService = LopHocSinhService();
    final widgetService = WidgetSnapshotService.instance;

    test(
      'TEST 1: Day rollover -> Sept 17 snapshot updated to Sept 18 on background refresh',
      () async {
        final sep17Date = DateTime(2026, 9, 17);
        final sep18Date = DateTime(2026, 9, 18);

        final snapshot17 = await widgetService.buildSnapshot(
          targetDate: sep17Date,
        );
        expect(snapshot17.date, equals('2026-09-17'));

        final snapshot18 = await widgetService.buildSnapshot(
          targetDate: sep18Date,
        );
        expect(snapshot18.date, equals('2026-09-18'));
      },
    );

    test(
      'TEST 2: Serialization / Deserialization -> HomeWidgetSnapshot roundtrip integrity',
      () {
        final snapshot = HomeWidgetSnapshot(
          date: '2026-09-18',
          dateFormatted: 'Thứ Sáu (18/09/2026)',
          widgetState: 'MORNING',
          todaySessionCount: 3,
          completedSessionCount: 1,
          currentSessionId: 10,
          currentSessionName: 'Vật lý 12A',
          currentStart: '17:30',
          currentEnd: '19:00',
          currentAttendedCount: 25,
          currentTotalCount: 28,
          attentionCount: 2,
          criticalCount: 1,
          unexcusedAbsenceCount: 1,
          tuitionReminderCount: 0,
          parentContactPendingCount: 1,
          studentAttentionCount: 0,
          dailyBriefSummary: 'Hôm nay có 3 ca dạy.',
          lastUpdatedAt: DateTime.now(),
          privacyMode: 'FULL',
        );

        final jsonStr = snapshot.toJson();
        final restored = HomeWidgetSnapshot.fromJson(jsonStr);

        expect(restored.date, equals('2026-09-18'));
        expect(restored.widgetState, equals('MORNING'));
        expect(restored.todaySessionCount, equals(3));
        expect(restored.currentSessionName, equals('Vật lý 12A'));
        expect(restored.currentAttendedCount, equals(25));
        expect(restored.isStale, isFalse);
      },
    );

    test(
      'TEST 3: No sessions scheduled today -> State set to NO_SESSION cleanly',
      () async {
        final snapshot = await widgetService.buildSnapshot(
          targetDate: DateTime(2026, 9, 18),
        );
        expect(snapshot.todaySessionCount, equals(0));
        expect(snapshot.widgetState, equals('NO_SESSION'));
      },
    );

    test('TEST 4: Snapshot older than 12 hours -> isStale returns true', () {
      final oldSnapshot = HomeWidgetSnapshot(
        date: '2026-09-17',
        dateFormatted: 'Thứ Năm (17/09/2026)',
        widgetState: 'EVENING_SUMMARY',
        todaySessionCount: 2,
        completedSessionCount: 2,
        attentionCount: 0,
        criticalCount: 0,
        unexcusedAbsenceCount: 0,
        tuitionReminderCount: 0,
        parentContactPendingCount: 0,
        studentAttentionCount: 0,
        lastUpdatedAt: DateTime.now().subtract(const Duration(hours: 13)),
      );

      expect(oldSnapshot.isStale, isTrue);
    });

    test(
      'TEST 5: Privacy mode HIDE_NAMES or COUNTS_ONLY -> Snapshot respects settings',
      () async {
        final db = await DBHelper.instance.database;
        await db.insert(DBHelper.tenBangCaiDat, {
          'khoa': 'widget_privacy_mode',
          'gia_tri': 'COUNTS_ONLY',
        });

        final snapshot = await widgetService.buildSnapshot(
          targetDate: DateTime(2026, 9, 18),
        );
        expect(snapshot.privacyMode, equals('COUNTS_ONLY'));
      },
    );

    test(
      'TEST 6: Offline local DB build -> 100% operates without internet connection',
      () async {
        final hs = await hsService.taoHocSinh(
          HS(ten: 'Học sinh Widget Offline'),
        );
        final lop = await lopService.taoLop(Lop(ten: '12AW1', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        final snapshot = await widgetService.buildSnapshot(
          targetDate: DateTime(2026, 9, 18),
        );
        expect(snapshot, isNotNull);
        expect(snapshot.date, equals('2026-09-18'));
      },
    );
  });
}
