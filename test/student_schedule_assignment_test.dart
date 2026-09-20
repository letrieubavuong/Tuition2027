import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/hs_lop_view_model.dart';
import 'package:tuition2025/models/lich_hoc.dart';
import 'package:tuition2025/services/student_schedule_assignment_service.dart';
import 'package:tuition2025/utils/db.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  final service = StudentScheduleAssignmentService.instance;

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
            thu_trong_tuan INTEGER NOT NULL,
            gio_bat_dau TEXT NOT NULL,
            gio_ket_thuc TEXT NOT NULL
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

  test('Batch assignment successfully inserts into student_schedule_assignments with all columns', () async {
    final res = await service.batchAssignStudentsToSchedule(
      classId: 1,
      scheduleId: 10,
      dayOfWeek: 2,
      startTime: '18:00',
      endTime: '20:00',
      studentIds: [101, 102],
    );

    expect(res['success'], equals(2));
    expect(res['skipped'], equals(0));

    final rows = await db.query(DBHelper.tenBangStudentScheduleAssignments);
    expect(rows.length, equals(2));
    expect(rows.first['student_id'], equals(101));
    expect(rows.first['class_id'], equals(1));
    expect(rows.first['schedule_id'], equals(10));
    expect(rows.first['day_of_week'], equals(2));
    expect(rows.first['start_time'], equals('18:00'));
    expect(rows.first['end_time'], equals('20:00'));
    expect(rows.first['priority'], equals(1));
  });

  test('getClassScheduleRoster correctly maps legacy lich_hoc_ca_nhan records with Vietnamese day names', () async {
    // Insert legacy general schedule: Monday 18:00 - 20:00
    final lhcId = await db.insert('lich_hoc_chung', {
      'id_lop': 1,
      'ngay_trong_tuan': 'Thứ Hai',
      'gio_bat_dau': '18:00',
      'gio_ket_thuc': '20:00',
    });

    // Insert legacy student assignment
    await db.insert('lich_hoc_ca_nhan', {
      'id_hoc_sinh': 201,
      'id_lich_hoc_chung': lhcId,
    });

    final schedules = [
      LichHoc(
        id: 50,
        idLop: 1,
        thuTrongTuan: 2, // Monday
        gioBatDau: '18:00:00',
        gioKetThuc: '20:00:00',
      ),
    ];

    final List<HSLopViewModel> activeStudents = [
      HSLopViewModel(
        hocSinh: HS(
          id: 201,
          ten: 'Học sinh Cũ',
          sdt: '0901234567',
        ),
        ngayThamGia: '2026-01-01',
        trangThai: 'DANG_HOC',
      ),
    ];

    final roster = await service.getClassScheduleRoster(
      classId: 1,
      schedules: schedules,
      activeStudents: activeStudents,
    );

    expect(roster.studentIdsByScheduleId[50], contains(201));
    expect(roster.unassignedStudentIds, isEmpty);
    expect(roster.activeAssignmentByStudentId[201]?.scheduleId, equals(50));
  });
}
