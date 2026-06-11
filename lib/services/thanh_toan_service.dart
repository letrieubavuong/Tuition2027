// File: lib/services/thanh_toan_service.dart (ĐÃ THÊM HÀM layBaoCaoHocPhiThang)

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../models/lich_su_thanh_toan_view_model.dart';

class ThanhToanService {
  final String tenBangThanhToan = DBHelper.tenBangThanhToan;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  // ===================================================
  // HÀM MỚI: ĐỌC HỌC PHÍ THEO BUỔI TỪ CÀI ĐẶT
  // ===================================================
  Future<void> capNhatSoTienDaDong(
    int idHocSinh,
    int idLop, // Đã thêm
    String thang,
    int soTienDaDongMoi,
    String? ghiChu, {
    DateTime? ngayThanhToan,
  }) async {
    final db = await _database;

    // Chuẩn bị dữ liệu cần cập nhật
    final Map<String, dynamic> values = {
      'so_tien_da_dong': soTienDaDongMoi,
      'ghi_chu_thanh_toan': ghiChu,
      // Cập nhật thời gian thanh toán (Tùy chọn)
      'ngay_thanh_toan': (ngayThanhToan ?? DateTime.now()).toIso8601String(),
    };

    // Thực hiện cập nhật dựa trên khóa chính (id_hoc_sinh, id_lop, thang)
    final int count = await db.update(
      tenBangThanhToan,
      values,
      where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
      whereArgs: [idHocSinh, idLop, thang],
    );

    if (count == 0) {
      // Trường hợp không tìm thấy hồ sơ (rất hiếm nếu đã gọi layBaoCaoHocPhiThang)
      throw Exception(
        'Không tìm thấy hồ sơ thanh toán cho học sinh ID $idHocSinh, lớp ID $idLop, tháng $thang',
      );
    }
  }

  // ===================================================
  // HÀM MỚI: LẤY LỊCH SỬ THANH TOÁN CỦA HỌC SINH
  // ===================================================
  Future<List<LichSuThanhToanViewModel>> layLichSuThanhToan(
    int idHocSinh,
  ) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
        SELECT 
            L.ten as tenLop, 
            TT.thang, 
            TT.so_tien_da_dong, 
            TT.ngay_thanh_toan, 
            TT.ghi_chu_thanh_toan
        FROM $tenBangThanhToan TT
        JOIN ${DBHelper.tenBangLop} L ON TT.id_lop = L.id
        WHERE TT.id_hoc_sinh = ? AND TT.so_tien_da_dong > 0
        ORDER BY TT.ngay_thanh_toan DESC, TT.thang DESC
    ''',
      [idHocSinh],
    );

    return maps.map((map) {
      return LichSuThanhToanViewModel(
        tenLop: map['tenLop'] as String,
        thang: map['thang'] as String,
        soTienDaDong: map['so_tien_da_dong'] as int,
        ngayThanhToan: map['ngay_thanh_toan'] as String?,
        ghiChu: map['ghi_chu_thanh_toan'] as String?,
      );
    }).toList();
  }
}
