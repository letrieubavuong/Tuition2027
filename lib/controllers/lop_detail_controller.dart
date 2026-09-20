// File: lib/controllers/lop_detail_controller.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/v2/lop_v2.dart';
import '../models/v2/hoc_sinh_v2.dart';
import '../models/v2/lich_hoc_v2.dart';
import '../repositories/v2/lop_repository_v2.dart';
import '../repositories/v2/hoc_sinh_repository_v2.dart';
import '../repositories/v2/membership_repository_v2.dart';
import '../repositories/v2/schedule_repository_v2.dart';
import '../services/v2/roster_service_v2.dart';
import '../services/v2/tuition_service_v2.dart';
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
  final LopV2 lop;
  final List<HocSinhV2> hocSinhs;
  final List<LichHocV2> lichHocs;
  final List<dynamic> nhiemVus; // TODO: V2 NhiemVu
  final String selectedMonth;
  final int siSo;
  final LopSummary summary;

  LopDetailState({
    required this.lop,
    this.hocSinhs = const [],
    this.lichHocs = const [],
    this.nhiemVus = const [],
    required this.selectedMonth,
    this.siSo = 0,
    LopSummary? summary,
  }) : summary = summary ?? LopSummary();
}

@riverpod
class LopDetailController extends _$LopDetailController {
  LopRepositoryV2 get _lopRepo => ref.read(lopRepositoryV2Provider);
  HocSinhRepositoryV2 get _hsRepo => ref.read(hocSinhRepositoryV2Provider);
  MembershipRepositoryV2 get _mRepo => ref.read(membershipRepositoryV2Provider);
  ScheduleRepositoryV2 get _sRepo => ref.read(scheduleRepositoryV2Provider);
  TuitionServiceV2 get _tuitionService => ref.read(tuitionServiceV2Provider);

  @override
  Future<LopDetailState> build(int lopId) async {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    return await _loadAllData(lopId, month: currentMonth);
  }

  Future<LopDetailState> _loadAllData(int lopId, {String? month}) async {
    final selectedMonth = month ?? DateFormat('yyyy-MM').format(DateTime.now());
    final dateToday = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final lop = await _lopRepo.getById(lopId);
    if (lop == null) throw Exception('Lớp không tồn tại');

    final memberships = await _mRepo.getActiveAt(lopId, dateToday);
    final List<HocSinhV2> students = [];
    for (var m in memberships) {
      final s = await _hsRepo.getById(m.idHocSinh);
      if (s != null) students.add(s);
    }

    final lichHocs = await _sRepo.getByClassId(lopId);

    // Aggregate summary for all students in class
    int totalDue = 0;
    int totalPaid = 0;
    for (var s in students) {
      final res = await _tuitionService.calculate(s.id!, lopId, selectedMonth);
      totalDue += res.amountDue;
      totalPaid += res.amountPaid;
    }

    return LopDetailState(
      lop: lop,
      hocSinhs: students,
      lichHocs: lichHocs,
      selectedMonth: selectedMonth,
      siSo: students.length,
      summary: LopSummary(
        tongHocPhiDuKien: totalDue,
        tongHocPhiDaThu: totalPaid,
        tyLeChuyenCan: 0.85, // TODO: Implement real attendance rate
      ),
    );
  }

  Future<void> refreshAll() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadAllData(lopId));
  }
}
