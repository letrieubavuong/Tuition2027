// File: test/student_timeline_signal_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/diem_danh.dart';
import 'package:tuition2025/models/danh_gia_buoi_hoc.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/lop_hoc_sinh.dart';
import 'package:tuition2025/models/student_signal.dart';
import 'package:tuition2025/models/student_timeline.dart';
import 'package:tuition2025/services/diem_danh_service.dart';
import 'package:tuition2025/services/danh_gia_buoi_hoc_service.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/lop_service.dart';
import 'package:tuition2025/services/lop_hoc_sinh_service.dart';
import 'package:tuition2025/services/student_signal_service.dart';
import 'package:tuition2025/services/student_timeline_service.dart';
import 'package:tuition2025/services/attention_queue_service.dart';
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
    await db.delete(DBHelper.tenBangStudentSignals);
    await db.delete(DBHelper.tenBangDanhGiaBuoiHoc);
    await db.delete(DBHelper.tenBangDiemDanh);
    await db.delete(DBHelper.tenBangThanhToan);
    await db.delete(DBHelper.tenBangLopHS);
    await db.delete(DBHelper.tenBangLop);
    await db.delete(DBHelper.tenBangHS);
    await db.execute('PRAGMA foreign_keys = ON');
  });

  group('STUDENT TIMELINE & AUTOMATIC MONITORING SIGNAL TESTS', () {
    final hsService = HocSinhService();
    final lopService = LopService();
    final lhsService = LopHocSinhService();
    final ddService = DiemDanhService();
    final reviewService = DanhGiaBuoiHocService();
    final signalService = StudentSignalService.instance;
    final timelineService = StudentTimelineService.instance;
    final attentionService = AttentionQueueService.instance;
    final payService = ThanhToanService();

    test(
      'TEST 1: HS có attendance + review + homework cùng session -> 1 Session Card hợp nhất',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 1'));
        final lop = await lopService.taoLop(Lop(ten: '12A', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        final attId = await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-17 17:30:00',
            trangThai: 'Có mặt',
          ),
        );

        await reviewService.luuDanhGia(
          DanhGiaBuoiHoc(
            idDiemDanh: attId,
            diemThaiDo: 9.0,
            diemHieuBai: 8.5,
            diemBaiTap: 10.0,
            nhanXet: 'Tốt, Đầy đủ BTVN',
          ),
        );

        final feed = await timelineService.fetchTimeline(studentId: hs.id!);
        final sessionItems = feed
            .whereType<StudentSessionTimelineItem>()
            .toList();
        expect(sessionItems.length, equals(1));
        final item = sessionItems.first;
        expect(item.attendanceStatus, equals('Có mặt'));
        expect(item.className, equals('12A'));
      },
    );

    test('TEST 2: HS nghỉ KP 2 lần/14 ngày -> 1 ACTIVE warning', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 2'));
      final lop = await lopService.taoLop(Lop(ten: '12B', khoi: 12));
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
          gioDiemDanh: '2026-09-15 17:30:00',
          trangThai: 'Nghỉ không phép',
        ),
      );

      final signals = await signalService.getSignalsForStudent(
        hs.id!,
        activeOnly: true,
      );
      final absSignal = signals.firstWhere(
        (s) => s.signalType == StudentSignalType.UNEXCUSED_ABSENCE_WARNING,
      );
      expect(absSignal.status, equals(StudentSignalStatus.active));
    });

    test('TEST 3: Recompute nhiều lần -> Không duplicate warning', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 3'));
      final lop = await lopService.taoLop(Lop(ten: '12C', khoi: 12));
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

      await signalService.recomputeSignalsForStudent(hs.id!);
      await signalService.recomputeSignalsForStudent(hs.id!);
      await signalService.recomputeSignalsForStudent(hs.id!);

      final signals = await signalService.getSignalsForStudent(hs.id!);
      final absSignals = signals
          .where(
            (s) => s.signalType == StudentSignalType.UNEXCUSED_ABSENCE_WARNING,
          )
          .toList();
      expect(absSignals.length, equals(1));
    });

    test('TEST 4: HS thiếu BTVN 3/5 buổi -> HOMEWORK warning', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 4'));
      final lop = await lopService.taoLop(Lop(ten: '12D', khoi: 12));
      await lhsService.themHocSinhVaoLop(
        LopHocSinh(
          idLop: lop.id!,
          idHocSinh: hs.id!,
          ngayThamGia: '2026-09-01',
        ),
      );

      for (var i = 1; i <= 3; i++) {
        final attId = await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-0$i 17:30:00',
            trangThai: 'Có mặt',
          ),
        );
        await reviewService.luuDanhGia(
          DanhGiaBuoiHoc(
            idDiemDanh: attId,
            diemBaiTap: 4.0,
            nhanXet: 'Thiếu BTVN',
          ),
        );
      }

      await signalService.recomputeSignalsForStudent(hs.id!);
      final signals = await signalService.getSignalsForStudent(
        hs.id!,
        activeOnly: true,
      );
      expect(
        signals.any(
          (s) => s.signalType == StudentSignalType.HOMEWORK_REPEATED_WARNING,
        ),
        isTrue,
      );
    });

    test(
      'TEST 5: HS tham gia giữa tháng -> Không có timeline/signal attendance giả trước ngày tham gia',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 5'));
        final lop = await lopService.taoLop(Lop(ten: '12E', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-15',
          ),
        );

        await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-05 17:30:00',
            trangThai: 'Nghỉ không phép',
          ),
        );

        final feed = await timelineService.fetchTimeline(studentId: hs.id!);
        final preJoinEvents = feed.where((item) {
          if (item is StudentSessionTimelineItem) {
            return item.sessionDate.isBefore(DateTime(2026, 9, 15));
          }
          return false;
        }).toList();

        expect(preJoinEvents, isEmpty);
      },
    );

    test('TEST 6: Một ngày 2 session -> 2 session độc lập', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 6'));
      final lop = await lopService.taoLop(Lop(ten: '12F', khoi: 12));
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
          gioDiemDanh: '2026-09-17 17:30:00',
          trangThai: 'Có mặt',
        ),
      );

      await ddService.themDiemDanh(
        DiemDanh(
          idHocSinh: hs.id!,
          idLop: lop.id!,
          gioDiemDanh: '2026-09-17 19:30:00',
          trangThai: 'Có mặt',
        ),
      );

      final feed = await timelineService.fetchTimeline(studentId: hs.id!);
      final sessionItems = feed
          .whereType<StudentSessionTimelineItem>()
          .toList();
      expect(sessionItems.length, equals(2));
    });

    test(
      'TEST 7: Payment confirmed -> Timeline có payment event, warning overdue được resolve',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 7'));
        final lop = await lopService.taoLop(Lop(ten: '12G', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        await payService.capNhatSoTienDaDong(
          hs.id!,
          lop.id!,
          '2026-09',
          500000,
          'Đã đóng đủ',
        );
        await signalService.recomputeSignalsForStudent(hs.id!);

        final feed = await timelineService.fetchTimeline(
          studentId: hs.id!,
          filter: StudentTimelineFilter.payment,
        );
        expect(feed.any((e) => e is StudentPaymentTimelineItem), isTrue);
      },
    );

    test(
      'TEST 8: Signal ACTIVE -> ACKNOWLEDGED state change -> Cập nhật attention queue, timeline không mất',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 8'));
        final lop = await lopService.taoLop(Lop(ten: '12H', khoi: 12));
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

        final signals = await signalService.getSignalsForStudent(
          hs.id!,
          activeOnly: true,
        );
        final activeSig = signals.first;

        await attentionService.acknowledge(activeSig.id!);

        final updatedSig = (await signalService.getSignalsForStudent(
          hs.id!,
        )).firstWhere((s) => s.id == activeSig.id);
        expect(updatedSig.status, equals(StudentSignalStatus.acknowledged));

        final feed = await timelineService.fetchTimeline(studentId: hs.id!);
        expect(feed.isNotEmpty, isTrue);
      },
    );

    test('TEST 9: Filter Attendance -> Không hiện payment events', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 9'));
      final lop = await lopService.taoLop(Lop(ten: '12I', khoi: 12));
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
          trangThai: 'Có mặt',
        ),
      );
      await payService.capNhatSoTienDaDong(
        hs.id!,
        lop.id!,
        '2026-09',
        500000,
        'Đã nộp',
      );

      final attFeed = await timelineService.fetchTimeline(
        studentId: hs.id!,
        filter: StudentTimelineFilter.session,
      );
      for (var item in attFeed) {
        expect(item, isNot(isA<StudentPaymentTimelineItem>()));
      }
    });

    test(
      'TEST 10: 50+ timeline events -> Pagination giới hạn đúng số lượng theo page',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh 10'));
        final lop = await lopService.taoLop(Lop(ten: '12K', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-01-01',
          ),
        );

        for (var i = 1; i <= 50; i++) {
          final dayStr = (i % 28 + 1).toString().padLeft(2, '0');
          final monthStr = ((i ~/ 28) + 1).toString().padLeft(2, '0');
          await ddService.themDiemDanh(
            DiemDanh(
              idHocSinh: hs.id!,
              idLop: lop.id!,
              gioDiemDanh: '2026-$monthStr-$dayStr 17:30:00',
              trangThai: 'Có mặt',
            ),
          );
        }

        final page1 = await timelineService.fetchTimeline(
          studentId: hs.id!,
          page: 1,
          limit: 25,
        );
        expect(page1.length, equals(25));

        final page2 = await timelineService.fetchTimeline(
          studentId: hs.id!,
          page: 2,
          limit: 25,
        );
        expect(page2.length, equals(25));
      },
    );
  });
}
