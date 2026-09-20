// File: lib/controllers/diem_danh_controller.dart

import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/diem_danh.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc.dart';
import '../models/lop.dart';
import '../services/diem_danh_service.dart';
import '../services/lich_hoc_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/lop_service.dart';

import 'service_providers.dart';

part 'diem_danh_controller.g.dart';

/// State của màn hình điểm danh
class DiemDanhState {
  final List<Lop> lopList;
  final Lop? selectedLop;
  final DateTime selectedDate;
  final List<LichHoc> caHocTrongNgay;
  final Map<int, List<HSLopViewModel>> danhSachHSCuaTungCa;
  final Map<String, DiemDanh> trangThaiDiemDanh;
  final Set<int> studentsWithWarnings;
  final Map<int, Map<String, DiemDanh>> lastBulkBackupPerCa;

  DiemDanhState({
    this.lopList = const [],
    this.selectedLop,
    required this.selectedDate,
    this.caHocTrongNgay = const [],
    this.danhSachHSCuaTungCa = const {},
    this.trangThaiDiemDanh = const {},
    this.studentsWithWarnings = const {},
    this.lastBulkBackupPerCa = const {},
  });

  DiemDanhState copyWith({
    List<Lop>? lopList,
    Lop? selectedLop,
    DateTime? selectedDate,
    List<LichHoc>? caHocTrongNgay,
    Map<int, List<HSLopViewModel>>? danhSachHSCuaTungCa,
    Map<String, DiemDanh>? trangThaiDiemDanh,
    Set<int>? studentsWithWarnings,
    Map<int, Map<String, DiemDanh>>? lastBulkBackupPerCa,
  }) {
    return DiemDanhState(
      lopList: lopList ?? this.lopList,
      selectedLop: selectedLop ?? this.selectedLop,
      selectedDate: selectedDate ?? this.selectedDate,
      caHocTrongNgay: caHocTrongNgay ?? this.caHocTrongNgay,
      danhSachHSCuaTungCa: danhSachHSCuaTungCa ?? this.danhSachHSCuaTungCa,
      trangThaiDiemDanh: trangThaiDiemDanh ?? this.trangThaiDiemDanh,
      studentsWithWarnings: studentsWithWarnings ?? this.studentsWithWarnings,
      lastBulkBackupPerCa: lastBulkBackupPerCa ?? this.lastBulkBackupPerCa,
    );
  }
}

@riverpod
class DiemDanhController extends _$DiemDanhController {
  // Services
  LopService get _lopService => ref.read(lopServiceProvider);
  LopHocSinhService get _lhsService => ref.read(lopHocSinhServiceProvider);
  DiemDanhService get _diemDanhService => ref.read(diemDanhServiceProvider);
  LichHocService get _lichHocService => ref.read(lichHocServiceProvider);

  @override
  Future<DiemDanhState> build(int? initialLopId, DateTime? initialDate) async {
    final date = initialDate ?? DateTime.now();
    final lopList = await _lopService.docTatCaLop();

    Lop? selectedLop;
    if (lopList.isNotEmpty) {
      if (initialLopId != null) {
        selectedLop = lopList.firstWhere(
          (lop) => lop.id == initialLopId,
          orElse: () => lopList.first,
        );
      } else {
        selectedLop = lopList.first;
      }
    }

    final initialState = DiemDanhState(
      lopList: lopList,
      selectedLop: selectedLop,
      selectedDate: date,
    );
    return await _loadDataForSelection(initialState);
  }

  Future<DiemDanhState> _loadDataForSelection(
    DiemDanhState currentState,
  ) async {
    if (currentState.selectedLop == null) return currentState;

    final lopId = currentState.selectedLop!.id!;
    final date = currentState.selectedDate;

    final allCaHoc = await _lichHocService.layLichHocTheoLop(lopId);
    final int thuTrongTuanDB = (date.weekday == 7) ? 1 : date.weekday + 1;
    final caHocTrongNgay = allCaHoc
        .where((lh) => lh.thuTrongTuan == thuTrongTuanDB)
        .toList();

    final danhSachHSCuaTungCaMoi = <int, List<HSLopViewModel>>{};
    final trangThaiMoi = <String, DiemDanh>{};
    final ngayStr = DateFormat('yyyy-MM-dd').format(date);
    final diemDanhDaCoTrongNgay = await _diemDanhService
        .layDiemDanhTheoLopVaNgay(lopId, ngayStr);

    // Batch load tất cả học sinh có đơn nghỉ trong ngày để tránh N+1 Query (Phần H)
    final hsCoDonNghiSet = await _lhsService.layHsCoDonNghiTrongNgay(
      lopId,
      ngayStr,
    );

    for (var caHoc in caHocTrongNgay) {
      final tatCaHsCuaCa = await _lhsService.docDSHSTheoCaHoc(caHoc.id!);
      final hsCuaCa = tatCaHsCuaCa
          .where((hs) => _lhsService.hoatDongTrongNgay(hs, date))
          .toList();
      danhSachHSCuaTungCaMoi[caHoc.id!] = hsCuaCa;

      final targetTime = caHoc.gioBatDau.length >= 5
          ? caHoc.gioBatDau.substring(0, 5)
          : caHoc.gioBatDau;

      for (var hs in hsCuaCa) {
        final key = '${hs.id}-${caHoc.id}';
        final coDonNghi = hsCoDonNghiSet.contains(hs.id!);
        final ddRecord = diemDanhDaCoTrongNgay.firstWhere(
          (dd) {
            if (dd.idHocSinh != hs.id) return false;
            final parts = dd.gioDiemDanh.trim().split(' ');
            if (parts.length < 2) return false;
            final dDate = parts[0];
            final dTime = parts[1];
            if (dDate != ngayStr) return false;
            return dTime.startsWith(targetTime);
          },
          orElse: () => DiemDanh(
            idHocSinh: hs.id!,
            idLop: lopId,
            gioDiemDanh: '$ngayStr ${caHoc.gioBatDau}',
            trangThai: coDonNghi ? 'Nghỉ có phép' : 'Có mặt',
          ),
        );
        trangThaiMoi[key] = ddRecord;
      }
    }

    final allStudentsInClass = danhSachHSCuaTungCaMoi.values
        .expand((list) => list)
        .map((hs) => hs.id!)
        .toList();
    final warnings = await _diemDanhService.kiemTraVangLienTiepChoNhieuHS(
      allStudentsInClass,
      lopId,
    );

    caHocTrongNgay.sort((a, b) => a.gioBatDau.compareTo(b.gioBatDau));

    return currentState.copyWith(
      caHocTrongNgay: caHocTrongNgay,
      danhSachHSCuaTungCa: danhSachHSCuaTungCaMoi,
      trangThaiDiemDanh: trangThaiMoi,
      studentsWithWarnings: warnings,
      lastBulkBackupPerCa: {},
    );
  }

