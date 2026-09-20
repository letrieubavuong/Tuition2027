// File: lib/services/v2/roster_service_v2.dart

import '../../models/v2/hoc_sinh_v2.dart';
import '../../models/v2/buoi_hoc_v2.dart';
import '../../models/v2/tham_gia_lop_v2.dart';
import '../../repositories/v2/hoc_sinh_repository_v2.dart';
import '../../repositories/v2/membership_repository_v2.dart';
import '../../repositories/v2/session_repository_v2.dart';
import '../../repositories/v2/attendance_repository_v2.dart';

class RosterEntry {
  final HocSinhV2 student;
  final String status; // CO_MAT, NGHI, CHUA_DIEM_DANH, etc.
  final String loaiThamGia; // CHINH, DOI_CA, HOC_BU
  RosterEntry({required this.student, required this.status, required this.loaiThamGia});
}

class RosterServiceV2 {
  final HocSinhRepositoryV2 _hsRepo = HocSinhRepositoryV2();
  final MembershipRepositoryV2 _mRepo = MembershipRepositoryV2();
  final SessionRepositoryV2 _sessionRepo = SessionRepositoryV2();
  final AttendanceRepositoryV2 _aRepo = AttendanceRepositoryV2();

  Future<List<RosterEntry>> getRosterForSession(int sessionId) async {
    final session = await _sessionRepo.getById(sessionId);
    if (session == null) return [];

    final activeMemberships = await _mRepo.getActiveAt(session.idLop, session.ngay);
    final attendances = await _aRepo.getBySessionId(sessionId);
    
    final List<RosterEntry> roster = [];
    
    for (var m in activeMemberships) {
      final student = await _hsRepo.getById(m.idHocSinh);
      if (student == null) continue;

      final attendance = attendances.firstWhere((a) => a.idHocSinh == student.id, orElse: () => null as dynamic);
      
      roster.add(RosterEntry(
        student: student,
        status: attendance?.trangThai ?? 'CHUA_DIEM_DANH',
        loaiThamGia: attendance?.loaiThamGia ?? 'CHINH',
      ));
    }
    
    // Add students from other classes who are attending this session (Make-up or Change Shift)
    for (var a in attendances) {
      if (!activeMemberships.any((m) => m.idHocSinh == a.idHocSinh)) {
        final student = await _hsRepo.getById(a.idHocSinh);
        if (student != null) {
          roster.add(RosterEntry(
            student: student,
            status: a.trangThai,
            loaiThamGia: a.loaiThamGia,
          ));
        }
      }
    }

    return roster;
  }
}
