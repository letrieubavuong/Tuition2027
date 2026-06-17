// File: lib/services/nhan_xet_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/hs_lop_view_model.dart';
import '../models/nhan_xet_thang.dart';
import '../utils/db.dart';
import 'diem_danh_service.dart';
import 'danh_gia_buoi_hoc_service.dart';

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

        // 3.1 TỰ ĐỘNG ĐÁNH GIÁ TRƯỚC: Tạo các đánh giá mặc định (10.0) cho các buổi 'Có mặt' chưa được đánh giá
        if (coMat > 0) {
          final List<Map<String, dynamic>> sessions = await db.query(
            DBHelper.tenBangDiemDanh,
            where: "id_hoc_sinh = ? AND id_lop = ? AND trang_thai = 'Có mặt' AND gio_diem_danh >= ? AND gio_diem_danh < ?",
            whereArgs: [hs.id!, idLop, startDateStr, endDateStr],
          );

          for (var sess in sessions) {
            final idDiemDanh = sess['id'] as int;
            final List<Map<String, dynamic>> existEval = await db.query(
              _tenBangDGBH,
              where: 'id_diem_danh = ?',
              whereArgs: [idDiemDanh],
            );
            if (existEval.isEmpty) {
              final autoComment = DanhGiaBuoiHocService().sinhNhanXetTuDong(0.0, 0.0, 0.0);
              await db.insert(
                _tenBangDGBH,
                {
                  'id_diem_danh': idDiemDanh,
                  'diem_thai_do': 0.0,
                  'diem_hieu_bai': 0.0,
                  'diem_bai_tap': 0.0,
                  'nhan_xet': autoComment,
                },
              );
            }
          }
        }

        // 4. TÍNH TOÁN ĐIỂM TRUNG BÌNH TỪ BẢNG `danh_gia_buoi_hoc` (Sau khi đã tự động đánh giá)
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
          nhanXetThang.diemThaiDo = avgMap['avg_thai_do'] != null
              ? (avgMap['avg_thai_do'] as num).toDouble()
              : 0.0;

          nhanXetThang.diemBaiTap = avgMap['avg_bai_tap'] != null
              ? (avgMap['avg_bai_tap'] as num).toDouble()
              : 0.0;

          nhanXetThang.diemKiemTra = avgMap['avg_hieu_bai'] != null
              ? (avgMap['avg_hieu_bai'] as num).toDouble()
              : 0.0;
        } else {
          nhanXetThang.diemThaiDo = 0.0;
          nhanXetThang.diemBaiTap = 0.0;
          nhanXetThang.diemKiemTra = 0.0;
        }

        // 5. Tính toán lại xếp hạng
        nhanXetThang.xepHang = _tinhToanXepHang(nhanXetThang.diemTrungBinh);

        // 5.1 Tự động sinh nhận xét tháng nếu nhận xét cũ trống hoặc là nhận xét tự động mặc định
        if (nhanXetThang.nhanXetChung == null ||
            nhanXetThang.nhanXetChung!.isEmpty ||
            nhanXetThang.nhanXetChung == 'Con ngoan, học tập chăm chỉ.' ||
            nhanXetThang.nhanXetChung!.startsWith('Trong tháng này, em ')) {
          nhanXetThang.nhanXetChung = sinhNhanXetThangTuDong(
            nhanXetThang.diemChuyenCan,
            nhanXetThang.diemThaiDo,
            nhanXetThang.diemKiemTra,
            nhanXetThang.diemBaiTap,
          );
        }
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

  /// Tự động sinh nhận xét đánh giá tháng dựa trên điểm số chuyên cần, thái độ, hiểu bài, bài tập.
  String sinhNhanXetThangTuDong(double chuyenCan, double thaiDo, double hieuBai, double baiTap) {
    String nxChuyenCan = '';
    if (chuyenCan >= 9.0) {
      nxChuyenCan = 'đi học rất chuyên cần và đầy đủ';
    } else if (chuyenCan >= 7.0) {
      nxChuyenCan = 'đi học tương đối đầy đủ';
    } else {
      nxChuyenCan = 'vắng mặt nhiều buổi học, cần đi học đều đặn hơn';
    }

    String nxThaiDo = '';
    if (thaiDo >= 5.0) {
      nxThaiDo = 'thái độ học tập trên lớp rất xuất sắc, luôn hăng hái phát biểu';
    } else if (thaiDo >= 1.5) {
      nxThaiDo = 'thái độ học tập tốt, tập trung nghe giảng';
    } else if (thaiDo >= 0.0) {
      nxThaiDo = 'ngoan ngoãn, thực hiện đầy đủ hướng dẫn của thầy cô';
    } else if (thaiDo >= -2.5) {
      nxThaiDo = 'đôi khi còn chưa tập trung hoặc nói chuyện riêng trong lớp';
    } else {
      nxThaiDo = 'thường xuyên làm việc riêng, cần nghiêm túc chấn chỉnh thái độ học';
    }

    String nxHieuBai = '';
    if (hieuBai >= 5.0) {
      nxHieuBai = 'tiếp thu kiến thức cực tốt, kết quả kiểm tra rất xuất sắc';
    } else if (hieuBai >= 1.5) {
      nxHieuBai = 'hiểu bài tốt, nắm vững kiến thức trọng tâm';
    } else if (hieuBai >= 0.0) {
      nxHieuBai = 'hiểu bài ở mức cơ bản, cần ôn tập thêm';
    } else if (hieuBai >= -2.5) {
      nxHieuBai = 'tiếp thu bài còn chậm, cần kiên nhẫn làm nhiều bài tập hơn';
    } else {
      nxHieuBai = 'gặp nhiều khó khăn khi tiếp thu kiến thức, cần kèm cặp thêm';
    }

    String nxBaiTap = '';
    if (baiTap >= 5.0) {
      nxBaiTap = 'hoàn thành bài tập về nhà rất tốt, trình bày khoa học và cẩn thận';
    } else if (baiTap >= 1.5) {
      nxBaiTap = 'làm bài tập đầy đủ trước khi lên lớp';
    } else if (baiTap >= 0.0) {
      nxBaiTap = 'có làm bài tập nhưng đôi lúc còn thiếu hoặc làm chưa kỹ';
    } else if (baiTap >= -2.5) {
      nxBaiTap = 'làm bài tập về nhà còn đối phó hoặc nộp muộn';
    } else {
      nxBaiTap = 'không làm bài tập về nhà, cần tự giác hơn';
    }

    return 'Trong tháng này, em $nxChuyenCan. Về học tập, em có $nxThaiDo, $nxHieuBai và $nxBaiTap.';
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

  // Hàm tính toán xếp hạng theo game Liên Quân Mobile (Cập nhật: TB = 0.0 thì xếp hạng Vàng)
  String _tinhToanXepHang(double diemTrungBinh) {
    if (diemTrungBinh == 0.0) {
      return 'Vàng'; // Tổng trung bình bằng 0.0 thì xếp hạng Vàng
    }

    if (diemTrungBinh >= 8.5) {
      return 'Thách Đấu';
    } else if (diemTrungBinh >= 7.0) {
      return 'Cao Thủ';
    } else if (diemTrungBinh >= 5.5) {
      return 'Tinh Anh';
    } else if (diemTrungBinh >= 4.0) {
      return 'Kim Cương';
    } else if (diemTrungBinh >= 2.5) {
      return 'Bạch Kim';
    } else if (diemTrungBinh >= 1.0) {
      return 'Vàng';
    } else if (diemTrungBinh >= -2.0) {
      return 'Bạc';
    } else {
      return 'Đồng';
    }
  }

  // Lấy bảng xếp hạng học sinh theo Khối (Grade) trong tháng YYYY-MM
  Future<List<Map<String, dynamic>>> layBangXepHangTheoKhoi(int khoi, String thang) async {
    final db = await _database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT 
        HS.id as id_hoc_sinh,
        HS.ten as ten_hoc_sinh,
        L.ten as ten_lop,
        L.id as id_lop,
        NX.diem_chuyen_can,
        NX.diem_thai_do,
        NX.diem_bai_tap,
        NX.diem_kiem_tra,
        NX.xep_hang
      FROM ${DBHelper.tenBangHS} HS
      JOIN ${DBHelper.tenBangLopHS} LHS ON HS.id = LHS.id_hoc_sinh
      JOIN ${DBHelper.tenBangLop} L ON LHS.id_lop = L.id
      LEFT JOIN $_tenBang NX ON HS.id = NX.id_hoc_sinh AND L.id = NX.id_lop AND NX.thang = ?
      WHERE L.khoi = ? AND LHS.trang_thai = 'Dang hoc'
    ''', [thang, khoi]);

    // Tiến hành ánh xạ dữ liệu và tính toán điểm trung bình
    final List<Map<String, dynamic>> processed = results.map((row) {
      final double cc = (row['diem_chuyen_can'] as num?)?.toDouble() ?? 0.0;
      final double td = (row['diem_thai_do'] as num?)?.toDouble() ?? 0.0;
      final double bt = (row['diem_bai_tap'] as num?)?.toDouble() ?? 0.0;
      final double kt = (row['diem_kiem_tra'] as num?)?.toDouble() ?? 0.0;
      final double dtb = (cc + td + bt + kt) / 4.0;
      final String rankStr = row['xep_hang'] as String? ?? 'Đồng';

      return {
        'id_hoc_sinh': row['id_hoc_sinh'],
        'ten_hoc_sinh': row['ten_hoc_sinh'],
        'ten_lop': row['ten_lop'],
        'id_lop': row['id_lop'],
        'diem_trung_binh': dtb,
        'xep_hang': rankStr,
      };
    }).toList();

    // Sắp xếp theo điểm trung bình giảm dần
    processed.sort((a, b) => (b['diem_trung_binh'] as double).compareTo(a['diem_trung_binh'] as double));
    return processed;
  }
}
