// File: lib/services/v2/report_service_v2.dart

import '../../models/v2/lop_v2.dart';
import '../../models/v2/hoc_sinh_v2.dart';
import '../../repositories/v2/lop_repository_v2.dart';
import '../../repositories/v2/hoc_sinh_repository_v2.dart';
import '../../repositories/v2/membership_repository_v2.dart';
import 'tuition_service_v2.dart';

class ClassTuitionReportV2 {
  final LopV2 lop;
  final String month;
  final int totalDue;
  final int totalPaid;
  final List<StudentDebtV2> debtors;

  ClassTuitionReportV2({
    required this.lop,
    required this.month,
    required this.totalDue,
    required this.totalPaid,
    required this.debtors,
  });
}

class StudentDebtV2 {
  final HocSinhV2 student;
  final int amountDue;
  final int amountPaid;
  final int balance;

  StudentDebtV2({required this.student, required this.amountDue, required this.amountPaid, required this.balance});
}

class ReportServiceV2 {
  final LopRepositoryV2 _lopRepo = LopRepositoryV2();
  final HocSinhRepositoryV2 _hsRepo = HocSinhRepositoryV2();
  final MembershipRepositoryV2 _mRepo = MembershipRepositoryV2();
  final TuitionServiceV2 _tuitionService = TuitionServiceV2();

  Future<ClassTuitionReportV2> getClassTuitionReport(int lopId, String month) async {
    final lop = await _lopRepo.getById(lopId);
    if (lop == null) throw Exception('Lớp không tồn tại');

    final memberships = await _mRepo.getByClassId(lopId); // Simple for now
    final List<StudentDebtV2> debtors = [];
    int totalDue = 0;
    int totalPaid = 0;

    for (var m in memberships) {
      final hs = await _hsRepo.getById(m.idHocSinh);
      if (hs == null) continue;

      final res = await _tuitionService.calculate(hs.id!, lopId, month);
      totalDue += res.amountDue;
      totalPaid += res.amountPaid;

      if (res.amountRemaining > 0) {
        debtors.add(StudentDebtV2(
          student: hs,
          amountDue: res.amountDue,
          amountPaid: res.amountPaid,
          balance: res.amountRemaining,
        ));
      }
    }

    return ClassTuitionReportV2(
      lop: lop,
      month: month,
      totalDue: totalDue,
      totalPaid: totalPaid,
      debtors: debtors,
    );
  }
}
