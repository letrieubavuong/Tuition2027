import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/hs_lop_view_model.dart';
import 'package:tuition2025/models/lich_hoc.dart';
import 'package:tuition2025/services/lich_hoc_service.dart';
import 'package:tuition2025/services/student_schedule_assignment_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  final service = StudentScheduleAssignmentService.instance;
  final lichHocService = LichHocService();

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 36,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE hoc_sinh (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ho_ten TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE lop (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ten TEXT NOT NULL,
            khoi INTEGER NOT NULL
          )
        ''');
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
        await db.execute('''
          CREATE TABLE lich_hoc_ca_nhan (
            id_hoc_sinh INTEGER NOT NULL,
            id_lich_hoc_chung INTEGER NOT NULL,
            PRIMARY KEY (id_hoc_sinh, id_lich_hoc_chung)
          )
        ''');
        await db.execute('''
          CREATE TABLE student_schedule_assignments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id INTEGER NOT NULL,
            class_id INTEGER NOT NULL,
            schedule_id INTEGER,
            effective_from TEXT NOT NULL,
            effective_to TEXT,
            source TEXT NOT NULL DEFAULT 'MANUAL',
            recurrence_type TEXT NOT NULL DEFAULT 'WEEKLY',
            day_of_week INTEGER,
            start_time TEXT,
            end_time TEXT,
            priority INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
      },
    );
    DBHelper.setTestDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Multi-slot schedule sync & display: layLichHocTheoLop syncs all slots from lich_hoc_chung and roster maps them correctly', () async {
    // Insert 2 legacy slots in lich_hoc_chung: Slot 1 (Monday) & Slot 2 (Wednesday)
    final lhc1 = await db.insert('lich_hoc_chung', {
      'id_lop': 10,
      'ngay_trong_tuan': 'Thứ Hai',
      'gio_bat_dau': '18:00',
      'gio_ket_thuc': '20:00',
    });
    final lhc2 = await db.insert('lich_hoc_chung', {
      'id_lop': 10,
      'ngay_trong_tuan': 'Thứ Tư',
      'gio_bat_dau': '18:00',
      'gio_ket_thuc': '20:00',
    });

    // Assign Student 1 to Slot 1, Student 2 to Slot 2
    await db.insert('lich_hoc_ca_nhan', {'id_hoc_sinh': 101, 'id_lich_hoc_chung': lhc1});
    await db.insert('lich_hoc_ca_nhan', {'id_hoc_sinh': 102, 'id_lich_hoc_chung': lhc2});

    // Read schedules for class 10 -> verify both slots are synced & returned
    final loadedSchedules = await lichHocService.layLichHocTheoLop(10);
    expect(loadedSchedules.length, equals(2));

    final slot1 = loadedSchedules.firstWhere((s) => s.thuTrongTuan == 2);
    final slot2 = loadedSchedules.firstWhere((s) => s.thuTrongTuan == 4);

    final activeStudents = [
      HSLopViewModel(
        hocSinh: HS(id: 101, ten: 'Học sinh Slot 1'),
        ngayThamGia: '2026-01-01',
        trangThai: 'DANG_HOC',
      ),
      HSLopViewModel(
        hocSinh: HS(id: 102, ten: 'Học sinh Slot 2'),
        ngayThamGia: '2026-01-01',
        trangThai: 'DANG_HOC',
      ),
    ];

    final roster = await service.getClassScheduleRoster(
      classId: 10,
      schedules: loadedSchedules,
      activeStudents: activeStudents,
    );

    // Verify Slot 1 contains Student 1, Slot 2 contains Student 2
    expect(roster.studentIdsByScheduleId[slot1.id], contains(101));
    expect(roster.studentIdsByScheduleId[slot1.id], isNot(contains(102)));

    expect(roster.studentIdsByScheduleId[slot2.id], contains(102));
    expect(roster.studentIdsByScheduleId[slot2.id], isNot(contains(101)));
    expect(roster.unassignedStudentIds, isEmpty);
  });

  test('Transfer student from Slot 1 to Slot 2 replaces previous assignment cleanly', () async {
    final slot1 = LichHoc(id: 1, idLop: 10, thuTrongTuan: 2, gioBatDau: '18:00:00', gioKetThuc: '20:00:00');
    final slot2 = LichHoc(id: 2, idLop: 10, thuTrongTuan: 4, gioBatDau: '18:00:00', gioKetThuc: '20:00:00');

    final student = HSLopViewModel(
      hocSinh: HS(id: 301, ten: 'Học sinh Chuyển Ca'),
      ngayThamGia: '2026-01-01',
      trangThai: 'DANG_HOC',
    );

    // 1. Assign to Slot 1
    await service.batchAssignStudentsToSchedule(
      classId: 10,
      scheduleId: 1,
      dayOfWeek: 2,
      startTime: '18:00',
      endTime: '20:00',
      studentIds: [301],
    );

    var roster = await service.getClassScheduleRoster(
      classId: 10,
      schedules: [slot1, slot2],
      activeStudents: [student],
    );
    expect(roster.studentIdsByScheduleId[1], contains(301));
    expect(roster.studentIdsByScheduleId[2], isEmpty);

    // 2. Transfer student to Slot 2
    await service.batchAssignStudentsToSchedule(
      classId: 10,
      scheduleId: 2,
      dayOfWeek: 4,
      startTime: '18:00',
      endTime: '20:00',
      studentIds: [301],
    );

    roster = await service.getClassScheduleRoster(
      classId: 10,
      schedules: [slot1, slot2],
      activeStudents: [student],
    );
    expect(roster.studentIdsByScheduleId[1], isEmpty);
    expect(roster.studentIdsByScheduleId[2], contains(301));
  });

  test('Unassign student removes student from schedule and moves them to unassigned', () async {
    final slot1 = LichHoc(id: 1, idLop: 10, thuTrongTuan: 2, gioBatDau: '18:00:00', gioKetThuc: '20:00:00');
    final student = HSLopViewModel(
      hocSinh: HS(id: 401, ten: 'Học sinh Hủy Gán'),
      ngayThamGia: '2026-01-01',
      trangThai: 'DANG_HOC',
    );

    await service.batchAssignStudentsToSchedule(
      classId: 10,
      scheduleId: 1,
      dayOfWeek: 2,
      startTime: '18:00',
      endTime: '20:00',
      studentIds: [401],
    );

    // Unassign student
    final unassignCount = await service.unassignStudentsFromClassSchedules(
      classId: 10,
      studentIds: [401],
    );
    expect(unassignCount, equals(1));

    final roster = await service.getClassScheduleRoster(
      classId: 10,
      schedules: [slot1],
      activeStudents: [student],
    );

    expect(roster.studentIdsByScheduleId[1], isEmpty);
    expect(roster.unassignedStudentIds, contains(401));
  });
}
