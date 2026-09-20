// File: lib/services/diem_danh_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc.dart';
import '../utils/db.dart'; // Đảm bảo import DBHelper
import '../models/diem_danh.dart'; // Import model DiemDanh (Đã được cập nhật có idLop)
import 'tuition_event_service.dart';
import 'firebase_sync_service.dart';
import 'student_signal_service.dart';

class DiemDanhService {
  // Sửa: Dùng hằng số từ DBHelper
  final String tenBangDD = DBHelper.tenBangDiemDanh;

  // Lấy instance database
  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  /// Thao tác Upsert an toàn không dùng ConflictAlgorithm.replace (giữ nguyên primary key và không làm xóa mất child table danh_gia_buoi_hoc)
  Future<int> safeUpsertDiemDanhTxn(
    DatabaseExecutor db,
    DiemDanh record,
  ) async {
    final data = record.toMap();

    if (record.id != null) {
      final updated = await db.update(
        tenBangDD,
        data,
        where: 'id = ?',
        whereArgs: [record.id],
      );
      if (updated > 0) return record.id!;
    }

    final existing = await db.query(
      tenBangDD,
      columns: ['id'],
      where: 'id_hoc_sinh = ? AND gio_diem_danh = ?',
      whereArgs: [record.idHocSinh, record.gioDiemDanh],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      record.id = existingId;
      data['id'] = existingId;
      await db.update(
        tenBangDD,
        data,
        where: 'id = ?',
        whereArgs: [existingId],
      );
      return existingId;
    } else {
      final insertedId = await db.insert(
        tenBangDD,
        data,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      record.id = insertedId;
      return insertedId;
    }
  }

  Future<int> themDiemDanh(DiemDanh diemDanh) async {
    final db = await _database;
    final res = await safeUpsertDiemDanhTxn(db, diemDanh);
    if (res > 0) {
      final key =
          '${diemDanh.idHocSinh}_${diemDanh.idLop}_${diemDanh.gioDiemDanh.replaceAll(' ', '_')}';
      FirebaseSyncService.instance.pushRecordToCloud(
        tenBangDD,
        key,
        diemDanh.toMap(),
      );
      TuitionEventService().notifyTuitionChanged();
      await StudentSignalService.instance.recomputeSignalsForStudent(
        diemDanh.idHocSinh,
      );
    }
    return res;
  }

  /// Hàm lưu hàng loạt các bản ghi điểm danh trong một giao dịch SQLite duy nhất (Atomic Transaction).
  /// Đảm bảo tất cả được lưu thành công 100% hoặc tự động hoàn tác (rollback) nếu có lỗi.
  Future<void> luuDanhSachDiemDanhAtomic(List<DiemDanh> records) async {
    if (records.isEmpty) return;
    final db = await _database;

    await db.transaction((txn) async {
      for (var record in records) {
        final res = await safeUpsertDiemDanhTxn(txn, record);
        if (res > 0) {
          final key =
              '${record.idHocSinh}_${record.idLop}_${record.gioDiemDanh.replaceAll(' ', '_')}';
          FirebaseSyncService.instance.pushRecordToCloud(
            tenBangDD,
            key,
            record.toMap(),
          );
        }
      }
    });

    TuitionEventService().notifyTuitionChanged();
    final studentIds = records.map((r) => r.idHocSinh).toSet();
    for (var id in studentIds) {
      await StudentSignalService.instance.recomputeSignalsForStudent(id);
    }
  }

  // ===================================================
  // HÀM MỚI: LẤY TẤT CẢ ĐIỂM DANH CỦA LỚP TRONG MỘT NGÀY
  // ===================================================
  /// Lấy tất cả các bản ghi điểm danh của một lớp trong một ngày cụ thể.
  /// Dùng để tải trước dữ liệu cho trang điểm danh.
  Future<List<DiemDanh>> layDiemDanhTheoLopVaNgay(
    int idLop,
    String ngay, // Dạng YYYY-MM-DD
  ) async {
    final db = await _database;

    // Tìm kiếm tất cả bản ghi trong ngày đó
    final String startDate = '$ngay 00:00:00';
    final String endDate = '$ngay 23:59:59';

    final List<Map<String, dynamic>> maps = await db.query(
      tenBangDD,
      where: 'id_lop = ? AND gio_diem_danh BETWEEN ? AND ?',
      whereArgs: [idLop, startDate, endDate],
      orderBy: 'gio_diem_danh ASC',
    );

    return List.generate(maps.length, (i) => DiemDanh.fromMap(maps[i]));
  }

  // ===================================================
  // HÀM MỚI: ĐIỂM DANH "CÓ MẶT" HÀNG LOẠT
  // ===================================================
  /// Dùng cho chức năng điểm danh bù.
  /// Thêm các bản ghi "Có mặt" cho tất cả học sinh của một lớp trong một ngày cụ thể.
  Future<void> diemDanhCoMatHangLoat(
    List<HSLopViewModel> danhSachHS,
    List<LichHoc> danhSachCaHoc,
    DateTime ngayDiemDanh,
  ) async {
    if (danhSachHS.isEmpty || danhSachCaHoc.isEmpty) return;

    final db = await _database;
    final batch = db.batch();
    final ngayStr = DateFormat('yyyy-MM-dd').format(ngayDiemDanh);

    for (var hs in danhSachHS) {
      for (var caHoc in danhSachCaHoc) {
        final diemDanhRecord = DiemDanh(
          idHocSinh: hs.id!,
          idLop: caHoc.idLop,
          gioDiemDanh: '$ngayStr ${caHoc.gioBatDau}',
          trangThai: 'Có mặt',
        );
        final data = diemDanhRecord.toMap();
        batch.insert(
          tenBangDD,
          data,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    await batch.commit(noResult: true);
    TuitionEventService().notifyTuitionChanged();
  }

  // 2. Lấy DiemDanh theo ID học sinh và tháng (READ - tổng quan)
  // Hàm này vẫn chỉ dùng idHocSinh và thang, trả về tất cả bản ghi
  Future<List<DiemDanh>> layDiemDanhTheoHocSinhVaThang(
    int idHocSinh,
    String thang,
  ) async {
    final db = await _database;

    final parts = thang.split('-');
    if (parts.length != 2) {
      throw Exception('Định dạng tháng không hợp lệ, ví dụ: YYYY-MM');
    }

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final lastDayOfMonth = DateTime(year, month + 1, 0);

    final startDate = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime(year, month, 1, 0, 0, 0));
    final endDate = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime(year, month, lastDayOfMonth.day, 23, 59, 59));

    final maps = await db.query(
      tenBangDD,
      where: 'id_hoc_sinh = ? AND gio_diem_danh BETWEEN ? AND ?',
      whereArgs: [idHocSinh, startDate, endDate],
      orderBy: 'gio_diem_danh ASC',
    );

    return List.generate(maps.length, (i) => DiemDanh.fromMap(maps[i]));
  }

  // ===================================================
  // HÀM MỚI: ĐẾM SỐ BUỔI THEO TRẠNG THÁI TRONG THÁNG (CẬP NHẬT: THÊM idLop)
  // ===================================================
  /// Đếm số ca học theo trạng thái cho một học sinh VÀ một lớp cụ thể trong tháng.
  Future<Map<String, int>> demSoBuoiTheoTrangThai(
    int idHocSinh,
    int idLop,
    String thang,
  ) async {
    final db = await _database;

    final parts = thang.split('-');
    if (parts.length != 2) {
      throw Exception('Định dạng tháng không hợp lệ, ví dụ: YYYY-MM');
    }

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final lastDayOfMonth = DateTime(year, month + 1, 0);

    final startDate = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime(year, month, 1, 0, 0, 0));
    final endDate = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(DateTime(year, month, lastDayOfMonth.day, 23, 59, 59));

    // SQL Query: Group theo trạng thái và đếm (THÊM id_lop)
    final sql =
        '''
      SELECT 
          trang_thai, 
          COUNT(id) as so_buoi
      FROM $tenBangDD
      WHERE 
          id_hoc_sinh = ? 
          AND id_lop = ? -- <<< THÊM ID LỚP
          AND gio_diem_danh BETWEEN ? AND ? 
      GROUP BY trang_thai
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      sql,
      [idHocSinh, idLop, startDate, endDate], // <<< THÊM idLop
    );

    const Map<String, String> dbToInternalMap = {
      'Có mặt': 'coMat',
      'Nghỉ có phép': 'nghiCoPhep',
      'Nghỉ không phép': 'nghiKhongPhep',
      'Học bù': 'hocBu',
    };

    final Map<String, int> counts = {
      'coMat': 0,
      'nghiCoPhep': 0,
      'nghiKhongPhep': 0,
      'hocBu': 0,
    };

    for (var map in maps) {
      final dbStatus = map['trang_thai'] as String;
      final count = map['so_buoi'] as int;

      if (dbToInternalMap.containsKey(dbStatus)) {
        final internalKey = dbToInternalMap[dbStatus]!;
        if (counts.containsKey(internalKey)) {
          counts[internalKey] = count;
        }
      }
    }

    return counts;
  }

  // ===================================================
  // HÀM MỚI: KIỂM TRA HỌC SINH VẮNG LIÊN TIẾP
  // ===================================================
  /// Kiểm tra xem một học sinh có vắng 'Không phép' quá `limit` buổi liên tiếp hay không.
  Future<bool> kiemTraVangLienTiep(
    int idHocSinh,
    int idLop, {
    int limit = 3,
  }) async {
    final db = await _database;

    // 1. Chỉ lấy `limit` bản ghi điểm danh gần nhất của học sinh trong lớp đó
    final List<Map<String, dynamic>> maps = await db.query(
      tenBangDD,
      where: 'id_hoc_sinh = ? AND id_lop = ?',
      whereArgs: [idHocSinh, idLop],
      orderBy: 'gio_diem_danh DESC',
      limit: limit,
    );

    if (maps.length < limit) {
      return false; // Không đủ dữ liệu để kiểm tra
    }

    // 2. Kiểm tra nếu tất cả `limit` bản ghi gần nhất đều là 'Nghỉ không phép'
    for (var i = 0; i < maps.length; i++) {
      final record = DiemDanh.fromMap(maps[i]);
      if (record.trangThai != 'Nghỉ không phép') {
        return false;
      }
    }
    return true;
  }

  // HÀM MỚI: Tối ưu hóa, kiểm tra vắng liên tiếp cho nhiều học sinh cùng lúc
  Future<Set<int>> kiemTraVangLienTiepChoNhieuHS(
    List<int> dsIdHocSinh,
    int idLop, {
    int limit = 3,
  }) async {
    if (dsIdHocSinh.isEmpty) return {};

    final db = await _database;
    final Set<int> studentsWithWarnings = {};

    // 1. Lấy `limit` bản ghi điểm danh gần nhất của TẤT CẢ học sinh trong danh sách
    final String placeholders = List.filled(dsIdHocSinh.length, '?').join(',');
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT * FROM (
        SELECT *, ROW_NUMBER() OVER(PARTITION BY id_hoc_sinh ORDER BY gio_diem_danh DESC) as rn
        FROM $tenBangDD
        WHERE id_hoc_sinh IN ($placeholders) AND id_lop = ?
      )
      WHERE rn <= ?
    ''',
      [...dsIdHocSinh, idLop, limit],
    );

    // 2. Group các bản ghi theo id_hoc_sinh
    final recordsByStudent = <int, List<DiemDanh>>{};
    for (var map in maps) {
      final record = DiemDanh.fromMap(map);
      recordsByStudent.putIfAbsent(record.idHocSinh, () => []).add(record);
    }

    // 3. Kiểm tra từng học sinh
    for (var hsId in dsIdHocSinh) {
      final records = recordsByStudent[hsId] ?? [];
      if (records.length >= limit &&
          records.every((r) => r.trangThai == 'Nghỉ không phép')) {
        studentsWithWarnings.add(hsId);
      }
    }
    return studentsWithWarnings;
  }

