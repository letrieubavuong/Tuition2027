// File: lib/utils/schedule_helpers.dart

import 'package:sqflite/sqflite.dart';
import 'dart:developer' as developer;

/// Chuyển đổi chuỗi thời gian "HH:mm" hoặc "HH:mm:ss" thành tổng số phút trong ngày.
///
/// Trả về 0 nếu định dạng không hợp lệ.
int chuyenGioSangPhut(String time) {
  try {
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return hours * 60 + minutes;
  } catch (e) {
    developer.log(
      '❌ Lỗi khi chuyển đổi giờ: $time',
      name: 'chuyenGioSangPhut',
      error: e,
    );
    return 0;
  }
}

/// Kiểm tra xem một khung thời gian mới có bị chồng lấn với các lịch đã có trong cùng một lớp và ngày không.
///
/// Hàm này đủ linh hoạt để làm việc với cả `lich_hoc` (dùng `thuTrongTuan` kiểu int)
/// và `lich_hoc_chung` (dùng `ngay_trong_tuan` kiểu String).
///
/// [db]: Đối tượng Database.
/// [tenBang]: Tên bảng cần kiểm tra ('lich_hoc' hoặc 'lich_hoc_chung').
/// [idLop]: ID của lớp học.
/// [cotNgay]: Tên cột chứa ngày trong tuần ('thuTrongTuan' hoặc 'ngay_trong_tuan').
/// [giaTriNgay]: Giá trị của ngày trong tuần (int hoặc String).
/// [gioBatDauMoi]: Giờ bắt đầu của lịch mới.
/// [gioKetThucMoi]: Giờ kết thúc của lịch mới.
/// [excludeId]: (Tùy chọn) ID của lịch học cần loại trừ khỏi việc kiểm tra (dùng khi cập nhật).
Future<bool> kiemTraChongLanLichHoc({
  required Database db,
  required String tenBang,
  required int idLop,
  required String cotNgay,
  required dynamic giaTriNgay,
  required String gioBatDauMoi,
  required String gioKetThucMoi,
  int? excludeId,
}) async {
  try {
    String whereClause = 'id_lop = ? AND $cotNgay = ?';
    List<dynamic> whereArgs = [idLop, giaTriNgay];

    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final existingSchedules = await db.query(
      tenBang,
      where: whereClause,
      whereArgs: whereArgs,
    );

    final batDauMoiPhut = chuyenGioSangPhut(gioBatDauMoi);
    final ketThucMoiPhut = chuyenGioSangPhut(gioKetThucMoi);

    for (var schedule in existingSchedules) {
      final batDauCuPhut = chuyenGioSangPhut(
        schedule['gio_bat_dau'] as String? ??
            schedule['gioBatDau'] as String? ??
            '',
      );
      final ketThucCuPhut = chuyenGioSangPhut(
        schedule['gio_ket_thuc'] as String? ??
            schedule['gioKetThuc'] as String? ??
            '',
      );

      // Điều kiện chồng lấn: (StartA < EndB) and (EndA > StartB)
      if (batDauMoiPhut < ketThucCuPhut && ketThucMoiPhut > batDauCuPhut) {
        developer.log(
          '⚠️ Phát hiện chồng lấn lịch học',
          name: 'kiemTraChongLanLichHoc',
          error: {
            'lịch mới': '$gioBatDauMoi - $gioKetThucMoi',
            'lịch cũ':
                '${schedule['gio_bat_dau'] ?? schedule['gioBatDau']} - ${schedule['gio_ket_thuc'] ?? schedule['gioKetThuc']}',
          },
        );
        return true; // Bị chồng lấn
      }
    }
    return false; // Không chồng lấn
  } catch (e, st) {
    developer.log(
      '❌ Lỗi khi kiểm tra chồng lấn',
      name: 'kiemTraChongLanLichHoc',
      error: e,
      stackTrace: st,
    );
    return true; // Mặc định là có chồng lấn để tránh lỗi dữ liệu
  }
}
