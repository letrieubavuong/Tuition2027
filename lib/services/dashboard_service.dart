// File: lib/services/dashboard_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';

class CaHocHomNay {
  final int idLop; // <-- THÊM: ID của lớp học
  final String tenLop;
  final String gioBatDau;
  final String gioKetThuc;

  CaHocHomNay({
    required this.idLop,
    required this.tenLop,
    required this.gioBatDau,
    required this.gioKetThuc,
  });

  factory CaHocHomNay.fromMap(Map<String, dynamic> map) {
    // Helper để parse int an toàn
    int parseInt(dynamic v) =>
        (v is int) ? v : (int.tryParse(v.toString()) ?? 0);

    return CaHocHomNay(
      idLop: parseInt(map['idLop']), // <-- THÊM: Đọc idLop từ map
      tenLop: map['tenLop'] as String,
      gioBatDau: map['gioBatDau'] as String,
      gioKetThuc: map['gioKetThuc'] as String,
    );
  }
}

// Model cho dữ liệu biểu đồ
class HocSinhTheoKhoi {
  final int khoi;
  final int soLuong;

  HocSinhTheoKhoi({required this.khoi, required this.soLuong});
}

class DashboardData {
  final int soLopHoc;
  final int soHocSinh;
  final int soCaHocHomNay;
  final int tongTienNo;
  final int tongTienThu; // <-- THÊM: Tổng tiền đã thu
  final List<CaHocHomNay> dsCaHocHomNay;
  final List<HocSinhTheoKhoi> phanBoHocSinh; // Dữ liệu cho biểu đồ

  DashboardData({
    this.soLopHoc = 0,
    this.soHocSinh = 0,
    this.soCaHocHomNay = 0,
    this.tongTienNo = 0,
    this.tongTienThu = 0, // <-- THÊM: Mặc định 0
    this.dsCaHocHomNay = const [],
    this.phanBoHocSinh = const [],
  });
}

class DashboardService {
  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  Future<DashboardData> getDashboardData() async {
    try {
      final db = await _database.timeout(const Duration(seconds: 3));

      // 1. Đếm tổng số lớp
      final soLopHocResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DBHelper.tenBangLop}',
      );
      final int soLopHoc = Sqflite.firstIntValue(soLopHocResult) ?? 0;

      // 2. Đếm tổng số học sinh
      final soHocSinhResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${DBHelper.tenBangHS}',
      );
      final int soHocSinh = Sqflite.firstIntValue(soHocSinhResult) ?? 0;

      // 3. Đếm và lấy danh sách ca học hôm nay
      final now = DateTime.now();
      final int thuHienTai = now.weekday; // 1=Mon, ..., 7=Sun
      final int thuTrongTuanDB = (thuHienTai == 7) ? 1 : thuHienTai + 1;

      final List<Map<String, dynamic>> caHocHomNayResult = await db.rawQuery(
        '''
        SELECT L.id as idLop, L.ten as tenLop, LH.gioBatDau, LH.gioKetThuc
        FROM ${DBHelper.tenBangLichHoc} LH
        JOIN ${DBHelper.tenBangLop} L ON LH.id_lop = L.id
        WHERE LH.thuTrongTuan = ?
        ORDER BY LH.gioBatDau ASC
      ''',
        [thuTrongTuanDB],
      );

      final int soCaHocHomNay = caHocHomNayResult.length;
      final List<CaHocHomNay> dsCaHocHomNay = caHocHomNayResult
          .map((map) => CaHocHomNay.fromMap(map))
          .toList();

      // 4. Tính tổng số tiền còn nợ trong tháng hiện tại
      final thangHienTai = DateFormat('yyyy-MM').format(now);
      final tongTienNoResult = await db.rawQuery(
        '''
        SELECT SUM(tong_thanh_toan - so_tien_da_dong) as total_debt
        FROM ${DBHelper.tenBangThanhToan}
        WHERE thang = ? AND (tong_thanh_toan > so_tien_da_dong)
      ''',
        [thangHienTai],
      );

      int tongTienNo = 0;
      if (tongTienNoResult.isNotEmpty &&
          tongTienNoResult.first['total_debt'] != null) {
        tongTienNo = (tongTienNoResult.first['total_debt'] as num).toInt();
      }

      // 4.1 Tính tổng số tiền đã thu trong tháng hiện tại
      final tongTienThuResult = await db.rawQuery(
        '''
        SELECT SUM(so_tien_da_dong) as total_collected
        FROM ${DBHelper.tenBangThanhToan}
        WHERE thang = ?
      ''',
        [thangHienTai],
      );

      int tongTienThu = 0;
      if (tongTienThuResult.isNotEmpty &&
          tongTienThuResult.first['total_collected'] != null) {
        tongTienThu = (tongTienThuResult.first['total_collected'] as num).toInt();
      }

      // 5. Lấy phân bố học sinh theo khối
      final List<Map<String, dynamic>> phanBoResult = await db.rawQuery('''
        SELECT L.khoi, COUNT(DISTINCT LHS.id_hoc_sinh) as so_luong
        FROM ${DBHelper.tenBangLopHS} LHS
        JOIN ${DBHelper.tenBangLop} L ON LHS.id_lop = L.id
        GROUP BY L.khoi
        ORDER BY L.khoi ASC
      ''');

      final List<HocSinhTheoKhoi> phanBoHocSinh = phanBoResult
          .map(
            (map) => HocSinhTheoKhoi(
              khoi: (map['khoi'] is int)
                  ? map['khoi'] as int
                  : (int.tryParse(map['khoi']?.toString() ?? '0') ?? 0),
              soLuong: (map['so_luong'] is num)
                  ? (map['so_luong'] as num).toInt()
                  : (int.tryParse(map['so_luong']?.toString() ?? '0') ?? 0),
            ),
          )
          .toList();

      return DashboardData(
        soLopHoc: soLopHoc,
        soHocSinh: soHocSinh,
        soCaHocHomNay: soCaHocHomNay,
        tongTienNo: tongTienNo,
        tongTienThu: tongTienThu,
        dsCaHocHomNay: dsCaHocHomNay,
        phanBoHocSinh: phanBoHocSinh,
      );
    } catch (e) {
      return DashboardData();
    }
  }
}
