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

    // 2. Tính điểm cuối cùng (bắt đầu từ 0.0 và cộng/trừ)
    // Giới hạn điểm trong khoảng từ -10 đến 10
    final diemThaiDo = (0.0 + diemThayDoiThaiDo).clamp(-10.0, 10.0);
    final diemHieuBai = (0.0 + diemThayDoiHieuBai).clamp(-10.0, 10.0);
    final diemBaiTap = (0.0 + diemThayDoiBaiTap).clamp(-10.0, 10.0);

    // 3. Lấy hoặc tạo bản ghi đánh giá buổi học
    final danhGia = await layHoacTaoDanhGia(idDiemDanh);

    // 4. Cập nhật điểm
    danhGia.diemThaiDo = diemThaiDo;
    danhGia.diemHieuBai = diemHieuBai;
    danhGia.diemBaiTap = diemBaiTap;

    // Tự động sinh nhận xét nếu nhận xét cũ trống hoặc là nhận xét tự động mặc định
    if (danhGia.nhanXet == null ||
        danhGia.nhanXet!.isEmpty ||
        danhGia.nhanXet == 'Tự động đánh giá' ||
        danhGia.nhanXet!.startsWith('Em ')) {
      danhGia.nhanXet = sinhNhanXetTuDong(diemThaiDo, diemHieuBai, diemBaiTap);
    }

    // 5. Lưu lại vào CSDL
    final db = await _database;
    await db.insert(
      _tenBang,
      danhGia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Tự động sinh nhận xét buổi học dựa trên điểm thái độ, hiểu bài, bài tập.
  String sinhNhanXetTuDong(double thaiDo, double hieuBai, double baiTap) {
    String nxThaiDo = '';
    if (thaiDo >= 5.0) {
      nxThaiDo = 'thái độ học tập rất tích cực, chủ động phát biểu';
    } else if (thaiDo >= 1.5) {
      nxThaiDo = 'thái độ học tập tốt, tập trung nghe giảng';
    } else if (thaiDo >= 0.0) {
      nxThaiDo = 'ngoan ngoãn, hoàn thành nhiệm vụ trong lớp';
    } else if (thaiDo >= -2.5) {
      nxThaiDo = 'đôi lúc còn mất tập trung, nói chuyện riêng';
    } else {
      nxThaiDo = 'thiếu tập trung, cần giáo viên nhắc nhở nhiều';
    }

    String nxHieuBai = '';
    if (hieuBai >= 5.0) {
      nxHieuBai = 'tiếp thu bài rất nhanh, làm bài trôi chảy';
    } else if (hieuBai >= 1.5) {
      nxHieuBai = 'hiểu bài tốt, nắm vững kiến thức';
    } else if (hieuBai >= 0.0) {
      nxHieuBai = 'hiểu bài ở mức cơ bản';
    } else if (hieuBai >= -2.5) {
      nxHieuBai = 'tiếp thu bài còn hơi chậm';
    } else {
      nxHieuBai = 'tiếp thu bài chậm, gặp nhiều khó khăn';
    }

    String nxBaiTap = '';
    if (baiTap >= 5.0) {
      nxBaiTap = 'hoàn thành bài tập về nhà xuất sắc, sạch đẹp';
    } else if (baiTap >= 1.5) {
      nxBaiTap = 'làm bài tập đầy đủ, tự giác';
    } else if (baiTap >= 0.0) {
      nxBaiTap = 'có làm bài tập nhưng chưa đầy đủ';
    } else if (baiTap >= -2.5) {
      nxBaiTap = 'bài tập làm đối phó hoặc nộp muộn';
    } else {
      nxBaiTap = 'không làm bài tập về nhà';
    }

    return 'Em $nxThaiDo, $nxHieuBai và $nxBaiTap.';
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
