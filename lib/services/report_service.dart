// File: lib/services/report_service.dart

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../models/thanh_toan.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../models/hs.dart';
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

    // Để tránh deadlock SQLite do việc đọc dữ liệu trong khi transaction ghi đang hoạt động,
    // ta thực hiện tất cả các truy vấn đọc dữ liệu trước ngoài transaction,
    // sau đó gom tất cả thao tác ghi (insert/update) vào một transaction duy nhất để tăng tốc.
    final List<_TinhToanHocSinhResult> dsTinhToan = [];

    for (var hsViewModel in dsHsLop) {
      if (hsViewModel.id != null) {
        final idHocSinh = hsViewModel.id!;
        int soBuoiDuHienTai = hsViewModel.soBuoiDu ?? 0;

        // Đọc bản ghi thanh toán cũ nếu có
        final List<Map<String, dynamic>> existingRecords = await db.query(
          tenBangThanhToan,
          where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
          whereArgs: [idHocSinh, idLop, thang],
        );

        if (existingRecords.isNotEmpty) {
          final existing = existingRecords.first;
          final int prevNghiCoPhep = existing['so_buoi_mien_giam_100'] as int? ?? 0;
          final int prevDuocBuTru = existing['so_buoi_duoc_bu_tru'] as int? ?? 0;
          
          final int delta = prevNghiCoPhep - prevDuocBuTru;
          soBuoiDuHienTai = soBuoiDuHienTai - delta;
          if (soBuoiDuHienTai < 0) soBuoiDuHienTai = 0;
        }

        DateTime? ngayThamGia;
        if (hsViewModel.ngayThamGia.isNotEmpty) {
          ngayThamGia = DateTime.tryParse(hsViewModel.ngayThamGia);
        }

        final int mienGiam = hsViewModel.mienGiam ?? 0;

        // 1. Lấy tổng số buổi học dự kiến của cá nhân trong tháng theo lớp này
        final int tongSoBuoiDuKien = await _lhcService.demSoBuoiHocCaNhanTrongThang(
          idHocSinh,
          thang,
          ngayThamGia: ngayThamGia,
          idLop: idLop,
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

        // 3. Công thức tính tiền thu mới khấu trừ theo buổi dư và chuyển tiếp nghỉ có phép
        final int soBuoiDuocBuTru = (soBuoiDuHienTai < tongSoBuoiDuKien)
            ? soBuoiDuHienTai
            : tongSoBuoiDuKien;

        final int soBuoiDuChuaDung = soBuoiDuHienTai - soBuoiDuocBuTru;
        final int soBuoiDuCuoiCung = soBuoiDuChuaDung + soBuoiNghiCoPhep;

        int soBuoiTinhPhi = tongSoBuoiDuKien - soBuoiDuocBuTru;
        if (soBuoiTinhPhi < 0) soBuoiTinhPhi = 0;
        
        int hocPhiDuKien = soBuoiTinhPhi * giaHocPhiMoiBuoi;

        int tongThanhToan = hocPhiDuKien;
        if (tongThanhToan > hocPhiThangToiDa) {
          tongThanhToan = hocPhiThangToiDa;
        }

        if (mienGiam > 0) {
          tongThanhToan = (tongThanhToan * (100 - mienGiam) / 100).round();
        }

        final int soTienDaDong = existingRecords.isNotEmpty
            ? existingRecords.first['so_tien_da_dong'] as int? ?? 0
            : 0;

        dsTinhToan.add(_TinhToanHocSinhResult(
          idHocSinh: idHocSinh,
          tongSoBuoiDuKien: tongSoBuoiDuKien,
          soBuoiNghiCoPhep: soBuoiNghiCoPhep,
          soBuoiNghiKhongPhep: soBuoiNghiKhongPhep,
          soBuoiDuocBuTru: soBuoiDuocBuTru,
          soBuoiDuCuoiCung: soBuoiDuCuoiCung,
          tongThanhToan: tongThanhToan,
          soTienDaDong: soTienDaDong,
        ));
      }
    }

    // TỐI ƯU HÓA: Thực hiện các thao tác ghi dữ liệu trong một transaction duy nhất để tăng tốc tối đa
    await db.transaction((txn) async {
      for (var item in dsTinhToan) {
        final newThanhToan = ThanhToan(
          idHocSinh: item.idHocSinh,
          idLop: idLop,
          thang: thang,
          tongSoBuoi: item.tongSoBuoiDuKien,
          soBuoiMienGiam100: item.soBuoiNghiCoPhep,
          soBuoiMienGiam50: item.soBuoiNghiKhongPhep,
          soBuoiDuocBuTru: item.soBuoiDuocBuTru,
          soBuoiDuConLai: item.soBuoiDuCuoiCung,
          tongThanhToan: item.tongThanhToan,
          soTienDaDong: item.soTienDaDong,
        );

        await txn.insert(
          tenBangThanhToan,
          newThanhToan.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        await txn.update(
          DBHelper.tenBangHS,
          {'so_buoi_du': item.soBuoiDuCuoiCung},
          where: 'id = ?',
          whereArgs: [item.idHocSinh],
        );
      }
    });

    // BƯỚC 2: TRUY VẤN DỮ LIỆU TỪ DB ĐỂ TẠO BÁO CÁO
    // Lấy dữ liệu thanh toán và tên học sinh
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT 
          T.id_hoc_sinh, T.tong_so_buoi, T.tong_thanh_toan, T.so_tien_da_dong, H.mien_giam, H.so_buoi_du,
          H.ten, H.sdt
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
            sdt: map['sdt'] as String?,
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
    DatabaseExecutor? executor,
    HS? hs,
    String? ngayThamGiaStr,
  }) async {
    final db = executor ?? await _database;
    final hsModel = hs ?? await _hsService.docHocSinhTheoId(idHocSinh);
    int soBuoiDuHienTai = hsModel?.soBuoiDu ?? 0;

    // Đọc bản ghi thanh toán cũ nếu có để đảm bảo tính idempotent (tránh cộng dồn vô hạn khi xem báo cáo)
    final List<Map<String, dynamic>> existingRecords = await db.query(
      tenBangThanhToan,
      where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
      whereArgs: [idHocSinh, idLop, thang],
    );

    if (existingRecords.isNotEmpty) {
      final existing = existingRecords.first;
      final int prevNghiCoPhep = existing['so_buoi_mien_giam_100'] as int? ?? 0;
      final int prevDuocBuTru = existing['so_buoi_duoc_bu_tru'] as int? ?? 0;
      
      final int delta = prevNghiCoPhep - prevDuocBuTru;
      soBuoiDuHienTai = soBuoiDuHienTai - delta;
      if (soBuoiDuHienTai < 0) soBuoiDuHienTai = 0;
    }

    DateTime? ngayThamGia;
    if (ngayThamGiaStr != null) {
      if (ngayThamGiaStr.isNotEmpty) {
        ngayThamGia = DateTime.tryParse(ngayThamGiaStr);
      }
    } else {
      // Lấy ngày tham gia của học sinh trong lớp này
      final lopHsRecords = await db.query(
        DBHelper.tenBangLopHS,
        where: 'id_hoc_sinh = ? AND id_lop = ?',
        whereArgs: [idHocSinh, idLop],
        limit: 1,
      );
      if (lopHsRecords.isNotEmpty) {
        ngayThamGia = DateTime.tryParse(
          lopHsRecords.first['ngay_tham_gia'] as String? ?? '',
        );
      }
    }

    final int mienGiam = hsModel?.mienGiam ?? 0;

    // 1. Lấy tổng số buổi học dự kiến của cá nhân trong tháng theo lớp này
    final int tongSoBuoiDuKien = await _lhcService.demSoBuoiHocCaNhanTrongThang(
      idHocSinh,
      thang,
      ngayThamGia: ngayThamGia,
      idLop: idLop,
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

    // 3. Công thức tính tiền thu mới khấu trừ theo buổi dư và chuyển tiếp nghỉ có phép
    // Số buổi dư được sử dụng để bù trừ cho tháng này (không vượt quá tổng số buổi dự kiến)
    final int soBuoiDuocBuTru = (soBuoiDuHienTai < tongSoBuoiDuKien)
        ? soBuoiDuHienTai
        : tongSoBuoiDuKien;

    // Số buổi dư còn lại sau khi đã khấu trừ cho các buổi dự kiến
    final int soBuoiDuChuaDung = soBuoiDuHienTai - soBuoiDuocBuTru;

    // Số buổi dư cuối cùng mang sang tháng sau (bao gồm số chưa dùng + số nghỉ có phép tháng này)
    final int soBuoiDuCuoiCung = soBuoiDuChuaDung + soBuoiNghiCoPhep;

    // Số buổi tính phí của tháng này (số buổi dự kiến trừ đi số buổi dư đã khấu trừ)
    int soBuoiTinhPhi = tongSoBuoiDuKien - soBuoiDuocBuTru;
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
    final List<Map<String, dynamic>> mapsDaDong = await db.query(
      tenBangThanhToan,
      columns: ['so_tien_da_dong'],
      where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
      whereArgs: [idHocSinh, idLop, thang],
    );
    final int soTienDaDong = mapsDaDong.isNotEmpty ? mapsDaDong.first['so_tien_da_dong'] as int? ?? 0 : 0;

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
      soBuoiDuocBuTru: soBuoiDuocBuTru, // Lưu lại số buổi đã được bù trừ học phí
      soBuoiDuConLai: soBuoiDuCuoiCung, // Lưu lại số buổi dư mang sang tháng sau
      tongThanhToan: tongThanhToan,
      soTienDaDong: soTienDaDong,
    );

    await db.insert(
      tenBangThanhToan,
      newThanhToan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Cập nhật số buổi dư vào hồ sơ học sinh
    await db.update(
      DBHelper.tenBangHS,
      {'so_buoi_du': soBuoiDuCuoiCung},
      where: 'id = ?',
      whereArgs: [idHocSinh],
    );
  }

  // Khởi tạo và tính toán lại toàn bộ số buổi dư cho tất cả học sinh theo thứ tự thời gian
  Future<void> recalculateAllStudentsRemainingSessions() async {
    final db = await _database;
    
    // 1. Đặt tất cả so_buoi_du của học sinh về 0
    await db.update(DBHelper.tenBangHS, {'so_buoi_du': 0});
    
    // 2. Đặt các trường tạm liên quan đến buổi dư của bảng thanh_toan về 0
    await db.update(tenBangThanhToan, {
      'so_buoi_duoc_bu_tru': 0,
      'so_buoi_du_con_lai': 0,
    });

    // 3. Lấy danh sách ID học sinh
    final List<Map<String, dynamic>> hsMaps = await db.query(DBHelper.tenBangHS);
    final List<int> studentIds = hsMaps.map((m) => m['id'] as int).toList();

    // 4. Lấy tất cả các tháng thanh toán hiện có, sắp xếp theo thứ tự thời gian tăng dần
    final List<Map<String, dynamic>> monthMaps = await db.rawQuery(
      'SELECT DISTINCT thang FROM $tenBangThanhToan ORDER BY thang ASC'
    );
    final List<String> months = monthMaps.map((m) => m['thang'] as String).toList();
    
    if (months.isEmpty || studentIds.isEmpty) return;

    final int giaHocPhiMoiBuoi = await _docGiaHocPhiBuoi();
    final int hocPhiThangToiDa = await _docHocPhiThang();
    final int soBuoiChuanThang = await _docSoBuoiChuanThang();

    // 5. Tính toán tuần tự từ tháng cũ nhất đến mới nhất
    for (var thang in months) {
      for (var idHocSinh in studentIds) {
        // Lấy các lớp học sinh có bản ghi thanh toán trong tháng này
        final List<Map<String, dynamic>> classMaps = await db.query(
          tenBangThanhToan,
          columns: ['id_lop'],
          where: 'id_hoc_sinh = ? AND thang = ?',
          whereArgs: [idHocSinh, thang],
        );
        
        for (var row in classMaps) {
          final int idLop = row['id_lop'] as int;
          await _tinhToanVaLuuHoSo(
            idHocSinh,
            idLop,
            thang,
            giaHocPhiMoiBuoi: giaHocPhiMoiBuoi,
            hocPhiThangToiDa: hocPhiThangToiDa,
            soBuoiChuanThang: soBuoiChuanThang,
          );
        }
      }
    }
  }
}

// Lớp phụ trợ lưu trữ kết quả tính toán tạm thời của học sinh
class _TinhToanHocSinhResult {
  final int idHocSinh;
  final int tongSoBuoiDuKien;
  final int soBuoiNghiCoPhep;
  final int soBuoiNghiKhongPhep;
  final int soBuoiDuocBuTru;
  final int soBuoiDuCuoiCung;
  final int tongThanhToan;
  final int soTienDaDong;

  _TinhToanHocSinhResult({
    required this.idHocSinh,
    required this.tongSoBuoiDuKien,
    required this.soBuoiNghiCoPhep,
    required this.soBuoiNghiKhongPhep,
    required this.soBuoiDuocBuTru,
    required this.soBuoiDuCuoiCung,
    required this.tongThanhToan,
    required this.soTienDaDong,
  });
}