  // 3. Lấy tất cả DiemDanh (READ - tất cả)
  Future<List<DiemDanh>> layTatCaDiemDanh() async {
    final db = await _database;
    final maps = await db.query(tenBangDD, orderBy: 'gio_diem_danh ASC');
    return List.generate(maps.length, (i) => DiemDanh.fromMap(maps[i]));
  }

  // 4. Lấy DiemDanh theo ID (READ - một bản ghi)
  Future<DiemDanh?> layDiemDanhTheoID(int id) async {
    final db = await _database;
    final maps = await db.query(tenBangDD, where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return DiemDanh.fromMap(maps.first);
    }
    return null;
  }

  // ===================================================
  // HÀM CỐT LÕI: LẤY TRẠNG THÁI ĐIỂM DANH THEO CA HỌC (THÊM idLop)
  // ===================================================
  /// Lấy trạng thái điểm danh của một HS cho một Ca Học (Lớp + Ngày + Giờ).
  Future<DiemDanh?> layTrangThaiDiemDanhTheoCa(
    int idHocSinh,
    int idLop, // <<< Bắt buộc phải có
    String ngay, // Dạng YYYY-MM-DD
    String gioBatDauCa, // Dạng HH:mm:ss của ca học
  ) async {
    final db = await _database;

    final caHocStart = DateTime.parse('$ngay $gioBatDauCa');
    // Tìm kiếm trong khoảng +/- 15 phút so với giờ bắt đầu ca học
    final searchStartTime = caHocStart.subtract(const Duration(minutes: 15));
    final searchEndTime = caHocStart.add(const Duration(minutes: 15));
    final startStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(searchStartTime);
    final endStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(searchEndTime);

    final List<Map<String, dynamic>> maps = await db.query(
      tenBangDD,
      // Truy vấn BẮT BUỘC phải có id_lop
      where: 'id_hoc_sinh = ? AND id_lop = ? AND gio_diem_danh BETWEEN ? AND ?',
      whereArgs: [idHocSinh, idLop, startStr, endStr],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return DiemDanh.fromMap(maps.first);
    }

    return null;
  }

