import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/services/report_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Recalculate Remaining Sessions Idempotency & Correctness Tests', () {
    test(
      'Idempotency verification: running recalculate twice produces identical student remaining sessions',
      () async {
        final db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (Database db, int version) async {
            await db.execute('''
            CREATE TABLE ${DBHelper.tenBangHS} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ten TEXT NOT NULL,
              so_buoi_du INTEGER DEFAULT 0
            )
          ''');

            await db.execute('''
            CREATE TABLE ${DBHelper.tenBangLop} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ten TEXT NOT NULL,
              hoc_phi_hang_thang INTEGER DEFAULT 500000,
              hoc_phi_theo_buoi INTEGER DEFAULT 50000
            )
          ''');

            await db.execute('''
            CREATE TABLE ${DBHelper.tenBangLopHS} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_lop INTEGER,
              id_hoc_sinh INTEGER,
              ngay_tham_gia TEXT,
              ngay_nghi_hoc TEXT
            )
          ''');

            await db.execute('''
            CREATE TABLE ${DBHelper.tenBangDiemDanh} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_lop INTEGER,
              id_hoc_sinh INTEGER,
              gio_diem_danh TEXT,
              trang_thai TEXT
            )
          ''');

            await db.execute('''
            CREATE TABLE ${DBHelper.tenBangThanhToan} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_hoc_sinh INTEGER,
              id_lop INTEGER,
              thang TEXT,
              tong_thanh_toan INTEGER,
              so_tien_da_dong INTEGER,
              so_buoi_duoc_bu_tru INTEGER DEFAULT 0,
              so_buoi_du_con_lai INTEGER DEFAULT 0
            )
          ''');
          },
        );

        // Populate test student & class
        await db.insert(DBHelper.tenBangHS, {
          'id': 1,
          'ten': 'Hoc Sinh Test',
          'so_buoi_du': 0,
        });
        await db.insert(DBHelper.tenBangLop, {
          'id': 1,
          'ten': 'Lop 12A1',
          'hoc_phi_hang_thang': 600000,
        });
        await db.insert(DBHelper.tenBangLopHS, {
          'id_lop': 1,
          'id_hoc_sinh': 1,
          'ngay_tham_gia': '2026-09-01',
        });
        await db.insert(DBHelper.tenBangDiemDanh, {
          'id_lop': 1,
          'id_hoc_sinh': 1,
          'gio_diem_danh': '2026-09-05 08:00:00',
          'trang_thai': 'Có mặt',
        });

        final reportService = ReportService();

        // Run 1
        await reportService.recalculateAllStudentsRemainingSessions();
        final hsAfterRun1 = await db.query(
          DBHelper.tenBangHS,
          where: 'id = ?',
          whereArgs: [1],
        );
        final remainingSessionsRun1 = hsAfterRun1.first['so_buoi_du'];

        // Run 2
        await reportService.recalculateAllStudentsRemainingSessions();
        final hsAfterRun2 = await db.query(
          DBHelper.tenBangHS,
          where: 'id = ?',
          whereArgs: [1],
        );
        final remainingSessionsRun2 = hsAfterRun2.first['so_buoi_du'];

        // Verification: f(f(x)) == f(x)
        expect(remainingSessionsRun1, equals(remainingSessionsRun2));
        expect(remainingSessionsRun2, greaterThanOrEqualTo(0));

        await db.close();
      },
    );
  });
}
