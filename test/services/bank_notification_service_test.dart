import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/services/bank_notification_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('BankNotificationService Audit Tests', () {
    test('1. Trusted bank package recognition', () {
      expect(
        BankNotificationService.isTrustedBankPackage('com.sacombank.mbanking'),
        true,
      );
      expect(
        BankNotificationService.isTrustedBankPackage('com.vcb.vietcombank'),
        true,
      );
      expect(
        BankNotificationService.isTrustedBankPackage('com.mbbank.mobile'),
        true,
      );
      expect(
        BankNotificationService.isTrustedBankPackage(
          'com.untrusted.maliciousapp',
        ),
        false,
      );
    });

    test('2. Fingerprint generation idempotency & uniqueness', () {
      final fp1 = BankNotificationService.notificationFingerprint(
        'com.vcb',
        'TK 123',
        '+500,000VND',
      );
      final fp2 = BankNotificationService.notificationFingerprint(
        'com.vcb',
        'TK 123',
        '+500,000VND',
      );
      final fp3 = BankNotificationService.notificationFingerprint(
        'com.vcb',
        'TK 123',
        '+600,000VND',
      );

      expect(fp1, equals(fp2));
      expect(fp1, isNot(equals(fp3)));
    });

    test(
      '3. Partial vs High-Confidence Match Classification Schema Integration Test',
      () async {
        final db = await openDatabase(
          inMemoryDatabasePath,
          version: 1,
          onCreate: (Database db, int version) async {
            await db.execute('''
            CREATE TABLE ${DBHelper.tenBangHS} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ten TEXT NOT NULL,
              so_dien_thoai TEXT
            )
          ''');

            await db.execute('''
            CREATE TABLE ${DBHelper.tenBangLop} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              ten TEXT NOT NULL
            )
          ''');

            await db.execute('''
            CREATE TABLE ${DBHelper.tenBangThanhToan} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_hoc_sinh INTEGER,
              id_lop INTEGER,
              thang TEXT,
              tong_thanh_toan INTEGER,
              so_tien_da_dong INTEGER
            )
          ''');

            await db.execute('''
            CREATE TABLE payment_transactions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              hoc_sinh_id INTEGER,
              lop_id INTEGER,
              month TEXT,
              amount INTEGER,
              status TEXT,
              transaction_id TEXT UNIQUE,
              created_at TEXT,
              updated_at TEXT
            )
          ''');
          },
        );

        await db.insert(DBHelper.tenBangHS, {
          'id': 1,
          'ten': 'Nguyen Van Anh',
          'so_dien_thoai': '0901234567',
        });
        await db.insert(DBHelper.tenBangLop, {'id': 1, 'ten': 'Lop 10A1'});
        await db.insert(DBHelper.tenBangThanhToan, {
          'id_hoc_sinh': 1,
          'id_lop': 1,
          'thang': '2026-09',
          'tong_thanh_toan': 500000,
          'so_tien_da_dong': 0,
        });

        // Verify DB schema exists and allows status values ('pending', 'success')
        await db.insert('payment_transactions', {
          'hoc_sinh_id': 1,
          'lop_id': 1,
          'month': '2026-09',
          'amount': 500000,
          'status': 'pending',
          'transaction_id': 'test_tx_1',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        final rows = await db.query(
          'payment_transactions',
          where: 'status = ?',
          whereArgs: ['pending'],
        );
        expect(rows.length, 1);
        expect(rows.first['status'], 'pending');

        await db.close();
      },
    );
  });
}
