// File: lib/services/v2/session_generation_service_v2.dart

import 'package:intl/intl.dart';
import '../../models/v2/buoi_hoc_v2.dart';
import '../../models/v2/lich_hoc_v2.dart';
import '../../repositories/v2/schedule_repository_v2.dart';
import '../../repositories/v2/session_repository_v2.dart';

class SessionGenerationServiceV2 {
  final ScheduleRepositoryV2 _scheduleRepo = ScheduleRepositoryV2();
  final SessionRepositoryV2 _sessionRepo = SessionRepositoryV2();

  /// Generates planned sessions for a class in a given month.
  /// month: YYYY-MM
  Future<int> generateForMonth(int lopId, String month) async {
    final DateTime firstDay = DateFormat('yyyy-MM').parse(month);
    final DateTime lastDay = DateTime(firstDay.year, firstDay.month + 1, 0);
    
    final List<LichHocV2> schedules = await _scheduleRepo.getByClassId(lopId);
    int generatedCount = 0;

    for (var day = firstDay; day.isBefore(lastDay.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      final int weekday = day.weekday; // 1=Mon, 7=Sun
      final String dateStr = DateFormat('yyyy-MM-dd').format(day);
      
      final activeSchedules = schedules.where((s) {
        if (s.thuTrongTuan != weekday) return false;
        final sStart = DateTime.parse(s.hieuLucTu);
        if (day.isBefore(sStart)) return false;
        if (s.hieuLucDen != null) {
          final sEnd = DateTime.parse(s.hieuLucDen!);
          if (day.isAfter(sEnd)) return false;
        }
        return true;
      });

      for (var s in activeSchedules) {
        final session = BuoiHocV2(
          idLop: lopId,
          idLichHoc: s.id,
          ngay: dateStr,
          gioBatDau: s.gioBatDau,
          gioKetThuc: s.gioKetThuc,
          loai: 'CHINH',
          trangThai: 'DU_KIEN',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Repository insert uses ignore/check to ensure idempotency
        final id = await _sessionRepo.insert(session);
        if (id > 0) generatedCount++;
      }
    }
    return generatedCount;
  }
}
