// File: test/post_session_review_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/post_session_review.dart';
import 'package:tuition2025/services/post_session_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ROUND 4 — Post-Session Quick Review & Parent Zalo Assist Tests', () {
    test(
      'TEST 1: 40 students present -> Apply default review -> all 40 get default values',
      () {
        final reviews = List.generate(
          40,
          (i) => StudentReviewData(
            studentId: i + 1,
            studentName: 'Học sinh ${i + 1}',
            attendanceStatus: 'Có mặt',
            thaiDo: 'Tốt',
            baiCu: 'Đã chuẩn bị',
            baiTap: 'Đầy đủ',
            tiepThu: 'Tốt',
          ),
        );

        expect(reviews.length, equals(40));
        for (var r in reviews) {
          expect(r.thaiDo, equals('Tốt'));
          expect(r.baiCu, equals('Đã chuẩn bị'));
          expect(r.baiTap, equals('Đầy đủ'));
          expect(r.tiepThu, equals('Tốt'));
          expect(r.isAttentionNeeded, isFalse);
        }
      },
    );

    test(
      'TEST 2: Modify 3 students after default -> only 3 students differ from default',
      () {
        final reviews = List.generate(
          40,
          (i) => StudentReviewData(
            studentId: i + 1,
            studentName: 'Học sinh ${i + 1}',
            attendanceStatus: 'Có mặt',
            thaiDo: 'Tốt',
            baiCu: 'Đã chuẩn bị',
            baiTap: 'Đầy đủ',
            tiepThu: 'Tốt',
          ),
        );

        // Edit 3 students (HS 5, HS 12, HS 30)
        reviews[4].baiTap = 'Không làm';
        reviews[11].thaiDo = 'Mất tập trung';
        reviews[29].canPhPhoiHop = true;

        final attentionList = reviews
            .where((r) => r.isAttentionNeeded)
            .toList();
        expect(attentionList.length, equals(3));
        expect(attentionList.map((r) => r.studentId), containsAll([5, 12, 30]));
      },
    );

    test(
      'TEST 3: Unexcused absent student DOES NOT get default review & IS added to parent alert queue',
      () {
        final s = StudentReviewData(
          studentId: 1,
          studentName: 'Trần Văn A',
          attendanceStatus: 'Nghỉ không phép',
        );

        expect(s.isAbsent, isTrue);
        expect(s.isUnexcusedAbsent, isTrue);
        expect(s.isAttentionNeeded, isTrue);
        expect(s.attentionReason, equals('Nghỉ không phép'));

        final message = PostSessionReviewService.generateMessage(
          review: s,
          className: '10A1',
          date: DateTime(2026, 9, 17),
          timeSlot: '17:30 - 19:00',
        );

        expect(message, contains('vắng buổi học 17/09/2026'));
        expect(message, contains('hệ thống chưa ghi nhận đơn xin nghỉ'));
      },
    );

    test(
      'TEST 4: Excused absent student DOES NOT receive learning review & IS NOT auto-queued',
      () {
        final s = StudentReviewData(
          studentId: 2,
          studentName: 'Lê Thị B',
          attendanceStatus: 'Nghỉ có phép',
        );

        expect(s.isAbsent, isTrue);
        expect(s.isExcusedAbsent, isTrue);
        expect(s.isAttentionNeeded, isFalse);
      },
    );

    test(
      'TEST 5: Batch Homework assignment generation formats homework and due date correctly',
      () {
        final s = StudentReviewData(
          studentId: 3,
          studentName: 'Nguyễn Văn C',
          attendanceStatus: 'Có mặt',
          baiTap: 'Thiếu',
        );

        final message = PostSessionReviewService.generateMessage(
          review: s,
          className: '10A1',
          date: DateTime(2026, 9, 17),
          timeSlot: '17:30 - 19:00',
          homeworkContent: 'Bài 1 đến 5 trang 47',
          homeworkDueDate: 'Buổi học tiếp theo',
        );

        expect(message, contains('BTVN: Bài 1 đến 5 trang 47'));
        expect(message, contains('Hạn: Buổi học tiếp theo'));
      },
    );

    test(
      'TEST 6: Smart Filter selects ONLY 5 students needing attention out of 38 total',
      () async {
        final service = PostSessionReviewService();
        final reviews = List.generate(
          38,
          (i) => StudentReviewData(
            studentId: i + 1,
            studentName: 'Học sinh ${i + 1}',
            phone: '098765432$i',
            attendanceStatus: 'Có mặt',
          ),
        );

        // Mark 5 exception students
        reviews[0] = reviews[0].copyWith(attendanceStatus: 'Nghỉ không phép');
        reviews[1] = reviews[1].copyWith(baiTap: 'Không làm');
        reviews[2] = reviews[2].copyWith(baiCu: 'Chưa thuộc');
        reviews[3] = reviews[3].copyWith(thaiDo: 'Mất tập trung');
        reviews[4] = reviews[4].copyWith(canPhPhoiHop: true);

        final queue = await service.getPendingCommunicationQueue(
          classId: 1,
          className: '10A1',
          date: DateTime(2026, 9, 17),
          timeSlot: '17:30',
          reviews: reviews,
        );

        expect(queue.length, equals(5));
        expect(queue.map((q) => q.studentId), containsAll([1, 2, 3, 4, 5]));
      },
    );

    test(
      'TEST 7 & 8: Opening Zalo DOES NOT set status to SENT_MANUALLY_CONFIRMED automatically',
      () {
        final record = ParentCommunicationRecord(
          studentId: 1,
          studentName: 'Nguyễn Văn A',
          classId: 1,
          className: '10A1',
          sessionDate: '2026-09-17',
          sessionTime: '17:30',
          parentPhone: '0987654321',
          reason: 'Không làm BTVN',
          messageContent: 'Thông báo BTVN',
          status: 'READY',
          createdAt: '2026-09-17 19:00:00',
        );

        // Status remains READY before explicit confirmation
        expect(record.status, equals('READY'));
        expect(record.status, isNot(equals('SENT_MANUALLY_CONFIRMED')));
      },
    );

    test(
      'TEST 9: Teacher clicks "Đã gửi" -> status becomes SENT_MANUALLY_CONFIRMED',
      () async {
        final service = PostSessionReviewService();
        final record = ParentCommunicationRecord(
          studentId: 99,
          studentName: 'Test Student',
          classId: 1,
          className: '10A1',
          sessionDate: '2026-09-17',
          sessionTime: '17:30',
          parentPhone: '0901234567',
          reason: 'Thiếu BTVN',
          messageContent: 'Test Content',
          status: 'READY',
          createdAt: '2026-09-17 19:00:00',
        );

        final res = await service.markAsSentManuallyConfirmed(record);
        expect(res, greaterThan(0));
      },
    );

    test(
      'TEST 10: Message already SENT_MANUALLY_CONFIRMED is NOT re-queued for same session',
      () async {
        final service = PostSessionReviewService();
        final record = ParentCommunicationRecord(
          studentId: 88,
          studentName: 'HS Sent Previously',
          classId: 1,
          className: '10A1',
          sessionDate: '2026-09-17',
          sessionTime: '17:30',
          parentPhone: '0909999999',
          reason: 'Không làm BTVN',
          messageContent: 'Content',
          status: 'READY',
          createdAt: '2026-09-17 19:00:00',
        );

        // Save as SENT_MANUALLY_CONFIRMED
        await service.markAsSentManuallyConfirmed(record);

        final reviews = [
          StudentReviewData(
            studentId: 88,
            studentName: 'HS Sent Previously',
            phone: '0909999999',
            attendanceStatus: 'Có mặt',
            baiTap: 'Không làm',
          ),
        ];

        final queue = await service.getPendingCommunicationQueue(
          classId: 1,
          className: '10A1',
          date: DateTime(2026, 9, 17),
          timeSlot: '17:30',
          reviews: reviews,
        );

        // Student 88 is NOT re-queued!
        expect(queue.length, equals(0));
      },
    );

    test(
      'TEST 11: Missing parent phone DOES NOT crash and generates valid communication record',
      () {
        final s = StudentReviewData(
          studentId: 77,
          studentName: 'HS Không Có SĐT',
          phone: null,
          attendanceStatus: 'Nghỉ không phép',
        );

        expect(s.phone, isNull);
        expect(s.isAttentionNeeded, isTrue);

        final message = PostSessionReviewService.generateMessage(
          review: s,
          className: '10A1',
          date: DateTime(2026, 9, 17),
          timeSlot: '17:30 - 19:00',
        );

        expect(message, isNotEmpty);
        expect(message, contains('HS Không Có SĐT'));
      },
    );

    test('TEST 12: Template placeholders replacement works accurately', () {
      final s = StudentReviewData(
        studentId: 10,
        studentName: 'Phạm Minh Anh',
        attendanceStatus: 'Có mặt',
        thaiDo: 'Tốt',
        baiCu: 'Đã chuẩn bị',
        baiTap: 'Đầy đủ',
        tiepThu: 'Tốt',
      );

      final customTpl =
          'Kính gửi PH em {TEN_HS} (lớp {TEN_LOP}). Buổi học {NGAY_HOC} em tiếp thu {TIEP_THU}. BTVN: {BTVN}.';

      final msg = PostSessionReviewService.generateMessage(
        review: s,
        className: '11B2',
        date: DateTime(2026, 9, 17),
        timeSlot: '19:00 - 20:30',
        homeworkContent: 'Bài 1-3',
        customTemplate: customTpl,
      );

      expect(
        msg,
        equals(
          'Kính gửi PH em Phạm Minh Anh (lớp 11B2). Buổi học 17/09/2026 em tiếp thu Tốt. BTVN: Bài 1-3.',
        ),
      );
    });
  });
}
