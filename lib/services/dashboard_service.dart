// File: lib/services/dashboard_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:developer' as developer;
import '../utils/db.dart';
import '../utils/student_status.dart';
import '../utils/schedule_helpers.dart';

class CaHocHomNay {
  final int idLop;
  final String tenLop;
  final String gioBatDau;
  final String gioKetThuc;
  final int? idLichHoc;
  final String status; // 'Sắp bắt đầu', 'Đang diễn ra', 'Đã kết thúc', 'Chưa điểm danh', 'Đã điểm danh', 'Cần đánh giá', 'Hoàn tất'
  final int attendedCount;
  final int totalStudentsCount;
  final bool attendanceDone;
  final bool reviewDone;

  CaHocHomNay({
    required this.idLop,
    required this.tenLop,
    required this.gioBatDau,
    required this.gioKetThuc,
    this.idLichHoc,
    this.status = 'Sắp bắt đầu',
    this.attendedCount = 0,
    this.totalStudentsCount = 0,
    this.attendanceDone = false,
    this.reviewDone = false,
  });

  factory CaHocHomNay.fromMap(Map<String, dynamic> map) {
    int parseInt(dynamic v) {
      if (v is int) return v;
      if (v != null) {
        final parsed = int.tryParse(v.toString());
        if (parsed != null) return parsed;
      }
      return 0;
    }

    return CaHocHomNay(
      idLop: parseInt(map['idLop']),
      tenLop: (map['tenLop'] as String?) ?? '',
      gioBatDau: (map['gioBatDau'] as String?) ?? '',
      gioKetThuc: (map['gioKetThuc'] as String?) ?? '',
      idLichHoc: parseInt(map['idLichHoc']),
      status: map['status']?.toString() ?? 'Sắp bắt đầu',
      attendedCount: parseInt(map['attendedCount']),
      totalStudentsCount: parseInt(map['totalStudentsCount']),
      attendanceDone: map['attendanceDone'] == 1 || map['attendanceDone'] == true,
      reviewDone: map['reviewDone'] == 1 || map['reviewDone'] == true,
    );
  }
}

class DashboardData {
  final int soLopHoc;
  final int soHocSinh;
  final int soCaHocHomNay;
  final int tongTienNo;
  final int tongTienThu;
  final String monthKey;
  final List<CaHocHomNay> dsCaHocHomNay;

  DashboardData({
    this.soLopHoc = 0,
    this.soHocSinh = 0,
    this.soCaHocHomNay = 0,
    this.tongTienNo = 0,
    this.tongTienThu = 0,
    this.monthKey = '',
    this.dsCaHocHomNay = const [],
  });
}

