// File: lib/services/thong_ke_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import 'dart:developer' as developer;
import '../utils/attendance_calculator.dart';
import '../utils/student_status.dart';

/// Model chứa dữ liệu cho biểu đồ học sinh
class HocSinhThang {
  final String thang; // YYYY-MM
  final int soLuong;

  HocSinhThang({required this.thang, required this.soLuong});
}

/// Model chứa dữ liệu cho biểu đồ học phí
class HocPhiThang {
  final String thang; // YYYY-MM
  final int tongThu;
  final int tongNo;

  HocPhiThang({
    required this.thang,
    required this.tongThu,
    required this.tongNo,
  });
}

class ThongKeService {
  final dbHelper = DBHelper.instance;
  Future<Database> get _database async {
    return await dbHelper.database;
  }

  /// Lấy danh sách 12 tháng gần nhất, tính từ tháng hiện tại
  List<String> _get12ThangGanNhat() {
    final now = DateTime.now();
    return List.generate(12, (index) {
      final date = DateTime(now.year, now.month - index, 1);
      return DateFormat('yyyy-MM').format(date);
    }).reversed.toList();
  }

  /// Lấy dữ liệu số lượng học sinh đang học/hoạt động thực tế trong 12 tháng gần nhất.
  /// Tính dựa trên danh sách đăng ký lớp (lop_hoc_sinh) và mốc thời gian tham gia/nghỉ/tạm ngưng.
  Future<List<HocSinhThang>> getSoLuongHSHoatDong12Thang() async {
    try {
      final db = await _database;
      final thangList = _get12ThangGanNhat();
      if (thangList.isEmpty) return [];

      final query =
          '''
        SELECT 
          LHS.id_hoc_sinh,
          LHS.ngay_tham_gia,
          LHS.trang_thai,
          LHS.ngay_tam_ngung,
          LHS.ngay_du_kien_hoc_lai,
          LHS.ngay_hoc_lai_thuc_te,
          LHS.ngay_nghi_hoc,
          LHS.ngay_hoc_lai_sau_nghi
        FROM ${DBHelper.tenBangLopHS} LHS
        INNER JOIN ${DBHelper.tenBangHS} HS ON (LHS.id_hoc_sinh = HS.id OR CAST(LHS.id_hoc_sinh AS TEXT) = CAST(HS.id AS TEXT))
      ''';

      final List<Map<String, dynamic>> rows = await db.rawQuery(query);

      final List<HocSinhThang> results = thangList.map((thang) {
        final parts = thang.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final startOfMonth = DateTime(year, month, 1);
        final midOfMonth = DateTime(year, month, 15);
        final endOfMonth = DateTime(year, month + 1, 0);

        final Set<int> activeHsIds = {};

        for (final r in rows) {
          final hsId = (r['id_hoc_sinh'] is num)
              ? (r['id_hoc_sinh'] as num).toInt()
              : int.tryParse(r['id_hoc_sinh']?.toString() ?? '');
          if (hsId == null) continue;

          final status = StudentStatus.parse(r['trang_thai']);
          final ngayThamGia = AttendanceCalculator.parseDateSafely(
            r['ngay_tham_gia'],
          );
          final ngayTamNgung = AttendanceCalculator.parseDateSafely(
            r['ngay_tam_ngung'],
          );
          final ngayHocLai = AttendanceCalculator.parseDateSafely(
            r['ngay_hoc_lai_thuc_te'] ?? r['ngay_du_kien_hoc_lai'],
          );
          final ngayNghiHoc = AttendanceCalculator.parseDateSafely(
            r['ngay_nghi_hoc'],
          );
          final ngayHocLaiSauNghi = AttendanceCalculator.parseDateSafely(
            r['ngay_hoc_lai_sau_nghi'],
          );

          if (status.isStopped &&
              ngayNghiHoc == null &&
              ngayHocLaiSauNghi == null) {
            continue;
          }
          if (status.isPaused && ngayTamNgung == null && ngayHocLai == null) {
            continue;
          }

          final isActive =
              AttendanceCalculator.isDateInParticipationWindow(
                date: startOfMonth,
                ngayThamGia: ngayThamGia,
                ngayTamNgung: ngayTamNgung,
                ngayHocLai: ngayHocLai,
                ngayNghiHoc: ngayNghiHoc,
                ngayHocLaiSauNghi: ngayHocLaiSauNghi,
              ) ||
              AttendanceCalculator.isDateInParticipationWindow(
                date: midOfMonth,
                ngayThamGia: ngayThamGia,
                ngayTamNgung: ngayTamNgung,
                ngayHocLai: ngayHocLai,
                ngayNghiHoc: ngayNghiHoc,
                ngayHocLaiSauNghi: ngayHocLaiSauNghi,
              ) ||
              AttendanceCalculator.isDateInParticipationWindow(
                date: endOfMonth,
                ngayThamGia: ngayThamGia,
                ngayTamNgung: ngayTamNgung,
                ngayHocLai: ngayHocLai,
                ngayNghiHoc: ngayNghiHoc,
                ngayHocLaiSauNghi: ngayHocLaiSauNghi,
              );

          if (isActive) {
            activeHsIds.add(hsId);
          }
        }

        return HocSinhThang(thang: thang, soLuong: activeHsIds.length);
      }).toList();

      developer.log(
        '✅ Lấy dữ liệu HS hoạt động 12 tháng thành công (Single Batch Query + Participation Window).',
        name: 'ThongKeService',
      );
      return results;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi khi lấy dữ liệu HS hoạt động 12 tháng',
        name: 'ThongKeService',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Lấy dữ liệu số lượng học sinh có phát sinh điểm danh trong 12 tháng gần nhất (thống kê mặt chuyên cần).
  Future<List<HocSinhThang>> getSoLuongHSDiemDanh12Thang() async {
    try {
      final db = await _database;
      final thangList = _get12ThangGanNhat();
      if (thangList.isEmpty) return [];

      final minThangStr = '${thangList.first}-01 00:00:00';
      final lastThangParts = thangList.last.split('-');
      final nextMonthDate = DateTime(
        int.parse(lastThangParts[0]),
        int.parse(lastThangParts[1]) + 1,
        1,
      );
      final maxThangStr =
          '${DateFormat('yyyy-MM-dd').format(nextMonthDate)} 00:00:00';

      final query =
          '''
        SELECT 
          SUBSTR(gio_diem_danh, 1, 7) as thang,
          COUNT(DISTINCT id_hoc_sinh) as so_luong
        FROM ${DBHelper.tenBangDiemDanh}
        WHERE gio_diem_danh >= ? AND gio_diem_danh < ?
        GROUP BY SUBSTR(gio_diem_danh, 1, 7)
      ''';

      final List<Map<String, dynamic>> rows = await db.rawQuery(query, [
        minThangStr,
        maxThangStr,
      ]);
      final Map<String, int> thangCountMap = {
        for (var r in rows)
          if (r['thang'] != null)
            r['thang'].toString(): (r['so_luong'] as num).toInt(),
      };

      final List<HocSinhThang> results = thangList.map((thang) {
        return HocSinhThang(thang: thang, soLuong: thangCountMap[thang] ?? 0);
      }).toList();

      return results;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi khi lấy dữ liệu HS điểm danh 12 tháng',
        name: 'ThongKeService',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Lấy dữ liệu tổng thu và tổng nợ học phí trong 12 tháng gần nhất (1 SQL Query duy nhất).
  Future<List<HocPhiThang>> getHocPhi12Thang() async {
    try {
      final db = await _database;
      final thangList = _get12ThangGanNhat();
      if (thangList.isEmpty) return [];

      final placeholders = List.filled(thangList.length, '?').join(',');
      final query =
          '''
        SELECT 
          thang,
          SUM(tong_thanh_toan) as tong_phai_nop,
          SUM(so_tien_da_dong) as tong_da_dong
        FROM ${DBHelper.tenBangThanhToan}
        WHERE thang IN ($placeholders)
        GROUP BY thang
      ''';

      final List<Map<String, dynamic>> rows = await db.rawQuery(
        query,
        thangList,
      );
      final Map<String, Map<String, int>> thangDataMap = {
        for (var r in rows)
          if (r['thang'] != null)
            r['thang'].toString(): {
              'phai_nop': (r['tong_phai_nop'] as num?)?.toInt() ?? 0,
              'da_dong': (r['tong_da_dong'] as num?)?.toInt() ?? 0,
            },
      };

      final List<HocPhiThang> results = thangList.map((thang) {
        final data = thangDataMap[thang];
        final tongPhaiNop = data?['phai_nop'] ?? 0;
        final tongThu = data?['da_dong'] ?? 0;
        int tongNo = tongPhaiNop - tongThu;
        if (tongNo < 0) tongNo = 0;

        return HocPhiThang(thang: thang, tongThu: tongThu, tongNo: tongNo);
      }).toList();

      developer.log(
        '✅ Lấy dữ liệu học phí 12 tháng thành công (Single Batch Query).',
        name: 'ThongKeService',
      );
      return results;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi khi lấy dữ liệu học phí 12 tháng',
        name: 'ThongKeService',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Lấy danh sách chi tiết các khoản thu trong một khoảng thời gian (Kiểm soát dòng tiền)
  Future<List<Map<String, dynamic>>> getDongTienTheoThoiGian(
    DateTime tuNgay,
    DateTime denNgay,
  ) async {
    try {
      final db = await _database;
      // Dùng khoảng nửa mở [tuNgay 00:00:00, denNgay + 1 ngay 00:00:00)
      final fromStr = DateFormat('yyyy-MM-dd 00:00:00').format(tuNgay);
      final nextDayAfterDenNgay = denNgay.add(const Duration(days: 1));
      final toStr = DateFormat(
        'yyyy-MM-dd 00:00:00',
      ).format(nextDayAfterDenNgay);

      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT t.ngay_thanh_toan, h.ten as ten_hoc_sinh, l.ten as ten_lop, t.thang, t.so_tien_da_dong
        FROM ${DBHelper.tenBangThanhToan} t
        JOIN ${DBHelper.tenBangHS} h ON t.id_hoc_sinh = h.id
        JOIN ${DBHelper.tenBangLop} l ON t.id_lop = l.id
        WHERE t.so_tien_da_dong > 0 
          AND t.ngay_thanh_toan IS NOT NULL
          AND t.ngay_thanh_toan >= ? 
          AND t.ngay_thanh_toan < ?
        ORDER BY t.ngay_thanh_toan DESC
      ''',
        [fromStr, toStr],
      );

      return results;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi khi lấy dữ liệu dòng tiền',
        name: 'ThongKeService',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }
}
