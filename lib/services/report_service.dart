// File: lib/services/report_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../utils/db.dart';
import '../models/thanh_toan.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../models/hs.dart';
import 'diem_danh_service.dart';
import 'lop_hoc_sinh_service.dart';
import 'lich_hoc_chung_service.dart';
import 'hoc_sinh_service.dart';
import 'caidat_service.dart';
import 'firebase_sync_service.dart';
import 'tuition_event_service.dart';

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

  static bool isStatusInactive(String? st) {
    if (st == null) return false;
    final s = st.toUpperCase().trim();
    return s == 'NGHI_HOC' ||
        s == 'TAM_NGUNG' ||
        s == 'TAM_NGHI' ||
        s == 'DA_NGHI' ||
        s == 'NGHỈ HỌC' ||
        s == 'TẠM NGỪNG' ||
        s == 'TẠM NGHỈ' ||
        s == 'ĐÃ NGHỈ';
  }

  // ===================================================
  // HÀM BÁO CÁO CHÍNH - ĐÃ TỐI ƯU HÓA BATCH
  // ===================================================
  Future<HocPhiTongHop> layBaoCaoHocPhiThang(int idLop, String thang) async {
    final db = await _database;

    // 1. Tải danh sách học sinh của lớp
    final dsHsLop = await _lhsService.docDSHSThuocLop(idLop);

    // Dọn dẹp các hồ sơ chưa nộp tiền của học sinh không còn thuộc lớp này
    final validHsIds = dsHsLop.map((e) => e.id).whereType<int>().toList();
    if (validHsIds.isNotEmpty) {
      final placeholders = List.filled(validHsIds.length, '?').join(',');
      await db.delete(
        tenBangThanhToan,
        where: 'id_lop = ? AND thang = ? AND id_hoc_sinh NOT IN ($placeholders) AND so_tien_da_dong = 0',
        whereArgs: [idLop, thang, ...validHsIds],
      );
    } else {
      await db.delete(
        tenBangThanhToan,
        where: 'id_lop = ? AND thang = ? AND so_tien_da_dong = 0',
        whereArgs: [idLop, thang],
      );
    }

    // ĐỌC THÔNG SỐ CÀI ĐẶT MỘT LẦN DUY NHẤT (Tránh truy vấn lặp trong vòng lặp học sinh)
    final int giaHocPhiMoiBuoi = await _docGiaHocPhiBuoi();
    final int hocPhiThangToiDa = await _docHocPhiThang();

    // Để tránh deadlock SQLite do việc đọc dữ liệu trong khi transaction ghi đang hoạt động,
    // ta thực hiện tất cả các truy vấn đọc dữ liệu trước ngoài transaction,
    // sau đó gom tất cả thao tác ghi (insert/update) vào một transaction duy nhất để tăng tốc.
    final List<_TinhToanHocSinhResult> dsTinhToan = [];

    for (var hsViewModel in dsHsLop) {
      if (hsViewModel.id != null) {
        final idHocSinh = hsViewModel.id!;
        final int mienGiam = hsViewModel.mienGiam ?? 0;
        int soBuoiDuHienTai = hsViewModel.soBuoiDu;

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

        DateTime? ngayThamGia = parseFlexibleDate(hsViewModel.ngayThamGia);
        DateTime? ngayTamNgung = parseFlexibleDate(hsViewModel.ngayTamNgung);
        DateTime? ngayHocLai = parseFlexibleDate(hsViewModel.ngayHocLaiThucTe);
        DateTime? ngayNghiHoc = parseFlexibleDate(hsViewModel.ngayNghiHoc);
        DateTime? ngayHocLaiSauNghi = parseFlexibleDate(hsViewModel.ngayHocLaiSauNghi);

        final int tongSoBuoiDuKien = await _lhcService.demSoBuoiHocCaNhanTrongThang(
          idHocSinh,
          thang,
          ngayThamGia: ngayThamGia,
          idLop: idLop,
          ngayTamNgung: ngayTamNgung,
          ngayHocLai: ngayHocLai,
          ngayNghiHoc: ngayNghiHoc,
          ngayHocLaiSauNghi: ngayHocLaiSauNghi,
        );

        final int soBuoiChuanThang = await _docSoBuoiChuanThang();



        // 2. Lấy số buổi nghỉ (chỉ tính sau ngày nhập học)
        final int soBuoiNghiKhongPhep = await _diemDanhService.demSoBuoiTheoThang(
          idHocSinh,
          idLop,
          thang,
          'Nghỉ không phép',
          ngayBatDauTinh: ngayThamGia,
        );
        final int soBuoiNghiCoPhep = await demSoBuoiNghiCoPhepTrongThang(
          idHocSinh,
          idLop,
          thang,
          ngayThamGia,
        );
        final int soBuoiHocBu = await _diemDanhService.demSoBuoiTheoThang(
          idHocSinh,
          idLop,
          thang,
          'Học bù',
          ngayBatDauTinh: ngayThamGia,
        );

        // 3. Số buổi học thực tế học sinh tham gia/được tính trong tháng (Nghỉ có phép trừ buổi, Nghỉ không phép vẫn tính tiền)
        int soBuoiHocThucTe = tongSoBuoiDuKien - soBuoiNghiCoPhep + soBuoiHocBu;
        if (soBuoiHocThucTe < 0) soBuoiHocThucTe = 0;

        int soBuoiCanThanhToan = 0;
        int soBuoiVuotChuan = 0;
        int soBuoiDuocBuTru = 0;

        if (soBuoiHocThucTe >= soBuoiChuanThang) {
          soBuoiCanThanhToan = soBuoiChuanThang;
          soBuoiVuotChuan = soBuoiHocThucTe - soBuoiChuanThang;
          soBuoiDuocBuTru = 0;
        } else {
          soBuoiCanThanhToan = soBuoiHocThucTe;
          soBuoiVuotChuan = 0;
          int thieuBuoi = soBuoiChuanThang - soBuoiHocThucTe;
          if (soBuoiDuHienTai > 0 && thieuBuoi > 0) {
            soBuoiDuocBuTru = (soBuoiDuHienTai < thieuBuoi) ? soBuoiDuHienTai : thieuBuoi;
          }
        }

        int soBuoiDuConLai = soBuoiDuHienTai - soBuoiDuocBuTru + soBuoiVuotChuan;
        if (soBuoiDuConLai < 0) soBuoiDuConLai = 0;

        final int soBuoiDuCuoiCung = soBuoiDuConLai;

        int soBuoiTinhPhi = soBuoiCanThanhToan - soBuoiDuocBuTru;
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

        // Bỏ qua học sinh đã nghỉ học/tạm ngừng từ trước tháng này (0 buổi dự kiến, 0 điểm danh, 0 nợ, 0 đã đóng)
        if (isStatusInactive(hsViewModel.trangThai) &&
            tongSoBuoiDuKien == 0 &&
            soBuoiNghiCoPhep == 0 &&
            soBuoiNghiKhongPhep == 0 &&
            soBuoiHocBu == 0 &&
            tongThanhToan == 0 &&
            soTienDaDong == 0) {
          await db.delete(
            tenBangThanhToan,
            where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ? AND so_tien_da_dong = 0',
            whereArgs: [idHocSinh, idLop, thang],
          );
          continue;
        }

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

    for (var item in dsTinhToan) {
      final recordKey = '${item.idHocSinh}_${idLop}_$thang';
      final ttMap = {
        'id_hoc_sinh': item.idHocSinh,
        'id_lop': idLop,
        'thang': thang,
        'tong_so_buoi': item.tongSoBuoiDuKien,
        'so_buoi_mien_giam_100': item.soBuoiNghiCoPhep,
        'so_buoi_mien_giam_50': item.soBuoiNghiKhongPhep,
        'so_buoi_duoc_bu_tru': item.soBuoiDuocBuTru,
        'so_buoi_du_con_lai': item.soBuoiDuCuoiCung,
        'tong_thanh_toan': item.tongThanhToan,
        'so_tien_da_dong': item.soTienDaDong,
      };
      FirebaseSyncService.instance
          .pushRecordToCloud(tenBangThanhToan, recordKey, ttMap)
          .catchError((e) => null);
    }

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
            tongSoBuoi: map['tong_so_buoi'] as int? ?? 12,
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
      tongSoHocSinh: maps.length,
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
    final int mienGiam = hsModel?.mienGiam ?? 0;
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
    DateTime? ngayTamNgung;
    DateTime? ngayHocLai;
    DateTime? ngayNghiHoc;
    DateTime? ngayHocLaiSauNghi;
    String trangThai = 'DANG_HOC';

    if (ngayThamGiaStr != null && ngayThamGiaStr.isNotEmpty) {
      ngayThamGia = parseFlexibleDate(ngayThamGiaStr);
    }

    final lopHsRecords = await db.query(
      DBHelper.tenBangLopHS,
      where: 'id_hoc_sinh = ? AND id_lop = ?',
      whereArgs: [idHocSinh, idLop],
      limit: 1,
    );
    if (lopHsRecords.isNotEmpty) {
      final rec = lopHsRecords.first;
      trangThai = rec['trang_thai'] as String? ?? 'DANG_HOC';
      if (ngayThamGia == null) {
        ngayThamGia = parseFlexibleDate(rec['ngay_tham_gia'] as String?);
      }
      ngayTamNgung = parseFlexibleDate(rec['ngay_tam_ngung'] as String?);
      ngayHocLai = parseFlexibleDate(rec['ngay_hoc_lai_thuc_te'] as String?);
      ngayNghiHoc = parseFlexibleDate(rec['ngay_nghi_hoc'] as String?);
      ngayHocLaiSauNghi = parseFlexibleDate(rec['ngay_hoc_lai_sau_nghi'] as String?);
    }

    final int tongSoBuoiDuKien = await _lhcService.demSoBuoiHocCaNhanTrongThang(
      idHocSinh,
      thang,
      ngayThamGia: ngayThamGia,
      idLop: idLop,
      ngayTamNgung: ngayTamNgung,
      ngayHocLai: ngayHocLai,
      ngayNghiHoc: ngayNghiHoc,
      ngayHocLaiSauNghi: ngayHocLaiSauNghi,
    );

    final int soBuoiChuanThang = await _docSoBuoiChuanThang();



    // 2. Lấy số buổi nghỉ (chỉ tính sau ngày nhập học)
    final int soBuoiNghiKhongPhep = await _diemDanhService.demSoBuoiTheoThang(
      idHocSinh,
      idLop,
      thang,
      'Nghỉ không phép',
      ngayBatDauTinh: ngayThamGia,
    );
    final int soBuoiNghiCoPhep = await demSoBuoiNghiCoPhepTrongThang(
      idHocSinh,
      idLop,
      thang,
      ngayThamGia,
    );
    final int soBuoiHocBu = await _diemDanhService.demSoBuoiTheoThang(
      idHocSinh,
      idLop,
      thang,
      'Học bù',
      ngayBatDauTinh: ngayThamGia,
    );

    // 3. Số buổi học thực tế học sinh tham gia/được tính trong tháng (Nghỉ có phép trừ buổi, Nghỉ không phép vẫn tính tiền)
    int soBuoiHocThucTe = tongSoBuoiDuKien - soBuoiNghiCoPhep + soBuoiHocBu;
    if (soBuoiHocThucTe < 0) soBuoiHocThucTe = 0;

    int soBuoiCanThanhToan = 0;
    int soBuoiVuotChuan = 0;
    int soBuoiDuocBuTru = 0;

    if (soBuoiHocThucTe >= soBuoiChuanThang) {
      soBuoiCanThanhToan = soBuoiChuanThang;
      soBuoiVuotChuan = soBuoiHocThucTe - soBuoiChuanThang;
      soBuoiDuocBuTru = 0;
    } else {
      soBuoiCanThanhToan = soBuoiHocThucTe;
      soBuoiVuotChuan = 0;
      int thieuBuoi = soBuoiChuanThang - soBuoiHocThucTe;
      if (soBuoiDuHienTai > 0 && thieuBuoi > 0) {
        soBuoiDuocBuTru = (soBuoiDuHienTai < thieuBuoi) ? soBuoiDuHienTai : thieuBuoi;
      }
    }

    int soBuoiDuConLai = soBuoiDuHienTai - soBuoiDuocBuTru + soBuoiVuotChuan;
    if (soBuoiDuConLai < 0) soBuoiDuConLai = 0;

    final int soBuoiDuCuoiCung = soBuoiDuConLai;

    int soBuoiTinhPhi = soBuoiCanThanhToan - soBuoiDuocBuTru;
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

    // Bỏ qua học sinh đã nghỉ học/tạm ngừng từ trước tháng này (0 buổi dự kiến, 0 điểm danh, 0 nợ, 0 đã đóng)
    if (isStatusInactive(trangThai) &&
        tongSoBuoiDuKien == 0 &&
        soBuoiNghiCoPhep == 0 &&
        soBuoiNghiKhongPhep == 0 &&
        soBuoiHocBu == 0 &&
        tongThanhToan == 0 &&
        soTienDaDong == 0) {
      await db.delete(
        tenBangThanhToan,
        where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ? AND so_tien_da_dong = 0',
        whereArgs: [idHocSinh, idLop, thang],
      );
      return;
    }

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

    final recordKey = '${idHocSinh}_${idLop}_$thang';
    FirebaseSyncService.instance
        .pushRecordToCloud(tenBangThanhToan, recordKey, newThanhToan.toMap())
        .catchError((e) => null);

    // Cập nhật số buổi dư vào hồ sơ học sinh
    await db.update(
      DBHelper.tenBangHS,
      {'so_buoi_du': soBuoiDuCuoiCung},
      where: 'id = ?',
      whereArgs: [idHocSinh],
    );
  }

  Future<int> demSoBuoiNghiCoPhepTrongThang(
    int idHocSinh,
    int idLop,
    String thang,
    DateTime? ngayThamGia,
  ) async {
    final db = await _database;
    int countDD = await _diemDanhService.demSoBuoiTheoThang(
      idHocSinh,
      idLop,
      thang,
      'Nghỉ có phép',
      ngayBatDauTinh: ngayThamGia,
    );

    try {
      final parts = thang.split('-');
      if (parts.length != 2) return countDD;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final firstDayMonthStr = '$thang-01';
      final lastDayOfMonth = DateTime(year, month + 1, 0);
      final lastDayMonthStr = DateFormat('yyyy-MM-dd').format(lastDayOfMonth);

      final donNghiRows = await db.query(
        DBHelper.tenBangDonNghiHoc,
        where: 'id_hoc_sinh = ? AND id_lop = ? AND tu_ngay <= ? AND den_ngay >= ?',
        whereArgs: [idHocSinh, idLop, lastDayMonthStr, firstDayMonthStr],
      );

      if (donNghiRows.isEmpty) return countDD;

      final lichCaNhan = await _lhcService.layLichHocCaNhanCuaHocSinh(idHocSinh, idLop: idLop);
      if (lichCaNhan.isEmpty) return countDD;

      final Map<String, int> weekdayMap = {
        'Thứ Hai': 1, 'Thứ Ba': 2, 'Thứ Tư': 3, 'Thứ Năm': 4, 'Thứ Sáu': 5, 'Thứ Bảy': 6, 'Chủ Nhật': 7,
      };
      final Set<int> lichHocWeekdays = lichCaNhan
          .map((l) => weekdayMap[l.ngayTrongTuan])
          .where((d) => d != null)
          .cast<int>()
          .toSet();

      int extraFromDon = 0;

      for (int day = 1; day <= lastDayOfMonth.day; day++) {
        final currentDate = DateTime(year, month, day);
        if (!lichHocWeekdays.contains(currentDate.weekday)) continue;

        if (ngayThamGia != null && currentDate.isBefore(DateTime(ngayThamGia.year, ngayThamGia.month, ngayThamGia.day))) {
          continue;
        }

        final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

        bool inDon = false;
        for (var row in donNghiRows) {
          final tu = row['tu_ngay'] as String;
          final den = row['den_ngay'] as String;
          if (dateStr.compareTo(tu) >= 0 && dateStr.compareTo(den) <= 0) {
            inDon = true;
            break;
          }
        }
        if (!inDon) continue;

        final startStr = '$dateStr 00:00:00';
        final endStr = '$dateStr 23:59:59';
        final ddRecords = await db.query(
          DBHelper.tenBangDiemDanh,
          where: 'id_hoc_sinh = ? AND id_lop = ? AND gio_diem_danh BETWEEN ? AND ?',
          whereArgs: [idHocSinh, idLop, startStr, endStr],
        );

        if (ddRecords.isEmpty) {
          extraFromDon++;
        }
      }
      return countDD + extraFromDon;
    } catch (_) {
      return countDD;
    }
  }

  // Khởi tạo và tính toán lại toàn bộ số buổi dư cho tất cả học sinh từ ngày tham gia đến tháng hiện tại
  Future<void> recalculateAllStudentsRemainingSessions() async {
    final db = await _database;
    
    // 1. Đặt tất cả so_buoi_du của học sinh về 0
    await db.update(DBHelper.tenBangHS, {'so_buoi_du': 0});
    
    // 2. Đặt các trường tạm liên quan đến buổi dư của bảng thanh_toan về 0
    await db.update(tenBangThanhToan, {
      'so_buoi_duoc_bu_tru': 0,
      'so_buoi_du_con_lai': 0,
    });

    final List<Map<String, dynamic>> hsMaps = await db.query(DBHelper.tenBangHS);
    if (hsMaps.isEmpty) return;

    final int giaHocPhiMoiBuoi = await _docGiaHocPhiBuoi();
    final int hocPhiThangToiDa = await _docHocPhiThang();
    final int soBuoiChuanThang = await _docSoBuoiChuanThang();

    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    for (var hsMap in hsMaps) {
      final int idHocSinh = hsMap['id'] as int;

      // Lấy danh sách tất cả các lớp của học sinh này
      final List<Map<String, dynamic>> lhsList = await db.query(
        DBHelper.tenBangLopHS,
        where: 'id_hoc_sinh = ?',
        whereArgs: [idHocSinh],
      );

      if (lhsList.isEmpty) continue;

      for (var lhs in lhsList) {
        final int idLop = lhs['id_lop'] as int;
        String? ngayThamGiaStr = lhs['ngay_tham_gia'] as String?;

        DateTime startDt = now;
        if (ngayThamGiaStr != null && ngayThamGiaStr.isNotEmpty) {
          final parsed = parseFlexibleDate(ngayThamGiaStr);
          if (parsed != null) startDt = parsed;
        } else {
          // Tìm ngày điểm danh sớm nhất của học sinh trong lớp này
          final earliestDd = await db.query(
            DBHelper.tenBangDiemDanh,
            columns: ['gio_diem_danh'],
            where: 'id_hoc_sinh = ? AND id_lop = ?',
            whereArgs: [idHocSinh, idLop],
            orderBy: 'gio_diem_danh ASC',
            limit: 1,
          );
          if (earliestDd.isNotEmpty) {
            final parsedDd = parseFlexibleDate(earliestDd.first['gio_diem_danh'] as String?);
            if (parsedDd != null) startDt = parsedDd;
          }
        }

        final Set<String> targetMonths = {};
        int y = startDt.year;
        int m = startDt.month;
        while (y < currentYear || (y == currentYear && m <= currentMonth)) {
          final mStr = '$y-${m.toString().padLeft(2, '0')}';
          targetMonths.add(mStr);
          m++;
          if (m > 12) {
            m = 1;
            y++;
          }
        }

        final existingPayMonths = await db.query(
          tenBangThanhToan,
          columns: ['thang'],
          where: 'id_hoc_sinh = ? AND id_lop = ?',
          whereArgs: [idHocSinh, idLop],
        );
        for (var row in existingPayMonths) {
          final t = row['thang'] as String?;
          if (t != null && t.isNotEmpty) {
            targetMonths.add(t);
          }
        }

        final sortedMonths = targetMonths.toList()..sort();

        for (var thang in sortedMonths) {
          await _tinhToanVaLuuHoSo(
            idHocSinh,
            idLop,
            thang,
            giaHocPhiMoiBuoi: giaHocPhiMoiBuoi,
            hocPhiThangToiDa: hocPhiThangToiDa,
            soBuoiChuanThang: soBuoiChuanThang,
            ngayThamGiaStr: ngayThamGiaStr,
          );
        }
      }
    }

    // Đảm bảo số buổi dư của bất kỳ học sinh nào nếu < 0 sẽ được đưa về 0
    await db.execute('UPDATE ${DBHelper.tenBangHS} SET so_buoi_du = 0 WHERE so_buoi_du < 0');

    TuitionEventService().notifyTuitionChanged();
  }

  static DateTime? parseFlexibleDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return null;
    final str = dateStr.trim();
    final parsedIso = DateTime.tryParse(str);
    if (parsedIso != null) {
      return DateTime(parsedIso.year, parsedIso.month, parsedIso.day);
    }
    if (str.contains('/')) {
      final parts = str.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2].split(' ')[0]);
        if (day != null && month != null && year != null) {
          return DateTime(year, month, day);
        }
      }
    }
    if (str.contains('-')) {
      final parts = str.split('-');
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final day = int.tryParse(parts[2].split(' ')[0]);
          if (year != null && month != null && day != null) {
            return DateTime(year, month, day);
          }
        } else {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2].split(' ')[0]);
          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
    }
    return null;
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
