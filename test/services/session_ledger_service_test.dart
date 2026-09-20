// File: test/services/session_ledger_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/utils/db.dart';
import 'package:tuition2025/services/session_ledger_service.dart';

void main() {
  late Database db;
  late SessionLedgerService ledgerService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 30,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE hoc_sinh (id INTEGER PRIMARY KEY AUTOINCREMENT, ten TEXT, so_buoi_du INTEGER NOT NULL DEFAULT 0)',
        );
        await db.execute(
          'CREATE TABLE lop (id INTEGER PRIMARY KEY AUTOINCREMENT, ten TEXT, khoi INTEGER)',
        );
        await db.execute('''
          CREATE TABLE lop_hoc_sinh (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_hoc_sinh INTEGER,
            id_lop INTEGER,
            ngay_tham_gia TEXT,
            ngay_tam_ngung TEXT,
            ngay_du_kien_hoc_lai TEXT,
            ngay_hoc_lai_thuc_te TEXT,
            ngay_nghi_hoc TEXT,
            ngay_hoc_lai_sau_nghi TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE lich_hoc_chung (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_lop INTEGER,
            ngay_trong_tuan TEXT,
            gio_bat_dau TEXT,
            gio_ket_thuc TEXT,
            effective_from TEXT NOT NULL DEFAULT '2000-01-01',
            effective_to TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE diem_danh (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_hoc_sinh INTEGER,
            id_lop INTEGER,
            gio_diem_danh TEXT,
            trang_thai TEXT,
            ghi_chu TEXT,
            ngay_vang_goc TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE don_nghi_hoc (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_hoc_sinh INTEGER,
            id_lop INTEGER,
            tu_ngay TEXT,
            den_ngay TEXT,
            ly_do TEXT,
            ngay_tao TEXT,
            loai_nghi TEXT NOT NULL DEFAULT 'CANHAN'
          )
        ''');
      },
    );
    DBHelper.setTestDatabase(db);
    ledgerService = SessionLedgerService();
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'TEST 1: HS tham gia từ đầu tháng, lịch 13 buổi, tất cả CÓ MẶT -> phát sinh 1 buổi dư',
    () async {
      await db.insert('hoc_sinh', {'id': 1, 'ten': 'Học sinh A'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 1,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
      });

      // Lịch Thứ 2, Thứ 4, Thứ 6 (Tháng 09/2026: 13 buổi)
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Tư',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Sáu',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      // Điểm danh có mặt tất cả các buổi
      final dates = [
        '2026-09-02',
        '2026-09-04',
        '2026-09-07',
        '2026-09-09',
        '2026-09-11',
        '2026-09-14',
        '2026-09-16',
        '2026-09-18',
        '2026-09-21',
        '2026-09-23',
        '2026-09-25',
        '2026-09-28',
        '2026-09-30',
      ];
      for (final d in dates) {
        await db.insert('diem_danh', {
          'id_hoc_sinh': 1,
          'id_lop': 101,
          'gio_diem_danh': '$d 17:30:00',
          'trang_thai': 'CO_MAT',
        });
      }

      final res = await ledgerService.rebuildStudentSessionBalance(
        1,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      expect(res.currentBalance, equals(1));
      expect(res.monthlyLedgers.first.earnedExtra, equals(1));
      expect(res.monthlyLedgers.first.scheduledEligibleCount, equals(13));
    },
  );

  test(
    'TEST 2: HS tham gia giữa tháng (15/09) -> KHÔNG bị cộng dư mặc định',
    () async {
      await db.insert('hoc_sinh', {'id': 2, 'ten': 'Học sinh B'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 2,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-15',
      });

      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Tư',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Sáu',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      // Điểm danh từ 15/09 trở đi
      final dates = [
        '2026-09-16',
        '2026-09-18',
        '2026-09-21',
        '2026-09-23',
        '2026-09-25',
        '2026-09-28',
        '2026-09-30',
      ];
      for (final d in dates) {
        await db.insert('diem_danh', {
          'id_hoc_sinh': 2,
          'id_lop': 101,
          'gio_diem_danh': '$d 17:30:00',
          'trang_thai': 'CO_MAT',
        });
      }

      final res = await ledgerService.rebuildStudentSessionBalance(
        2,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      expect(
        res.currentBalance,
        equals(0),
      ); // Chỉ có 7 buổi eligible <= 12 -> dư = 0
      expect(res.monthlyLedgers.first.scheduledEligibleCount, equals(7));
    },
  );

  test(
    'TEST 3: Lịch thay đổi giữa các tháng -> Tháng trước dùng lịch cũ, tháng sau dùng lịch mới',
    () async {
      await db.insert('hoc_sinh', {'id': 3, 'ten': 'Học sinh C'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 3,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
      });

      // Lịch tháng 9 (T2, T4, T6) hết hạn 2026-09-30
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
        'effective_to': '2026-09-30',
      });
      // Lịch tháng 10 (T3, T5, T7) từ 2026-10-01
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Ba',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-10-01',
      });

      final res = await ledgerService.rebuildStudentSessionBalance(
        3,
        101,
        untilDate: DateTime(2026, 10, 31),
      );
      expect(res.monthlyLedgers.length, equals(2));
      expect(res.monthlyLedgers[0].yearMonth, equals('2026-09'));
      expect(res.monthlyLedgers[1].yearMonth, equals('2026-10'));
    },
  );

  test(
    'TEST 4: Có VANG_CO_PHEP tại buổi thứ 13 -> Buổi đó KHÔNG biến thành buổi dư',
    () async {
      await db.insert('hoc_sinh', {'id': 4, 'ten': 'Học sinh D'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 4,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
      });

      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Tư',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Sáu',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      final dates = [
        '2026-09-02',
        '2026-09-04',
        '2026-09-07',
        '2026-09-09',
        '2026-09-11',
        '2026-09-14',
        '2026-09-16',
        '2026-09-18',
        '2026-09-21',
        '2026-09-23',
        '2026-09-25',
        '2026-09-28',
        '2026-09-30',
      ];
      for (int i = 0; i < dates.length; i++) {
        final status = (i == 12)
            ? 'VANG_CO_PHEP'
            : 'CO_MAT'; // Buổi thứ 13 vắng có phép
        await db.insert('diem_danh', {
          'id_hoc_sinh': 4,
          'id_lop': 101,
          'gio_diem_danh': '${dates[i]} 17:30:00',
          'trang_thai': status,
        });
      }

      final res = await ledgerService.rebuildStudentSessionBalance(
        4,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      expect(
        res.currentBalance,
        equals(0),
      ); // Buổi thứ 13 vắng -> earnedExtra = 0
    },
  );

  test(
    'TEST 5: Có VANG_KHONG_PHEP tại buổi thứ 13 -> KHÔNG biến thành buổi dư',
    () async {
      await db.insert('hoc_sinh', {'id': 5, 'ten': 'Học sinh E'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 5,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
      });

      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Tư',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Sáu',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      final dates = [
        '2026-09-02',
        '2026-09-04',
        '2026-09-07',
        '2026-09-09',
        '2026-09-11',
        '2026-09-14',
        '2026-09-16',
        '2026-09-18',
        '2026-09-21',
        '2026-09-23',
        '2026-09-25',
        '2026-09-28',
        '2026-09-30',
      ];
      for (int i = 0; i < dates.length; i++) {
        final status = (i == 12) ? 'VANG_KHONG_PHEP' : 'CO_MAT';
        await db.insert('diem_danh', {
          'id_hoc_sinh': 5,
          'id_lop': 101,
          'gio_diem_danh': '${dates[i]} 17:30:00',
          'trang_thai': status,
        });
      }

      final res = await ledgerService.rebuildStudentSessionBalance(
        5,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      expect(res.currentBalance, equals(0));
    },
  );

  test(
    'TEST 6 & 7: VANG_CO_PHEP + HOC_BU có ngay_vang_goc -> HOC_BU không tạo thêm buổi dư mới',
    () async {
      await db.insert('hoc_sinh', {'id': 6, 'ten': 'Học sinh F'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 6,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
      });

      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      // 07/09 Vắng có phép, 12/09 Học bù cho 07/09
      await db.insert('diem_danh', {
        'id_hoc_sinh': 6,
        'id_lop': 101,
        'gio_diem_danh': '2026-09-07 17:30:00',
        'trang_thai': 'VANG_CO_PHEP',
      });
      await db.insert('diem_danh', {
        'id_hoc_sinh': 6,
        'id_lop': 101,
        'gio_diem_danh': '2026-09-12 17:30:00',
        'trang_thai': 'HOC_BU',
        'ngay_vang_goc': '2026-09-07',
      });

      final res = await ledgerService.rebuildStudentSessionBalance(
        6,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      expect(res.monthlyLedgers.first.hocBuCount, equals(1));
      expect(res.monthlyLedgers.first.vangCoPhepCount, equals(1));
    },
  );

  test(
    'TEST 8: HS tạm nghỉ rồi học lại -> Các session trong khoảng tạm nghỉ bị đánh dấu Ineligible',
    () async {
      await db.insert('hoc_sinh', {'id': 8, 'ten': 'Học sinh H'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 8,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
        'ngay_tam_ngung': '2026-09-10',
        'ngay_hoc_lai_thuc_te': '2026-09-20',
      });

      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      final res = await ledgerService.rebuildStudentSessionBalance(
        8,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      final sept = res.monthlyLedgers.first;
      // 14/09 (Thứ 2) thuộc khoảng [10/09, 20/09) -> Ineligible
      final item14 = sept.sessions.firstWhere((s) => s.date == '2026-09-14');
      expect(item14.isScheduledEligible, isFalse);
    },
  );

  test(
    'TEST 9: HS nghỉ hẳn giữa tháng -> Các session sau ngày nghỉ bị đánh dấu Ineligible',
    () async {
      await db.insert('hoc_sinh', {'id': 9, 'ten': 'Học sinh I'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 9,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
        'ngay_nghi_hoc': '2026-09-15',
      });

      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      final res = await ledgerService.rebuildStudentSessionBalance(
        9,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      final sept = res.monthlyLedgers.first;
      final item21 = sept.sessions.firstWhere((s) => s.date == '2026-09-21');
      expect(item21.isScheduledEligible, isFalse);
    },
  );

  test(
    'TEST 10 & 11: Session không có attendance & Điểm danh ngoài lịch -> Phát hiện DATA_WARNING',
    () async {
      await db.insert('hoc_sinh', {'id': 10, 'ten': 'Học sinh J'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 10,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      // 13/09 là Chủ Nhật (không có lịch), nhưng có điểm danh
      await db.insert('diem_danh', {
        'id_hoc_sinh': 10,
        'id_lop': 101,
        'gio_diem_danh': '2026-09-13 17:30:00',
        'trang_thai': 'CO_MAT',
      });

      final res = await ledgerService.rebuildStudentSessionBalance(
        10,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      final sept = res.monthlyLedgers.first;
      final item13 = sept.sessions.firstWhere((s) => s.date == '2026-09-13');
      expect(
        item13.warnings.any((w) => w.contains('ngoài khung lịch học')),
        isTrue,
      );
    },
  );

  test(
    'TEST 12: Rebuild 10 lần liên tiếp -> Kết quả 100% giữ nguyên (Idempotency)',
    () async {
      await db.insert('hoc_sinh', {'id': 12, 'ten': 'Học sinh L'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 12,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Tư',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Sáu',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      final dates = [
        '2026-09-02',
        '2026-09-04',
        '2026-09-07',
        '2026-09-09',
        '2026-09-11',
        '2026-09-14',
        '2026-09-16',
        '2026-09-18',
        '2026-09-21',
        '2026-09-23',
        '2026-09-25',
        '2026-09-28',
        '2026-09-30',
      ];
      for (final d in dates) {
        await db.insert('diem_danh', {
          'id_hoc_sinh': 12,
          'id_lop': 101,
          'gio_diem_danh': '$d 17:30:00',
          'trang_thai': 'CO_MAT',
        });
      }

      final firstRun = await ledgerService.rebuildStudentSessionBalance(
        12,
        101,
        untilDate: DateTime(2026, 9, 30),
      );

      for (int i = 0; i < 10; i++) {
        final repeatRun = await ledgerService.rebuildStudentSessionBalance(
          12,
          101,
          untilDate: DateTime(2026, 9, 30),
        );
        expect(repeatRun.currentBalance, equals(firstRun.currentBalance));
        expect(
          repeatRun.monthlyLedgers.first.earnedExtra,
          equals(firstRun.monthlyLedgers.first.earnedExtra),
        );
      }
    },
  );

  test(
    'TEST 13 & 14: Hai HS cùng lớp vào khác ngày -> Số dư khác nhau chính xác',
    () async {
      await db.insert('hoc_sinh', {'id': 141, 'ten': 'Học sinh X'});
      await db.insert('hoc_sinh', {'id': 142, 'ten': 'Học sinh Y'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});

      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 141,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
      });
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 142,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-15',
      });

      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Tư',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Sáu',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      final dates = [
        '2026-09-02',
        '2026-09-04',
        '2026-09-07',
        '2026-09-09',
        '2026-09-11',
        '2026-09-14',
        '2026-09-16',
        '2026-09-18',
        '2026-09-21',
        '2026-09-23',
        '2026-09-25',
        '2026-09-28',
        '2026-09-30',
      ];
      for (final d in dates) {
        await db.insert('diem_danh', {
          'id_hoc_sinh': 141,
          'id_lop': 101,
          'gio_diem_danh': '$d 17:30:00',
          'trang_thai': 'CO_MAT',
        });
      }
      for (final d in dates.where((x) => x.compareTo('2026-09-15') >= 0)) {
        await db.insert('diem_danh', {
          'id_hoc_sinh': 142,
          'id_lop': 101,
          'gio_diem_danh': '$d 17:30:00',
          'trang_thai': 'CO_MAT',
        });
      }

      final resX = await ledgerService.rebuildStudentSessionBalance(
        141,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      final resY = await ledgerService.rebuildStudentSessionBalance(
        142,
        101,
        untilDate: DateTime(2026, 9, 30),
      );

      expect(resX.currentBalance, equals(1));
      expect(resY.currentBalance, equals(0));
    },
  );

  test(
    'TEST 15: Ngày nghỉ toàn lớp (TOANLOP) bị loại khỏi isScheduledEligible và không làm phát sinh buổi dư',
    () async {
      await db.insert('hoc_sinh', {'id': 15, 'ten': 'Học sinh Holiday'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10'});
      await db.insert('lop_hoc_sinh', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'ngay_tham_gia': '2026-09-01',
      });

      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Hai',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Tư',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });
      await db.insert('lich_hoc_chung', {
        'id_lop': 101,
        'ngay_trong_tuan': 'Thứ Sáu',
        'gio_bat_dau': '17:30',
        'gio_ket_thuc': '19:30',
        'effective_from': '2026-09-01',
      });

      // 02/09 (Quốc Khánh) đăng ký nghỉ toàn lớp TOANLOP
      await db.insert('don_nghi_hoc', {
        'id_hoc_sinh': null,
        'id_lop': 101,
        'tu_ngay': '2026-09-02',
        'den_ngay': '2026-09-02',
        'ly_do': 'Nghỉ lễ Quốc Khánh 2/9',
        'loai_nghi': 'TOANLOP',
      });

      final res = await ledgerService.rebuildStudentSessionBalance(
        15,
        101,
        untilDate: DateTime(2026, 9, 30),
      );
      final sept = res.monthlyLedgers.first;

      final item02 = sept.sessions.firstWhere((s) => s.date == '2026-09-02');
      expect(item02.attendanceStatus, equals('HOLIDAY'));
      expect(item02.isScheduledEligible, isFalse);
      expect(
        sept.scheduledEligibleCount,
        equals(12),
      ); // 13 buổi - 1 ngày nghỉ TOANLOP = 12 buổi eligible
      expect(res.currentBalance, equals(0)); // 12 buổi = chuẩn -> dư 0
    },
  );
}
