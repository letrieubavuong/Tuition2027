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

  DiemDanhState({
    this.lopList = const [],
    this.selectedLop,
    required this.selectedDate,
    this.caHocTrongNgay = const [],
    this.danhSachHSCuaTungCa = const {},
    this.trangThaiDiemDanh = const {},
    this.studentsWithWarnings = const {},
  });

  DiemDanhState copyWith({
    List<Lop>? lopList,
    Lop? selectedLop,
    DateTime? selectedDate,
    List<LichHoc>? caHocTrongNgay,
    Map<int, List<HSLopViewModel>>? danhSachHSCuaTungCa,
    Map<String, DiemDanh>? trangThaiDiemDanh,
    Set<int>? studentsWithWarnings,
  }) {
    return DiemDanhState(
      lopList: lopList ?? this.lopList,
      selectedLop: selectedLop ?? this.selectedLop,
      selectedDate: selectedDate ?? this.selectedDate,
      caHocTrongNgay: caHocTrongNgay ?? this.caHocTrongNgay,
      danhSachHSCuaTungCa: danhSachHSCuaTungCa ?? this.danhSachHSCuaTungCa,
      trangThaiDiemDanh: trangThaiDiemDanh ?? this.trangThaiDiemDanh,
      studentsWithWarnings: studentsWithWarnings ?? this.studentsWithWarnings,
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

    for (var caHoc in caHocTrongNgay) {
      final hsCuaCa = await _lhsService.docDSHSTheoCaHoc(caHoc.id!);
      danhSachHSCuaTungCaMoi[caHoc.id!] = hsCuaCa;

      for (var hs in hsCuaCa) {
        final key = '${hs.id}-${caHoc.id}';
        final ddRecord = diemDanhDaCoTrongNgay.firstWhere(
          (dd) =>
              dd.idHocSinh == hs.id &&
              dd.gioDiemDanh.startsWith('$ngayStr ${caHoc.gioBatDau}'),
          orElse: () => DiemDanh(
            idHocSinh: hs.id!,
            idLop: lopId,
            gioDiemDanh: '$ngayStr ${caHoc.gioBatDau}',
            trangThai: 'Có mặt',
          ),
        );
        trangThaiMoi[key] = ddRecord;
      }
    }

    final allStudentsInClass = danhSachHSCuaTungCaMoi.values
        .expand((list) => list)
        .map((hs) => hs.id!)
        .toSet();
    final warnings = <int>{};
    for (final hsId in allStudentsInClass) {
      final hasWarning = await _diemDanhService.kiemTraVangLienTiep(
        hsId,
        lopId,
      );
      if (hasWarning) warnings.add(hsId);
    }

    caHocTrongNgay.sort((a, b) => a.gioBatDau.compareTo(b.gioBatDau));

    return currentState.copyWith(
      caHocTrongNgay: caHocTrongNgay,
      danhSachHSCuaTungCa: danhSachHSCuaTungCaMoi,
      trangThaiDiemDanh: trangThaiMoi,
      studentsWithWarnings: warnings,
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
      newTrangThai[key]!.trangThai = newStatus;
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
      newTrangThai[key]!.ghiChu = newNote;
      state = AsyncValue.data(
        currentState.copyWith(trangThaiDiemDanh: newTrangThai),
      );
    }
  }

  Future<void> saveAllChanges() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = AsyncValue.data(currentState); // Keep showing current data

    for (final record in currentState.trangThaiDiemDanh.values) {
      final newId = await _diemDanhService.themDiemDanh(record);
      if (record.id == null && newId > 0) {
        record.id = newId;
      }
    }
    // Optionally, reload data to get all IDs updated correctly
    await changeSelection(currentState.selectedLop, currentState.selectedDate);
  }

  void markAllPresent(LichHoc caHoc) {
    final currentState = state.value;
    if (currentState == null) return;

    final hsCuaCa = currentState.danhSachHSCuaTungCa[caHoc.id!] ?? [];
    final newTrangThai = Map<String, DiemDanh>.from(
      currentState.trangThaiDiemDanh,
    );

    for (var hs in hsCuaCa) {
      final key = '${hs.id}-${caHoc.id}';
      if (newTrangThai.containsKey(key)) {
        newTrangThai[key]!.trangThai = 'Có mặt';
      }
    }
    state = AsyncValue.data(
      currentState.copyWith(trangThaiDiemDanh: newTrangThai),
    );
  }
}
