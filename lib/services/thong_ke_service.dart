// File: lib/services/thong_ke_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:collection/collection.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../services/report_service.dart';
import '../utils/db.dart';
import 'dart:developer' as developer;

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
  final _reportService = ReportService();

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

  /// Lấy dữ liệu số lượng học sinh hoạt động trong 12 tháng gần nhất.
  /// "Học sinh hoạt động" được định nghĩa là học sinh có ít nhất 1 bản ghi điểm danh trong tháng.
  Future<List<HocSinhThang>> getSoLuongHSHoatDong12Thang() async {
    try {
      final db = await _database;
      final thangList = _get12ThangGanNhat();
      final List<HocSinhThang> results = [];

      for (final thang in thangList) {
        final year = thang.substring(0, 4);
        final month = thang.substring(5, 7);

        // Sử dụng LIKE để tìm kiếm các bản ghi trong tháng
        final query =
            '''
          SELECT COUNT(DISTINCT id_hoc_sinh) as so_luong
          FROM ${DBHelper.tenBangDiemDanh}
          WHERE gio_diem_danh LIKE '$year-$month-%'
        ''';

        final result = await db.rawQuery(query);

        int soLuong = 0;
        if (result.isNotEmpty && result.first['so_luong'] != null) {
          soLuong = result.first['so_luong'] as int;
        }
        results.add(HocSinhThang(thang: thang, soLuong: soLuong));
      }

      developer.log(
        '✅ Lấy dữ liệu HS hoạt động 12 tháng thành công.',
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

  /// Lấy dữ liệu tổng thu và tổng nợ học phí trong 12 tháng gần nhất.
  Future<List<HocPhiThang>> getHocPhi12Thang() async {
    try {
      final db = await _database;
      final thangList = _get12ThangGanNhat();
      final List<HocPhiThang> results = [];

      for (final thang in thangList) {
        // Sử dụng câu lệnh SUM để tính toán trực tiếp từ cơ sở dữ liệu cho tháng hiện tại
        final List<Map<String, dynamic>> res = await db.rawQuery(
          '''
          SELECT 
            SUM(tong_thanh_toan) as tong_phai_nop,
            SUM(so_tien_da_dong) as tong_da_dong
          FROM ${DBHelper.tenBangThanhToan}
          WHERE thang = ?
          ''',
          [thang],
        );

        int tongPhaiNopThang = 0;
        int tongThuThang = 0;

        if (res.isNotEmpty) {
          tongPhaiNopThang = res.first['tong_phai_nop'] as int? ?? 0;
          tongThuThang = res.first['tong_da_dong'] as int? ?? 0;
        }

        int tongNoThang = tongPhaiNopThang - tongThuThang;
        if (tongNoThang < 0) tongNoThang = 0; // Nợ không thể âm

        results.add(
          HocPhiThang(thang: thang, tongThu: tongThuThang, tongNo: tongNoThang),
        );
      }

      developer.log(
        '✅ Lấy dữ liệu học phí 12 tháng thành công.',
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
      // Đảm bảo định dạng chuẩn ISO. Thêm 23:59:59 vào denNgay để bao trọn vẹn ngày cuối cùng.
      final fromStr = DateFormat('yyyy-MM-dd').format(tuNgay);
      final toStr = '${DateFormat('yyyy-MM-dd').format(denNgay)} 23:59:59';

      final List<Map<String, dynamic>> results = await db.rawQuery(
        '''
        SELECT t.ngay_thanh_toan, h.ten as ten_hoc_sinh, l.ten as ten_lop, t.thang, t.so_tien_da_dong
        FROM ${DBHelper.tenBangThanhToan} t
        JOIN ${DBHelper.tenBangHS} h ON t.id_hoc_sinh = h.id
        JOIN ${DBHelper.tenBangLop} l ON t.id_lop = l.id
        WHERE t.so_tien_da_dong > 0 
          AND t.ngay_thanh_toan IS NOT NULL
          AND t.ngay_thanh_toan >= ? 
          AND t.ngay_thanh_toan <= ?
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