class DashboardService {
  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  /// Lightweight "Teacher Today Dashboard" query engine (< 50ms)
  Future<DashboardData> getDashboardData({String? month}) async {
    final sw = Stopwatch()..start();
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final targetMonth = month ?? DateFormat('yyyy-MM').format(now);
    final int thuTrongTuanDB = databaseWeekdayFromDate(now);

    Database? db;
    try {
      db = await _database.timeout(const Duration(seconds: 3));
    } catch (e, st) {
      developer.log('[Dashboard] Lỗi mở Database: $e', name: 'DashboardService', error: e, stackTrace: st);
      return DashboardData();
    }

    // 1. Đếm tổng số lớp (Independent Error Boundary)
    int soLopHoc = 0;
    try {
      final res = await db.rawQuery('SELECT COUNT(*) as count FROM ${DBHelper.tenBangLop}');
      soLopHoc = Sqflite.firstIntValue(res) ?? 0;
    } catch (e) {
      developer.log('[Dashboard][Lop] Lỗi query số lớp: $e', name: 'DashboardService');
    }

    // 2. Đếm tổng số học sinh (Independent Error Boundary)
    int soHocSinh = 0;
    try {
      final res = await db.rawQuery('SELECT COUNT(*) as count FROM ${DBHelper.tenBangHS}');
      soHocSinh = Sqflite.firstIntValue(res) ?? 0;
    } catch (e) {
      developer.log('[Dashboard][HocSinh] Lỗi query số học sinh: $e', name: 'DashboardService');
    }

    // 3. Đếm và lấy ca học hôm nay (Independent Error Boundary)
    final List<CaHocHomNay> dsCaHocHomNay = [];
    final nowMinutes = now.hour * 60 + now.minute;

    try {
      final List<Map<String, dynamic>> caHocHomNayResult = await db.rawQuery(
        '''
        SELECT L.id as idLop, L.ten as tenLop, LH.id as idLichHoc, LH.gioBatDau, LH.gioKetThuc
        FROM ${DBHelper.tenBangLichHoc} LH
        JOIN ${DBHelper.tenBangLop} L ON (LH.id_lop = L.id OR CAST(LH.id_lop AS TEXT) = CAST(L.id AS TEXT))
        WHERE LH.thuTrongTuan = ?
        ORDER BY LH.gioBatDau ASC
      ''',
        [thuTrongTuanDB],
      );

      for (var map in caHocHomNayResult) {
        final idLop = (map['idLop'] as num).toInt();
        final idLichHoc = map['idLichHoc'] != null ? (map['idLichHoc'] as num).toInt() : null;
        final tenLop = map['tenLop'] as String? ?? '';
        final gioBatDau = map['gioBatDau'] as String? ?? '00:00';
        final gioKetThuc = map['gioKetThuc'] as String? ?? '23:59';

        int startMin = 0;
        int endMin = 24 * 60;
        if (gioBatDau.contains(':')) {
          final parts = gioBatDau.split(':');
          startMin = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        }
        if (gioKetThuc.contains(':')) {
          final parts = gioKetThuc.split(':');
          endMin = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        }

        int totalHs = 0;
        try {
          final hsCountRes = await db.rawQuery(
            'SELECT COUNT(*) as count FROM ${DBHelper.tenBangLopHS} LHS WHERE LHS.id_lop = ? AND ${StudentStatus.activeSqlCondition}',
            [idLop],
          );
          totalHs = Sqflite.firstIntValue(hsCountRes) ?? 0;
        } catch (_) {}

        int attendedCount = 0;
        bool attendanceDone = false;
        try {
          final attRes = await db.rawQuery(
            'SELECT trang_thai FROM ${DBHelper.tenBangDiemDanh} WHERE id_lop = ? AND gio_diem_danh LIKE ?',
            [idLop, '$todayStr%'],
          );
          attendanceDone = attRes.isNotEmpty;
          for (var r in attRes) {
            final st = r['trang_thai']?.toString();
            if (st == 'Có mặt' || st == 'Muộn' || st == 'Trễ') attendedCount++;
          }
        } catch (_) {}

        bool reviewDone = false;
        try {
          final ledgerRes = await db.rawQuery(
            'SELECT review_status FROM session_completion_ledger WHERE class_id = ? AND session_date = ?',
            [idLop, todayStr],
          );
          if (ledgerRes.isNotEmpty) {
            final rSt = ledgerRes.first['review_status']?.toString();
            if (rSt == 'COMPLETED' || rSt == 'DONE') reviewDone = true;
          }
        } catch (_) {}

        String statusStr = 'Sắp bắt đầu';
        if (nowMinutes >= startMin && nowMinutes <= endMin) {
          statusStr = 'Đang diễn ra';
        } else if (nowMinutes > endMin) {
          statusStr = 'Đã kết thúc';
        }

        if (attendanceDone) {
          statusStr = reviewDone ? 'Hoàn tất' : 'Đã điểm danh';
        } else if (nowMinutes > startMin) {
          statusStr = 'Chưa điểm danh';
        }

        final caHoc = CaHocHomNay(
          idLop: idLop,
          tenLop: tenLop,
          gioBatDau: gioBatDau,
          gioKetThuc: gioKetThuc,
          idLichHoc: idLichHoc,
          status: statusStr,
          attendedCount: attendedCount,
          totalStudentsCount: totalHs,
          attendanceDone: attendanceDone,
          reviewDone: reviewDone,
        );

        dsCaHocHomNay.add(caHoc);
      }
    } catch (e) {
      developer.log('[Dashboard][CaHoc] Lỗi query ca học hôm nay: $e', name: 'DashboardService');
    }

    final int soCaHocHomNay = dsCaHocHomNay.length;

    // 4. Tổng thu & Tổng nợ theo tháng (Aggregate sum for target month, graceful error boundary)
    int tongTienNo = 0;
    int tongTienThu = 0;
    try {
      final hocPhiResult = await db.rawQuery(
        '''
        SELECT 
          SUM(CASE WHEN tong_thanh_toan > so_tien_da_dong THEN tong_thanh_toan - so_tien_da_dong ELSE 0 END) as total_debt,
          SUM(so_tien_da_dong) as total_collected
        FROM ${DBHelper.tenBangThanhToan}
        WHERE thang LIKE ?
      ''',
        ['$targetMonth%'],
      );
      if (hocPhiResult.isNotEmpty) {
        final row = hocPhiResult.first;
        tongTienNo = (row['total_debt'] as num?)?.toInt() ?? 0;
        tongTienThu = (row['total_collected'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      developer.log('[Dashboard][HocPhi] Lỗi query tổng học phí tháng $targetMonth: $e', name: 'DashboardService');
    }

    sw.stop();
    developer.log(
      '[Dashboard] getDashboardData TOTAL durationMs=${sw.elapsedMilliseconds} (students=$soHocSinh, classes=$soLopHoc, todaySessions=$soCaHocHomNay, month=$targetMonth, debt=$tongTienNo, collected=$tongTienThu)',
      name: 'DashboardService',
    );

    return DashboardData(
      soLopHoc: soLopHoc,
      soHocSinh: soHocSinh,
      soCaHocHomNay: soCaHocHomNay,
      tongTienNo: tongTienNo,
      tongTienThu: tongTienThu,
      monthKey: targetMonth,
      dsCaHocHomNay: dsCaHocHomNay,
    );
  }
}
