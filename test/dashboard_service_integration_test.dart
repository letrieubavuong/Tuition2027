import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/services/dashboard_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() {
    DBHelper.setTestDatabase(null);
  });

  group('DashboardService Real Database Integration Test', () {
    test('getDashboardData executes cleanly without throwing exceptions', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: 36,
        onCreate: (db, version) async {
          // Create basic tables
          await db.execute('CREATE TABLE lop (id INTEGER PRIMARY KEY AUTOINCREMENT, ten TEXT UNIQUE, khoi INTEGER)');
          await db.execute('CREATE TABLE hoc_sinh (id INTEGER PRIMARY KEY AUTOINCREMENT, ten TEXT)');
          await db.execute('CREATE TABLE lop_hoc_sinh (id INTEGER PRIMARY KEY AUTOINCREMENT, id_hoc_sinh INTEGER, id_lop INTEGER, trang_thai TEXT DEFAULT "DANG_HOC")');
          await db.execute('CREATE TABLE lich_hoc (id INTEGER PRIMARY KEY AUTOINCREMENT, id_lop INTEGER, thuTrongTuan INTEGER, gioBatDau TEXT, gioKetThuc TEXT)');
          await db.execute('CREATE TABLE diem_danh (id INTEGER PRIMARY KEY AUTOINCREMENT, id_hoc_sinh INTEGER, id_lop INTEGER, gio_diem_danh TEXT, trang_thai TEXT)');
          await db.execute('CREATE TABLE thanh_toan (id INTEGER PRIMARY KEY AUTOINCREMENT, id_hoc_sinh INTEGER, id_lop INTEGER, thang TEXT, tong_thanh_toan INTEGER, so_tien_da_dong INTEGER)');
          await db.execute('CREATE TABLE nhiem_vu (id INTEGER PRIMARY KEY AUTOINCREMENT, id_lop INTEGER, ten_nhiem_vu TEXT, ngay_giao TEXT, ngay_nop TEXT)');
          await db.execute('CREATE TABLE nhiem_vu_hoc_sinh (id_nhiem_vu INTEGER, id_hoc_sinh INTEGER, trang_thai TEXT)');
          await db.execute('CREATE TABLE session_completion_ledger (id TEXT PRIMARY KEY, class_id INTEGER, session_id INTEGER, session_date TEXT, status TEXT, session_status TEXT, review_status TEXT)');
          await db.execute('CREATE TABLE attention_items (id TEXT PRIMARY KEY, type TEXT, severity TEXT, priority TEXT, status TEXT, title TEXT, summary TEXT, source_type TEXT, action_type TEXT, action_label TEXT)');

          // Seed test data
          await db.insert('lop', {'id': 1, 'ten': 'Lớp 10A1', 'khoi': 10});
          await db.insert('lop', {'id': 2, 'ten': 'Lớp 11B1', 'khoi': 11});
          await db.insert('hoc_sinh', {'id': 101, 'ten': 'Nguyễn Văn A'});
          await db.insert('hoc_sinh', {'id': 102, 'ten': 'Trần Thị B'});
          await db.insert('lop_hoc_sinh', {'id_hoc_sinh': 101, 'id_lop': 1, 'trang_thai': 'DANG_HOC'});
          await db.insert('lop_hoc_sinh', {'id_hoc_sinh': 102, 'id_lop': 2, 'trang_thai': 'DANG_HOC'});
          await db.insert('lich_hoc', {'id_lop': 1, 'thuTrongTuan': DateTime.now().weekday == 7 ? 1 : DateTime.now().weekday + 1, 'gioBatDau': '08:00', 'gioKetThuc': '10:00'});
          await db.insert('thanh_toan', {'id_hoc_sinh': 101, 'id_lop': 1, 'thang': '2026-09', 'tong_thanh_toan': 500000, 'so_tien_da_dong': 300000});
          await db.insert('nhiem_vu', {'id': 1, 'id_lop': 1, 'ten_nhiem_vu': 'Bài tập về nhà Hàm số', 'ngay_giao': '2026-09-18', 'ngay_nop': '2026-09-20'});
        },
      );

      DBHelper.setTestDatabase(db);

      final service = DashboardService();
      final data = await service.getDashboardData();

      print('\n📊 DIAGNOSTIC RESULTS:');
      print('• Total Students (soHocSinh): ${data.soHocSinh}');
      print('• Total Classes (soLopHoc): ${data.soLopHoc}');
      print('• Today Sessions (soCaHocHomNay): ${data.soCaHocHomNay}');
      print('• Total Debt (tongTienNo): ${data.tongTienNo}');
      print('• Total Collected (tongTienThu): ${data.tongTienThu}');

      expect(data.soHocSinh, equals(2));
      expect(data.soLopHoc, equals(2));
      expect(data.soCaHocHomNay, equals(1));
      expect(data.tongTienNo, equals(200000));
      expect(data.tongTienThu, equals(300000));
    });
  });
}
