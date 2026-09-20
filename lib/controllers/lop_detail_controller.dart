// File: lib/controllers/lop_detail_controller.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc.dart';
import '../models/lich_hoc_chung.dart';
import '../models/lop.dart';
import '../models/lop_hoc_sinh.dart';
import '../models/nhiem_vu.dart';
import '../models/nhan_xet_thang.dart';
import '../services/lich_hoc_chung_service.dart';
import '../services/lich_hoc_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/lop_service.dart';
import '../services/nhiem_vu_service.dart';
import '../services/nhan_xet_service.dart';
import '../services/report_service.dart';
import '../services/diem_danh_service.dart';
import '../utils/schedule_helpers.dart';
import 'service_providers.dart';

part 'lop_detail_controller.g.dart';

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
  final List<NhiemVu> nhiemVus;
  final String selectedMonth;
  final List<NhanXetThang> nhanXetThangs;
  final int siSo;
  final LopSummary summary;

  LopDetailState({
    required this.lop,
    this.hocSinhs = const [],
    this.hocSinhsDaNghi = const [],
    this.lichHocs = const [],
    this.nhiemVus = const [],
    required this.selectedMonth,
    this.nhanXetThangs = const [],
    this.siSo = 0,
    LopSummary? summary,
  }) : summary = summary ?? LopSummary();

  LopDetailState copyWith({
    Lop? lop,
    List<HSLopViewModel>? hocSinhs,
    List<HSLopViewModel>? hocSinhsDaNghi,
    List<LichHoc>? lichHocs,
    List<NhiemVu>? nhiemVus,
    String? selectedMonth,
    List<NhanXetThang>? nhanXetThangs,
    int? siSo,
    LopSummary? summary,
  }) {
    return LopDetailState(
      lop: lop ?? this.lop,
      hocSinhs: hocSinhs ?? this.hocSinhs,
      hocSinhsDaNghi: hocSinhsDaNghi ?? this.hocSinhsDaNghi,
      lichHocs: lichHocs ?? this.lichHocs,
      nhiemVus: nhiemVus ?? this.nhiemVus,
      selectedMonth: selectedMonth ?? this.selectedMonth,
      nhanXetThangs: nhanXetThangs ?? this.nhanXetThangs,
      siSo: siSo ?? this.siSo,
      summary: summary ?? this.summary,
    );
  }
}

@riverpod
class LopDetailController extends _$LopDetailController {
  LopHocSinhService get _lhsService => ref.read(lopHocSinhServiceProvider);
  LichHocService get _lichHocService => ref.read(lichHocServiceProvider);
  LichHocChungService get _lhcService => ref.read(lichHocChungServiceProvider);
  ReportService get _reportService => ref.read(reportServiceProvider);
  DiemDanhService get _diemDanhService => ref.read(diemDanhServiceProvider);
  LopService get _lopService => LopService();
  NhiemVuService get _nhiemVuService => NhiemVuService();
  NhanXetService get _nhanXetService => NhanXetService();

  @override
  Future<LopDetailState> build(int lopId) async {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    return await _loadAllData(lopId, month: currentMonth);
  }

  Future<LopDetailState> _loadAllData(int lopId, {String? month}) async {
    final selectedMonth =
        month ??
        state.value?.selectedMonth ??
        DateFormat('yyyy-MM').format(DateTime.now());

    final lop = await _lopService.docLop(lopId);
    if (lop == null) {
      throw Exception('Không tìm thấy lớp học với ID $lopId');
    }

    final tatCaHocSinh = await _lhsService.docDSHSThuocLop(lopId);
    final filteredActive = tatCaHocSinh
        .where((hs) => _lhsService.hoatDongTrongNgay(hs, DateTime.now()))
        .toList();
    final hocSinhsDaNghi = tatCaHocSinh
        .where((hs) => !_lhsService.hoatDongTrongNgay(hs, DateTime.now()))
        .toList();

    final lichHocs = await _lichHocService.layLichHocTheoLop(lopId);
    final nhiemVus = await _nhiemVuService.layNhiemVuTheoLop(lopId);
    final nhanXetThangs = await _nhanXetService.layDanhSachNhanXet(
      lopId,
      selectedMonth,
    );

    int tongHocPhiDuKien = 0;
    int tongHocPhiDaThu = 0;
    double tyLeCC = 0;

    try {
      final hocPhiReport = await _reportService.layBaoCaoHocPhiThang(
        lopId,
        selectedMonth,
      );
      tongHocPhiDuKien = (hocPhiReport.tongSoTienCanThu as num).toInt();
      tongHocPhiDaThu = (hocPhiReport.tongSoTienDaThu as num).toInt();

      final countsMap = await _diemDanhService.demTongSoBuoiCuaLopTheoThang(
        lopId,
        selectedMonth,
      );
      final tongCoMat = countsMap['Có mặt'] ?? 0;
      final tongVangCP = countsMap['Nghỉ có phép'] ?? 0;
      final tongVangKP = countsMap['Nghỉ không phép'] ?? 0;
      final tongVang = tongVangCP + tongVangKP;

      if ((tongCoMat + tongVang) > 0) {
        tyLeCC = tongCoMat / (tongCoMat + tongVang);
      }
    } catch (e, st) {
      developer.log(
        'Lỗi tính summary lớp trong LopDetailController: $e',
        stackTrace: st,
      );
    }

    return LopDetailState(
      lop: lop,
      hocSinhs: filteredActive,
      hocSinhsDaNghi: hocSinhsDaNghi,
      lichHocs: lichHocs,
      nhiemVus: nhiemVus,
      selectedMonth: selectedMonth,
      nhanXetThangs: nhanXetThangs,
      siSo: filteredActive.length,
      summary: LopSummary(
        tyLeChuyenCan: tyLeCC,
        tongHocPhiDuKien: tongHocPhiDuKien,
        tongHocPhiDaThu: tongHocPhiDaThu,
      ),
    );
  }

