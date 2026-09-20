// File: test/services/student_timeline_v2_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/student_timeline.dart';
import 'package:tuition2025/services/student_timeline_service.dart';
import 'package:tuition2025/services/session_close_pipeline.dart';
import 'package:tuition2025/models/diem_danh.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  late Database db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 35,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ${DBHelper.tenBangHS} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ten TEXT NOT NULL,
            ngay_sinh TEXT,
            gioi_tinh TEXT,
            sdt_phu_huynh TEXT,
            sdt_hoc_sinh TEXT,
            trang_thai TEXT DEFAULT 'Đang học',
            ca_hoc_truong TEXT NOT NULL DEFAULT 'Sáng',
            mien_giam INTEGER NOT NULL DEFAULT 0,
            so_buoi_du INTEGER NOT NULL DEFAULT 0,
            zalo_link_status TEXT NOT NULL DEFAULT 'UNLINKED'
          )
        ''');

        await db.execute('''
          CREATE TABLE ${DBHelper.tenBangLop} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ten TEXT NOT NULL,
            khoi INTEGER NOT NULL,
            hoc_phi_buoi INTEGER NOT NULL DEFAULT 0,
            hoc_phi_thang INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE ${DBHelper.tenBangLopHS} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_lop INTEGER NOT NULL,
            id_hoc_sinh INTEGER NOT NULL,
            ngay_tham_gia TEXT,
            ngay_nghi_hoc TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE ${DBHelper.tenBangDiemDanh} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_lop INTEGER NOT NULL,
            id_hoc_sinh INTEGER NOT NULL,
            gio_diem_danh TEXT NOT NULL,
            trang_thai TEXT NOT NULL,
            ghi_chu TEXT,
            ngay_vang_goc TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE ${DBHelper.tenBangDanhGiaBuoiHoc} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_diem_danh INTEGER NOT NULL,
            diem_thai_do REAL,
            diem_hieu_bai REAL,
            diem_bai_tap REAL,
            nhan_xet TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE session_homework (
            id TEXT PRIMARY KEY,
            class_id INTEGER NOT NULL,
            session_id INTEGER,
            session_date TEXT NOT NULL,
            assignment_content TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE payment_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            class_id INTEGER,
            amount INTEGER NOT NULL,
            billing_month TEXT,
            payment_method TEXT,
            note TEXT,
            payment_date TEXT,
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE parent_communications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_hoc_sinh INTEGER NOT NULL,
            ten_hoc_sinh TEXT NOT NULL,
            id_lop INTEGER NOT NULL,
            ten_lop TEXT NOT NULL,
            ngay_hoc TEXT NOT NULL,
            gio_hoc TEXT NOT NULL,
            sdt_phu_huynh TEXT,
            ly_do TEXT NOT NULL,
            loai_tin_nhan TEXT NOT NULL DEFAULT 'POST_SESSION_REVIEW',
            noi_dung TEXT NOT NULL,
            trang_thai TEXT NOT NULL DEFAULT 'READY',
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE ${DBHelper.tenBangStudentSignals} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            signal_type TEXT NOT NULL,
            status TEXT NOT NULL,
            severity TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            snoozed_until TEXT,
            metadata TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE ${DBHelper.tenBangThanhToan} (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            id_hoc_sinh INTEGER NOT NULL,
            id_lop INTEGER NOT NULL,
            thang TEXT NOT NULL,
            so_tien_da_dong INTEGER NOT NULL DEFAULT 0,
            ngay_thanh_toan TEXT
          )
        ''');
      },
    );

    DBHelper.setTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'TEST 1: Empty student data -> no fake 100%/Tốt/Khá summaries',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {
        'ten': 'Học sinh test 1',
      });

      final summary = await StudentTimelineService.instance
          .getStudentSummaryStatus(hsId);

      expect(summary.attendanceSummary, equals('Chưa có dữ liệu'));
      expect(summary.homeworkSummary, equals('Chưa có dữ liệu'));
      expect(summary.attitudeSummary, equals('Chưa đánh giá'));
      expect(summary.comprehensionSummary, equals('Chưa đánh giá'));
    },
  );

  test(
    'TEST 2: 1 Present session -> exactly 1 StudentSessionTimelineItem',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 2'});
      final lopId = await db.insert(DBHelper.tenBangLop, {
        'ten': 'Lớp 12A',
        'khoi': 12,
      });
      await db.insert(DBHelper.tenBangLopHS, {
        'id_lop': lopId,
        'id_hoc_sinh': hsId,
        'ngay_tham_gia': '2026-09-01',
      });

      await db.insert(DBHelper.tenBangDiemDanh, {
        'id_lop': lopId,
        'id_hoc_sinh': hsId,
        'gio_diem_danh': '2026-09-18 18:00:00',
        'trang_thai': 'Có mặt',
      });

      final feed = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        filter: StudentTimelineFilter.session,
      );

      expect(feed.length, equals(1));
      expect(feed.first, isA<StudentSessionTimelineItem>());

      final item = feed.first as StudentSessionTimelineItem;
      expect(item.attendanceStatus, equals('Có mặt'));
      expect(item.className, equals('Lớp 12A'));
    },
  );

  test(
    'TEST 3: Session with attendance + review + homework -> combined into 1 Session Card',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 3'});
      final lopId = await db.insert(DBHelper.tenBangLop, {
        'ten': 'Lớp 12B',
        'khoi': 12,
      });
      await db.insert(DBHelper.tenBangLopHS, {
        'id_lop': lopId,
        'id_hoc_sinh': hsId,
        'ngay_tham_gia': '2026-09-01',
      });

      final attId = await db.insert(DBHelper.tenBangDiemDanh, {
        'id_lop': lopId,
        'id_hoc_sinh': hsId,
        'gio_diem_danh': '2026-09-18 18:00:00',
        'trang_thai': 'Có mặt',
      });

      await db.insert(DBHelper.tenBangDanhGiaBuoiHoc, {
        'id_diem_danh': attId,
        'diem_thai_do': 9.0,
        'diem_hieu_bai': 8.5,
        'diem_bai_tap': 10.0,
        'nhan_xet': 'Tốt và Đầy đủ BTVN',
      });

      await db.insert('session_homework', {
        'id': '${lopId}_2026-09-18',
        'class_id': lopId,
        'session_date': '2026-09-18',
        'assignment_content': 'Làm bài 1–8 trang 35',
        'created_at': DateTime.now().toIso8601String(),
      });

      final feed = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        filter: StudentTimelineFilter.session,
      );

      expect(feed.length, equals(1));
      expect(feed.first, isA<StudentSessionTimelineItem>());

      final sessionCard = feed.first as StudentSessionTimelineItem;
      expect(sessionCard.diemThaiDo, equals(9.0));
      expect(sessionCard.diemHieuBai, equals(8.5));
      expect(sessionCard.assignedHomework, equals('Làm bài 1–8 trang 35'));
    },
  );

  test('TEST 4: Unexcused absence appears under absence filter', () async {
    final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 4'});
    final lopId = await db.insert(DBHelper.tenBangLop, {
      'ten': 'Lớp 12A',
      'khoi': 12,
    });
    await db.insert(DBHelper.tenBangLopHS, {
      'id_lop': lopId,
      'id_hoc_sinh': hsId,
      'ngay_tham_gia': '2026-09-01',
    });

    await db.insert(DBHelper.tenBangDiemDanh, {
      'id_lop': lopId,
      'id_hoc_sinh': hsId,
      'gio_diem_danh': '2026-09-18 18:00:00',
      'trang_thai': 'Nghỉ không phép',
    });

    final absenceItems = await StudentTimelineService.instance.fetchTimeline(
      studentId: hsId,
      filter: StudentTimelineFilter.absence,
    );

    expect(absenceItems.length, equals(1));
    final item = absenceItems.first as StudentSessionTimelineItem;
    expect(item.attendanceStatus, equals('Nghỉ không phép'));
  });

  test(
    'TEST 5: Teacher comment without score -> scores are null, no auto 8.0 created',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 5'});
      final lopId = await db.insert(DBHelper.tenBangLop, {
        'ten': 'Lớp 12A',
        'khoi': 12,
      });
      await db.insert(DBHelper.tenBangLopHS, {
        'id_lop': lopId,
        'id_hoc_sinh': hsId,
        'ngay_tham_gia': '2026-09-01',
      });

      final record = DiemDanh(
        idHocSinh: hsId,
        idLop: lopId,
        gioDiemDanh: '2026-09-18 18:00:00',
        trangThai: 'Có mặt',
      );

      await SessionClosePipeline.instance.executePipeline(
        classId: lopId,
        className: 'Lớp 12A',
        sessionDate: DateTime(2026, 9, 18),
        startTime: '18:00',
        endTime: '19:30',
        attendanceRecords: [record],
        defaultReviewNote: 'Hiểu bài khá tốt',
      );

      final feed = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        filter: StudentTimelineFilter.session,
      );
      expect(feed.length, equals(1));
      final card = feed.first as StudentSessionTimelineItem;

      expect(card.teacherComment, equals('Hiểu bài khá tốt'));
      expect(card.diemThaiDo, isNull);
      expect(card.diemHieuBai, isNull);
      expect(card.diemBaiTap, isNull);
    },
  );

  test('TEST 6: Payment 500k + 700k produces 2 transaction events', () async {
    final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 6'});

    await db.insert('payment_transactions', {
      'student_id': hsId,
      'amount': 500000,
      'billing_month': '09/2026',
      'payment_method': 'Chuyển khoản',
      'created_at': '2026-09-10 10:00:00',
    });

    await db.insert('payment_transactions', {
      'student_id': hsId,
      'amount': 700000,
      'billing_month': '09/2026',
      'payment_method': 'Tiền mặt',
      'created_at': '2026-09-15 14:00:00',
    });

    final paymentItems = await StudentTimelineService.instance.fetchTimeline(
      studentId: hsId,
      filter: StudentTimelineFilter.payment,
    );

    expect(paymentItems.length, equals(2));
    expect(paymentItems[0], isA<StudentPaymentTimelineItem>());
    expect(paymentItems[1], isA<StudentPaymentTimelineItem>());

    final pay1 = paymentItems[0] as StudentPaymentTimelineItem;
    final pay2 = paymentItems[1] as StudentPaymentTimelineItem;

    expect(pay1.amount, equals(700000));
    expect(pay2.amount, equals(500000));
  });

  test(
    'TEST 7: Positive streak signal does NOT increment activeWarningsCount',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 7'});

      await db.insert(DBHelper.tenBangStudentSignals, {
        'student_id': hsId,
        'signal_type': 'POSITIVE_STREAK',
        'status': 'ACTIVE',
        'severity': 'POSITIVE',
        'title': '⭐ Chuỗi học tập tích cực 5 buổi',
        'description': 'Làm BTVN đầy đủ 5 buổi liên tiếp',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      final summary = await StudentTimelineService.instance
          .getStudentSummaryStatus(hsId);

      expect(summary.activeWarningsCount, equals(0));
    },
  );

  test('TEST 8: Resolved signal is NOT counted as active warning', () async {
    final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 8'});

    await db.insert(DBHelper.tenBangStudentSignals, {
      'student_id': hsId,
      'signal_type': 'UNEXCUSED_ABSENCE_WARNING',
      'status': 'RESOLVED',
      'severity': 'WARNING',
      'title': 'Cảnh báo nghỉ học',
      'description': 'Nghỉ không phép 2 buổi',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final summary = await StudentTimelineService.instance
        .getStudentSummaryStatus(hsId);

    expect(summary.activeWarningsCount, equals(0));
  });

  test(
    'TEST 9: Snoozed signal in future is NOT counted as active warning',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 9'});

      await db.insert(DBHelper.tenBangStudentSignals, {
        'student_id': hsId,
        'signal_type': 'HOMEWORK_REPEATED_WARNING',
        'status': 'SNOOZED',
        'severity': 'WARNING',
        'title': 'Cảnh báo BTVN',
        'description': 'Thiếu BTVN',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'snoozed_until': DateTime.now()
            .add(const Duration(days: 3))
            .toIso8601String(),
      });

      final summary = await StudentTimelineService.instance
          .getStudentSummaryStatus(hsId);

      expect(summary.activeWarningsCount, equals(0));
    },
  );

  test(
    'TEST 10: Parent contact READY suggestion is NOT included in history feed',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 10'});

      await db.insert('parent_communications', {
        'id_hoc_sinh': hsId,
        'ten_hoc_sinh': 'HS Test 10',
        'id_lop': 1,
        'ten_lop': 'Lớp 12A',
        'ngay_hoc': '2026-09-18',
        'gio_hoc': '18:00',
        'ly_do': 'Gợi ý nhắn tin',
        'noi_dung': 'Tin nhắn gợi ý chưa gửi',
        'trang_thai': 'READY',
        'created_at': DateTime.now().toIso8601String(),
      });

      final contactItems = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        filter: StudentTimelineFilter.parentContact,
      );

      expect(contactItems.length, equals(0));
    },
  );

  test(
    'TEST 11: Confirmed parent contact (SENT/CONFIRMED/DONE) appears in timeline',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 11'});

      await db.insert('parent_communications', {
        'id_hoc_sinh': hsId,
        'ten_hoc_sinh': 'HS Test 11',
        'id_lop': 1,
        'ten_lop': 'Lớp 12A',
        'ngay_hoc': '2026-09-18',
        'gio_hoc': '18:00',
        'ly_do': 'Vắng học',
        'noi_dung': 'Đã trao đổi qua Zalo với phụ huynh về việc vắng học.',
        'trang_thai': 'SENT',
        'created_at': DateTime.now().toIso8601String(),
      });

      final contactItems = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        filter: StudentTimelineFilter.parentContact,
      );

      expect(contactItems.length, equals(1));
      expect(contactItems.first, isA<StudentParentContactTimelineItem>());
    },
  );

  test(
    'TEST 12: 60 timeline items pagination (page 1=25, page 2=25, page 3=10)',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 12'});
      final lopId = await db.insert(DBHelper.tenBangLop, {
        'ten': 'Lớp 12A',
        'khoi': 12,
      });

      for (int i = 1; i <= 60; i++) {
        final dateStr =
            '2026-${(i ~/ 30 + 1).toString().padLeft(2, '0')}-${(i % 28 + 1).toString().padLeft(2, '0')} 18:00:00';
        await db.insert(DBHelper.tenBangDiemDanh, {
          'id_lop': lopId,
          'id_hoc_sinh': hsId,
          'gio_diem_danh': dateStr,
          'trang_thai': 'Có mặt',
        });
      }

      final page1 = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        page: 1,
        limit: 25,
        filter: StudentTimelineFilter.session,
      );
      final page2 = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        page: 2,
        limit: 25,
        filter: StudentTimelineFilter.session,
      );
      final page3 = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        page: 3,
        limit: 25,
        filter: StudentTimelineFilter.session,
      );
      final page4 = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        page: 4,
        limit: 25,
        filter: StudentTimelineFilter.session,
      );

      expect(page1.length, equals(25));
      expect(page2.length, equals(25));
      expect(page3.length, equals(10));
      expect(page4.length, equals(0));

      // Ensure no duplicate IDs between page1 and page2
      final page1Ids = page1.map((x) => x.id).toSet();
      final page2Ids = page2.map((x) => x.id).toSet();
      expect(page1Ids.intersection(page2Ids).isEmpty, isTrue);
    },
  );

  test('TEST 13: Filter switching resets items correctly', () async {
    final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 13'});

    await db.insert('payment_transactions', {
      'student_id': hsId,
      'amount': 500000,
      'billing_month': '09/2026',
      'created_at': '2026-09-10 10:00:00',
    });

    final paymentItems = await StudentTimelineService.instance.fetchTimeline(
      studentId: hsId,
      filter: StudentTimelineFilter.payment,
    );
    final sessionItems = await StudentTimelineService.instance.fetchTimeline(
      studentId: hsId,
      filter: StudentTimelineFilter.session,
    );

    expect(paymentItems.length, equals(1));
    expect(sessionItems.length, equals(0));
  });

  test(
    'TEST 14: Legacy session without sessionId parses without crash',
    () async {
      final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 14'});
      final lopId = await db.insert(DBHelper.tenBangLop, {
        'ten': 'Lớp 12A',
        'khoi': 12,
      });

      // Legacy row in diem_danh without sessionId in database
      await db.insert(DBHelper.tenBangDiemDanh, {
        'id_lop': lopId,
        'id_hoc_sinh': hsId,
        'gio_diem_danh': '2025-05-10 17:30:00',
        'trang_thai': 'Có mặt',
      });

      final feed = await StudentTimelineService.instance.fetchTimeline(
        studentId: hsId,
        filter: StudentTimelineFilter.session,
      );

      expect(feed.length, equals(1));
      expect(feed.first, isA<StudentSessionTimelineItem>());
      final item = feed.first as StudentSessionTimelineItem;
      expect(item.sessionId, isNull);
      expect(item.className, equals('Lớp 12A'));
    },
  );

  test('TEST 15: Warning filter excludes positive signals', () async {
    final hsId = await db.insert(DBHelper.tenBangHS, {'ten': 'HS Test 15'});

    await db.insert(DBHelper.tenBangStudentSignals, {
      'student_id': hsId,
      'signal_type': 'POSITIVE_STREAK',
      'status': 'ACTIVE',
      'severity': 'POSITIVE',
      'title': '⭐ Chuỗi học tập tích cực',
      'description': 'Làm BTVN đầy đủ 5 buổi liên tiếp',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    await db.insert(DBHelper.tenBangStudentSignals, {
      'student_id': hsId,
      'signal_type': 'UNEXCUSED_ABSENCE_WARNING',
      'status': 'ACTIVE',
      'severity': 'WARNING',
      'title': 'Cảnh báo vắng học',
      'description': 'Vắng không phép 2 buổi',
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    final warningItems = await StudentTimelineService.instance.fetchTimeline(
      studentId: hsId,
      filter: StudentTimelineFilter.warning,
    );

    expect(warningItems.length, equals(1));
    final item = warningItems.first as StudentSignalTimelineItem;
    expect(item.severity, equals(StudentTimelineSeverity.warning));
  });
}
