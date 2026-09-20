// File: lib/utils/schedule_helpers.dart

import 'package:sqflite/sqflite.dart';
import 'dart:developer' as developer;

/// Chuyển đổi chuỗi thời gian "HH:mm" hoặc "HH:mm:ss" thành tổng số phút trong ngày (0..1439).
///
/// Trả về `null` nếu định dạng không hợp lệ hoặc ngoài dải cho phép (hour 0..23, minute 0..59).
/// Trả về `0` nếu là "00:00".
int? chuyenGioSangPhut(String time) {
  final trimmed = time.trim();
  if (trimmed.isEmpty) return null;

  try {
    final parts = trimmed.split(':');
    if (parts.length < 2) return null;

    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);

    if (hours == null || minutes == null) return null;
    if (hours < 0 || hours > 23) return null;
    if (minutes < 0 || minutes > 59) return null;

    return hours * 60 + minutes;
  } catch (e) {
    developer.log(
      '❌ Lỗi khi chuyển đổi giờ: $time',
      name: 'chuyenGioSangPhut',
      error: e,
    );
    return null;
  }
}

/// Kiểm tra khung thời gian có hợp lệ không (cả hai thời gian đều hợp lệ và start < end).
bool validateTimeRange(String start, String end) {
  final startPhut = chuyenGioSangPhut(start);
  final endPhut = chuyenGioSangPhut(end);
  if (startPhut == null || endPhut == null) return false;
  return startPhut < endPhut;
}

/// Chuẩn hóa định dạng chuỗi giờ thành "HH:mm" (ví dụ: "19:30:00" -> "19:30", "9:5" -> "09:05").
String normalizeTime(String time) {
  final trimmed = time.trim();
  final parts = trimmed.split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
      final hStr = h.toString().padLeft(2, '0');
      final mStr = m.toString().padLeft(2, '0');
      return '$hStr:$mStr';
    }
  }
  return trimmed;
}

/// Kiểm tra xem một khung thời gian mới có bị chồng lấn với các lịch đã có trong cùng một lớp và ngày không.
///
/// Trả về `true` nếu bị chồng lấn hoặc dữ liệu/thời gian không hợp lệ (fail-closed).
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
    final batDauMoiPhut = chuyenGioSangPhut(gioBatDauMoi);
    final ketThucMoiPhut = chuyenGioSangPhut(gioKetThucMoi);

    // Validate khung thời gian mới (phải hợp lệ và start < end)
    if (batDauMoiPhut == null ||
        ketThucMoiPhut == null ||
        batDauMoiPhut >= ketThucMoiPhut) {
      developer.log(
        '⚠️ Khung thời gian mới không hợp lệ: $gioBatDauMoi - $gioKetThucMoi',
        name: 'kiemTraChongLanLichHoc',
      );
      return true; // Fail-closed: coi như conflict/reject
    }

    String whereClause = 'id_lop = ? AND $cotNgay = ?';
    List<dynamic> whereArgs = [idLop, giaTriNgay];

    if (excludeId != null) {
      whereClause += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final columns = tenBang == 'lich_hoc_chung'
        ? const ['id', 'gio_bat_dau', 'gio_ket_thuc']
        : const ['id', 'gioBatDau', 'gioKetThuc'];

    final existingSchedules = await db.query(
      tenBang,
      columns: columns,
      where: whereClause,
      whereArgs: whereArgs,
    );

    for (var schedule in existingSchedules) {
      final rawBatDau =
          schedule['gio_bat_dau'] as String? ??
          schedule['gioBatDau'] as String? ??
          '';
      final rawKetThuc =
          schedule['gio_ket_thuc'] as String? ??
          schedule['gioKetThuc'] as String? ??
          '';

      final batDauCuPhut = chuyenGioSangPhut(rawBatDau);
      final ketThucCuPhut = chuyenGioSangPhut(rawKetThuc);

      if (batDauCuPhut == null ||
          ketThucCuPhut == null ||
          batDauCuPhut >= ketThucCuPhut) {
        developer.log(
          '⚠️ Lịch cũ trong DB không hợp lệ: $rawBatDau - $rawKetThuc',
          name: 'kiemTraChongLanLichHoc',
        );
        return true; // Fail-closed
      }

      // Quy tắc chồng lấn: (startA < endB) && (endA > startB)
      if (batDauMoiPhut < ketThucCuPhut && ketThucMoiPhut > batDauCuPhut) {
        developer.log(
          '⚠️ Phát hiện chồng lấn lịch học',
          name: 'kiemTraChongLanLichHoc',
          error: {
            'lịch mới': '$gioBatDauMoi - $gioKetThucMoi',
            'lịch cũ': '$rawBatDau - $rawKetThuc',
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
    return true; // Fail-closed: Mặc định là có chồng lấn
  }
}

/// Chuyển đổi ngày (DateTime) thành giá trị thứ trong Database (`thuTrongTuan`):
/// 1 = Chủ Nhật, 2 = Thứ Hai, 3 = Thứ Ba, 4 = Thứ Tư, 5 = Thứ Năm, 6 = Thứ Sáu, 7 = Thứ Bảy.
int databaseWeekdayFromDate(DateTime date) {
  return (date.weekday == 7) ? 1 : date.weekday + 1;
}