  Future<void> refreshAll() async {
    final targetLopId = state.value?.lop.id ?? lopId;
    final currentMonth = state.value?.selectedMonth;
    state = await AsyncValue.guard(() async {
      return await _loadAllData(targetLopId, month: currentMonth);
    });
  }

  Future<void> setSelectedMonth(String month) async {
    final targetLopId = state.value?.lop.id ?? lopId;
    state = await AsyncValue.guard(() async {
      return await _loadAllData(targetLopId, month: month);
    });
  }

  Future<bool> updateClassInfo(String tenMoi, int khoiMoi) async {
    final currentLop = state.value!.lop;
    final updatedLop = currentLop.copyWith(ten: tenMoi, khoi: khoiMoi);
    final res = await _lopService.capNhatLop(updatedLop);
    if (res > 0) {
      await refreshAll();
      return true;
    }
    return false;
  }

  Future<void> themHocSinhVaoLop(int hsId, {String? ngayThamGia}) async {
    final targetLopId = state.value!.lop.id!;
    final joinDateStr =
        ngayThamGia ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    await _lhsService.themHocSinhVaoLop(
      LopHocSinh(idLop: targetLopId, idHocSinh: hsId, ngayThamGia: joinDateStr),
    );
    await refreshAll();
  }

  Future<void> xoaHocSinhKhoiLop(int hsId) async {
    final targetLopId = state.value!.lop.id!;
    await _lhsService.xoaHocSinhKhoiLop(targetLopId, hsId);
    await refreshAll();
  }

  Future<bool> themLichHoc(LichHoc lichHoc) async {
    final result = await _lichHocService.themLichHoc(lichHoc);
    if (result != null) {
      await refreshAll();
      return true;
    }
    return false;
  }

  Future<bool> capNhatLichHoc(LichHoc lichHoc) async {
    final result = await _lichHocService.capNhatLichHoc(lichHoc);
    if (result) {
      await refreshAll();
    }
    return result;
  }

  Future<void> xoaLichHoc(int lichHocId) async {
    await _lichHocService.xoaLichHoc(lichHocId);
    await refreshAll();
  }

  Future<int> ganLichChoNhieuHS(List<int> hsIds, LichHoc lichHocCoDinh) async {
    final lop = state.value!.lop;

    final lhcToAssign = LichHocChung(
      idLop: lop.id!,
      ngayTrongTuan: _thuTrongTuanToVN(lichHocCoDinh.thuTrongTuan),
      gioBatDau: normalizeTime(lichHocCoDinh.gioBatDau),
      gioKetThuc: normalizeTime(lichHocCoDinh.gioKetThuc),
    );

    LichHocChung? finalLhc = await _lhcService.themLichHocChung(lhcToAssign);
    finalLhc ??= await _lhcService.findLichHocChung(lhcToAssign);

    if (finalLhc?.id == null) {
      throw Exception('Không thể tạo hoặc tìm thấy lịch học chung để gán.');
    }

    final addedCount = await _lhcService.ganLichChoNhieuHS(
      hsIds,
      finalLhc!.id!,
    );

    await refreshAll();
    return addedCount;
  }

  Future<void> themNhiemVu(NhiemVu nv) async {
    await _nhiemVuService.themNhiemVu(nv);
    await refreshAll();
  }

  Future<void> capNhatNhiemVu(NhiemVu nv) async {
    await _nhiemVuService.capNhatNhiemVu(nv);
    await refreshAll();
  }

  Future<void> xoaNhiemVu(int id) async {
    await _nhiemVuService.xoaNhiemVu(id);
    await refreshAll();
  }

  Future<void> capNhatTrangThaiNhiemVu(
    int nvId,
    int hsId,
    String status,
  ) async {
    await _nhiemVuService.capNhatTrangThai(nvId, hsId, status);
    await refreshAll();
  }

  Future<void> tongHopVaCapNhatNhanXetThang(String month) async {
    final currentState = state.value;
    if (currentState == null) return;
    final allStudents = [
      ...currentState.hocSinhs,
      ...currentState.hocSinhsDaNghi,
    ];
    await _nhanXetService.tongHopVaCapNhatNhanXetThang(
      allStudents,
      currentState.lop.id!,
      month,
    );
    await setSelectedMonth(month);
  }

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
