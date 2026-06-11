// File: lib/services/report_service.dart

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../models/thanh_toan.dart';
import '../models/hoc_phi_tong_hop.dart';
import 'diem_danh_service.dart';
import 'lop_hoc_sinh_service.dart';
import 'lich_hoc_chung_service.dart';
import 'hoc_sinh_service.dart';
import 'caidat_service.dart';

// Giả định: Giá học phí mặc định cho một buổi học
const int GIA_HOC_PHI_MAC_DINH = 50000;

/// Service chịu trách nhiệm tạo các báo cáo phức tạp bằng cách tổng hợp dữ liệu
/// từ nhiều service và bảng khác nhau.
class ReportService {
  final String tenBangThanhToan = DBHelper.tenBangThanhToan;
  final DiemDanhService _diemDanhService = DiemDanhService();
  final LopHocSinhService _lhsService = LopHocSinhService();
  final HocSinhService _hsService = HocSinhService();
  final CaiDatService _caiDatService = CaiDatService();
  final LichHocChungService _lhcService = LichHocChungService();
  final dbHelper = DBHelper.instance;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  // ===================================================
  // HÀM BÁO CÁO CHÍNH - ĐÃ TỐI ƯU HÓA BATCH
  // ===================================================
  Future<HocPhiTongHop> layBaoCaoHocPhiThang(int idLop, String thang) async {
    final db = await _database;

    // 1. Tải danh sách học sinh của lớp
    final dsHsLop = await _lhsService.docDSHSThuocLop(idLop);

    // ĐỌC THÔNG SỐ CÀI ĐẶT MỘT LẦN DUY NHẤT (Tránh truy vấn lặp trong vòng lặp học sinh)
    final int giaHocPhiMoiBuoi = await _docGiaHocPhiBuoi();
    final int hocPhiThangToiDa = await _docHocPhiThang();
    final int soBuoiChuanThang = await _docSoBuoiChuanThang();

    // TỐI ƯU HÓA: Chạy tính toán song song sử dụng các tham số đã đọc sẵn
    await Future.wait(dsHsLop.map((hs) {
      if (hs.id != null) {
        return _tinhToanVaLuuHoSo(
          hs.id!,
          idLop,
          thang,
          giaHocPhiMoiBuoi: giaHocPhiMoiBuoi,
          hocPhiThangToiDa: hocPhiThangToiDa,
          soBuoiChuanThang: soBuoiChuanThang,
        );
      }
      return Future.value();
    }));

    // BƯỚC 2: TRUY VẤN DỮ LIỆU TỪ DB ĐỂ TẠO BÁO CÁO
    // Lấy dữ liệu thanh toán và tên học sinh
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT 
          T.id_hoc_sinh, T.tong_so_buoi, T.tong_thanh_toan, T.so_tien_da_dong, H.mien_giam, H.so_buoi_du,
          H.ten
      FROM $tenBangThanhToan T
      JOIN ${DBHelper.tenBangHS} H ON T.id_hoc_sinh = H.id
      WHERE T.id_lop = ? AND T.thang = ?
    ''',
      [idLop, thang],
    );

    int tongSoTienCanThu = 0;
    int tongSoTienDaThu = 0;
    int tongSoTienConNo = 0;
    final List<HocSinhNoHocPhi> dsNo = [];

    for (var map in maps) {
      final canThu = map['tong_thanh_toan'] as int? ?? 0;
      final daDong = map['so_tien_da_dong'] as int? ?? 0;
      final conNo = canThu - daDong;

      tongSoTienCanThu += canThu;
      tongSoTienDaThu += daDong;
      tongSoTienConNo += conNo;

      // Chỉ thêm học sinh còn nợ vào danh sách chi tiết
      if (conNo > 0) {
        dsNo.add(
          HocSinhNoHocPhi(
            idHocSinh: map['id_hoc_sinh'] as int,
            tenHocSinh: map['ten'] as String,
            soTienCanNop: canThu,
            soTienDaDong: daDong,
            soTienConNo: conNo,
            mienGiam: map['mien_giam'] as int? ?? 0,
            soBuoiDu: map['so_buoi_du'] as int? ?? 0,
          ),
        );
      }
    }

    // Lấy tổng số buổi từ hồ sơ đầu tiên (Giả định số buổi là như nhau trong cùng một lớp/tháng)
    final int tongSoBuoi = maps.isNotEmpty
        ? maps.first['tong_so_buoi'] as int? ?? 0
        : 0;

    return HocPhiTongHop(
      tongSoBuoi: tongSoBuoi,
      tongSoHocSinh: dsHsLop.length,
      tongSoTienCanThu: tongSoTienCanThu,
      tongSoTienDaThu: tongSoTienDaThu,
      tongSoTienConNo: tongSoTienConNo,
      dsHocSinhConNo: dsNo,
    );
  }

  // ===================================================
  // CÁC HÀM HELPER CHO VIỆC TẠO BÁO CÁO
  // ===================================================

  Future<int> _docGiaHocPhiBuoi() async {
    final String? giaTriString = await _caiDatService.layCaiDat('hoc_phi_buoi');
    if (giaTriString != null) {
      try {
        return int.parse(giaTriString.replaceAll(RegExp(r'[^\d]'), ''));
      } catch (e) {
        print('Lỗi parse học phí buổi từ cài đặt: $e. Dùng giá trị mặc định.');
        return GIA_HOC_PHI_MAC_DINH;
      }
    }
    return GIA_HOC_PHI_MAC_DINH;
  }

  Future<int> _docHocPhiThang() async {
    final String? giaTriString = await _caiDatService.layCaiDat(
      'hoc_phi_thang',
    );
    if (giaTriString != null) {
      try {
        return int.parse(giaTriString.replaceAll(RegExp(r'[^\d]'), ''));
      } catch (e) {
        // Mặc định một giá trị lớn nếu có lỗi
        return 600000;
      }
    }
    return 600000;
  }

  Future<int> _docSoBuoiChuanThang() async {
    final String? giaTriString = await _caiDatService.layCaiDat(
      'so_buoi_chuan_thang',
    );
    if (giaTriString != null) {
      try {
        return int.parse(giaTriString.replaceAll(RegExp(r'[^\d]'), ''));
      } catch (e) {
        return 12; // Mặc định 12 buổi nếu lỗi
      }
    }
    return 12; // Mặc định 12 buổi nếu chưa cài đặt
  }

  Future<int?> _docSoTienDaDong(int idHocSinh, int idLop, String thang) async {
    final db = await _database;
    final maps = await db.query(
      tenBangThanhToan,
      columns: ['so_tien_da_dong'],
      where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
      whereArgs: [idHocSinh, idLop, thang],
    );
    return maps.isNotEmpty ? maps.first['so_tien_da_dong'] as int? : null;
  }

  Future<void> _tinhToanVaLuuHoSo(
    int idHocSinh,
    int idLop,
    String thang, {
    required int giaHocPhiMoiBuoi,
    required int hocPhiThangToiDa,
    required int soBuoiChuanThang,
  }) async {
    final db = await _database;
    final hs = await _hsService.docHocSinhTheoId(idHocSinh);
    final int soBuoiDuHienTai = hs?.soBuoiDu ?? 0;

    // Lấy ngày tham gia của học sinh trong lớp này
    final lopHsRecords = await db.query(
      DBHelper.tenBangLopHS,
      where: 'id_hoc_sinh = ? AND id_lop = ?',
      whereArgs: [idHocSinh, idLop],
      limit: 1,
    );

    DateTime? ngayThamGia;
    if (lopHsRecords.isNotEmpty) {
      ngayThamGia = DateTime.tryParse(
        lopHsRecords.first['ngay_tham_gia'] as String? ?? '',
      );
    }

    final int mienGiam = hs?.mienGiam ?? 0;

    // 1. Lấy tổng số buổi học dự kiến của cá nhân trong tháng
    final int tongSoBuoiDuKien = await _lhcService.demSoBuoiHocCaNhanTrongThang(
      idHocSinh,
      thang,
      ngayThamGia: ngayThamGia, // Truyền ngày tham gia vào đây
    );

    // 2. Lấy số buổi nghỉ (chỉ tính sau ngày nhập học)
    final int soBuoiNghiKhongPhep = await _diemDanhService.demSoBuoiTheoThang(
      idHocSinh,
      idLop,
      thang,
      'Nghỉ không phép',
      ngayBatDauTinh: ngayThamGia,
    );
    final int soBuoiNghiCoPhep = await _diemDanhService.demSoBuoiTheoThang(
      idHocSinh,
      idLop,
      thang,
      'Nghỉ có phép',
      ngayBatDauTinh: ngayThamGia,
    );

    // 3. SỬA: Áp dụng công thức tính tiền thu
    // Số buổi thực học trong tháng
    final int soBuoiThucHoc =
        tongSoBuoiDuKien - soBuoiNghiCoPhep - soBuoiNghiKhongPhep;

    // Số buổi dư được tạo ra trong tháng này (nếu học nhiều hơn số buổi chuẩn)
    final int soBuoiDuTaoRa = (soBuoiThucHoc > soBuoiChuanThang)
        ? (soBuoiThucHoc - soBuoiChuanThang)
        : 0;

    // Tổng số buổi dư có thể dùng để bù trừ
    final int tongSoBuoiDuKhaDung = soBuoiDuHienTai + soBuoiDuTaoRa;

    // Dùng buổi dư để bù cho các buổi nghỉ không phép
    final int soBuoiDuocBuTru = (soBuoiNghiKhongPhep < tongSoBuoiDuKhaDung)
        ? soBuoiNghiKhongPhep
        : tongSoBuoiDuKhaDung;

    // Số buổi dư cuối cùng sau khi đã bù trừ
    final int soBuoiDuCuoiCung = tongSoBuoiDuKhaDung - soBuoiDuocBuTru;

    // Số buổi tính phí cuối cùng = (số buổi phải đóng gốc) - (số buổi được bù trừ)
    int soBuoiTinhPhi = (tongSoBuoiDuKien - soBuoiNghiCoPhep) - soBuoiDuocBuTru;
    if (soBuoiTinhPhi < 0) soBuoiTinhPhi = 0;
    int hocPhiDuKien = soBuoiTinhPhi * giaHocPhiMoiBuoi;

    // 4. Áp dụng mức phí trần TRƯỚC
    int tongThanhToan = hocPhiDuKien;
    if (tongThanhToan > hocPhiThangToiDa) {
      tongThanhToan = hocPhiThangToiDa;
    }

    // 5. Áp dụng miễn giảm SAU KHI đã áp dụng mức phí trần
    if (mienGiam > 0) {
      tongThanhToan = (tongThanhToan * (100 - mienGiam) / 100).round();
    }

    // SỬA: Dùng các cột trong bảng thanh_toan để lưu lại các thông số tính toán
    final newThanhToan = ThanhToan(
      idHocSinh: idHocSinh,
      idLop: idLop,
      thang: thang,
      tongSoBuoi:
          tongSoBuoiDuKien, // Lưu tổng số buổi dự kiến của HS trong tháng
      soBuoiMienGiam100:
          soBuoiNghiCoPhep, // Dùng cột này để lưu số buổi nghỉ có phép
      soBuoiMienGiam50:
          soBuoiNghiKhongPhep, // Dùng cột này để lưu số buổi nghỉ không phép
      soBuoiDuocBuTru: soBuoiDuocBuTru, // Lưu lại số buổi đã được bù
      soBuoiDuConLai: soBuoiDuCuoiCung, // Lưu lại số buổi dư cuối cùng
      tongThanhToan: tongThanhToan,
      soTienDaDong: (await _docSoTienDaDong(idHocSinh, idLop, thang)) ?? 0,
    );

    await db.insert(
      tenBangThanhToan,
      newThanhToan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Cập nhật số buổi dư vào hồ sơ học sinh
    await _hsService.capNhatSoBuoiDu(idHocSinh, soBuoiDuCuoiCung);
  }
}