  // ===================================================
  // HÀM CẬP NHẬT/THAY THẾ/XÓA (LOGIC SỬ DỤNG TRÊN UI)
  // ===================================================
  /// Thêm, thay thế, hoặc xóa bản ghi điểm danh cho một ca học cụ thể.
  Future<int> capNhatDiemDanh(DiemDanh diemDanh) async {
    final db = await _database;

    // Nếu trạng thái là 'Chưa điểm danh' -> THỰC HIỆN XÓA BẢN GHI CŨ TRỰC TIẾP
    if (diemDanh.trangThai == 'Chưa điểm danh') {
      final DateTime ddTime = DateTime.parse(diemDanh.gioDiemDanh);
      final searchStartTime = ddTime.subtract(const Duration(minutes: 15));
      final searchEndTime = ddTime.add(const Duration(minutes: 15));
      final startStr = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(searchStartTime);
      final endStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(searchEndTime);

      final List<Map<String, dynamic>> recordsToDelete = await db.query(
        tenBangDD,
        columns: ['id', 'id_hoc_sinh', 'id_lop', 'gio_diem_danh'],
        where:
            'id_hoc_sinh = ? AND id_lop = ? AND gio_diem_danh BETWEEN ? AND ?',
        whereArgs: [diemDanh.idHocSinh, diemDanh.idLop, startStr, endStr],
      );

      final deletedRows = await db.delete(
        tenBangDD,
        where:
            'id_hoc_sinh = ? AND id_lop = ? AND gio_diem_danh BETWEEN ? AND ?',
        whereArgs: [diemDanh.idHocSinh, diemDanh.idLop, startStr, endStr],
      );

      if (deletedRows > 0) {
        for (var map in recordsToDelete) {
          final idVal = map['id'];
          final key = (idVal != null && idVal.toString().isNotEmpty)
              ? idVal.toString()
              : '${diemDanh.idHocSinh}_${diemDanh.idLop}_${map['gio_diem_danh'].toString().replaceAll(' ', '_')}';
          FirebaseSyncService.instance.deleteRecordFromCloud(tenBangDD, key);
        }
        TuitionEventService().notifyTuitionChanged();
      }
      return deletedRows;
    }

    // Nếu là 'Có mặt'/'Nghỉ có phép'/'Nghỉ không phép' -> THỰC HIỆN INSERT/REPLACE
    return await themDiemDanh(diemDanh);
  }

