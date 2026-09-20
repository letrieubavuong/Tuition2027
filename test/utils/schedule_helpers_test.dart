import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/utils/schedule_helpers.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('chuyenGioSangPhut Unit Tests', () {
    test('00:00 hợp lệ => 0 phút', () {
      expect(chuyenGioSangPhut('00:00'), equals(0));
      expect(chuyenGioSangPhut(' 00:00 '), equals(0));
    });

    test('HH:mm hợp lệ', () {
      expect(chuyenGioSangPhut('13:30'), equals(810));
      expect(chuyenGioSangPhut('08:15'), equals(495));
      expect(chuyenGioSangPhut('23:59'), equals(1439));
    });

    test('HH:mm:ss hợp lệ', () {
      expect(chuyenGioSangPhut('13:30:00'), equals(810));
      expect(chuyenGioSangPhut('08:15:30'), equals(495));
    });

    test('Chuỗi rỗng "" => null', () {
      expect(chuyenGioSangPhut(''), isNull);
      expect(chuyenGioSangPhut('   '), isNull);
    });

    test('Chuỗi không đúng định dạng "abc" => null', () {
      expect(chuyenGioSangPhut('abc'), isNull);
      expect(chuyenGioSangPhut('13'), isNull);
      expect(chuyenGioSangPhut('13:xx'), isNull);
    });

    test('Giờ vượt quá 23 "25:00" => null', () {
      expect(chuyenGioSangPhut('25:00'), isNull);
      expect(chuyenGioSangPhut('24:00'), isNull);
      expect(chuyenGioSangPhut('-1:00'), isNull);
    });

    test('Phút vượt quá 59 "12:60" => null', () {
      expect(chuyenGioSangPhut('12:60'), isNull);
      expect(chuyenGioSangPhut('12:-5'), isNull);
    });
  });

  group('validateTimeRange Unit Tests', () {
    test('start < end hợp lệ => true', () {
      expect(validateTimeRange('13:30', '15:00'), isTrue);
      expect(validateTimeRange('00:00', '00:01'), isTrue);
    });

    test('start > end => false', () {
      expect(validateTimeRange('15:00', '13:30'), isFalse);
    });

    test('start == end => false', () {
      expect(validateTimeRange('15:00', '15:00'), isFalse);
    });

    test('Format không hợp lệ => false', () {
      expect(validateTimeRange('abc', '15:00'), isFalse);
      expect(validateTimeRange('13:30', '25:00'), isFalse);
    });
  });

  group('normalizeTime Unit Tests', () {
    test('Chuẩn hóa chuỗi thời gian về HH:mm', () {
      expect(normalizeTime('13:30:00'), equals('13:30'));
      expect(normalizeTime('9:5'), equals('09:05'));
      expect(normalizeTime('00:00'), equals('00:00'));
      expect(normalizeTime('abc'), equals('abc'));
    });
  });

  group('kiemTraChongLanLichHoc Integration Tests with SQLite FFI', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE lich_hoc (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_lop INTEGER NOT NULL,
              thuTrongTuan INTEGER NOT NULL,
              gioBatDau TEXT NOT NULL,
              gioKetThuc TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE lich_hoc_chung (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_lop INTEGER NOT NULL,
              ngay_trong_tuan TEXT NOT NULL,
              gio_bat_dau TEXT NOT NULL,
              gio_ket_thuc TEXT NOT NULL
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('13:30-15:00 vs 14:00-16:00 => conflict (true)', () async {
      await db.insert('lich_hoc', {
        'id_lop': 1,
        'thuTrongTuan': 2,
        'gioBatDau': '14:00',
        'gioKetThuc': '16:00',
      });

      final result = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: 'lich_hoc',
        idLop: 1,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: 2,
        gioBatDauMoi: '13:30',
        gioKetThucMoi: '15:00',
      );

      expect(result, isTrue);
    });

    test('13:30-15:00 vs 15:00-16:30 => no conflict (false)', () async {
      await db.insert('lich_hoc', {
        'id_lop': 1,
        'thuTrongTuan': 2,
        'gioBatDau': '15:00',
        'gioKetThuc': '16:30',
      });

      final result = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: 'lich_hoc',
        idLop: 1,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: 2,
        gioBatDauMoi: '13:30',
        gioKetThucMoi: '15:00',
      );

      expect(result, isFalse);
    });

    test('Exact duplicate => conflict (true)', () async {
      await db.insert('lich_hoc', {
        'id_lop': 1,
        'thuTrongTuan': 2,
        'gioBatDau': '13:30',
        'gioKetThuc': '15:00',
      });

      final result = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: 'lich_hoc',
        idLop: 1,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: 2,
        gioBatDauMoi: '13:30',
        gioKetThucMoi: '15:00',
      );

      expect(result, isTrue);
    });

    test('start > end => invalid/reject (true)', () async {
      final result = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: 'lich_hoc',
        idLop: 1,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: 2,
        gioBatDauMoi: '15:00',
        gioKetThucMoi: '13:30',
      );

      expect(result, isTrue);
    });

    test('start == end => invalid/reject (true)', () async {
      final result = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: 'lich_hoc',
        idLop: 1,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: 2,
        gioBatDauMoi: '15:00',
        gioKetThucMoi: '15:00',
      );

      expect(result, isTrue);
    });

    test('excludeId loại trừ lịch đang được update', () async {
      final id = await db.insert('lich_hoc', {
        'id_lop': 1,
        'thuTrongTuan': 2,
        'gioBatDau': '14:00',
        'gioKetThuc': '16:00',
      });

      final result = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: 'lich_hoc',
        idLop: 1,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: 2,
        gioBatDauMoi: '13:30',
        gioKetThucMoi: '15:00',
        excludeId: id,
      );

      expect(result, isFalse);
    });

    test('Compatibility với lich_hoc_chung', () async {
      await db.insert('lich_hoc_chung', {
        'id_lop': 1,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '14:00',
        'gio_ket_thuc': '16:00',
      });

      final resultConflict = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: 'lich_hoc_chung',
        idLop: 1,
        cotNgay: 'ngay_trong_tuan',
        giaTriNgay: 'Thứ Hai',
        gioBatDauMoi: '13:30',
        gioKetThucMoi: '15:00',
      );

      expect(resultConflict, isTrue);

      final resultNoConflict = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: 'lich_hoc_chung',
        idLop: 1,
        cotNgay: 'ngay_trong_tuan',
        giaTriNgay: 'Thứ Hai',
        gioBatDauMoi: '16:00',
        gioKetThucMoi: '17:30',
      );

      expect(resultNoConflict, isFalse);
    });

    test('DB exception / closed DB => fail-closed conflict (true)', () async {
      final closedDb = await openDatabase(inMemoryDatabasePath);
      await closedDb.close();

      final result = await kiemTraChongLanLichHoc(
        db: closedDb,
        tenBang: 'lich_hoc',
        idLop: 1,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: 2,
        gioBatDauMoi: '13:30',
        gioKetThucMoi: '15:00',
      );

      expect(result, isTrue);
    });
  });
}
