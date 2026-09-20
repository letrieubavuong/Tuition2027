// File: lib/services/v2/roster_service_v2.dart

import '../../models/v2/hoc_sinh_v2.dart';
import '../../models/v2/buoi_hoc_v2.dart';
import '../../models/v2/diem_danh_v2.dart';
import '../../repositories/v2/hoc_sinh_repository_v2.dart';
import '../../repositories/v2/membership_repository_v2.dart';
import '../../repositories/v2/session_repository_v2.dart';
import '../../repositories/v2/attendance_repository_v2.dart';
import '../../utils/db_v2.dart';

class RosterEntry {
  final HocSinhV2 student;
  final String status; // CO_MAT, TRE, NGHI_CO_PHEP, NGHI_KHONG_PHEP, HOC_BU, CHUA_DIEM_DANH
  final String loaiThamGia; // CHINH, DOI_CA, HOC_BU
  final String? ghiChu;

  RosterEntry({
    required this.student, 
    required this.status, 
    required this.loaiThamGia,
    this.ghiChu,
  });
}

class RosterServiceV2 {
  final HocSinhRepositoryV2 _hsRepo = HocSinhRepositoryV2();
  final MembershipRepositoryV2 _mRepo = MembershipRepositoryV2();
  final SessionRepositoryV2 _sessionRepo = SessionRepositoryV2();
  final AttendanceRepositoryV2 _aRepo = AttendanceRepositoryV2();
  final DBV2 _db = DBV2.instance;

  Future<List<RosterEntry>> getRosterForSession(int sessionId) async {
    final session = await _sessionRepo.getById(sessionId);
    if (session == null) return [];

    final db = await _db.database;
    final String date = session.ngay;

    // 1. Get all students with active membership in this class on this date
    final memberships = await _mRepo.getActiveAt(session.idLop, date);
    final List<int> activeHsIds = memberships.map((m) => m.idHocSinh).toList();

    // 2. Identify students assigned to this specific recurring shift (if class has multiple shifts)
    // If session.idLichHoc is null, it's a PHAT_SINH session, we might need different logic.
    final List<int> assignedHsIds = [];
    if (session.idLichHoc != null) {
      final List<Map<String, dynamic>> assignments = await db.query(
        'phan_ca_hoc_sinh',
        where: 'id_lich_hoc = ? AND tu_ngay <= ? AND (den_ngay IS NULL OR den_ngay >= ?)',
        whereArgs: [session.idLichHoc, date, date],
      );
      assignedHsIds.addAll(assignments.map((a) => a['id_hoc_sinh'] as int));
    }

    // 3. Apply adjustments (Shift changes, Makeups)
    // Students moving OUT of this session
    final List<Map<String, dynamic>> movingOut = await db.query(
      'dieu_chinh_buoi_hoc',
      where: 'id_buoi_hoc_goc = ?',
      whereArgs: [sessionId],
    );
    final Set<int> movedOutIds = movingOut.map((m) => m['id_hoc_sinh'] as int).toSet();

    // Students moving INTO this session
    final List<Map<String, dynamic>> movingIn = await db.query(
      'dieu_chinh_buoi_hoc',
      where: 'id_buoi_hoc_tham_gia = ?',
      whereArgs: [sessionId],
    );
    final Map<int, String> movedInTypeMap = {
      for (var m in movingIn) m['id_hoc_sinh'] as int : m['loai'] as String
    };

    // 4. Determine final student list
    // - Assigned to this shift and NOT moved out
    // - OR Moved into this session
    final Set<int> finalStudentIds = {};
    
    // If no specific assignments exist for this class shift, include all active students (compat mode)
    if (session.idLichHoc != null) {
      final List<Map<String, dynamic>> allAssignmentsInClass = await db.query(
        'phan_ca_hoc_sinh',
        where: 'id_lop = ? AND tu_ngay <= ? AND (den_ngay IS NULL OR den_ngay >= ?)',
        whereArgs: [session.idLop, date, date],
      );
      
      if (allAssignmentsInClass.isEmpty) {
        // Class has no granular shift assignments yet -> everyone in roster
        finalStudentIds.addAll(activeHsIds);
      } else {
        finalStudentIds.addAll(assignedHsIds);
      }
    } else {
      // PHAT_SINH or special session -> typically explicitly adjusted in
      finalStudentIds.addAll(movedInTypeMap.keys);
    }
    
    finalStudentIds.removeAll(movedOutIds);
    finalStudentIds.addAll(movedInTypeMap.keys);

    // 5. Build Roster Entries
    final attendances = await _aRepo.getBySessionId(sessionId);
    final Map<int, DiemDanhV2> attendanceMap = {
      for (var a in attendances) a.idHocSinh : a
    };

    final List<RosterEntry> roster = [];
    for (int hsId in finalStudentIds) {
      final student = await _hsRepo.getById(hsId);
      if (student == null) continue;

      final att = attendanceMap[hsId];
      String loaiThamGia = movedInTypeMap[hsId] ?? 'CHINH';
      if (att != null) loaiThamGia = att.loaiThamGia;

      roster.add(RosterEntry(
        student: student,
        status: att?.trangThai ?? 'CHUA_DIEM_DANH',
        loaiThamGia: loaiThamGia,
        ghiChu: att?.ghiChu,
      ));
    }

    // Add anyone who has attendance but was not identified by logic (Safety)
    for (var att in attendances) {
      if (!finalStudentIds.contains(att.idHocSinh)) {
         final student = await _hsRepo.getById(att.idHocSinh);
         if (student != null) {
           roster.add(RosterEntry(
             student: student,
             status: att.trangThai,
             loaiThamGia: att.loaiThamGia,
             ghiChu: att.ghiChu,
           ));
         }
      }
    }

    return roster;
  }
}