  Future<int> xoaDiemDanh(int id) async {
    final db = await _database;
    final maps = await db.query(tenBangDD, where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final dd = DiemDanh.fromMap(maps.first);
      final key = dd.id != null
          ? dd.id.toString()
          : '${dd.idHocSinh}_${dd.idLop}_${dd.gioDiemDanh.replaceAll(' ', '_')}';
      FirebaseSyncService.instance.deleteRecordFromCloud(tenBangDD, key);
    }
    final res = await db.delete(tenBangDD, where: 'id = ?', whereArgs: [id]);
    if (res > 0) {
      TuitionEventService().notifyTuitionChanged();
    }
    return res;
  }

  Future<int> demSoBuoiTheoThang(
    int idHocSinh,
    int idLop,
    String thang,
    String trangThai, {
    DateTime? ngayBatDauTinh,
  }) async {
    final db = await _database;

    final parts = thang.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final startDateStr = '$thang-01 00:00:00';

    final lastDay = DateTime(year, month + 1, 0);
    final endDateStr =
        '${DateFormat('yyyy-MM').format(lastDay)}-${lastDay.day.toString().padLeft(2, '0')} 23:59:59';

    String query =
        '''
      SELECT COUNT(*) AS soBuoi
      FROM $tenBangDD
      WHERE id_hoc_sinh = ?
        AND id_lop = ?
        AND trang_thai = ?
        AND gio_diem_danh BETWEEN ? AND ?
    ''';

    List<dynamic> args = [
      idHocSinh,
      idLop,
      trangThai,
      startDateStr,
      endDateStr,
    ];

    if (ngayBatDauTinh != null) {
      final startDateFilter = DateFormat(
        'yyyy-MM-dd 00:00:00',
      ).format(ngayBatDauTinh);
      query += ' AND gio_diem_danh >= ?';
      args.add(startDateFilter);
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

    if (maps.isNotEmpty && maps.first['soBuoi'] != null) {
      return maps.first['soBuoi'] as int;
    }
    return 0;
  }

  // 7. Xóa DiemDanh theo ID học sinh (DELETE - tùy chọn)
  Future<int> xoaDiemDanhTheoHocSinh(int idHocSinh) async {
    final db = await _database;
    final maps = await db.query(
      tenBangDD,
      where: 'id_hoc_sinh = ?',
      whereArgs: [idHocSinh],
    );
    for (var map in maps) {
      final dd = DiemDanh.fromMap(map);
      final key = dd.id != null
          ? dd.id.toString()
          : '${dd.idHocSinh}_${dd.idLop}_${dd.gioDiemDanh.replaceAll(' ', '_')}';
      FirebaseSyncService.instance.deleteRecordFromCloud(tenBangDD, key);
    }
    final res = await db.delete(
      tenBangDD,
      where: 'id_hoc_sinh = ?',
      whereArgs: [idHocSinh],
    );
    if (res > 0) {
      TuitionEventService().notifyTuitionChanged();
    }
    return res;
  }

  /// Lấy tổng số buổi học theo từng trạng thái cho toàn bộ lớp trong một tháng (Single SQL Query batch)
  Future<Map<String, int>> demTongSoBuoiCuaLopTheoThang(
    int idLop,
    String thang,
  ) async {
    final db = await _database;
    final parts = thang.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final startDateStr = '$thang-01 00:00:00';

    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endDateStr =
        '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01 00:00:00';

    final List<Map<String, dynamic>> rows = await db.rawQuery(
      '''
      SELECT trang_thai, COUNT(*) as cnt
      FROM $tenBangDD
      WHERE id_lop = ? AND gio_diem_danh >= ? AND gio_diem_danh < ?
      GROUP BY trang_thai
      ''',
      [idLop, startDateStr, endDateStr],
    );

    final result = <String, int>{};
    for (var r in rows) {
      final st = r['trang_thai'] as String?;
      if (st != null) {
        result[st] = (r['cnt'] as num).toInt();
      }
    }
    return result;
  }

  // ===================================================
  // LẤY BÁO CÁO ĐIỂM DANH THÁNG CỦA HỌC SINH TRONG LỚP
  // ===================================================
  Future<Map<String, dynamic>> layBaoCaoDiemDanhThang({
    required int idHocSinh,
    required int idLop,
    required String thang, // YYYY-MM
  }) async {
    final db = await _database;

    final parts = thang.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month =
        int.tryParse(parts.length > 1 ? parts[1] : '1') ?? DateTime.now().month;

    final startDateStr =
        '$year-${month.toString().padLeft(2, '0')}-01 00:00:00';
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endDateStr =
        '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01 00:00:00';

    final results = await db.rawQuery(
      '''
      SELECT trang_thai, gio_diem_danh, ghi_chu
      FROM $tenBangDD
      WHERE id_hoc_sinh = ? AND id_lop = ? AND gio_diem_danh >= ? AND gio_diem_danh < ?
      ORDER BY gio_diem_danh DESC
    ''',
      [idHocSinh, idLop, startDateStr, endDateStr],
    );

    List<Map<String, dynamic>> listCoMat = [];
    List<Map<String, dynamic>> listTre = [];
    List<Map<String, dynamic>> listNghiCoPhep = [];
    List<Map<String, dynamic>> listNghiKhongPhep = [];
    List<Map<String, dynamic>> listHocBu = [];

    for (var row in results) {
      final trangThai = (row['trang_thai'] as String?)?.trim() ?? '';
      if (trangThai == 'Có mặt') {
        listCoMat.add(row);
      } else if (trangThai == 'Trễ') {
        listTre.add(row);
        listCoMat.add(row); // Phương án A: Trễ vẫn đếm vào Có mặt (đi học)
      } else if (trangThai == 'Nghỉ có phép') {
        listNghiCoPhep.add(row);
      } else if (trangThai == 'Nghỉ không phép') {
        listNghiKhongPhep.add(row);
      } else if (trangThai == 'Học bù') {
        listHocBu.add(row);
      } else {
        // Mặc định tính là có mặt đối với dữ liệu legacy chưa nhận diện
        listCoMat.add(row);
      }
    }

    return {
      'coMat': listCoMat.length,
      'tre': listTre.length,
      'nghiCoPhep': listNghiCoPhep.length,
      'nghiKhongPhep': listNghiKhongPhep.length,
      'hocBu': listHocBu.length,
      'tongSoBuoi': results.length,
      'listCoMat': listCoMat,
      'listTre': listTre,
      'listNghiCoPhep': listNghiCoPhep,
      'listNghiKhongPhep': listNghiKhongPhep,
      'listHocBu': listHocBu,
    };
  }
}
