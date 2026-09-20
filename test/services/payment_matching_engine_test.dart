// File: test/services/payment_matching_engine_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/utils/db.dart';
import 'package:tuition2025/services/bank_parsers/bank_notification_parser.dart';
import 'package:tuition2025/services/payment_matching_engine.dart';
import 'package:tuition2025/services/payment_coordinator.dart';

void main() {
  late Database db;
  late PaymentMatchingEngine matchingEngine;
  late PaymentCoordinator paymentCoordinator;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 31,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE hoc_sinh (id INTEGER PRIMARY KEY AUTOINCREMENT, ten TEXT, so_buoi_du INTEGER NOT NULL DEFAULT 0)',
        );
        await db.execute(
          'CREATE TABLE lop (id INTEGER PRIMARY KEY AUTOINCREMENT, ten TEXT, khoi INTEGER)',
        );
        await db.execute('''
          CREATE TABLE thanh_toan (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_hoc_sinh INTEGER NOT NULL,
            id_lop INTEGER NOT NULL,
            thang TEXT NOT NULL,
            tong_thanh_toan INTEGER NOT NULL,
            so_tien_da_dong INTEGER NOT NULL DEFAULT 0,
            trang_thai TEXT NOT NULL DEFAULT 'Chưa thanh toán',
            ngay_thanh_toan TEXT,
            ghi_chu_thanh_toan TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE payment_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hoc_sinh_id INTEGER NOT NULL,
            lop_id INTEGER NOT NULL,
            month TEXT NOT NULL,
            amount INTEGER NOT NULL,
            status TEXT NOT NULL,
            transaction_id TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            bank_code TEXT,
            raw_content TEXT,
            match_method TEXT,
            failure_reason TEXT,
            linked_payment_id INTEGER,
            raw_fingerprint TEXT
          )
        ''');
      },
    );
    DBHelper.setTestDatabase(db);
    matchingEngine = PaymentMatchingEngine();
    paymentCoordinator = PaymentCoordinator();
  });

  tearDown(() async {
    await db.close();
  });

  test(
    '1. Exact Machine Reference HP 000007 202609 + Exact Debt -> CONFIRMED',
    () async {
      await db.insert('hoc_sinh', {'id': 7, 'ten': 'NGUYỄN VĂN A'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 7,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'sacombank',
        direction: 'CREDIT',
        amount: 800000,
        transactionId: 'TX1001',
        transferContent: 'HP 000007 202609 NGUYEN VAN A',
        rawFingerprint: 'FP1001',
        packageName: 'com.sacombank.mbanking',
        rawTitle: 'Biến động số dư',
        rawText: 'TK +800,000VND HP 000007 202609',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.status, equals('CONFIRMED'));
      expect(result.matchedStudentId, equals(7));
      expect(result.matchedMonth, equals('2026-09'));

      final recordId = await paymentCoordinator.confirmPaymentAtomic(
        candidate: candidate,
        studentId: result.matchedStudentId!,
        classId: result.matchedClassId!,
        month: result.matchedMonth!,
        matchMethod: result.matchMethod!,
      );

      expect(recordId, greaterThan(0));
      final ttRows = await db.query(
        'thanh_toan',
        where: 'id_hoc_sinh = ?',
        whereArgs: [7],
      );
      expect(ttRows.first['so_tien_da_dong'], equals(800000));
      expect(ttRows.first['ngay_thanh_toan'], isNotNull);
    },
  );

  test(
    '2. Partial Payment (300k / 800k debt) -> CONFIRMED as partial',
    () async {
      await db.insert('hoc_sinh', {'id': 8, 'ten': 'TRAN VAN B'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 8,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'vcb',
        direction: 'CREDIT',
        amount: 300000,
        transactionId: 'TX1002',
        transferContent: 'HP 000008 202609',
        rawFingerprint: 'FP1002',
        packageName: 'com.vcb.vietcombank',
        rawTitle: 'VCB Digibank',
        rawText: 'TK +300,000VND HP 000008 202609',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.status, equals('CONFIRMED'));

      await paymentCoordinator.confirmPaymentAtomic(
        candidate: candidate,
        studentId: result.matchedStudentId!,
        classId: result.matchedClassId!,
        month: result.matchedMonth!,
        matchMethod: result.matchMethod!,
      );

      final ttRows = await db.query(
        'thanh_toan',
        where: 'id_hoc_sinh = ?',
        whereArgs: [8],
      );
      expect(ttRows.first['so_tien_da_dong'], equals(300000));
      expect(ttRows.first['ghi_chu_thanh_toan'], contains('Ngân hàng'));
    },
  );

  test(
    '3. Overpayment (1M / 800k debt) -> NEED_REVIEW (Do NOT clamp 200k!)',
    () async {
      await db.insert('hoc_sinh', {'id': 9, 'ten': 'LE VAN C'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 9,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'mbbank',
        direction: 'CREDIT',
        amount: 1000000,
        transactionId: 'TX1003',
        transferContent: 'HP 000009 202609',
        rawFingerprint: 'FP1003',
        packageName: 'com.mbbank.mobile',
        rawTitle: 'MBBank',
        rawText: 'TK +1,000,000VND HP 000009 202609',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.status, equals('NEED_REVIEW'));
      expect(result.reason.contains('tiền thừa'), isTrue);
    },
  );

  test('4. Non-existent Student ID -> UNMATCHED', () async {
    final candidate = BankTransactionCandidate(
      bankCode: 'sacombank',
      direction: 'CREDIT',
      amount: 800000,
      transactionId: 'TX1004',
      transferContent: 'HP 999999 202609',
      rawFingerprint: 'FP1004',
      packageName: 'com.sacombank.mbanking',
      rawTitle: 'Biến động số dư',
      rawText: 'TK +800,000VND HP 999999 202609',
    );

    final result = await matchingEngine.matchTransaction(
      candidate,
      autoApproveEnabled: true,
    );
    expect(result.status, equals('UNMATCHED'));
  });

  test('6. Duplicate Transaction ID -> DUPLICATE', () async {
    await db.insert('payment_transactions', {
      'hoc_sinh_id': 7,
      'lop_id': 101,
      'month': '2026-09',
      'amount': 800000,
      'status': 'CONFIRMED',
      'transaction_id': 'TX_DUP_01',
      'created_at': '2026-09-17',
      'raw_fingerprint': 'FP_DUP_01',
    });

    final candidate = BankTransactionCandidate(
      bankCode: 'sacombank',
      direction: 'CREDIT',
      amount: 800000,
      transactionId: 'TX_DUP_01',
      transferContent: 'HP 000007 202609',
      rawFingerprint: 'FP_DUP_01',
      packageName: 'com.sacombank.mbanking',
      rawTitle: 'Biến động số dư',
      rawText: 'TK +800,000VND',
    );

    final result = await matchingEngine.matchTransaction(
      candidate,
      autoApproveEnabled: true,
    );
    expect(result.status, equals('DUPLICATE'));
  });

  test('7. Auto Approve OFF -> NEED_REVIEW for manual verification', () async {
    await db.insert('hoc_sinh', {'id': 12, 'ten': 'PHAM VAN D'});
    await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
    await db.insert('thanh_toan', {
      'id_hoc_sinh': 12,
      'id_lop': 101,
      'thang': '2026-09',
      'tong_thanh_toan': 800000,
      'so_tien_da_dong': 0,
    });

    final candidate = BankTransactionCandidate(
      bankCode: 'sacombank',
      direction: 'CREDIT',
      amount: 800000,
      transactionId: 'TX1007',
      transferContent: 'HP 000012 202609',
      rawFingerprint: 'FP1007',
      packageName: 'com.sacombank.mbanking',
      rawTitle: 'Biến động số dư',
      rawText: 'TK +800,000VND HP 000012 202609',
    );

    final result = await matchingEngine.matchTransaction(
      candidate,
      autoApproveEnabled: false,
    );
    expect(result.status, equals('NEED_REVIEW'));
    expect(result.reason.contains('TẮT'), isTrue);
  });

  // --- MANDATORY TEST CASES FOR NAME MATCHING FIX ---

  test(
    'TEST 1: 1 Student + 1 Debt Row -> NEED_REVIEW without duplicate student warning',
    () async {
      await db.insert('hoc_sinh', {'id': 15, 'ten': 'Nguyễn Văn An'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'vcb',
        direction: 'CREDIT',
        amount: 800000,
        transactionId: 'TX_T1',
        transferContent: 'NGUYEN VAN AN chuyen tien hoc phi',
        rawFingerprint: 'FP_T1',
        packageName: 'com.vcb.vietcombank',
        rawTitle: 'VCB Digibank',
        rawText: 'TK +800,000VND NGUYEN VAN AN',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.status, equals('NEED_REVIEW'));
      expect(result.matchedStudentId, equals(15));
      expect(result.reason.contains('trùng tên'), isFalse);
      expect(
        result.reason.contains('Đã khớp tên học sinh Nguyễn Văn An'),
        isTrue,
      );
    },
  );

  test(
    'TEST 2: 1 Student + 2 Debt Rows -> NEED_REVIEW reporting 2 unpaid debts, NOT 2 duplicate students',
    () async {
      await db.insert('hoc_sinh', {'id': 15, 'ten': 'Nguyễn Văn An'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-08',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'vcb',
        direction: 'CREDIT',
        amount: 800000,
        transactionId: 'TX_T2',
        transferContent: 'NGUYEN VAN AN chuyen tien hoc phi',
        rawFingerprint: 'FP_T2',
        packageName: 'com.vcb.vietcombank',
        rawTitle: 'VCB Digibank',
        rawText: 'TK +800,000VND NGUYEN VAN AN',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.status, equals('NEED_REVIEW'));
      expect(result.matchedStudentId, equals(15));
      expect(result.reason.contains('trùng tên'), isFalse);
      expect(result.reason.contains('2 khoản học phí chưa thanh toán'), isTrue);
    },
  );

  test(
    'TEST 3: 2 Different Student IDs (#15, #72) with same name -> NEED_REVIEW reporting 2 matching students',
    () async {
      await db.insert('hoc_sinh', {'id': 15, 'ten': 'Nguyễn Văn An'});
      await db.insert('hoc_sinh', {'id': 72, 'ten': 'Nguyễn Văn An'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 72,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'vcb',
        direction: 'CREDIT',
        amount: 800000,
        transactionId: 'TX_T3',
        transferContent: 'NGUYEN VAN AN chuyen tien hoc phi',
        rawFingerprint: 'FP_T3',
        packageName: 'com.vcb.vietcombank',
        rawTitle: 'VCB Digibank',
        rawText: 'TK +800,000VND NGUYEN VAN AN',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.status, equals('NEED_REVIEW'));
      expect(
        result.reason.contains('Phát hiện 2 học sinh có tên phù hợp'),
        isTrue,
      );
    },
  );

  test(
    'TEST 4: 1 Student with 3 Debt Rows -> Reports 3 unpaid debts, NEVER 3 duplicate students',
    () async {
      await db.insert('hoc_sinh', {'id': 15, 'ten': 'Nguyễn Văn An'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-07',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-08',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'vcb',
        direction: 'CREDIT',
        amount: 800000,
        transactionId: 'TX_T4',
        transferContent: 'NGUYEN VAN AN nop tien',
        rawFingerprint: 'FP_T4',
        packageName: 'com.vcb.vietcombank',
        rawTitle: 'VCB Digibank',
        rawText: 'TK +800,000VND NGUYEN VAN AN',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.status, equals('NEED_REVIEW'));
      expect(result.reason.contains('3 khoản học phí chưa thanh toán'), isTrue);
      expect(result.reason.contains('trùng tên'), isFalse);
    },
  );

  test(
    'TEST 5: Canonical reference HP 000015 202609 remains AUTO_EXACT',
    () async {
      await db.insert('hoc_sinh', {'id': 15, 'ten': 'Nguyễn Văn An'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'sacombank',
        direction: 'CREDIT',
        amount: 800000,
        transactionId: 'TX_T5',
        transferContent: 'HP 000015 202609',
        rawFingerprint: 'FP_T5',
        packageName: 'com.sacombank.mbanking',
        rawTitle: 'Biến động số dư',
        rawText: 'TK +800,000VND HP 000015 202609',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.status, equals('CONFIRMED'));
      expect(result.matchMethod, equals('AUTO_EXACT'));
      expect(result.matchedStudentId, equals(15));
      expect(result.matchedMonth, equals('2026-09'));
    },
  );

  test('TEST 6: Unmatched name -> UNMATCHED', () async {
    await db.insert('hoc_sinh', {'id': 15, 'ten': 'Nguyễn Văn An'});
    await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
    await db.insert('thanh_toan', {
      'id_hoc_sinh': 15,
      'id_lop': 101,
      'thang': '2026-09',
      'tong_thanh_toan': 800000,
      'so_tien_da_dong': 0,
    });

    final candidate = BankTransactionCandidate(
      bankCode: 'vcb',
      direction: 'CREDIT',
      amount: 800000,
      transactionId: 'TX_T6',
      transferContent: 'Tran Thi B chuyen tien',
      rawFingerprint: 'FP_T6',
      packageName: 'com.vcb.vietcombank',
      rawTitle: 'VCB Digibank',
      rawText: 'TK +800,000VND Tran Thi B',
    );

    final result = await matchingEngine.matchTransaction(
      candidate,
      autoApproveEnabled: true,
    );
    expect(result.status, equals('UNMATCHED'));
  });

  test(
    'TEST 7: Diacritics matching (Nguyễn Văn An -> NGUYEN VAN AN)',
    () async {
      await db.insert('hoc_sinh', {'id': 15, 'ten': 'Nguyễn Văn An'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp 10A'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'vcb',
        direction: 'CREDIT',
        amount: 800000,
        transactionId: 'TX_T7',
        transferContent: 'NGUYEN VAN AN dong tien',
        rawFingerprint: 'FP_T7',
        packageName: 'com.vcb.vietcombank',
        rawTitle: 'VCB Digibank',
        rawText: 'TK +800,000VND NGUYEN VAN AN',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.matchedStudentId, equals(15));
      expect(result.studentName, equals('Nguyễn Văn An'));
    },
  );

  test(
    'TEST 8: Same student ID across multiple classes -> counted as 1 student ID',
    () async {
      await db.insert('hoc_sinh', {'id': 15, 'ten': 'Nguyễn Văn An'});
      await db.insert('lop', {'id': 101, 'ten': 'Lớp Toán 10A'});
      await db.insert('lop', {'id': 102, 'ten': 'Lớp Lý 10B'});
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 101,
        'thang': '2026-09',
        'tong_thanh_toan': 800000,
        'so_tien_da_dong': 0,
      });
      await db.insert('thanh_toan', {
        'id_hoc_sinh': 15,
        'id_lop': 102,
        'thang': '2026-09',
        'tong_thanh_toan': 600000,
        'so_tien_da_dong': 0,
      });

      final candidate = BankTransactionCandidate(
        bankCode: 'vcb',
        direction: 'CREDIT',
        amount: 800000,
        transactionId: 'TX_T8',
        transferContent: 'NGUYEN VAN AN hoc phi',
        rawFingerprint: 'FP_T8',
        packageName: 'com.vcb.vietcombank',
        rawTitle: 'VCB Digibank',
        rawText: 'TK +800,000VND NGUYEN VAN AN',
      );

      final result = await matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: true,
      );
      expect(result.status, equals('NEED_REVIEW'));
      expect(result.matchedStudentId, equals(15));
      expect(result.reason.contains('trùng tên'), isFalse);
      expect(result.reason.contains('2 khoản học phí chưa thanh toán'), isTrue);
    },
  );
}
