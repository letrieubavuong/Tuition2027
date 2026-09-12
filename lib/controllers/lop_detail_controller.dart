// File: lib/controllers/lop_detail_controller.dart

import 'dart:async';
// Sửa: Thêm các import cần thiết cho Riverpod Generator
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc.dart';
import '../models/lich_hoc_chung.dart';
import '../models/lop.dart';
import '../services/lich_hoc_chung_service.dart';
import '../services/lich_hoc_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/report_service.dart';
import '../services/diem_danh_service.dart';
import 'service_providers.dart';

// Sửa: Đặt part directive sau tất cả các import và sửa lại đường dẫn
part 'lop_detail_controller.g.dart';

// 1. Định nghĩa State của màn hình
class LopSummary {
  final double tyLeChuyenCan;
  final int tongSoBuoiHoc;
  final int tongHocPhiDuKien;
  final int tongHocPhiDaThu;

  LopSummary({
    this.tyLeChuyenCan = 0,
    this.tongSoBuoiHoc = 0,
    this.tongHocPhiDuKien = 0,
    this.tongHocPhiDaThu = 0,
  });
}

class LopDetailState {
  final Lop lop;
  final List<HSLopViewModel> hocSinhs;
  final List<HSLopViewModel> hocSinhsDaNghi;
  final List<LichHoc> lichHocs;
  final int siSo;
  final LopSummary summary;

  LopDetailState({
    required this.lop,
    this.hocSinhs = const [],
    this.hocSinhsDaNghi = const [],
    this.lichHocs = const [],
    this.siSo = 0,
    LopSummary? summary,
  }) : summary = summary ?? LopSummary();

  LopDetailState copyWith({
    Lop? lop,
    List<HSLopViewModel>? hocSinhs,
    List<HSLopViewModel>? hocSinhsDaNghi,
    List<LichHoc>? lichHocs,
    int? siSo,
    LopSummary? summary,
  }) {
    return LopDetailState(
      lop: lop ?? this.lop,
      hocSinhs: hocSinhs ?? this.hocSinhs,
      hocSinhsDaNghi: hocSinhsDaNghi ?? this.hocSinhsDaNghi,
      lichHocs: lichHocs ?? this.lichHocs,
      siSo: siSo ?? this.siSo,
      summary: summary ?? this.summary,
    );
  }
}

// 3. Controller (AsyncNotifier)
@riverpod
class LopDetailController extends _$LopDetailController {
  // Services
  LopHocSinhService get _lhsService => ref.read(lopHocSinhServiceProvider);
  LichHocService get _lichHocService => ref.read(lichHocServiceProvider);
  LichHocChungService get _lhcService => ref.read(lichHocChungServiceProvider);
  ReportService get _reportService => ref.read(reportServiceProvider);
  DiemDanhService get _diemDanhService => ref.read(diemDanhServiceProvider);

  // Hàm build sẽ được gọi để lấy trạng thái ban đầu
  @override
  Future<LopDetailState> build(Lop initialLop) async {
    return await _loadAllData(initialLop);
  }

