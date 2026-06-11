// File: lib/services/nhan_xet_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/hs_lop_view_model.dart';
import '../models/nhan_xet_thang.dart';
import '../utils/db.dart';
import 'diem_danh_service.dart';

class NhanXetService {
  final String _tenBang = DBHelper.tenBangNhanXetThang;
  final DiemDanhService _diemDanhService = DiemDanhService();
  final String _tenBangDGBH = DBHelper.tenBangDanhGiaBuoiHoc;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  // Lấy hoặc tạo mới một bản ghi nhận xét
  Future<NhanXetThang> layHoacTaoNhanXet(
    int idHocSinh,
    int idLop,
    String thang,
  ) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
      whereArgs: [idHocSinh, idLop, thang],
    );

    if (maps.isNotEmpty) {
      return NhanXetThang.fromMap(maps.first);
    } else {
      // Nếu chưa có, tạo một bản ghi mặc định
      final nhanXetMoi = NhanXetThang(
        idHocSinh: idHocSinh,
        idLop: idLop,
        thang: thang,
      );
      // Tự động tính điểm chuyên cần lần đầu
      nhanXetMoi.diemChuyenCan = await _tinhDiemChuyenCan(
        idHocSinh,
        idLop,
        thang,
      );
      // Tính luôn xếp hạng
      nhanXetMoi.xepHang = _tinhToanXepHang(nhanXetMoi.diemTrungBinh);

      final id = await db.insert(
        _tenBang,
        nhanXetMoi.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return nhanXetMoi.copyWith(id: id);
    }
  }

  // Cập nhật một bản ghi nhận xét
  Future<int> capNhatNhanXet(NhanXetThang nhanXet) async {
    final db = await _database;
    // Tính lại xếp hạng trước khi lưu
    nhanXet.xepHang = _tinhToanXepHang(nhanXet.diemTrungBinh);
    return await db.update(
      _tenBang,
      nhanXet.toMap(),
      where: 'id = ?',
      whereArgs: [nhanXet.id],
    );
  }

  // Lấy tất cả nhận xét của một lớp trong một tháng
  Future<List<NhanXetThang>> layDanhSachNhanXet(int idLop, String thang) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'id_lop = ? AND thang = ?',
      whereArgs: [idLop, thang],
    );
    return maps.map((map) => NhanXetThang.fromMap(map)).toList();
  }

  // HÀM MỚI: Tự động tổng hợp điểm từ các buổi học và cập nhật cho cả lớp
  Future<void> tongHopVaCapNhatNhanXetThang(
    List<HSLopViewModel> dsHocSinh,
    int idLop,
    String thang,
  ) async {
    final db = await _database;

    // Chuẩn bị chuỗi ngày để truy vấn (tháng này và đầu tháng sau)
    final parts = thang.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final startDateStr = '$thang-01 00:00:00';
    
    // Tính ngày đầu tháng sau
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endDateStr = '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01 00:00:00';

    for (var hs in dsHocSinh) {
      // 1. Lấy hoặc tạo bản ghi nhận xét tháng
      final nhanXetThang = await layHoacTaoNhanXet(hs.id!, idLop, thang);

      // 2. Kiểm tra xem có buổi học nào không
      final counts = await _diemDanhService.demSoBuoiTheoTrangThai(hs.id!, idLop, thang);
      final coMat = counts['coMat'] ?? 0;
      final nghiCP = counts['nghiCoPhep'] ?? 0;
      final nghiKP = counts['nghiKhongPhep'] ?? 0;
      final tongSoBuoi = coMat + nghiCP + nghiKP;

      if (tongSoBuoi == 0) {
        // Nếu không có dữ liệu điểm danh, gán điểm về 0 và bỏ qua tính toán AVG
        nhanXetThang.diemChuyenCan = 0;
        nhanXetThang.diemThaiDo = 0;
        nhanXetThang.diemBaiTap = 0;
        nhanXetThang.diemKiemTra = 0;
        nhanXetThang.xepHang = 'Chưa xếp hạng';
      } else {
        // 3. Tính điểm chuyên cần: (Có mặt + Nghỉ có phép) / Tổng số buổi * 10
        nhanXetThang.diemChuyenCan = ((coMat + nghiCP) / tongSoBuoi * 10.0);

        // 4. TÍNH TOÁN ĐIỂM TRUNG BÌNH TỪ BẢNG `danh_gia_buoi_hoc`
        final String sql =
            '''
          SELECT 
            AVG(DGBH.diem_thai_do) as avg_thai_do,
            AVG(DGBH.diem_hieu_bai) as avg_hieu_bai,
            AVG(DGBH.diem_bai_tap) as avg_bai_tap
          FROM $_tenBangDGBH DGBH
          JOIN ${DBHelper.tenBangDiemDanh} DD ON DGBH.id_diem_danh = DD.id
          WHERE DD.id_hoc_sinh = ? 
            AND DD.id_lop = ? 
            AND DD.gio_diem_danh >= ? 
            AND DD.gio_diem_danh < ? 
            AND (DGBH.diem_thai_do IS NOT NULL OR DGBH.diem_hieu_bai IS NOT NULL OR DGBH.diem_bai_tap IS NOT NULL)
        ''';

        final List<Map<String, dynamic>> avgResult = await db.rawQuery(sql, [
          hs.id!,
          idLop,
          startDateStr,
          endDateStr,
        ]);

        if (avgResult.isNotEmpty && avgResult.first.values.any((v) => v != null)) {
          final avgMap = avgResult.first;
          if (avgMap['avg_thai_do'] != null) {
            nhanXetThang.diemThaiDo = (avgMap['avg_thai_do'] as num).toDouble();
          } else if (coMat > 0) {
            nhanXetThang.diemThaiDo = 10.0; // Mặc định 10 nếu có đi học nhưng không bị trừ điểm
          } else {
            nhanXetThang.diemThaiDo = 0;
          }

          if (avgMap['avg_bai_tap'] != null) {
            nhanXetThang.diemBaiTap = (avgMap['avg_bai_tap'] as num).toDouble();
          } else if (coMat > 0) {
            nhanXetThang.diemBaiTap = 10.0;
          } else {
            nhanXetThang.diemBaiTap = 0;
          }

          if (avgMap['avg_hieu_bai'] != null) {
            nhanXetThang.diemKiemTra = (avgMap['avg_hieu_bai'] as num).toDouble();
          } else if (coMat > 0) {
            nhanXetThang.diemKiemTra = 10.0;
          } else {
            nhanXetThang.diemKiemTra = 0;
          }
        } else {
          // Nếu không có đánh giá buổi học nào nhưng có đi học
          if (coMat > 0) {
            nhanXetThang.diemThaiDo = 10.0;
            nhanXetThang.diemBaiTap = 10.0;
            nhanXetThang.diemKiemTra = 10.0;
          } else {
            nhanXetThang.diemThaiDo = 0;
            nhanXetThang.diemBaiTap = 0;
            nhanXetThang.diemKiemTra = 0;
          }
        }

        // 5. Tính toán lại xếp hạng
        nhanXetThang.xepHang = _tinhToanXepHang(nhanXetThang.diemTrungBinh);
      }

      // 6. Lưu lại bản ghi đã cập nhật
      await db.update(
        _tenBang,
        nhanXetThang.toMap(),
        where: 'id = ?',
        whereArgs: [nhanXetThang.id],
      );
    }
  }

  // Hàm tính điểm chuyên cần
  Future<double> _tinhDiemChuyenCan(
    int idHocSinh,
    int idLop,
    String thang,
  ) async {
    final soBuoiNghiKhongPhep = await _diemDanhService.demSoBuoiTheoThang(
      idHocSinh,
      idLop,
      thang,
      'Nghỉ không phép',
    );
    // Công thức: 10 điểm, mỗi buổi nghỉ không phép trừ 1 điểm, tối thiểu 0.
    double diem = 10.0 - soBuoiNghiKhongPhep;
    return diem < 0 ? 0 : diem;
  }

  // Hàm tính toán xếp hạng
  String _tinhToanXepHang(double diemTrungBinh) {
    if (diemTrungBinh >= 9.5) {
      return 'Kim Cương';
    } else if (diemTrungBinh >= 8.5) {
      return 'Bạch Kim';
    } else if (diemTrungBinh >= 7.5) {
      return 'Vàng';
    } else if (diemTrungBinh >= 6.5) {
      return 'Bạc';
    } else if (diemTrungBinh >= 5.0) {
      return 'Đồng';
    } else {
      return 'Chưa xếp hạng';
    }
  }
}