  Future<void> changeSelection(Lop? newLop, DateTime? newDate) async {
    final currentState = state.value;
    if (currentState == null) return;

    final nextState = currentState.copyWith(
      selectedLop: newLop ?? currentState.selectedLop,
      selectedDate: newDate ?? currentState.selectedDate,
    );

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadDataForSelection(nextState));
  }

  void updateAttendanceStatus(String key, String newStatus) {
    final currentState = state.value;
    if (currentState == null) return;

    final newTrangThai = Map<String, DiemDanh>.from(
      currentState.trangThaiDiemDanh,
    );
    if (newTrangThai.containsKey(key)) {
      newTrangThai[key] = newTrangThai[key]!.copyWith(trangThai: newStatus);
      state = AsyncValue.data(
        currentState.copyWith(trangThaiDiemDanh: newTrangThai),
      );
    }
  }

  void updateAttendanceNote(String key, String newNote) {
    final currentState = state.value;
    if (currentState == null) return;

    final newTrangThai = Map<String, DiemDanh>.from(
      currentState.trangThaiDiemDanh,
    );
    if (newTrangThai.containsKey(key)) {
      newTrangThai[key] = newTrangThai[key]!.copyWith(ghiChu: newNote);
      state = AsyncValue.data(
        currentState.copyWith(trangThaiDiemDanh: newTrangThai),
      );
    }
  }

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  Future<bool> saveAllChanges() async {
    if (_isSaving) return false;
    _isSaving = true;
    try {
      final currentState = state.value;
      if (currentState == null) return false;

      state = AsyncValue.data(currentState); // Keep showing current data

      final records = currentState.trangThaiDiemDanh.values.toList();
      await _diemDanhService.luuDanhSachDiemDanhAtomic(records);

      // Reload data to get all IDs updated correctly
      await changeSelection(
        currentState.selectedLop,
        currentState.selectedDate,
      );
      return true;
    } finally {
      _isSaving = false;
    }
  }

  void markAllPresent(LichHoc caHoc) {
    markAllStatus(caHoc, 'Có mặt');
  }

  /// Đánh dấu trạng thái hàng loạt cho duy nhất học sinh của caHoc đang chọn
  void markAllStatus(LichHoc caHoc, String targetStatus) {
    final currentState = state.value;
    if (currentState == null || caHoc.id == null) return;

    final caId = caHoc.id!;
    final hsCuaCa = currentState.danhSachHSCuaTungCa[caId] ?? [];
    final newTrangThai = Map<String, DiemDanh>.from(
      currentState.trangThaiDiemDanh,
    );
    final backupForThisCa = <String, DiemDanh>{};

    for (var hs in hsCuaCa) {
      final key = '${hs.id}-$caId';
      if (newTrangThai.containsKey(key)) {
        backupForThisCa[key] = newTrangThai[key]!;
        newTrangThai[key] = newTrangThai[key]!.copyWith(
          trangThai: targetStatus,
        );
      }
    }

    final newBackupMap = Map<int, Map<String, DiemDanh>>.from(
      currentState.lastBulkBackupPerCa,
    );
    newBackupMap[caId] = backupForThisCa;

    state = AsyncValue.data(
      currentState.copyWith(
        trangThaiDiemDanh: newTrangThai,
        lastBulkBackupPerCa: newBackupMap,
      ),
    );
  }

  /// Hoàn tác thao tác hàng loạt gần nhất của caHoc
  void undoBulkAction(LichHoc caHoc) {
    final currentState = state.value;
    if (currentState == null || caHoc.id == null) return;

    final caId = caHoc.id!;
    final backupForThisCa = currentState.lastBulkBackupPerCa[caId];
    if (backupForThisCa == null || backupForThisCa.isEmpty) return;

    final newTrangThai = Map<String, DiemDanh>.from(
      currentState.trangThaiDiemDanh,
    );
    backupForThisCa.forEach((key, record) {
      newTrangThai[key] = record;
    });

    final newBackupMap = Map<int, Map<String, DiemDanh>>.from(
      currentState.lastBulkBackupPerCa,
    );
    newBackupMap.remove(caId);

    state = AsyncValue.data(
      currentState.copyWith(
        trangThaiDiemDanh: newTrangThai,
        lastBulkBackupPerCa: newBackupMap,
      ),
    );
  }
}
