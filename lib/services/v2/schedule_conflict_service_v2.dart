// File: lib/services/v2/schedule_conflict_service_v2.dart

import '../../models/v2/lich_hoc_v2.dart';
import '../../utils/db_v2.dart';

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
  final DBV2 _dbHelper = DBV2.instance;

  Future<ConflictResult> checkConflict(int hsId, LichHocV2 newSchedule, {int minimumTravelMinutes = 15}) async {
    final db = await _dbHelper.database;
    final List<String> hard = [];
    final List<String> soft = [];
    final List<String> codes = [];

    // 1. Check conflicts with other active class schedules for this student
    final List<Map<String, dynamic>> otherSchedules = await db.rawQuery('''
      SELECT LH.*, L.ten_lop
      FROM phan_ca_hoc_sinh PC
      JOIN lich_hoc LH ON PC.id_lich_hoc = LH.id
      JOIN lop L ON LH.id_lop = L.id
      WHERE PC.id_hoc_sinh = ? 
      AND LH.thu_trong_tuan = ?
      AND (PC.den_ngay IS NULL OR PC.den_ngay >= ?)
    ''', [hsId, newSchedule.thuTrongTuan, newSchedule.hieuLucTu]);

    for (var other in otherSchedules) {
      if (other['id'] == newSchedule.id) continue;
      
      final otherStart = other['gio_bat_dau'] as String;
      final otherEnd = other['gio_ket_thuc'] as String;
      
      if (isTimeOverlapping(newSchedule.gioBatDau, newSchedule.gioKetThuc, otherStart, otherEnd)) {
        hard.add('Trùng lịch với lớp ${other['ten_lop']} ($otherStart - $otherEnd)');
        codes.add('OVERLAP_CLASS');
      } else if (isNear(newSchedule.gioBatDau, newSchedule.gioKetThuc, otherStart, otherEnd, minimumTravelMinutes)) {
        soft.add('Sát giờ với lớp ${other['ten_lop']} ($otherStart - $otherEnd). Khoảng nghỉ < $minimumTravelMinutes phút.');
        codes.add('NEAR_CLASS');
      }
    }

    // 2. Check personal blocked schedules (lich_can)
    final List<Map<String, dynamic>> blockedSchedules = await db.query(
      'lich_can',
      where: 'id_hoc_sinh = ? AND thu_trong_tuan = ?',
      whereArgs: [hsId, newSchedule.thuTrongTuan],
    );

    for (var b in blockedSchedules) {
      final bStart = b['gio_bat_dau'] as String;
      final bEnd = b['gio_ket_thuc'] as String;
      final type = b['loai'] as String;
      final level = b['muc_do'] as String;

      if (isTimeOverlapping(newSchedule.gioBatDau, newSchedule.gioKetThuc, bStart, bEnd)) {
        if (level == 'CUNG') {
          hard.add('Vướng lịch bận: $type ($bStart - $bEnd)');
          codes.add('OVERLAP_BLOCKED_HARD');
        } else {
          soft.add('Trùng nguyện vọng: $type ($bStart - $bEnd)');
          codes.add('OVERLAP_BLOCKED_SOFT');
        }
      }
    }

    return ConflictResult(
      canAssign: hard.isEmpty,
      hardConflicts: hard,
      softWarnings: soft,
      reasonCodes: codes,
    );
  }

  bool isTimeOverlapping(String start1, String end1, String start2, String end2) {
    return start1.compareTo(end2) < 0 && start2.compareTo(end1) < 0;
  }

  bool isNear(String start1, String end1, String start2, String end2, int bufferMinutes) {
    final int s1 = _toMinutes(start1);
    final int e1 = _toMinutes(end1);
    final int s2 = _toMinutes(start2);
    final int e2 = _toMinutes(end2);

    // Gap between first ending and second starting
    if (s2 >= e1 && (s2 - e1) < bufferMinutes) return true;
    if (s1 >= e2 && (s1 - e2) < bufferMinutes) return true;

    return false;
  }

  int _toMinutes(String time) {
    try {
      final parts = time.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return 0;
    }
  }
}
