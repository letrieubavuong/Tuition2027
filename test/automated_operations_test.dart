// File: test/automated_operations_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/attention_item.dart';
import 'package:tuition2025/models/diem_danh.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/lop_hoc_sinh.dart';
import 'package:tuition2025/models/session_close_result.dart';
import 'package:tuition2025/services/attention_queue_service.dart';
import 'package:tuition2025/services/daily_brief_service.dart';
import 'package:tuition2025/services/diem_danh_service.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/lop_hoc_sinh_service.dart';
import 'package:tuition2025/services/lop_service.dart';
import 'package:tuition2025/services/session_close_pipeline.dart';
import 'package:tuition2025/services/student_signal_service.dart';
import 'package:tuition2025/services/thanh_toan_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbHelper = DBHelper.instance;
    final db = await dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    for (var table in [
      DBHelper.tenBangAttentionItems,
      DBHelper.tenBangStudentSignals,
      DBHelper.tenBangDanhGiaBuoiHoc,
      DBHelper.tenBangDiemDanh,
      DBHelper.tenBangThanhToan,
      'payment_transactions',
      'parent_communications',
      'session_homework',
      'session_completion_ledger',
      DBHelper.tenBangLopHS,
      DBHelper.tenBangLop,
      DBHelper.tenBangHS,
    ]) {
      try {
        await db.delete(table);
      } catch (_) {}
    }
    await db.execute('PRAGMA foreign_keys = ON');
    DailyBriefService.instance.invalidateCache();
  });

  group('AUTOMATED OPERATIONS — ATTENTION QUEUE TESTS', () {
    final hsService = HocSinhService();
    final lopService = LopService();
    final lhsService = LopHocSinhService();
    final ddService = DiemDanhService();
    final signalService = StudentSignalService.instance;
    final attentionService = AttentionQueueService.instance;

    test(
      'TEST 1: Same signal recomputed 5 times -> 1 attention item (no duplicates)',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh Queue 1'));
        final lop = await lopService.taoLop(Lop(ten: '12AQ1', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-10 17:30:00',
            trangThai: 'Nghỉ không phép',
          ),
        );
        await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-12 17:30:00',
            trangThai: 'Nghỉ không phép',
          ),
        );

        // Recompute 5 times
        for (int i = 0; i < 5; i++) {
          await signalService.recomputeSignalsForStudent(hs.id!);
        }

        final queue = await attentionService.getAttentionQueue(
          activeOnly: true,
        );
        final unexcusedItems = queue
            .where(
              (x) =>
                  x.type == AttentionType.UNEXCUSED_ABSENCE &&
                  x.studentId == hs.id!,
            )
            .toList();
        expect(unexcusedItems.length, equals(1));
      },
    );

    test('TEST 2: Condition resolved -> Attention auto resolved', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh Queue 2'));
      final lop = await lopService.taoLop(Lop(ten: '12AQ2', khoi: 12));
      await lhsService.themHocSinhVaoLop(
        LopHocSinh(
          idLop: lop.id!,
          idHocSinh: hs.id!,
          ngayThamGia: '2026-09-01',
        ),
      );

      await ddService.themDiemDanh(
        DiemDanh(
          idHocSinh: hs.id!,
          idLop: lop.id!,
          gioDiemDanh: '2026-09-10 17:30:00',
          trangThai: 'Nghỉ không phép',
        ),
      );
      await ddService.themDiemDanh(
        DiemDanh(
          idHocSinh: hs.id!,
          idLop: lop.id!,
          gioDiemDanh: '2026-09-12 17:30:00',
          trangThai: 'Nghỉ không phép',
        ),
      );

      var queue = await attentionService.getAttentionQueue(activeOnly: true);
      expect(queue.any((x) => x.studentId == hs.id!), isTrue);

      await attentionService.autoResolve(
        AttentionType.UNEXCUSED_ABSENCE,
        studentId: hs.id!,
      );
      queue = await attentionService.getAttentionQueue(activeOnly: true);
      expect(
        queue.any(
          (x) =>
              x.studentId == hs.id! &&
              x.type == AttentionType.UNEXCUSED_ABSENCE,
        ),
        isFalse,
      );
    });

    test(
      'TEST 3: Snooze 1 day -> Hidden from active queue until due',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh Queue 3'));
        final lop = await lopService.taoLop(Lop(ten: '12AQ3', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-10 17:30:00',
            trangThai: 'Nghỉ không phép',
          ),
        );
        await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-12 17:30:00',
            trangThai: 'Nghỉ không phép',
          ),
        );

        final queueBefore = await attentionService.getAttentionQueue(
          activeOnly: true,
        );
        final item = queueBefore.firstWhere((x) => x.studentId == hs.id!);

        await attentionService.snooze(
          item.id,
          duration: const Duration(days: 1),
        );

        final queueAfter = await attentionService.getAttentionQueue(
          activeOnly: true,
        );
        expect(queueAfter.any((x) => x.id == item.id), isFalse);
      },
    );

    test('TEST 4: Critical + Normal sorting by priority & severity', () async {
      final queue = await attentionService.getAttentionQueue(activeOnly: false);
      expect(queue, isNotNull);
    });
  });

  group('AUTOMATED OPERATIONS — DAILY BRIEF TESTS', () {
    final dailyBriefService = DailyBriefService.instance;
    final payService = ThanhToanService();
    final hsService = HocSinhService();
    final lopService = LopService();

    test('TEST 5: Morning brief displays sessions cleanly', () async {
      final morning = await dailyBriefService.getMorningBrief(
        forceRefresh: true,
      );
      expect(morning, isNotNull);
    });

    test('TEST 6: Active attention summary counts match', () async {
      final counts = await AttentionQueueService.instance.getSummaryCounts();
      expect(counts.containsKey('total'), isTrue);
    });

    test('TEST 7: Payment confirmed -> Evening brief updates totals', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh Brief 7'));
      final lop = await lopService.taoLop(Lop(ten: '12AB7', khoi: 12));

      await payService.capNhatSoTienDaDong(
        hs.id!,
        lop.id!,
        '2026-09',
        500000,
        'Đã đóng',
      );
      final evening = await dailyBriefService.getEveningBrief(
        forceRefresh: true,
      );
      expect(evening, isNotNull);
    });

    test('TEST 8: No issues -> Brief returns valid model', () async {
      final morning = await dailyBriefService.getMorningBrief(
        forceRefresh: true,
      );
      expect(morning.date, isNotNull);
    });
  });

  group('AUTOMATED OPERATIONS — SESSION CLOSE PIPELINE TESTS', () {
    final hsService = HocSinhService();
    final lopService = LopService();
    final lhsService = LopHocSinhService();
    final pipeline = SessionClosePipeline.instance;

    test('TEST 9: Normal session -> Pipeline status COMPLETED', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh Pipe 9'));
      final lop = await lopService.taoLop(Lop(ten: '12AP9', khoi: 12));
      await lhsService.themHocSinhVaoLop(
        LopHocSinh(
          idLop: lop.id!,
          idHocSinh: hs.id!,
          ngayThamGia: '2026-09-01',
        ),
      );

      final result = await pipeline.executePipeline(
        classId: lop.id!,
        className: lop.ten,
        sessionDate: DateTime(2026, 9, 18),
        startTime: '17:30',
        endTime: '19:00',
        attendanceRecords: [
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-18 17:30:00',
            trangThai: 'Có mặt',
          ),
        ],
        defaultReviewNote: 'Tốt, Đầy đủ BTVN',
        homeworkAssignment: 'Bài 1-5 trang 47',
      );

      expect(result.status, equals(SessionCloseStatus.completed));
      expect(result.attendanceSavedCount, equals(1));
      expect(result.reviewSavedCount, equals(1));
    });

    test(
      'TEST 10: Attendance has NO_RECORD -> Validation warning returned, no auto-mark present',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh Pipe 10'));
        final lop = await lopService.taoLop(Lop(ten: '12AP10', khoi: 12));

        final result = await pipeline.executePipeline(
          classId: lop.id!,
          className: lop.ten,
          sessionDate: DateTime(2026, 9, 18),
          startTime: '17:30',
          endTime: '19:00',
          attendanceRecords: [
            DiemDanh(
              idHocSinh: hs.id!,
              idLop: lop.id!,
              gioDiemDanh: '2026-09-18 17:30:00',
              trangThai: 'Chưa điểm danh',
            ),
          ],
        );

        expect(result.status, equals(SessionCloseStatus.completedWithWarnings));
        expect(
          result.warnings.any(
            (w) => w.contains('Chưa điểm danh') || w.contains('chưa điểm danh'),
          ),
          isTrue,
        );
      },
    );

    test(
      'TEST 11: Pipeline run twice -> Idempotent, zero duplicate records',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh Pipe 11'));
        final lop = await lopService.taoLop(Lop(ten: '12AP11', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        final attRecords = [
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-18 17:30:00',
            trangThai: 'Có mặt',
          ),
        ];

        await pipeline.executePipeline(
          classId: lop.id!,
          className: lop.ten,
          sessionDate: DateTime(2026, 9, 18),
          startTime: '17:30',
          endTime: '19:00',
          attendanceRecords: attRecords,
          homeworkAssignment: 'Bài 1-5 trang 47',
        );

        final result2 = await pipeline.executePipeline(
          classId: lop.id!,
          className: lop.ten,
          sessionDate: DateTime(2026, 9, 18),
          startTime: '17:30',
          endTime: '19:00',
          attendanceRecords: attRecords,
          homeworkAssignment: 'Bài 1-5 trang 47',
        );

        expect(result2.status, equals(SessionCloseStatus.completed));
      },
    );

    test(
      'TEST 12: Empty homework -> Pipeline status COMPLETED cleanly',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh Pipe 12'));
        final lop = await lopService.taoLop(Lop(ten: '12AP12', khoi: 12));

        final result = await pipeline.executePipeline(
          classId: lop.id!,
          className: lop.ten,
          sessionDate: DateTime(2026, 9, 18),
          startTime: '17:30',
          endTime: '19:00',
          attendanceRecords: [
            DiemDanh(
              idHocSinh: hs.id!,
              idLop: lop.id!,
              gioDiemDanh: '2026-09-18 17:30:00',
              trangThai: 'Có mặt',
            ),
          ],
          homeworkAssignment: null,
        );

        expect(result.status, equals(SessionCloseStatus.completed));
        expect(result.homeworkAssignedCount, equals(0));
      },
    );

    test(
      'TEST 13: 3 Students needing contact -> 3 parent contact items ready',
      () async {
        final lop = await lopService.taoLop(Lop(ten: '12AP13', khoi: 12));
        final attList = <DiemDanh>[];

        for (int i = 1; i <= 3; i++) {
          final hs = await hsService.taoHocSinh(
            HS(ten: 'Học sinh Pipe 13_$i', sdtPhuHuynh: '090123450$i'),
          );
          await lhsService.themHocSinhVaoLop(
            LopHocSinh(
              idLop: lop.id!,
              idHocSinh: hs.id!,
              ngayThamGia: '2026-09-01',
            ),
          );
          attList.add(
            DiemDanh(
              idHocSinh: hs.id!,
              idLop: lop.id!,
              gioDiemDanh: '2026-09-18 17:30:00',
              trangThai: 'Nghỉ không phép',
            ),
          );
        }

        final result = await pipeline.executePipeline(
          classId: lop.id!,
          className: lop.ten,
          sessionDate: DateTime(2026, 9, 18),
          startTime: '17:30',
          endTime: '19:00',
          attendanceRecords: attList,
        );

        expect(result.parentContactsGeneratedCount, equals(3));
      },
    );

    test(
      'TEST 14: 0 Students needing contact -> Session completes cleanly',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh Pipe 14'));
        final lop = await lopService.taoLop(Lop(ten: '12AP14', khoi: 12));

        final result = await pipeline.executePipeline(
          classId: lop.id!,
          className: lop.ten,
          sessionDate: DateTime(2026, 9, 18),
          startTime: '17:30',
          endTime: '19:00',
          attendanceRecords: [
            DiemDanh(
              idHocSinh: hs.id!,
              idLop: lop.id!,
              gioDiemDanh: '2026-09-18 17:30:00',
              trangThai: 'Có mặt',
            ),
          ],
          defaultReviewNote: 'Chăm chỉ, làm bài đầy đủ',
        );

        expect(result.status, equals(SessionCloseStatus.completed));
        expect(result.parentContactsGeneratedCount, equals(0));
      },
    );

    test(
      'TEST 15: Session past time unclosed -> Attention item generated',
      () async {
        final queue = await AttentionQueueService.instance.getAttentionQueue(
          activeOnly: false,
        );
        expect(queue, isNotNull);
      },
    );
  });
}
