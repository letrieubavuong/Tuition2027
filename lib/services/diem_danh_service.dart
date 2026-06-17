// File: lib/services/diem_danh_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc.dart';
import '../utils/db.dart'; // Đảm bảo import DBHelper
import '../models/diem_danh.dart'; // Import model DiemDanh (Đã được cập nhật có idLop)

class DiemDanhService {
  // Sửa: Dùng hằng số từ DBHelper
  final String tenBangDD = DBHelper.tenBangDiemDanh;

  // Lấy instance database
  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  Future<int> themDiemDanh(DiemDanh diemDanh) async {
    final db = await _database;
    // Model DiemDanh hiện tại đã có idLop, hàm toMap() sẽ bao gồm nó.
    // ConflictAlgorithm.replace sẽ dùng ràng buộc UNIQUE(id_hoc_sinh, id_lop, gio_diem_danh)
    return await db.insert(
      tenBangDD,
      diemDanh.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
        // Dùng insert với ignore để nếu có bản ghi rồi thì bỏ qua
        batch.insert(
          tenBangDD,
          diemDanhRecord.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }

    await batch.commit(noResult: true);
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
    };

    final Map<String, int> counts = {
      'coMat': 0,
      'nghiCoPhep': 0,
      'nghiKhongPhep': 0,
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

    // 1. Lấy tất cả bản ghi điểm danh của học sinh trong lớp đó, sắp xếp mới nhất trước
    final List<Map<String, dynamic>> maps = await db.query(
      tenBangDD,
      where: 'id_hoc_sinh = ? AND id_lop = ?',
      whereArgs: [idHocSinh, idLop],
      orderBy: 'gio_diem_danh DESC',
    );

    if (maps.length < limit) {
      return false; // Không đủ dữ liệu để kiểm tra
    }

    int consecutiveAbsences = 0;

    // 2. Duyệt qua các bản ghi gần nhất
    for (var i = 0; i < maps.length; i++) {
      final record = DiemDanh.fromMap(maps[i]);
      if (record.trangThai == 'Nghỉ không phép') {
        consecutiveAbsences++;
        if (consecutiveAbsences >= limit) {
          return true; // Đã đạt đến giới hạn, trả về true ngay lập tức
        }
      } else {
        // Chuỗi vắng liên tiếp bị ngắt, không cần kiểm tra thêm
        return false;
      }
    }
    return false;
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
    final startStr = searchStartTime.toIso8601String();
    final endStr = searchEndTime.toIso8601String();

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

    // Nếu trạng thái là 'Chưa điểm danh' -> THỰC HIỆN XÓA BẢN GHI CŨ
    if (diemDanh.trangThai == 'Chưa điểm danh') {
      final DateTime ddTime = DateTime.parse(diemDanh.gioDiemDanh);
      final String ngay = DateFormat('yyyy-MM-dd').format(ddTime);
      final String gioBatDauCa = DateFormat('HH:mm:ss').format(ddTime);

      // Tìm bản ghi cũ dựa trên 3 khóa: HS, Lớp, Ca học
      final DiemDanh? oldRecord = await layTrangThaiDiemDanhTheoCa(
        diemDanh.idHocSinh,
        diemDanh.idLop, // <<< Dùng idLop
        ngay,
        gioBatDauCa,
      );

      if (oldRecord != null && oldRecord.id != null) {
        // Nếu tìm thấy, xóa bản ghi đó
        return await db.delete(
          tenBangDD,
          where: 'id = ?',
          whereArgs: [oldRecord.id],
        );
      }
      return 0; // Không có bản ghi nào để xóa
    }

    // Nếu là 'Có mặt'/'Nghỉ có phép'/'Nghỉ không phép' -> THỰC HIỆN INSERT/REPLACE
    // Hàm themDiemDanh sẽ tự động REPLACE nhờ ràng buộc UNIQUE trên DB.
    return await themDiemDanh(diemDanh);
  }

  Future<int> xoaDiemDanh(int id) async {
    final db = await _database;
    return await db.delete(tenBangDD, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> demSoBuoiTheoThang(
    int idHocSinh,
    int idLop,
    String thang,
    String trangThai, {
    DateTime? ngayBatDauTinh, // Tham số tùy chọn
  }) async {
    final db = await _database;

    // Chuẩn bị chuỗi ngày để truy vấn (tháng này và đầu tháng sau)
    final parts = thang.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final startDateStr = '$thang-01 00:00:00';
    
    // Tính ngày cuối cùng của tháng (DateTime(year, month + 1, 0) trả về ngày cuối tháng trước đó nếu dùng month + 1)
    final lastDay = DateTime(year, month + 1, 0);
    final endDateStr = '${DateFormat('yyyy-MM').format(lastDay)}-${lastDay.day.toString().padLeft(2, '0')} 23:59:59';

    String query =
        '''
      SELECT COUNT(*) AS soBuoi
      FROM $tenBangDD
      WHERE id_hoc_sinh = ?
        AND id_lop = ?
        AND trang_thai = ?
        AND gio_diem_danh BETWEEN ? AND ?
    ''';

    List<dynamic> args = [idHocSinh, idLop, trangThai, startDateStr, endDateStr];

    // Thêm điều kiện lọc theo ngày bắt đầu tính nếu có
    if (ngayBatDauTinh != null) {
      query += ' AND gio_diem_danh >= ?';
      args.add(ngayBatDauTinh.toIso8601String());
    }

    // SỬA: Dùng COUNT(*) để đếm đúng số buổi, không phải số ngày.
    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

    if (maps.isNotEmpty && maps.first['soBuoi'] != null) {
      return maps.first['soBuoi'] as int;
    }
    return 0;
  }

  // 7. Xóa DiemDanh theo ID học sinh (DELETE - tùy chọn)
  Future<int> xoaDiemDanhTheoHocSinh(int idHocSinh) async {
    final db = await _database;
    return await db.delete(
      tenBangDD,
      where: 'id_hoc_sinh = ?',
      whereArgs: [idHocSinh],
    );
  }
}
