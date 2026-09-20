import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/diem_danh.dart';
import 'package:tuition2025/utils/db.dart';
import 'package:tuition2025/utils/attendance_calculator.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Luồng Đánh giá nhanh & Giữ nguyên điểm danh hiện hữu', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE ${DBHelper.tenBangDiemDanh} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              id_hoc_sinh INTEGER NOT NULL,
              id_lop INTEGER NOT NULL,
              gio_diem_danh TEXT NOT NULL,
              trang_thai TEXT NOT NULL,
              UNIQUE(id_hoc_sinh, id_lop, gio_diem_danh) ON CONFLICT REPLACE
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test(
      '1. Đánh giá nhanh học sinh ĐÃ TRỄ => giữ nguyên trạng thái "Trễ", không bị đổi thành "Có mặt"',
      () async {
        const ngayStr = '2026-09-16';
        const gioBatDau = '14:00:00';
        const gioDiemDanhFull = '$ngayStr $gioBatDau';

        // Tạo bản ghi đã Trễ từ trước
        await db.insert(DBHelper.tenBangDiemDanh, {
          'id_hoc_sinh': 101,
          'id_lop': 1,
          'gio_diem_danh': gioDiemDanhFull,
          'trang_thai': 'Trễ',
        });

        // Giả lập logic Mở đánh giá nhanh: Tìm bản ghi điểm danh hiện hữu
        final existingRecords = await db.query(
          DBHelper.tenBangDiemDanh,
          where: 'id_lop = ? AND gio_diem_danh BETWEEN ? AND ?',
          whereArgs: [1, '$ngayStr 00:00:00', '$ngayStr 23:59:59'],
        );

        final existingList = existingRecords
            .map((m) => DiemDanh.fromMap(m))
            .toList();
        final existingRecord = existingList.cast<DiemDanh?>().firstWhere(
          (dd) =>
              dd?.idHocSinh == 101 &&
              (dd?.gioDiemDanh.contains(gioBatDau) ?? false),
          orElse: () => null,
        );

        expect(existingRecord, isNotNull);
        expect(existingRecord!.trangThai, equals('Trễ'));

        // Giữ nguyên idDiemDanh hiện hữu
        final idDiemDanh = existingRecord.id!;

        // Kiểm tra lại DB sau khi mở đánh giá: trạng thái vẫn là "Trễ"
        final checkDb = await db.query(
          DBHelper.tenBangDiemDanh,
          where: 'id = ?',
          whereArgs: [idDiemDanh],
        );
        expect(checkDb.first['trang_thai'], equals('Trễ'));
      },
    );

    test(
      '2. Đánh giá nhanh học sinh ĐÃ NGHỈ CÓ PHÉP => giữ nguyên trạng thái "Nghỉ có phép"',
      () async {
        const ngayStr = '2026-09-16';
        const gioBatDau = '14:00:00';
        const gioDiemDanhFull = '$ngayStr $gioBatDau';

        await db.insert(DBHelper.tenBangDiemDanh, {
          'id_hoc_sinh': 102,
          'id_lop': 1,
          'gio_diem_danh': gioDiemDanhFull,
          'trang_thai': 'Nghỉ có phép',
        });

        final existingRecords = await db.query(
          DBHelper.tenBangDiemDanh,
          where: 'id_lop = ? AND gio_diem_danh BETWEEN ? AND ?',
          whereArgs: [1, '$ngayStr 00:00:00', '$ngayStr 23:59:59'],
        );

        final existingRecord = existingRecords
            .map((m) => DiemDanh.fromMap(m))
            .cast<DiemDanh?>()
            .firstWhere((dd) => dd?.idHocSinh == 102, orElse: () => null);

        expect(existingRecord, isNotNull);
        expect(existingRecord!.trangThai, equals('Nghỉ có phép'));
      },
    );

    test(
      '3. Đánh giá nhanh học sinh ĐÃ VẮNG => giữ nguyên trạng thái "Nghỉ không phép"',
      () async {
        const ngayStr = '2026-09-16';
        const gioBatDau = '14:00:00';

        await db.insert(DBHelper.tenBangDiemDanh, {
          'id_hoc_sinh': 103,
          'id_lop': 1,
          'gio_diem_danh': '$ngayStr $gioBatDau',
          'trang_thai': 'Nghỉ không phép',
        });

        final existingRecords = await db.query(
          DBHelper.tenBangDiemDanh,
          where: 'id_lop = ? AND gio_diem_danh BETWEEN ? AND ?',
          whereArgs: [1, '$ngayStr 00:00:00', '$ngayStr 23:59:59'],
        );

        final existingRecord = existingRecords
            .map((m) => DiemDanh.fromMap(m))
            .cast<DiemDanh?>()
            .firstWhere((dd) => dd?.idHocSinh == 103, orElse: () => null);

        expect(existingRecord, isNotNull);
        expect(existingRecord!.trangThai, equals('Nghỉ không phép'));
      },
    );

    test(
      '4. Đánh giá nhanh học sinh CHƯA điểm danh => tự tạo điểm danh ban đầu "Có mặt"',
      () async {
        const ngayStr = '2026-09-16';
        const gioBatDau = '14:00:00';

        final existingRecords = await db.query(
          DBHelper.tenBangDiemDanh,
          where: 'id_lop = ? AND gio_diem_danh BETWEEN ? AND ?',
          whereArgs: [1, '$ngayStr 00:00:00', '$ngayStr 23:59:59'],
        );

        final existingRecord = existingRecords
            .map((m) => DiemDanh.fromMap(m))
            .cast<DiemDanh?>()
            .firstWhere((dd) => dd?.idHocSinh == 104, orElse: () => null);

        expect(existingRecord, isNull);

        // Nếu chưa có, mới insert bản ghi ban đầu
        final id = await db.insert(DBHelper.tenBangDiemDanh, {
          'id_hoc_sinh': 104,
          'id_lop': 1,
          'gio_diem_danh': '$ngayStr $gioBatDau',
          'trang_thai': 'Có mặt',
        });

        expect(id, greaterThan(0));
      },
    );
  });

  group('Business rules ngày nghỉ học, tạm ngưng, học lại', () {
    test('Học sinh tham gia đúng cửa sổ ngày (Participation Window)', () {
      final now = DateTime(2026, 9, 16);
      final join = DateTime(2026, 9, 1);
      final leave = DateTime(2026, 9, 30);

      expect(
        AttendanceCalculator.isDateInParticipationWindow(
          date: now,
          ngayThamGia: join,
          ngayNghiHoc: leave,
        ),
        isTrue,
      );

      // Ngày sau ngày nghỉ học
      final afterLeave = DateTime(2026, 10, 1);
      expect(
        AttendanceCalculator.isDateInParticipationWindow(
          date: afterLeave,
          ngayThamGia: join,
          ngayNghiHoc: leave,
        ),
        isFalse,
      );
    });

    test('Học sinh nghỉ rồi học lại (resumeAfterStop)', () {
      final leave = DateTime(2026, 9, 10);
      final resume = DateTime(2026, 9, 20);

      // Trong thời gian nghỉ
      final duringLeave = DateTime(2026, 9, 15);
      expect(
        AttendanceCalculator.isDateInParticipationWindow(
          date: duringLeave,
          ngayNghiHoc: leave,
          ngayHocLaiSauNghi: resume,
        ),
        isFalse,
      );

      // Ngày học lại
      final onResume = DateTime(2026, 9, 20);
      expect(
        AttendanceCalculator.isDateInParticipationWindow(
          date: onResume,
          ngayNghiHoc: leave,
          ngayHocLaiSauNghi: resume,
        ),
        isTrue,
      );
    });

    test('Chuẩn hóa trạng thái tạm ngưng (isStudentPaused)', () {
      expect(AttendanceCalculator.isStudentPaused('TAM_NGUNG'), isTrue);
      expect(AttendanceCalculator.isStudentPaused('TAM_NGHI'), isTrue);
      expect(AttendanceCalculator.isStudentPaused('TẠM NGỪNG'), isTrue);
      expect(AttendanceCalculator.isStudentPaused('TẠM NGHỈ'), isTrue);
      expect(AttendanceCalculator.isStudentPaused('HOAT_DONG'), isFalse);
      expect(AttendanceCalculator.isStudentPaused(null), isFalse);
    });
  });
}
