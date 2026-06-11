// File: lib/services/danh_gia_buoi_hoc_service.dart

import 'package:sqflite/sqflite.dart';
import '../models/danh_gia_lich_su_view_model.dart';
import '../models/su_kien_hoc_tap.dart';
import 'su_kien_hoc_tap_service.dart';
import 'quy_tac_diem_service.dart'; // Import service mới
import '../models/danh_gia_buoi_hoc.dart';
import '../utils/db.dart';

class DanhGiaBuoiHocService {
  final String _tenBang = DBHelper.tenBangDanhGiaBuoiHoc;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  /// Lấy một bản ghi đánh giá dựa trên id_diem_danh.
  /// Nếu không tìm thấy, tạo và trả về một đối tượng mới (chưa lưu vào DB).
  Future<DanhGiaBuoiHoc> layHoacTaoDanhGia(int idDiemDanh) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'id_diem_danh = ?',
      whereArgs: [idDiemDanh],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      // Nếu tìm thấy, trả về bản ghi từ DB
      return DanhGiaBuoiHoc.fromMap(maps.first);
    } else {
      // Nếu không, tạo một đối tượng mới, rỗng
      return DanhGiaBuoiHoc(idDiemDanh: idDiemDanh);
    }
  }

  /// Cập nhật hoặc Thêm mới một bản ghi đánh giá.
  /// Sử dụng `ConflictAlgorithm.replace` để tự động xử lý.
  Future<int> luuDanhGia(DanhGiaBuoiHoc danhGia) async {
    final db = await _database;

    // Nếu không có điểm và nhận xét, không cần lưu
    if (danhGia.diemThaiDo == null &&
        danhGia.diemHieuBai == null &&
        danhGia.diemBaiTap == null &&
        (danhGia.nhanXet == null || danhGia.nhanXet!.isEmpty)) {
      return 0; // Không có gì để lưu
    }

    return await db.insert(
      _tenBang,
      danhGia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // HÀM MỚI: Tự động tính toán và cập nhật điểm buổi học từ các sự kiện
  Future<void> capNhatDiemTuSuKien(int idDiemDanh) async {
    final suKienService = SuKienHocTapService();
    final dsSuKien = await suKienService.laySuKienTheoBuoiHoc(idDiemDanh);

    // 1. Phân loại sự kiện và tính tổng điểm thay đổi cho mỗi tiêu chí
    double diemThayDoiThaiDo = 0;
    double diemThayDoiHieuBai = 0;
    double diemThayDoiBaiTap = 0;

    for (var suKien in dsSuKien) {
      final diem = suKien.diemThayDoi;
      
      // Phân bổ điểm dựa trên trường loaiSuKien đã được lưu
      if (suKien.loaiSuKien == LoaiSuKien.thaiDo) {
        diemThayDoiThaiDo += diem;
      } else if (suKien.loaiSuKien == LoaiSuKien.hieuBai) {
        diemThayDoiHieuBai += diem;
      } else if (suKien.loaiSuKien == LoaiSuKien.baiTap) {
        diemThayDoiBaiTap += diem;
      } else if (suKien.loaiSuKien == LoaiSuKien.tichCuc) {
        // Fallback cho dữ liệu cũ: tichCuc mặc định vào Thái độ
        diemThayDoiThaiDo += diem;
      } else if (suKien.loaiSuKien == LoaiSuKien.tieuCuc) {
        // Fallback cho dữ liệu cũ: tieuCuc mặc định vào Thái độ
        diemThayDoiThaiDo += diem;
      }
    }

    // 2. Tính điểm cuối cùng (bắt đầu từ 10 và cộng/trừ)
    // Giới hạn điểm trong khoảng từ 0 đến 10
    final diemThaiDo = (10.0 + diemThayDoiThaiDo).clamp(0.0, 10.0);
    final diemHieuBai = (10.0 + diemThayDoiHieuBai).clamp(0.0, 10.0);
    final diemBaiTap = (10.0 + diemThayDoiBaiTap).clamp(0.0, 10.0);

    // 3. Lấy hoặc tạo bản ghi đánh giá buổi học
    final danhGia = await layHoacTaoDanhGia(idDiemDanh);

    // 4. Cập nhật điểm
    danhGia.diemThaiDo = diemThaiDo;
    danhGia.diemHieuBai = diemHieuBai;
    danhGia.diemBaiTap = diemBaiTap;

    // 5. Lưu lại vào CSDL
    final db = await _database;
    await db.insert(
      _tenBang,
      danhGia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lấy toàn bộ lịch sử đánh giá của một học sinh, sắp xếp theo ngày mới nhất.
  Future<List<DanhGiaLichSuViewModel>> layLichSuDanhGia(int idHocSinh) async {
    final db = await _database;

    final String sql =
        '''
      SELECT 
        L.ten as tenLop,
        DD.gio_diem_danh as ngayHoc,
        DGBH.diem_thai_do,
        DGBH.diem_hieu_bai,
        DGBH.diem_bai_tap,
        DGBH.nhan_xet
      FROM ${DBHelper.tenBangDanhGiaBuoiHoc} DGBH
      JOIN ${DBHelper.tenBangDiemDanh} DD ON DGBH.id_diem_danh = DD.id
      JOIN ${DBHelper.tenBangLop} L ON DD.id_lop = L.id
      WHERE DD.id_hoc_sinh = ?
      ORDER BY DD.gio_diem_danh DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, [idHocSinh]);

    return List.generate(
      maps.length,
      (i) => DanhGiaLichSuViewModel.fromMap(maps[i]),
    );
  }
}
