// File: lib/services/report_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../utils/db.dart';
import '../models/lop.dart';
import '../models/thanh_toan.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../models/lich_hoc_chung.dart';
import '../models/report_models.dart';
import 'lop_hoc_sinh_service.dart';
import 'caidat_service.dart';
import 'firebase_sync_service.dart';
import 'tuition_event_service.dart';
import 'session_ledger_service.dart';

// Giả định: Giá học phí mặc định cho một buổi học
const int GIA_HOC_PHI_MAC_DINH = 50000;

/// Service chịu trách nhiệm tạo các báo cáo phức tạp bằng cách tổng hợp dữ liệu
/// từ nhiều service và bảng khác nhau.
class ReportService {
  final String tenBangThanhToan = DBHelper.tenBangThanhToan;
  final LopHocSinhService _lhsService = LopHocSinhService();
  final CaiDatService _caiDatService = CaiDatService();
  final dbHelper = DBHelper.instance;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  /// Tạo dữ liệu báo cáo thống nhất (FacilityReportData) cho toàn bộ cơ sở hoặc 1 lớp cụ thể
  Future<FacilityReportData> generateFacilityReport(
    ReportRequest request,
  ) async {
    final db = await _database;

    // 1. Xác định danh sách các lớp cần làm báo cáo
    List<Lop> targetLops = [];
    if (request.scope == ReportScope.singleClass && request.classId != null) {
      final lopRows = await db.query(
        DBHelper.tenBangLop,
        where: 'id = ?',
        whereArgs: [request.classId],
      );
      if (lopRows.isNotEmpty) {
        targetLops.add(Lop.fromMap(lopRows.first));
      }
    } else {
      final lopRows = await db.query(
        DBHelper.tenBangLop,
        orderBy: 'khoi ASC, ten ASC',
      );
      targetLops = lopRows.map((r) => Lop.fromMap(r)).toList();
    }

    final startStr = DateFormat('yyyy-MM-dd').format(request.startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(request.endDate);
    final endNextDayStr = DateFormat(
      'yyyy-MM-dd',
    ).format(request.endDate.add(const Duration(days: 1)));

    List<ClassReportData> classReports = [];
    int globalTotalExpectedTuition = 0;
    int globalTotalCollectedTuition = 0;
    int globalTotalDebtTuition = 0;
    double globalTotalPresentSessions = 0;
    double globalTotalSessionsCount = 0;
    final Set<int> uniqueStudentIds = {};

    for (var lop in targetLops) {
      final lopId = lop.id!;

      // 2. Tải danh sách học sinh thuộc lớp
      final hsLopViewModels = await _lhsService.docDSHSThuocLop(lopId);

      int activeCount = 0;
      int pausedCount = 0;
      int leftCount = 0;

      for (var vm in hsLopViewModels) {
        if (_lhsService.isStudentPaused(vm)) {
          pausedCount++;
        } else if (!_lhsService.hoatDongTrongNgay(vm, request.endDate)) {
          leftCount++;
        } else {
          activeCount++;
        }
      }

      // 3. Tải dữ liệu điểm danh trong khoảng thời gian
      final List<Map<String, dynamic>> attRows = await db.rawQuery(
        '''
        SELECT id_hoc_sinh, trang_thai, count(*) as cnt
        FROM ${DBHelper.tenBangDiemDanh}
        WHERE id_lop = ? AND gio_diem_danh >= ? AND gio_diem_danh < ?
        GROUP BY id_hoc_sinh, trang_thai
        ''',
        [lopId, '$startStr 00:00:00', '$endNextDayStr 00:00:00'],
      );

      final Map<int, Map<String, int>> hsAttMap = {};
      for (var row in attRows) {
        final hsId = row['id_hoc_sinh'] as int;
        final st = row['trang_thai'] as String? ?? 'Có mặt';
        final cnt = (row['cnt'] as num).toInt();
        hsAttMap.putIfAbsent(hsId, () => {})[st] = cnt;
      }

      // Tải tổng số ca học của lớp trong khoảng thời gian
      final List<Map<String, dynamic>> sessionCountRow = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT gio_diem_danh) as total_sessions
        FROM ${DBHelper.tenBangDiemDanh}
        WHERE id_lop = ? AND gio_diem_danh >= ? AND gio_diem_danh < ?
        ''',
        [lopId, '$startStr 00:00:00', '$endNextDayStr 00:00:00'],
      );
      final int totalClassSessions =
          (sessionCountRow.first['total_sessions'] as num?)?.toInt() ?? 0;

      List<StudentAttendanceReportItem> attReportList = [];
      int classTotalPresent = 0;
      int classTotalSessions = 0;

      for (var vm in hsLopViewModels) {
        if (vm.id == null) continue;
        final hsId = vm.id!;
        final counts = hsAttMap[hsId] ?? {};

        final present =
            (counts['Có mặt'] ?? 0) +
            (counts['Trễ'] ?? 0) +
            (counts['Học bù'] ?? 0);
        final excused = counts['Nghỉ có phép'] ?? 0;
        final unexcused = counts['Nghỉ không phép'] ?? 0;
        final totalSess = present + excused + unexcused;

        classTotalPresent += present;
        classTotalSessions += totalSess;

        final rate = totalSess > 0 ? (present / totalSess) : 0.0;

        attReportList.add(
          StudentAttendanceReportItem(
            studentId: hsId,
            studentName: vm.ten,
            totalSessions: totalSess,
            presentCount: present,
            excusedAbsenceCount: excused,
            unexcusedAbsenceCount: unexcused,
            attendanceRate: rate,
          ),
        );
      }

      final double classAttendanceRate = classTotalSessions > 0
          ? (classTotalPresent / classTotalSessions)
          : 0.0;

      // 4. Tải dữ liệu học phí
      List<StudentTuitionReportItem> tuitionReportList = [];
      int classExpectedTuition = 0;
      int classCollectedTuition = 0;
      int classDebtTuition = 0;

      final List<Map<String, dynamic>> ttRows = await db.rawQuery(
        '''
        SELECT TT.*, HS.ten as ten_hoc_sinh, HS.sdt
        FROM ${DBHelper.tenBangThanhToan} TT
        JOIN ${DBHelper.tenBangHS} HS ON TT.id_hoc_sinh = HS.id
        WHERE TT.id_lop = ? AND TT.thang = ?
        ''',
        [lopId, request.monthStr],
      );

      for (var row in ttRows) {
        final hsId = row['id_hoc_sinh'] as int;
        final name = row['ten_hoc_sinh'] as String? ?? '';
        final sdt = row['sdt'] as String?;
        final expected = (row['tong_thanh_toan'] as num?)?.toInt() ?? 0;
        final paid = (row['so_tien_da_dong'] as num?)?.toInt() ?? 0;
        final debt = (expected - paid) > 0 ? (expected - paid) : 0;
        final discount = (row['so_buoi_mien_giam_50'] as num?)?.toInt() ?? 0;

        classExpectedTuition += expected;
        classCollectedTuition += paid;
        classDebtTuition += debt;

        tuitionReportList.add(
          StudentTuitionReportItem(
            studentId: hsId,
            studentName: name,
            totalFee: expected,
            paidAmount: paid,
            debtAmount: debt,
            discount: discount,
            phone: sdt,
          ),
        );
      }

      // 5. Tải dữ liệu đánh giá tháng (NhanXetThang)
      List<StudentEvaluationReportItem> evalReportList = [];
      double sumScores = 0.0;
      int evalCount = 0;

      final List<Map<String, dynamic>> nxRows = await db.rawQuery(
        '''
        SELECT NX.*, HS.ten as ten_hoc_sinh
        FROM ${DBHelper.tenBangNhanXetThang} NX
        JOIN ${DBHelper.tenBangHS} HS ON NX.id_hoc_sinh = HS.id
        WHERE NX.id_lop = ? AND NX.thang = ?
        ''',
        [lopId, request.monthStr],
      );

      for (var row in nxRows) {
        final hsId = row['id_hoc_sinh'] as int;
        final name = row['ten_hoc_sinh'] as String? ?? '';
        final diemCc = (row['diem_chuyen_can'] as num?)?.toDouble() ?? 0.0;
        final diemTd = (row['diem_thai_do'] as num?)?.toDouble() ?? 0.0;
        final diemBt = (row['diem_bai_tap'] as num?)?.toDouble() ?? 0.0;
        final diemKt = (row['diem_kiem_tra'] as num?)?.toDouble() ?? 0.0;
        final diemTb = (row['diem_trung_binh'] as num?)?.toDouble() ?? 0.0;
        final rank = row['xep_hang'] as String? ?? 'Bạc';
        final remark = row['nhan_xet_chung'] as String? ?? 'Chưa có nhận xét';

        if (diemTb > 0) {
          sumScores += diemTb;
          evalCount++;
        }

        evalReportList.add(
          StudentEvaluationReportItem(
            studentId: hsId,
            studentName: name,
            attendanceScore: diemCc,
            attitudeScore: diemTd,
            homeworkScore: diemBt,
            testScore: diemKt,
            averageScore: diemTb,
            rank: rank,
            remark: remark,
          ),
        );
      }

      final double avgClassScore = evalCount > 0
          ? (sumScores / evalCount)
          : 0.0;

      final classData = ClassReportData(
        lop: lop,
        totalStudents: hsLopViewModels.length,
        activeStudents: activeCount,
        pausedStudents: pausedCount,
        leftStudents: leftCount,
        totalSessions: totalClassSessions,
        attendanceRate: classAttendanceRate,
        totalExpectedTuition: classExpectedTuition,
        totalCollectedTuition: classCollectedTuition,
        totalDebtTuition: classDebtTuition,
        averageClassScore: avgClassScore,
        attendanceList: attReportList,
        tuitionList: tuitionReportList,
        evaluationList: evalReportList,
      );

      classReports.add(classData);

      for (var vm in hsLopViewModels) {
        if (vm.id != null) uniqueStudentIds.add(vm.id!);
      }
      globalTotalExpectedTuition += classExpectedTuition;
      globalTotalCollectedTuition += classCollectedTuition;
      globalTotalDebtTuition += classDebtTuition;
      globalTotalPresentSessions += classTotalPresent;
      globalTotalSessionsCount += classTotalSessions;
    }

    final double overallRate = globalTotalSessionsCount > 0
        ? (globalTotalPresentSessions / globalTotalSessionsCount)
        : 0.0;

    return FacilityReportData(
      request: request,
      classReports: classReports,
      totalClasses: targetLops.length,
      totalStudents: uniqueStudentIds.length,
      totalExpectedTuition: globalTotalExpectedTuition,
      totalCollectedTuition: globalTotalCollectedTuition,
      totalDebtTuition: globalTotalDebtTuition,
      overallAttendanceRate: overallRate,
    );
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
  // 1. HÀM TÍNH TOÁN HỌC PHÍ THUẦN TÚY (PURE READ-ONLY CALCULATOR)
  // Chỉ đọc dữ liệu và tính toán kết quả trong bộ nhớ. Không ghi/xóa DB, không sync Firebase.
  // ===================================================
  Future<TuitionCalculationResult> calculateTuitionReport(
    int idLop,
    String thang,
  ) async {
    final db = await _database;

    // 1. Tải danh sách học sinh của lớp
    final dsHsLop = await _lhsService.docDSHSThuocLop(idLop);
    final validHsIds = dsHsLop.map((e) => e.id).whereType<int>().toList();

    // 2. Đọc cài đặt một lần duy nhất
    final int giaHocPhiMoiBuoi = await _docGiaHocPhiBuoi();
    final int hocPhiThangToiDa = await _docHocPhiThang();
    final int soBuoiChuanThang = await _docSoBuoiChuanThang();

    // 3. Batch pre-fetch dữ liệu
    final List<Map<String, dynamic>> allExistingRecords = await db.query(
      tenBangThanhToan,
      where: 'id_lop = ? AND thang = ?',
      whereArgs: [idLop, thang],
    );
    final Map<int, Map<String, dynamic>> existingRecordsMap = {};
    for (var r in allExistingRecords) {
      final hsId = r['id_hoc_sinh'] as int?;
      if (hsId != null) existingRecordsMap[hsId] = r;
    }

    final List<Map<String, dynamic>> rawSchedules = await db.rawQuery(
      '''
      SELECT lhcn.id_hoc_sinh, lhc.*
      FROM ${DBHelper.tenBangLichHocChung} lhc
      INNER JOIN ${DBHelper.tenBangLichHocCaNhan} lhcn ON lhc.id = lhcn.id_lich_hoc_chung
      WHERE lhc.id_lop = ?
      ORDER BY lhc.ngay_trong_tuan ASC, lhc.gio_bat_dau ASC
    ''',
      [idLop],
    );

    final Map<int, List<LichHocChung>> studentSchedulesMap = {};
    for (var r in rawSchedules) {
      final hsId = r['id_hoc_sinh'] as int?;
      if (hsId != null) {
        studentSchedulesMap
            .putIfAbsent(hsId, () => [])
            .add(LichHocChung.fromMap(r));
      }
    }

    final firstDayMonthStr = '$thang-01';
    final partsThang = thang.split('-');
    final yearThang = partsThang.length == 2
        ? (int.tryParse(partsThang[0]) ?? 2026)
        : 2026;
    final monthThang = partsThang.length == 2
        ? (int.tryParse(partsThang[1]) ?? 9)
        : 9;
    final lastDayOfMonthObj = DateTime(yearThang, monthThang + 1, 0);
    final lastDayMonthStr = DateFormat('yyyy-MM-dd').format(lastDayOfMonthObj);
    final nextMonthObj = DateTime(yearThang, monthThang + 1, 1);
    final nextMonthStr = DateFormat('yyyy-MM-dd').format(nextMonthObj);

    final List<Map<String, dynamic>> allAttRecords = await db.query(
      DBHelper.tenBangDiemDanh,
      where: 'id_lop = ? AND gio_diem_danh >= ? AND gio_diem_danh < ?',
      whereArgs: [idLop, firstDayMonthStr, nextMonthStr],
    );
    final Map<int, List<Map<String, dynamic>>> studentAttendanceMap = {};
    for (var r in allAttRecords) {
      final hsId = r['id_hoc_sinh'] as int?;
      if (hsId != null) {
        studentAttendanceMap.putIfAbsent(hsId, () => []).add(r);
      }
    }

    final List<Map<String, dynamic>> allDonNghiRecords = await db.query(
      DBHelper.tenBangDonNghiHoc,
      where: 'id_lop = ? AND tu_ngay <= ? AND den_ngay >= ?',
      whereArgs: [idLop, lastDayMonthStr, firstDayMonthStr],
    );
    final Map<int, List<Map<String, dynamic>>> studentDonNghiMap = {};
    for (var r in allDonNghiRecords) {
      final hsId = r['id_hoc_sinh'] as int?;
      if (hsId != null) {
        studentDonNghiMap.putIfAbsent(hsId, () => []).add(r);
      }
    }

    final List<TinhToanHocSinhResult> dsTinhToan = [];
    int tongSoTienCanThu = 0;
    int tongSoTienDaThu = 0;
    int tongSoTienConNo = 0;
    final List<HocSinhNoHocPhi> dsNo = [];
    int firstStudentTongSoBuoi = 0;

    for (var hsViewModel in dsHsLop) {
      if (hsViewModel.id != null) {
        final idHocSinh = hsViewModel.id!;
        final int mienGiam = hsViewModel.mienGiam ?? 0;
        final ledgerResult = await SessionLedgerService()
            .rebuildStudentSessionBalance(
              idHocSinh,
              idLop,
              untilDate: lastDayOfMonthObj,
              updateCacheInDb: false,
            );
        int soBuoiDuHienTai = ledgerResult.currentBalance;

        final existing = existingRecordsMap[idHocSinh];

        DateTime? ngayThamGia = parseFlexibleDate(hsViewModel.ngayThamGia);
        DateTime? ngayTamNgung = parseFlexibleDate(hsViewModel.ngayTamNgung);
        DateTime? ngayHocLai = parseFlexibleDate(hsViewModel.ngayHocLaiThucTe);
        DateTime? ngayNghiHoc = parseFlexibleDate(hsViewModel.ngayNghiHoc);
        DateTime? ngayHocLaiSauNghi = parseFlexibleDate(
          hsViewModel.ngayHocLaiSauNghi,
        );

        final List<LichHocChung> lichCaNhan =
            studentSchedulesMap[idHocSinh] ?? [];
        final List<Map<String, dynamic>> attList =
            studentAttendanceMap[idHocSinh] ?? [];
        final List<Map<String, dynamic>> donNghiList =
            studentDonNghiMap[idHocSinh] ?? [];

        final int tongSoBuoiDuKien = _tinhSoBuoiDuKienInMemory(
          lichCaNhan,
          thang,
          ngayThamGia: ngayThamGia,
          ngayTamNgung: ngayTamNgung,
          ngayHocLai: ngayHocLai,
          ngayNghiHoc: ngayNghiHoc,
          ngayHocLaiSauNghi: ngayHocLaiSauNghi,
        );

        final int soBuoiNghiKhongPhep = _demAttendanceInMemory(
          attList,
          'Nghỉ không phép',
          ngayThamGia,
        );
        final int soBuoiNghiCoPhep = _demNghiCoPhepInMemory(
          attList,
          donNghiList,
          lichCaNhan,
          thang,
          ngayThamGia: ngayThamGia,
          ngayTamNgung: ngayTamNgung,
          ngayHocLai: ngayHocLai,
          ngayNghiHoc: ngayNghiHoc,
          ngayHocLaiSauNghi: ngayHocLaiSauNghi,
        );
        final int soBuoiHocBu = _demAttendanceInMemory(
          attList,
          'Học bù',
          ngayThamGia,
        );

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
            soBuoiDuocBuTru = (soBuoiDuHienTai < thieuBuoi)
                ? soBuoiDuHienTai
                : thieuBuoi;
          }
        }

        int soBuoiDuConLai =
            soBuoiDuHienTai - soBuoiDuocBuTru + soBuoiVuotChuan;
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

        final int soTienDaDong = existing != null
            ? (existing['so_tien_da_dong'] as int? ?? 0)
            : 0;

        // Bỏ qua học sinh đã nghỉ học/tạm ngừng từ trước tháng này không phát sinh
        if (isStatusInactive(hsViewModel.trangThai) &&
            tongSoBuoiDuKien == 0 &&
            soBuoiNghiCoPhep == 0 &&
            soBuoiNghiKhongPhep == 0 &&
            soBuoiHocBu == 0 &&
            tongThanhToan == 0 &&
            soTienDaDong == 0) {
          continue;
        }

        dsTinhToan.add(
          TinhToanHocSinhResult(
            idHocSinh: idHocSinh,
            tongSoBuoiDuKien: tongSoBuoiDuKien,
            soBuoiNghiCoPhep: soBuoiNghiCoPhep,
            soBuoiNghiKhongPhep: soBuoiNghiKhongPhep,
            soBuoiDuocBuTru: soBuoiDuocBuTru,
            soBuoiDuCuoiCung: soBuoiDuCuoiCung,
            tongThanhToan: tongThanhToan,
            soTienDaDong: soTienDaDong,
          ),
        );

        final conNo = tongThanhToan - soTienDaDong;
        tongSoTienCanThu += tongThanhToan;
        tongSoTienDaThu += soTienDaDong;
        tongSoTienConNo += conNo;

        if (firstStudentTongSoBuoi == 0) {
          firstStudentTongSoBuoi = tongSoBuoiDuKien;
        }

        if (conNo > 0) {
          dsNo.add(
            HocSinhNoHocPhi(
              idHocSinh: idHocSinh,
              tenHocSinh: hsViewModel.ten,
              soTienCanNop: tongThanhToan,
              soTienDaDong: soTienDaDong,
              soTienConNo: conNo,
              mienGiam: mienGiam,
              soBuoiDu: soBuoiDuCuoiCung,
              tongSoBuoi: tongSoBuoiDuKien,
              sdt: hsViewModel.sdt,
            ),
          );
        }
      }
    }

    final report = HocPhiTongHop(
      tongSoBuoi: firstStudentTongSoBuoi,
      tongSoHocSinh: dsTinhToan.length,
      tongSoTienCanThu: tongSoTienCanThu,
      tongSoTienDaThu: tongSoTienDaThu,
      tongSoTienConNo: tongSoTienConNo,
      dsHocSinhConNo: dsNo,
    );

    return TuitionCalculationResult(
      idLop: idLop,
      thang: thang,
      dsTinhToan: dsTinhToan,
      validHsIds: validHsIds,
      report: report,
    );
  }

  // ===================================================
  // 2. HÀM PERSIST (GHI DB SQLITE VÀ SYNC FIREBASE)
  // Chỉ thực thi side-effects ghi dữ liệu khi cần thiết.
  // ===================================================
  Future<void> persistTuitionReport(
    TuitionCalculationResult result, {
    bool syncFirebase = true,
  }) async {
    final db = await _database;
    final idLop = result.idLop;
    final thang = result.thang;
    final validHsIds = result.validHsIds;

    // Dọn dẹp các hồ sơ chưa nộp tiền của học sinh không còn thuộc lớp này
    if (validHsIds.isNotEmpty) {
      final placeholders = List.filled(validHsIds.length, '?').join(',');
      await db.delete(
        tenBangThanhToan,
        where:
            'id_lop = ? AND thang = ? AND id_hoc_sinh NOT IN ($placeholders) AND so_tien_da_dong = 0',
        whereArgs: [idLop, thang, ...validHsIds],
      );
    } else {
      await db.delete(
        tenBangThanhToan,
        where: 'id_lop = ? AND thang = ? AND so_tien_da_dong = 0',
        whereArgs: [idLop, thang],
      );
    }

    // Ghi dữ liệu kết quả học phí và số buổi dư trong một Transaction
    await db.transaction((txn) async {
      for (var item in result.dsTinhToan) {
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
      }
    });

    // Đồng bộ Firebase async (chỉ khi syncFirebase == true)
    if (syncFirebase) {
      for (var item in result.dsTinhToan) {
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
    }
  }

  // ===================================================
  // 3. HÀM LAYBAOCAOHOCPHITHANG (ORCHESTRATOR API)
  // Tính toán và tùy chọn persist (mặc định persist = true, syncFirebase = true)
  // ===================================================
  Future<HocPhiTongHop> layBaoCaoHocPhiThang(
    int idLop,
    String thang, {
    bool persist = true,
    bool syncFirebase = true,
  }) async {
    final calcResult = await calculateTuitionReport(idLop, thang);
    if (persist) {
      await persistTuitionReport(calcResult, syncFirebase: syncFirebase);
    }
    return calcResult.report;
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

  // ===================================================
  // CÁC HÀM TÍNH TOÁN IN-MEMORY SIÊU TỐC (LOẠI BỎ TRUY VẤN LẶP VÀO DB)
  // ===================================================

  int _tinhSoBuoiDuKienInMemory(
    List<LichHocChung> lichCaNhan,
    String thang, {
    DateTime? ngayThamGia,
    DateTime? ngayTamNgung,
    DateTime? ngayHocLai,
    DateTime? ngayNghiHoc,
    DateTime? ngayHocLaiSauNghi,
  }) {
    if (lichCaNhan.isEmpty) return 0;

    final int nam = int.parse(thang.substring(0, 4));
    final int month = int.parse(thang.substring(5));
    final int daysInMonth = DateTime(nam, month + 1, 0).day;

    final joiningDateOnly = ngayThamGia != null
        ? DateTime(ngayThamGia.year, ngayThamGia.month, ngayThamGia.day)
        : null;
    final pauseDateOnly = ngayTamNgung != null
        ? DateTime(ngayTamNgung.year, ngayTamNgung.month, ngayTamNgung.day)
        : null;
    final resumeDateOnly = ngayHocLai != null
        ? DateTime(ngayHocLai.year, ngayHocLai.month, ngayHocLai.day)
        : null;
    final leaveDateOnly = ngayNghiHoc != null
        ? DateTime(ngayNghiHoc.year, ngayNghiHoc.month, ngayNghiHoc.day)
        : null;
    final resumeAfterLeaveOnly = ngayHocLaiSauNghi != null
        ? DateTime(
            ngayHocLaiSauNghi.year,
            ngayHocLaiSauNghi.month,
            ngayHocLaiSauNghi.day,
          )
        : null;

    final Map<String, int> weekdayMap = {
      'Thứ Hai': 1,
      'Thứ Ba': 2,
      'Thứ Tư': 3,
      'Thứ Năm': 4,
      'Thứ Sáu': 5,
      'Thứ Bảy': 6,
      'Chủ Nhật': 7,
    };
    final Map<int, int> caPerWeekdayCount = {};
    for (var l in lichCaNhan) {
      final dayNum = weekdayMap[l.ngayTrongTuan];
      if (dayNum != null) {
        caPerWeekdayCount[dayNum] = (caPerWeekdayCount[dayNum] ?? 0) + 1;
      }
    }

    int soBuoiHoc = 0;
    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(nam, month, day);
      final int caCountOnDay = caPerWeekdayCount[currentDate.weekday] ?? 0;
      final bool afterJoiningDate =
          joiningDateOnly == null ||
          currentDate.isAtSameMomentAs(joiningDateOnly) ||
          currentDate.isAfter(joiningDateOnly);
      final bool inPausedPeriod =
          pauseDateOnly != null &&
          !currentDate.isBefore(pauseDateOnly) &&
          (resumeDateOnly == null || currentDate.isBefore(resumeDateOnly));
      final bool outsideLeavePeriod =
          leaveDateOnly == null ||
          currentDate.isBefore(leaveDateOnly) ||
          (resumeAfterLeaveOnly != null &&
              !currentDate.isBefore(resumeAfterLeaveOnly));
      if (caCountOnDay > 0 &&
          afterJoiningDate &&
          !inPausedPeriod &&
          outsideLeavePeriod) {
        soBuoiHoc += caCountOnDay;
      }
    }
    return soBuoiHoc;
  }

  int _demAttendanceInMemory(
    List<Map<String, dynamic>> attList,
    String targetStatus,
    DateTime? ngayBatDauTinh,
  ) {
    int count = 0;
    final startDateOnly = ngayBatDauTinh != null
        ? DateTime(
            ngayBatDauTinh.year,
            ngayBatDauTinh.month,
            ngayBatDauTinh.day,
          )
        : null;

    for (var att in attList) {
      final status = att['trang_thai'] as String?;
      if (status == targetStatus) {
        if (startDateOnly != null) {
          final dateVal = att['gio_diem_danh'] ?? att['ngay'];
          if (dateVal != null) {
            final dt = parseFlexibleDate(dateVal.toString());
            if (dt != null && dt.isBefore(startDateOnly)) {
              continue;
            }
          }
        }
        count++;
      }
    }
    return count;
  }

  int _demNghiCoPhepInMemory(
    List<Map<String, dynamic>> attList,
    List<Map<String, dynamic>> donNghiRows,
    List<LichHocChung> lichCaNhan,
    String thang, {
    DateTime? ngayThamGia,
    DateTime? ngayTamNgung,
    DateTime? ngayHocLai,
    DateTime? ngayNghiHoc,
    DateTime? ngayHocLaiSauNghi,
  }) {
    int countDD = _demAttendanceInMemory(attList, 'Nghỉ có phép', ngayThamGia);
    if (donNghiRows.isEmpty || lichCaNhan.isEmpty) return countDD;

    final parts = thang.split('-');
    if (parts.length != 2) return countDD;
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final lastDayOfMonth = DateTime(year, month + 1, 0);

    final Map<String, int> weekdayMap = {
      'Thứ Hai': 1,
      'Thứ Ba': 2,
      'Thứ Tư': 3,
      'Thứ Năm': 4,
      'Thứ Sáu': 5,
      'Thứ Bảy': 6,
      'Chủ Nhật': 7,
    };
    final Map<int, int> caPerWeekdayCount = {};
    for (var l in lichCaNhan) {
      final dayNum = weekdayMap[l.ngayTrongTuan];
      if (dayNum != null) {
        caPerWeekdayCount[dayNum] = (caPerWeekdayCount[dayNum] ?? 0) + 1;
      }
    }

    final joiningDateOnly = ngayThamGia != null
        ? DateTime(ngayThamGia.year, ngayThamGia.month, ngayThamGia.day)
        : null;
    final pauseDateOnly = ngayTamNgung != null
        ? DateTime(ngayTamNgung.year, ngayTamNgung.month, ngayTamNgung.day)
        : null;
    final resumeDateOnly = ngayHocLai != null
        ? DateTime(ngayHocLai.year, ngayHocLai.month, ngayHocLai.day)
        : null;
    final leaveDateOnly = ngayNghiHoc != null
        ? DateTime(ngayNghiHoc.year, ngayNghiHoc.month, ngayNghiHoc.day)
        : null;
    final resumeAfterLeaveOnly = ngayHocLaiSauNghi != null
        ? DateTime(
            ngayHocLaiSauNghi.year,
            ngayHocLaiSauNghi.month,
            ngayHocLaiSauNghi.day,
          )
        : null;

    final markedDates = <String>{};
    for (var att in attList) {
      final dateVal = att['gio_diem_danh'] ?? att['ngay'];
      if (dateVal != null) {
        markedDates.add(dateVal.toString().trim().split('T')[0].split(' ')[0]);
      }
    }

    // Chuẩn hóa danh sách các ngày trong đơn nghỉ học cá nhân thành Set<String> để lookup O(1)
    final Set<String> donNghiDatesSet = {};
    for (var row in donNghiRows) {
      final loaiNghi = row['loai_nghi'] as String? ?? 'CANHAN';
      if (loaiNghi == 'TOANLOP') continue; // Bỏ qua đơn nghỉ lễ toàn lớp
      final tuStr = row['tu_ngay'] as String?;
      final denStr = row['den_ngay'] as String?;
      if (tuStr != null && denStr != null) {
        final tuDt = parseFlexibleDate(tuStr);
        final denDt = parseFlexibleDate(denStr);
        if (tuDt != null && denDt != null) {
          DateTime cur = tuDt;
          while (!cur.isAfter(denDt)) {
            donNghiDatesSet.add(DateFormat('yyyy-MM-dd').format(cur));
            cur = cur.add(const Duration(days: 1));
          }
        }
      }
    }

    int extraFromDon = 0;
    for (int day = 1; day <= lastDayOfMonth.day; day++) {
      final currentDate = DateTime(year, month, day);
      final int caCount = caPerWeekdayCount[currentDate.weekday] ?? 0;
      if (caCount == 0) continue;

      final bool afterJoiningDate =
          joiningDateOnly == null ||
          currentDate.isAtSameMomentAs(joiningDateOnly) ||
          currentDate.isAfter(joiningDateOnly);
      final bool inPausedPeriod =
          pauseDateOnly != null &&
          !currentDate.isBefore(pauseDateOnly) &&
          (resumeDateOnly == null || currentDate.isBefore(resumeDateOnly));
      final bool outsideLeavePeriod =
          leaveDateOnly == null ||
          currentDate.isBefore(leaveDateOnly) ||
          (resumeAfterLeaveOnly != null &&
              !currentDate.isBefore(resumeAfterLeaveOnly));

      if (!afterJoiningDate || inPausedPeriod || !outsideLeavePeriod) continue;

      final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);

      if (donNghiDatesSet.contains(dateStr) && !markedDates.contains(dateStr)) {
        extraFromDon += caCount;
      }
    }
    return countDD + extraFromDon;
  }

  /// Khởi tạo và tính toán lại toàn bộ số buổi dư cho tất cả học sinh từ ngày tham gia đến tháng hiện tại
  /// ỦY QUYỀN TOÀN BỘ CHO SessionLedgerService (Idempotent 100%)
  Future<void> recalculateAllStudentsRemainingSessions({
    bool syncFirebase = false,
  }) async {
    await SessionLedgerService().recalculateAllStudentsSessionBalance(
      syncFirebase: syncFirebase,
    );

    final db = await _database;
    final lopRows = await db.query(DBHelper.tenBangLop);
    final now = DateTime.now();
    final currentMonthStr = DateFormat('yyyy-MM').format(now);

    for (var lopRow in lopRows) {
      final idLop = lopRow['id'] as int?;
      if (idLop != null) {
        final calcResult = await calculateTuitionReport(idLop, currentMonthStr);
        await persistTuitionReport(calcResult, syncFirebase: syncFirebase);
      }
    }

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

// Kết quả tính toán học phí thuần túy (Read-only Result Model)
class TuitionCalculationResult {
  final int idLop;
  final String thang;
  final List<TinhToanHocSinhResult> dsTinhToan;
  final List<int> validHsIds;
  final HocPhiTongHop report;

  TuitionCalculationResult({
    required this.idLop,
    required this.thang,
    required this.dsTinhToan,
    required this.validHsIds,
    required this.report,
  });
}

// Lớp phụ trợ lưu trữ kết quả tính toán tạm thời của học sinh
class TinhToanHocSinhResult {
  final int idHocSinh;
  final int tongSoBuoiDuKien;
  final int soBuoiNghiCoPhep;
  final int soBuoiNghiKhongPhep;
  final int soBuoiDuocBuTru;
  final int soBuoiDuCuoiCung;
  final int tongThanhToan;
  final int soTienDaDong;

  TinhToanHocSinhResult({
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
