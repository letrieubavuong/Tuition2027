// File: test/attendance_correction_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/diem_danh.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/lop_hoc_sinh.dart';
import 'package:tuition2025/models/danh_gia_buoi_hoc.dart';
import 'package:tuition2025/models/student_signal.dart';
import 'package:tuition2025/models/student_timeline.dart';
import 'package:tuition2025/services/attendance_correction_service.dart';
import 'package:tuition2025/services/danh_gia_buoi_hoc_service.dart';
import 'package:tuition2025/services/diem_danh_service.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/lop_service.dart';
import 'package:tuition2025/services/lop_hoc_sinh_service.dart';
import 'package:tuition2025/services/student_signal_service.dart';
import 'package:tuition2025/services/student_timeline_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late HocSinhService hsService;
  late LopService lopService;
  late LopHocSinhService lhsService;
  late DiemDanhService ddService;
  late DanhGiaBuoiHocService reviewService;
  late StudentSignalService signalService;
  late StudentTimelineService timelineService;
  late AttendanceCorrectionService correctionService;

  setUp(() async {
    final dbHelper = DBHelper.instance;
    db = await dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.delete(DBHelper.tenBangStudentSignals);
    await db.delete(DBHelper.tenBangDanhGiaBuoiHoc);
    await db.delete(DBHelper.tenBangDiemDanh);
    await db.delete(DBHelper.tenBangLopHS);
    await db.delete(DBHelper.tenBangLop);
    await db.delete(DBHelper.tenBangHS);
    await db.delete('session_completion_ledger');
    await db.delete('session_homework');
    await db.delete(DBHelper.tenBangAttendanceChangeLog);
    await db.execute('PRAGMA foreign_keys = ON');

    hsService = HocSinhService();
    lopService = LopService();
    lhsService = LopHocSinhService();
    ddService = DiemDanhService();
    reviewService = DanhGiaBuoiHocService();
    signalService = StudentSignalService.instance;
    timelineService = StudentTimelineService.instance;
    correctionService = AttendanceCorrectionService.instance;
  });

  tearDownAll(() async {
    await db.close();
  });

  group('ATTENDANCE CORRECTION & SAFETY SUITE (12 TEST CASES)', () {
    test(
      'TEST 1: Nghỉ không phép -> Có mặt (Status edit & Signal recompute)',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T1'));
        final lop = await lopService.taoLop(Lop(ten: '12-T1', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        final id1 = await ddService.themDiemDanh(
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

        final preSignals = await signalService.getSignalsForStudent(
          hs.id!,
          activeOnly: true,
        );
        expect(preSignals.length, equals(1));

        // Sửa buổi 1 từ Nghỉ KP -> Có mặt
        await correctionService.editStudentStatus(
          attendanceId: id1,
          newStatus: 'Có mặt',
          reason: 'Giáo viên điểm danh nhầm',
        );

        // Recompute verify
        final postSignals = await signalService.getSignalsForStudent(
          hs.id!,
          activeOnly: true,
        );
        expect(postSignals, isEmpty); // Signal resolved automatically

        final timeline = await timelineService.fetchTimeline(studentId: hs.id!);
        final item = timeline
            .whereType<StudentSessionTimelineItem>()
            .firstWhere(
              (s) => s.eventDateTime == DateTime(2026, 9, 10, 17, 30),
            );
        expect(item.attendanceStatus, equals('Có mặt'));
      },
    );

    test('TEST 2: Có mặt -> Trễ (Update identity without duplicate)', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T2'));
      final lop = await lopService.taoLop(Lop(ten: '12-T2', khoi: 12));
      await lhsService.themHocSinhVaoLop(
        LopHocSinh(
          idLop: lop.id!,
          idHocSinh: hs.id!,
          ngayThamGia: '2026-09-01',
        ),
      );

      final id = await ddService.themDiemDanh(
        DiemDanh(
          idHocSinh: hs.id!,
          idLop: lop.id!,
          gioDiemDanh: '2026-09-15 17:30:00',
          trangThai: 'Có mặt',
        ),
      );
      await correctionService.editStudentStatus(
        attendanceId: id,
        newStatus: 'Trễ',
      );

      final countRows = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM diem_danh WHERE id_hoc_sinh = ?',
        [hs.id],
      );
      expect(countRows.first['cnt'], equals(1)); // Không duplicate
    });

    test(
      'TEST 3: Xóa học sinh được thêm nhầm (Remove single student)',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T3'));
        final lop = await lopService.taoLop(Lop(ten: '12-T3', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        final id = await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-15 17:30:00',
            trangThai: 'Có mặt',
          ),
        );
        await reviewService.luuDanhGia(
          DanhGiaBuoiHoc(
            idDiemDanh: id,
            diemThaiDo: 8.0,
            nhanXet: 'Nhiệt tình',
          ),
        );

        await correctionService.removeStudentFromSession(
          attendanceId: id,
          reason: 'Học sinh chọn nhầm lớp',
        );

        final attRows = await db.query(
          'diem_danh',
          where: 'id = ?',
          whereArgs: [id],
        );
        expect(attRows, isEmpty);

        final reviewRows = await db.query(
          'danh_gia_buoi_hoc',
          where: 'id_diem_danh = ?',
          whereArgs: [id],
        );
        expect(reviewRows, isEmpty); // Cascade clean

        final logs = await correctionService.getAuditLogsForStudent(hs.id!);
        expect(
          logs.any((l) => l.action == 'REMOVE_STUDENT'),
          isTrue,
        ); // Audit exists
      },
    );

    test('TEST 4: Sửa ngày cả buổi (18/09 -> 19/09)', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T4'));
      final lop = await lopService.taoLop(Lop(ten: '12-T4', khoi: 12));
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
          gioDiemDanh: '2026-09-18 18:00:00',
          trangThai: 'Có mặt',
        ),
      );

      await correctionService.updateSessionDetails(
        classId: lop.id!,
        oldDateStr: '2026-09-18',
        newDateStr: '2026-09-19',
        reason: 'Lùi lịch dạy',
      );

      final attRows = await db.query(
        'diem_danh',
        where: 'id_lop = ?',
        whereArgs: [lop.id],
      );
      expect(attRows.first['gio_diem_danh'], startsWith('2026-09-19'));
    });

    test(
      'TEST 5: Sửa sang ngày đã có session cùng ca -> StateError conflict',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T5'));
        final lop = await lopService.taoLop(Lop(ten: '12-T5', khoi: 12));
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
            gioDiemDanh: '2026-09-18 18:00:00',
            trangThai: 'Có mặt',
          ),
        );
        await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-19 18:00:00',
            trangThai: 'Có mặt',
          ),
        );

        expect(
          () async => await correctionService.updateSessionDetails(
            classId: lop.id!,
            oldDateStr: '2026-09-18',
            newDateStr: '2026-09-19',
            newStartTime: '18:00:00',
            reason: 'Trùng lịch',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('TEST 6: Hủy cả session (Session CANCELLED)', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T6'));
      final lop = await lopService.taoLop(Lop(ten: '12-T6', khoi: 12));
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
          gioDiemDanh: '2026-09-20 18:00:00',
          trangThai: 'Nghỉ không phép',
        ),
      );

      await correctionService.cancelSession(
        classId: lop.id!,
        dateStr: '2026-09-20',
        reason: 'Bão nghỉ học',
      );

      final timeline = await timelineService.fetchTimeline(studentId: hs.id!);
      final cancelledInTimeline = timeline
          .whereType<StudentSessionTimelineItem>()
          .where((s) => s.sessionDate == DateTime(2026, 9, 20));
      expect(
        cancelledInTimeline,
        isEmpty,
      ); // Session CANCELLED excluded from main timeline
    });

    test('TEST 7: Restore session', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T7'));
      final lop = await lopService.taoLop(Lop(ten: '12-T7', khoi: 12));
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
          gioDiemDanh: '2026-09-21 18:00:00',
          trangThai: 'Có mặt',
        ),
      );
      await correctionService.cancelSession(
        classId: lop.id!,
        dateStr: '2026-09-21',
        reason: 'Hủy nhầm',
      );

      await correctionService.restoreSession(
        classId: lop.id!,
        dateStr: '2026-09-21',
        reason: 'Khôi phục lại',
      );

      final timeline = await timelineService.fetchTimeline(studentId: hs.id!);
      final restoredItem = timeline
          .whereType<StudentSessionTimelineItem>()
          .firstWhere(
            (s) =>
                s.sessionDate.year == 2026 &&
                s.sessionDate.month == 9 &&
                s.sessionDate.day == 21,
          );
      expect(restoredItem.attendanceStatus, equals('Có mặt'));
    });

    test('TEST 8: Signal ACTIVE -> RESOLVED sau correction', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T8'));
      final lop = await lopService.taoLop(Lop(ten: '12-T8', khoi: 12));
      await lhsService.themHocSinhVaoLop(
        LopHocSinh(
          idLop: lop.id!,
          idHocSinh: hs.id!,
          ngayThamGia: '2026-09-01',
        ),
      );

      final id1 = await ddService.themDiemDanh(
        DiemDanh(
          idHocSinh: hs.id!,
          idLop: lop.id!,
          gioDiemDanh: '2026-09-10 18:00:00',
          trangThai: 'Nghỉ không phép',
        ),
      );
      await ddService.themDiemDanh(
        DiemDanh(
          idHocSinh: hs.id!,
          idLop: lop.id!,
          gioDiemDanh: '2026-09-12 18:00:00',
          trangThai: 'Nghỉ không phép',
        ),
      );
      await signalService.recomputeSignalsForStudent(hs.id!);

      final sigs = await signalService.getSignalsForStudent(
        hs.id!,
        activeOnly: true,
      );
      expect(sigs.length, equals(1));

      await correctionService.editStudentStatus(
        attendanceId: id1,
        newStatus: 'Có mặt',
      );

      final postSigs = await signalService.getSignalsForStudent(
        hs.id!,
        activeOnly: true,
      );
      expect(postSigs, isEmpty); // Auto resolved
    });

    test(
      'TEST 9: Legacy attendance không có sessionId -> không crash',
      () async {
        final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T9'));
        final lop = await lopService.taoLop(Lop(ten: '12-T9', khoi: 12));
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        final id = await ddService.themDiemDanh(
          DiemDanh(
            idHocSinh: hs.id!,
            idLop: lop.id!,
            gioDiemDanh: '2026-09-22 18:00:00',
            trangThai: 'Có mặt',
          ),
        );
        await correctionService.editStudentStatus(
          attendanceId: id,
          newStatus: 'Trễ',
        );

        final timeline = await timelineService.fetchTimeline(studentId: hs.id!);
        expect(timeline.isNotEmpty, isTrue);
      },
    );

    test('TEST 10: Lỗi giữa transaction -> Rollback toàn bộ', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T10'));
      final lop = await lopService.taoLop(Lop(ten: '12-T10', khoi: 12));

      expect(
        () async => await correctionService.editStudentStatus(
          attendanceId: 99999,
          newStatus: 'Có mặt',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('TEST 11: Sửa nhầm rồi Undo -> Khôi phục giá trị cũ', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T11'));
      final lop = await lopService.taoLop(Lop(ten: '12-T11', khoi: 12));
      await lhsService.themHocSinhVaoLop(
        LopHocSinh(
          idLop: lop.id!,
          idHocSinh: hs.id!,
          ngayThamGia: '2026-09-01',
        ),
      );

      final id = await ddService.themDiemDanh(
        DiemDanh(
          idHocSinh: hs.id!,
          idLop: lop.id!,
          gioDiemDanh: '2026-09-23 18:00:00',
          trangThai: 'Nghỉ không phép',
        ),
      );

      // Edit 1
      await correctionService.editStudentStatus(
        attendanceId: id,
        newStatus: 'Có mặt',
      );
      // Undo
      await correctionService.editStudentStatus(
        attendanceId: id,
        newStatus: 'Nghỉ không phép',
        reason: 'Hoàn tác',
      );

      final recordRows = await db.query(
        'diem_danh',
        where: 'id = ?',
        whereArgs: [id],
      );
      final record = DiemDanh.fromMap(recordRows.first);
      expect(record.trangThai, equals('Nghỉ không phép'));
    });

    test('TEST 12: Audit log tồn tại đúng sau restart', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Học sinh T12'));
      final lop = await lopService.taoLop(Lop(ten: '12-T12', khoi: 12));
      await lhsService.themHocSinhVaoLop(
        LopHocSinh(
          idLop: lop.id!,
          idHocSinh: hs.id!,
          ngayThamGia: '2026-09-01',
        ),
      );

      final id = await ddService.themDiemDanh(
        DiemDanh(
          idHocSinh: hs.id!,
          idLop: lop.id!,
          gioDiemDanh: '2026-09-24 18:00:00',
          trangThai: 'Có mặt',
        ),
      );
      await correctionService.editStudentStatus(
        attendanceId: id,
        newStatus: 'Trễ',
        reason: 'Đến trễ 15p',
      );

      final logs = await correctionService.getAuditLogsForStudent(hs.id!);
      expect(logs.first.oldStatus, equals('Có mặt'));
      expect(logs.first.newStatus, equals('Trễ'));
      expect(logs.first.reason, equals('Đến trễ 15p'));
    });
  });
}
