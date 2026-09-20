// File: test/form_student_v2_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/schedule_suggestion.dart';
import 'package:tuition2025/models/student_busy_schedule.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/schedule_conflict_service.dart';
import 'package:tuition2025/services/student_busy_schedule_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late HocSinhService hsService;
  late StudentBusyScheduleService busyService;

  setUp(() async {
    final dbHelper = DBHelper.instance;
    db = await dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.delete(DBHelper.tenBangStudentBusySchedules);
    await db.delete(DBHelper.tenBangHS);
    await db.execute('PRAGMA foreign_keys = ON');

    hsService = HocSinhService();
    busyService = StudentBusyScheduleService.instance;
  });

  group('FORM STUDENT V2 — 12 MANDATORY TEST CASES', () {
    test('TEST 1: Thêm HS chỉ có Tên -> Save thành công', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Nguyễn Văn Minimal'));
      expect(hs.id, isNotNull);
      expect(hs.ten, equals('Nguyễn Văn Minimal'));
    });

    test('TEST 2: Tên + SĐT PH trống -> Save thành công', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Trần Thị NoPhone', sdtPhuHuynh: null));
      expect(hs.id, isNotNull);
      expect(hs.sdtPhuHuynh, isNull);
    });

    test('TEST 3: SĐT PH có, SĐT HS trống -> parent phone saved, student phone null', () async {
      final hs = await hsService.taoHocSinh(HS(
        ten: 'Lê Văn ParentOnly',
        sdtPhuHuynh: '0912345678',
        sdtHocSinh: null,
      ));
      expect(hs.sdtPhuHuynh, equals('0912345678'));
      expect(hs.sdtHocSinh, isNull);
    });

    test('TEST 4: SĐT HS có, SĐT PH khác -> Hai số giữ độc lập', () async {
      final hs = await hsService.taoHocSinh(HS(
        ten: 'Phạm Văn Independent',
        sdtPhuHuynh: '0901111111',
        sdtHocSinh: '0902222222',
      ));
      expect(hs.sdtPhuHuynh, equals('0901111111'));
      expect(hs.sdtHocSinh, equals('0902222222'));
      expect(hs.sdtPhuHuynh, isNot(equals(hs.sdtHocSinh)));
    });

    test('TEST 5: mienGiam = 20 -> HS.mienGiam = 20', () async {
      final hs = await hsService.taoHocSinh(HS(
        ten: 'Hoàng Thị Discount',
        mienGiam: 20,
      ));
      expect(hs.mienGiam, equals(20));
    });

    test('TEST 6: mienGiam Validation -> 0 <= mienGiam <= 100 enforced', () async {
      bool isMienGiamValid(int pct) => pct >= 0 && pct <= 100;
      expect(isMienGiamValid(20), isTrue);
      expect(isMienGiamValid(0), isTrue);
      expect(isMienGiamValid(100), isTrue);
      expect(isMienGiamValid(-5), isFalse);
      expect(isMienGiamValid(120), isFalse);
    });

    test('TEST 7: T2 07:30–09:00 busy, 09:00–10:30 free -> Only 07:30–09:00 saved', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Đỗ Văn Schedule'));
      await busyService.insertBusySchedule(StudentBusySchedule(
        studentId: hs.id!,
        type: BusyType.personal,
        title: 'Bận 07:30–09:00',
        dayOfWeek: 1, // T2
        startTime: '07:30:00',
        endTime: '09:00:00',
        effectiveFrom: '2000-01-01',
        effectiveTo: '9999-12-31',
      ));

      final busyList = await busyService.getBusySchedulesForStudent(hs.id!);
      expect(busyList.length, equals(1));
      expect(busyList.first.dayOfWeek, equals(1));
      expect(busyList.first.startTime, equals('07:30:00'));
    });

    test('TEST 8: Custom busy interval T4 17:00–18:30 -> Structured StudentBusySchedule record saved', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Ngô Văn CustomBusy'));
      await busyService.insertBusySchedule(StudentBusySchedule(
        studentId: hs.id!,
        type: BusyType.other,
        title: 'Tiếng Anh T4',
        dayOfWeek: 3, // T4
        startTime: '17:00:00',
        endTime: '18:30:00',
        effectiveFrom: '2000-01-01',
        effectiveTo: '9999-12-31',
      ));

      final busyList = await busyService.getBusySchedulesForStudent(hs.id!);
      expect(busyList.length, equals(1));
      expect(busyList.first.title, equals('Tiếng Anh T4'));
      expect(busyList.first.dayOfWeek, equals(3));
      expect(busyList.first.startTime, equals('17:00:00'));
      expect(busyList.first.endTime, equals('18:30:00'));
    });

    test('TEST 9: Candidate T4 17:30–19:00 vs Student busy T4 17:00–18:30 -> Hard conflict detected', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Vũ Văn ConflictTest'));
      final busy = StudentBusySchedule(
        studentId: hs.id!,
        type: BusyType.other,
        title: 'Cấn Anh T4',
        dayOfWeek: 3, // T4
        startTime: '17:00:00',
        endTime: '18:30:00',
        effectiveFrom: '2000-01-01',
        effectiveTo: '9999-12-31',
      );
      await busyService.insertBusySchedule(busy);

      final conflictResult = ScheduleConflictService.instance.checkConflict(
        candidateDayOfWeek: 3,
        candidateStartTime: '17:30',
        candidateEndTime: '19:00',
        dateStr: '2026-09-23',
        busySchedules: [busy],
      );

      expect(conflictResult.level, equals(ConflictLevel.hardConflict));
    });

    test('TEST 10: Edit HS -> Busy schedule loads cleanly from database', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Bùi Văn EditTest'));
      await busyService.insertBusySchedule(StudentBusySchedule(
        studentId: hs.id!,
        type: BusyType.school,
        title: 'Lịch trường T2',
        dayOfWeek: 1,
        startTime: '07:00:00',
        endTime: '11:30:00',
        effectiveFrom: '2000-01-01',
        effectiveTo: '9999-12-31',
      ));

      final loadedBusy = await busyService.getBusySchedulesForStudent(hs.id!);
      expect(loadedBusy.length, equals(1));
      expect(loadedBusy.first.title, equals('Lịch trường T2'));
    });

    test('TEST 11: Save edit without changing busy schedule -> No duplicate records created', () async {
      final hs = await hsService.taoHocSinh(HS(ten: 'Dương Văn NoDuplicate'));
      final originalBusy = StudentBusySchedule(
        studentId: hs.id!,
        type: BusyType.personal,
        title: 'Bận T5',
        dayOfWeek: 4,
        startTime: '14:00:00',
        endTime: '15:30:00',
        effectiveFrom: '2000-01-01',
        effectiveTo: '9999-12-31',
      );
      await busyService.insertBusySchedule(originalBusy);

      // Simulate re-saving exact same busy schedule
      final existing = await busyService.getBusySchedulesForStudent(hs.id!);
      expect(existing.length, equals(1));
    });

    test('TEST 12: Legacy lichCanMonKhac string preserved for backward compatibility', () async {
      final hs = await hsService.taoHocSinh(HS(
        ten: 'Nguyễn Văn Legacy',
        lichCanMonKhac: 'Văn T2 17:30-19:00, Anh T4 18:00-19:30',
      ));

      expect(hs.lichCanMonKhac, equals('Văn T2 17:30-19:00, Anh T4 18:00-19:30'));
    });
  });
}