  Future<LopDetailState> _loadAllData(Lop lop) async {
    final lopId = lop.id!;
    final thangHienTai = DateFormat('yyyy-MM').format(DateTime.now());

    // Tải dữ liệu cơ bản
    final tatCaHocSinh = await _lhsService.docDSHSThuocLop(lopId);
    final hocSinhs = tatCaHocSinh
        .where((hs) => _lhsService.hoatDongTrongNgay(hs, DateTime.now()))
        .toList();
    final hocSinhsDaNghi = tatCaHocSinh
        .where((hs) => !_lhsService.hoatDongTrongNgay(hs, DateTime.now()))
        .toList();
    final lichHocs = await _lichHocService.layLichHocTheoLop(lopId);

    // Tải báo cáo học phí
    final hocPhiReport = await _reportService.layBaoCaoHocPhiThang(
      lopId,
      thangHienTai,
    );

    // Tính toán tỷ lệ chuyên cần tháng hiện tại
    double tyLeCC = 0;
    int tongCoMat = 0;
    int tongVang = 0;

    for (var hs in hocSinhs) {
      final coMat = await _diemDanhService.demSoBuoiTheoThang(
        hs.id!,
        lopId,
        thangHienTai,
        'Có mặt',
      );
      final vangKP = await _diemDanhService.demSoBuoiTheoThang(
        hs.id!,
        lopId,
        thangHienTai,
        'Nghỉ không phép',
      );
      final vangCP = await _diemDanhService.demSoBuoiTheoThang(
        hs.id!,
        lopId,
        thangHienTai,
        'Nghỉ có phép',
      );

      tongCoMat += coMat;
      tongVang += (vangKP + vangCP);
    }

    if ((tongCoMat + tongVang) > 0) {
      tyLeCC = tongCoMat / (tongCoMat + tongVang);
    }

    return LopDetailState(
      lop: lop,
      hocSinhs: hocSinhs,
      hocSinhsDaNghi: hocSinhsDaNghi,
      lichHocs: lichHocs,
      siSo: hocSinhs.length,
      summary: LopSummary(
        tyLeChuyenCan: tyLeCC,
        tongSoBuoiHoc: lichHocs.length,
        tongHocPhiDuKien: (hocPhiReport.tongSoTienCanThu as num).toInt(),
        tongHocPhiDaThu: (hocPhiReport.tongSoTienDaThu as num).toInt(),
      ),
    );
  }

  // Hàm private để tải lại toàn bộ dữ liệu và cập nhật state
  Future<void> _reloadData() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _loadAllData(state.value!.lop);
    });
  }

  // Các phương thức xử lý nghiệp vụ
  Future<void> themHocSinhVaoLop(int hsId) async {
    // Logic thêm học sinh...
    // Sau khi thành công, gọi _reloadData()
    await _reloadData();
  }

  Future<void> xoaHocSinhKhoiLop(int hsId) async {
    final lopId = state.value!.lop.id!;
    await _lhsService.xoaHocSinhKhoiLop(lopId, hsId);
    await _reloadData();
  }

  Future<bool> themLichHoc(LichHoc lichHoc) async {
    final result = await _lichHocService.themLichHoc(lichHoc);
    if (result != null) {
      await _reloadData();
      return true;
    }
    return false;
  }

  Future<bool> capNhatLichHoc(LichHoc lichHoc) async {
    final result = await _lichHocService.capNhatLichHoc(lichHoc);
    if (result) {
      await _reloadData();
    }
    return result;
  }

  Future<void> xoaLichHoc(int lichHocId) async {
    await _lichHocService.xoaLichHoc(lichHocId);
    await _reloadData();
  }

  Future<int> ganLichChoNhieuHS(List<int> hsIds, LichHoc lichHocCoDinh) async {
    final lop = state.value!.lop;

    // Chuyển đổi LichHoc -> LichHocChung
    final lhcToAssign = LichHocChung(
      idLop: lop.id!,
      ngayTrongTuan: _thuTrongTuanToVN(lichHocCoDinh.thuTrongTuan),
      gioBatDau: lichHocCoDinh.gioBatDau.substring(0, 5),
      gioKetThuc: lichHocCoDinh.gioKetThuc.substring(0, 5),
    );

    // Tạo hoặc tìm LichHocChung
    LichHocChung? finalLhc = await _lhcService.themLichHocChung(lhcToAssign);
    finalLhc ??= await _lhcService.findLichHocChung(lhcToAssign);

    if (finalLhc?.id == null) {
      throw Exception('Không thể tạo hoặc tìm thấy lịch học chung để gán.');
    }

    // Gán cho nhiều học sinh
    final addedCount = await _lhcService.ganLichChoNhieuHS(
      hsIds,
      finalLhc!.id!,
    );

    // Không cần reload vì logic này không thay đổi UI chính của LopDetail
    return addedCount;
  }

  // Helper method
  String _thuTrongTuanToVN(int thu) {
    switch (thu) {
      case 2:
        return 'Thứ Hai';
      case 3:
        return 'Thứ Ba';
      case 4:
        return 'Thứ Tư';
      case 5:
        return 'Thứ Năm';
      case 6:
        return 'Thứ Sáu';
      case 7:
        return 'Thứ Bảy';
      case 1:
        return 'Chủ Nhật';
      default:
        return 'Không rõ';
    }
  }
}
