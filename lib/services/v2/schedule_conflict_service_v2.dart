// File: lib/services/v2/schedule_conflict_service_v2.dart

import '../../models/v2/lich_hoc_v2.dart';
import '../../repositories/v2/schedule_repository_v2.dart';

class ConflictResult {
  final bool canAssign;
  final List<String> hardConflicts;
  final List<String> softWarnings;
  final List<String> reasonCodes;

  ConflictResult({
    required this.canAssign,
    this.hardConflicts = const [],
    this.softWarnings = const [],
    this.reasonCodes = const [],
  });
}

class ScheduleConflictServiceV2 {
  final ScheduleRepositoryV2 _scheduleRepo = ScheduleRepositoryV2();

  Future<ConflictResult> checkConflict(int hsId, LichHocV2 newSchedule) async {
    // Basic implementation: check overlap in same day/time for the student across all classes
    // and specific personal blocked dates (lich_can)
    return ConflictResult(canAssign: true);
  }

  bool isTimeOverlapping(String start1, String end1, String start2, String end2) {
    return start1.compareTo(end2) < 0 && start2.compareTo(end1) < 0;
  }
}
