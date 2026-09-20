// File: lib/controllers/diem_danh_controller.dart

import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/v2/lop_v2.dart';
import '../models/v2/buoi_hoc_v2.dart';
import '../models/v2/diem_danh_v2.dart';
import '../repositories/v2/lop_repository_v2.dart';
import '../repositories/v2/session_repository_v2.dart';
import '../repositories/v2/attendance_repository_v2.dart';
import '../services/v2/roster_service_v2.dart';
import 'service_providers.dart';

part 'diem_danh_controller.g.dart';

class DiemDanhState {
  final List<LopV2> lopList;
  final LopV2? selectedLop;
  final DateTime selectedDate;
  final List<BuoiHocV2> sessions;
  final Map<int, List<RosterEntry>> rosterPerSession;

  DiemDanhState({
    this.lopList = const [],
    this.selectedLop,
    required this.selectedDate,
    this.sessions = const [],
    this.rosterPerSession = const {},
  });
}

@riverpod
class DiemDanhController extends _$DiemDanhController {
  LopRepositoryV2 get _lopRepo => ref.read(lopRepositoryV2Provider);
  SessionRepositoryV2 get _sessionRepo => ref.read(sessionRepositoryV2Provider);
  RosterServiceV2 get _rosterService => ref.read(rosterServiceV2Provider);

  @override
  Future<DiemDanhState> build(int? initialLopId, DateTime? initialDate) async {
    final date = initialDate ?? DateTime.now();
    final lopList = await _lopRepo.getAll();
    
    LopV2? selectedLop;
    if (lopList.isNotEmpty) {
      selectedLop = (initialLopId != null) 
        ? lopList.firstWhere((l) => l.id == initialLopId, orElse: () => lopList.first)
        : lopList.first;
    }

    final stateObj = DiemDanhState(
      lopList: lopList,
      selectedLop: selectedLop,
      selectedDate: date,
    );
    
    return await _loadData(stateObj);
  }

  Future<DiemDanhState> _loadData(DiemDanhState current) async {
    if (current.selectedLop == null) return current;

    final dateStr = DateFormat('yyyy-MM-dd').format(current.selectedDate);
    final sessions = await _sessionRepo.getByClassAndDateRange(current.selectedLop!.id!, dateStr, dateStr);

    final Map<int, List<RosterEntry>> rosterMap = {};
    for (var s in sessions) {
      rosterMap[s.id!] = await _rosterService.getRosterForSession(s.id!);
    }

    return DiemDanhState(
      lopList: current.lopList,
      selectedLop: current.selectedLop,
      selectedDate: current.selectedDate,
      sessions: sessions,
      rosterPerSession: rosterMap,
    );
  }

  Future<void> changeSelection(LopV2? newLop, DateTime? newDate) async {
    final current = state.value;
    if (current == null) return;
    
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadData(DiemDanhState(
      lopList: current.lopList,
      selectedLop: newLop ?? current.selectedLop,
      selectedDate: newDate ?? current.selectedDate,
    )));
  }
}
