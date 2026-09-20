// File: lib/models/report_models.dart

import 'lop.dart';

enum ReportPeriodType { month, customRange }

enum ReportScope { singleClass, allClasses }

enum ReportSection { classSummary, attendance, tuition, evaluation }

class ReportRequest {
  final ReportPeriodType periodType;
  final String monthStr; // YYYY-MM if periodType == month
  final DateTime startDate;
  final DateTime endDate;
  final ReportScope scope;
  final int? classId;
  final Set<ReportSection> sections;

  ReportRequest({
    required this.periodType,
    required this.monthStr,
    required this.startDate,
    required this.endDate,
    required this.scope,
    this.classId,
    required this.sections,
  });
}

class StudentAttendanceReportItem {
  final int studentId;
  final String studentName;
  final int totalSessions;
  final int presentCount;
  final int excusedAbsenceCount;
  final int unexcusedAbsenceCount;
  final double attendanceRate;

  StudentAttendanceReportItem({
    required this.studentId,
    required this.studentName,
    required this.totalSessions,
    required this.presentCount,
    required this.excusedAbsenceCount,
    required this.unexcusedAbsenceCount,
    required this.attendanceRate,
  });
}

class StudentTuitionReportItem {
  final int studentId;
  final String studentName;
  final int totalFee;
  final int paidAmount;
  final int debtAmount;
  final int discount;
  final String? phone;

  StudentTuitionReportItem({
    required this.studentId,
    required this.studentName,
    required this.totalFee,
    required this.paidAmount,
    required this.debtAmount,
    required this.discount,
    this.phone,
  });
}

class StudentEvaluationReportItem {
  final int studentId;
  final String studentName;
  final double attendanceScore;
  final double attitudeScore;
  final double homeworkScore;
  final double testScore;
  final double averageScore;
  final String rank;
  final String remark;

  StudentEvaluationReportItem({
    required this.studentId,
    required this.studentName,
    required this.attendanceScore,
    required this.attitudeScore,
    required this.homeworkScore,
    required this.testScore,
    required this.averageScore,
    required this.rank,
    required this.remark,
  });
}

class ClassReportData {
  final Lop lop;
  final int totalStudents;
  final int activeStudents;
  final int pausedStudents;
  final int leftStudents;
  final int totalSessions;
  final double attendanceRate;
  final int totalExpectedTuition;
  final int totalCollectedTuition;
  final int totalDebtTuition;
  final double averageClassScore;

  final List<StudentAttendanceReportItem> attendanceList;
  final List<StudentTuitionReportItem> tuitionList;
  final List<StudentEvaluationReportItem> evaluationList;

  ClassReportData({
    required this.lop,
    required this.totalStudents,
    required this.activeStudents,
    required this.pausedStudents,
    required this.leftStudents,
    required this.totalSessions,
    required this.attendanceRate,
    required this.totalExpectedTuition,
    required this.totalCollectedTuition,
    required this.totalDebtTuition,
    required this.averageClassScore,
    required this.attendanceList,
    required this.tuitionList,
    required this.evaluationList,
  });
}

class FacilityReportData {
  final ReportRequest request;
  final List<ClassReportData> classReports;
  final int totalClasses;
  final int totalStudents;
  final int totalExpectedTuition;
  final int totalCollectedTuition;
  final int totalDebtTuition;
  final double overallAttendanceRate;

  FacilityReportData({
    required this.request,
    required this.classReports,
    required this.totalClasses,
    required this.totalStudents,
    required this.totalExpectedTuition,
    required this.totalCollectedTuition,
    required this.totalDebtTuition,
    required this.overallAttendanceRate,
  });
}
