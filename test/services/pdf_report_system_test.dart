// File: test/services/pdf_report_system_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lop_hoc_sinh.dart';
import 'package:tuition2025/models/report_models.dart';
import 'package:tuition2025/services/lop_service.dart';
import 'package:tuition2025/services/hoc_sinh_service.dart';
import 'package:tuition2025/services/lop_hoc_sinh_service.dart';
import 'package:tuition2025/services/report_service.dart';
import 'package:tuition2025/services/pdf_export_service.dart';
import 'package:tuition2025/utils/db.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('net.nfet.printing'), (
          MethodCall methodCall,
        ) async {
          return 1;
        });
  });

  group('PDF & Report System Comprehensive Test Suite', () {
    late Database db;
    late LopService lopService;
    late HocSinhService hsService;
    late LopHocSinhService lhsService;
    late ReportService reportService;
    late PdfExportService pdfService;

    setUp(() async {
      db = await DBHelper.instance.database;
      await db.delete(DBHelper.tenBangDiemDanh);
      await db.delete(DBHelper.tenBangThanhToan);
      await db.delete(DBHelper.tenBangLopHS);
      await db.delete(DBHelper.tenBangLop);
      await db.delete(DBHelper.tenBangHS);

      lopService = LopService();
      hsService = HocSinhService();
      lhsService = LopHocSinhService();
      reportService = ReportService();
      pdfService = PdfExportService();
    });

    tearDown(() async {
      await db.delete(DBHelper.tenBangDiemDanh);
      await db.delete(DBHelper.tenBangThanhToan);
      await db.delete(DBHelper.tenBangLopHS);
      await db.delete(DBHelper.tenBangLop);
      await db.delete(DBHelper.tenBangHS);
    });

    test('1. ReportRequest DTO - Monthly request creation', () {
      final request = ReportRequest(
        periodType: ReportPeriodType.month,
        monthStr: '2026-09',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
        scope: ReportScope.allClasses,
        sections: {ReportSection.classSummary, ReportSection.attendance},
      );

      expect(request.periodType, equals(ReportPeriodType.month));
      expect(request.monthStr, equals('2026-09'));
      expect(request.scope, equals(ReportScope.allClasses));
      expect(request.classId, isNull);
      expect(request.sections.contains(ReportSection.attendance), isTrue);
      expect(request.sections.contains(ReportSection.tuition), isFalse);
    });

    test('2. ReportRequest DTO - Custom date range request creation', () {
      final start = DateTime(2026, 9, 10);
      final end = DateTime(2026, 9, 20);
      final request = ReportRequest(
        periodType: ReportPeriodType.customRange,
        monthStr: '2026-09',
        startDate: start,
        endDate: end,
        scope: ReportScope.singleClass,
        classId: 42,
        sections: {ReportSection.tuition, ReportSection.evaluation},
      );

      expect(request.periodType, equals(ReportPeriodType.customRange));
      expect(request.startDate, equals(start));
      expect(request.endDate, equals(end));
      expect(request.scope, equals(ReportScope.singleClass));
      expect(request.classId, equals(42));
    });

    test('3. ReportRequest DTO - Scope & Section selection toggle logic', () {
      final sections = <ReportSection>{ReportSection.classSummary};
      sections.add(ReportSection.attendance);
      sections.add(ReportSection.tuition);
      expect(sections.length, equals(3));

      sections.remove(ReportSection.classSummary);
      expect(sections.contains(ReportSection.classSummary), isFalse);
      expect(sections.length, equals(2));
    });

    test(
      '4. Attendance calculation - Percentage logic with 0 and N sessions',
      () {
        final zeroSessionItem = StudentAttendanceReportItem(
          studentId: 1,
          studentName: 'Test Student',
          totalSessions: 0,
          presentCount: 0,
          excusedAbsenceCount: 0,
          unexcusedAbsenceCount: 0,
          attendanceRate: 0.0,
        );
        expect(zeroSessionItem.attendanceRate, equals(0.0));

        final activeItem = StudentAttendanceReportItem(
          studentId: 2,
          studentName: 'Active Student',
          totalSessions: 10,
          presentCount: 8,
          excusedAbsenceCount: 1,
          unexcusedAbsenceCount: 1,
          attendanceRate: 0.80,
        );
        expect(activeItem.attendanceRate, equals(0.80));
      },
    );

    test(
      '5. Tuition totals math logic - Expected, collected, and debt calculations',
      () {
        final tuitionItem = StudentTuitionReportItem(
          studentId: 1,
          studentName: 'Student 1',
          totalFee: 500000,
          paidAmount: 300000,
          debtAmount: 200000,
          discount: 0,
        );

        expect(
          tuitionItem.totalFee - tuitionItem.paidAmount,
          equals(tuitionItem.debtAmount),
        );
        expect(tuitionItem.debtAmount, equals(200000));
      },
    );

    test('6. Evaluation metrics model check - Averages & rankings', () {
      final evalItem = StudentEvaluationReportItem(
        studentId: 1,
        studentName: 'Student Eval',
        attendanceScore: 9.0,
        attitudeScore: 8.5,
        homeworkScore: 9.5,
        testScore: 8.0,
        averageScore: 8.75,
        rank: 'Giỏi',
        remark: 'Học tập chăm chỉ',
      );

      expect(evalItem.averageScore, equals(8.75));
      expect(evalItem.rank, equals('Giỏi'));
    });

    test(
      '7. ReportService - generateFacilityReport empty database check',
      () async {
        final request = ReportRequest(
          periodType: ReportPeriodType.month,
          monthStr: '2026-09',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
          scope: ReportScope.allClasses,
          sections: {
            ReportSection.classSummary,
            ReportSection.attendance,
            ReportSection.tuition,
          },
        );

        final facilityReport = await reportService.generateFacilityReport(
          request,
        );

        expect(facilityReport.totalClasses, equals(0));
        expect(facilityReport.totalStudents, equals(0));
        expect(facilityReport.totalExpectedTuition, equals(0));
        expect(facilityReport.totalCollectedTuition, equals(0));
        expect(facilityReport.totalDebtTuition, equals(0));
        expect(facilityReport.classReports, isEmpty);
      },
    );

    test(
      '8. ReportService - Single class report aggregation with SQLite data',
      () async {
        final lop = await lopService.taoLop(Lop(ten: 'Lớp 10A1', khoi: 10));
        final hs = await hsService.taoHocSinh(
          HS(ten: 'Nguyễn Văn A', sdt: '0901234567'),
        );
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop.id!,
            idHocSinh: hs.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        final request = ReportRequest(
          periodType: ReportPeriodType.month,
          monthStr: '2026-09',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
          scope: ReportScope.singleClass,
          classId: lop.id!,
          sections: {
            ReportSection.classSummary,
            ReportSection.attendance,
            ReportSection.tuition,
            ReportSection.evaluation,
          },
        );

        final facilityReport = await reportService.generateFacilityReport(
          request,
        );

        expect(facilityReport.totalClasses, equals(1));
        expect(facilityReport.totalStudents, equals(1));
        expect(facilityReport.classReports.length, equals(1));

        final classData = facilityReport.classReports.first;
        expect(classData.lop.id, equals(lop.id));
        expect(classData.lop.ten, equals('Lớp 10A1'));
        expect(classData.totalStudents, equals(1));
        expect(classData.attendanceList.length, equals(1));
        expect(
          classData.attendanceList.first.studentName,
          equals('Nguyễn Văn A'),
        );
      },
    );

    test(
      '9. ReportService - Facility-wide report aggregation across multiple classes',
      () async {
        final lop1 = await lopService.taoLop(Lop(ten: 'Lớp Toán 9A', khoi: 9));
        final lop2 = await lopService.taoLop(Lop(ten: 'Lớp Văn 9B', khoi: 9));

        final hs1 = await hsService.taoHocSinh(HS(ten: 'Học sinh 1'));
        final hs2 = await hsService.taoHocSinh(HS(ten: 'Học sinh 2'));

        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop1.id!,
            idHocSinh: hs1.id!,
            ngayThamGia: '2026-09-01',
          ),
        );
        await lhsService.themHocSinhVaoLop(
          LopHocSinh(
            idLop: lop2.id!,
            idHocSinh: hs2.id!,
            ngayThamGia: '2026-09-01',
          ),
        );

        final request = ReportRequest(
          periodType: ReportPeriodType.month,
          monthStr: '2026-09',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
          scope: ReportScope.allClasses,
          sections: {
            ReportSection.classSummary,
            ReportSection.attendance,
            ReportSection.tuition,
          },
        );

        final facilityReport = await reportService.generateFacilityReport(
          request,
        );

        expect(facilityReport.totalClasses, equals(2));
        expect(facilityReport.totalStudents, equals(2));
        expect(facilityReport.classReports.length, equals(2));
      },
    );

    test('10. Active status vs enrollment filtering check', () async {
      final lop = await lopService.taoLop(Lop(ten: 'Lớp Lý 11', khoi: 11));
      final hsActive = await hsService.taoHocSinh(HS(ten: 'Active Student'));
      final hsInactive = await hsService.taoHocSinh(
        HS(ten: 'Inactive Student'),
      );

      await lhsService.themHocSinhVaoLop(
        LopHocSinh(
          idLop: lop.id!,
          idHocSinh: hsActive.id!,
          trangThai: 'DANG_HOC',
          ngayThamGia: '2026-09-01',
        ),
      );
      await lhsService.themHocSinhVaoLop(
        LopHocSinh(
          idLop: lop.id!,
          idHocSinh: hsInactive.id!,
          trangThai: 'DA_NE',
          ngayThamGia: '2026-09-01',
        ),
      );

      final request = ReportRequest(
        periodType: ReportPeriodType.month,
        monthStr: '2026-09',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
        scope: ReportScope.singleClass,
        classId: lop.id!,
        sections: {ReportSection.attendance},
      );

      final facilityReport = await reportService.generateFacilityReport(
        request,
      );
      expect(facilityReport.classReports.first.totalStudents, equals(2));
      expect(
        facilityReport.classReports.first.attendanceList.length,
        equals(2),
      );
    });

    test('11. FacilityReportData totals calculation integrity', () {
      final lop1 = Lop(id: 1, ten: 'Lớp A', khoi: 10);
      final class1 = ClassReportData(
        lop: lop1,
        totalStudents: 15,
        activeStudents: 15,
        pausedStudents: 0,
        leftStudents: 0,
        totalSessions: 8,
        attendanceRate: 0.95,
        totalExpectedTuition: 3000000,
        totalCollectedTuition: 2000000,
        totalDebtTuition: 1000000,
        averageClassScore: 8.5,
        attendanceList: [],
        tuitionList: [],
        evaluationList: [],
      );

      final lop2 = Lop(id: 2, ten: 'Lớp B', khoi: 11);
      final class2 = ClassReportData(
        lop: lop2,
        totalStudents: 20,
        activeStudents: 20,
        pausedStudents: 0,
        leftStudents: 0,
        totalSessions: 8,
        attendanceRate: 0.90,
        totalExpectedTuition: 4000000,
        totalCollectedTuition: 4000000,
        totalDebtTuition: 0,
        averageClassScore: 8.0,
        attendanceList: [],
        tuitionList: [],
        evaluationList: [],
      );

      final request = ReportRequest(
        periodType: ReportPeriodType.month,
        monthStr: '2026-09',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
        scope: ReportScope.allClasses,
        sections: {ReportSection.classSummary},
      );

      final facilityReport = FacilityReportData(
        request: request,
        classReports: [class1, class2],
        totalClasses: 2,
        totalStudents: 35,
        totalExpectedTuition:
            class1.totalExpectedTuition + class2.totalExpectedTuition,
        totalCollectedTuition:
            class1.totalCollectedTuition + class2.totalCollectedTuition,
        totalDebtTuition: class1.totalDebtTuition + class2.totalDebtTuition,
        overallAttendanceRate: 0.92,
      );

      expect(facilityReport.totalStudents, equals(35));
      expect(facilityReport.totalExpectedTuition, equals(7000000));
      expect(facilityReport.totalCollectedTuition, equals(6000000));
      expect(facilityReport.totalDebtTuition, equals(1000000));
    });

    test(
      '12. PDF Export Service - Unified PDF report structure creation test',
      () async {
        final lop1 = Lop(id: 1, ten: 'Lớp Hóa 12', khoi: 12);
        final class1 = ClassReportData(
          lop: lop1,
          totalStudents: 2,
          activeStudents: 2,
          pausedStudents: 0,
          leftStudents: 0,
          totalSessions: 4,
          attendanceRate: 0.875,
          totalExpectedTuition: 1000000,
          totalCollectedTuition: 600000,
          totalDebtTuition: 400000,
          averageClassScore: 9.38,
          attendanceList: [
            StudentAttendanceReportItem(
              studentId: 101,
              studentName: 'Trần Văn A',
              totalSessions: 4,
              presentCount: 4,
              excusedAbsenceCount: 0,
              unexcusedAbsenceCount: 0,
              attendanceRate: 1.0,
            ),
            StudentAttendanceReportItem(
              studentId: 102,
              studentName: 'Lê Thị B',
              totalSessions: 4,
              presentCount: 3,
              excusedAbsenceCount: 1,
              unexcusedAbsenceCount: 0,
              attendanceRate: 0.75,
            ),
          ],
          tuitionList: [
            StudentTuitionReportItem(
              studentId: 101,
              studentName: 'Trần Văn A',
              totalFee: 500000,
              paidAmount: 500000,
              debtAmount: 0,
              discount: 0,
            ),
            StudentTuitionReportItem(
              studentId: 102,
              studentName: 'Lê Thị B',
              totalFee: 500000,
              paidAmount: 100000,
              debtAmount: 400000,
              discount: 0,
            ),
          ],
          evaluationList: [
            StudentEvaluationReportItem(
              studentId: 101,
              studentName: 'Trần Văn A',
              attendanceScore: 10.0,
              attitudeScore: 9.0,
              homeworkScore: 9.5,
              testScore: 9.0,
              averageScore: 9.38,
              rank: 'Xuất sắc',
              remark: 'Học sinh rất giỏi',
            ),
          ],
        );

        final request = ReportRequest(
          periodType: ReportPeriodType.month,
          monthStr: '2026-09',
          startDate: DateTime(2026, 9, 1),
          endDate: DateTime(2026, 9, 30),
          scope: ReportScope.singleClass,
          classId: 1,
          sections: {
            ReportSection.classSummary,
            ReportSection.attendance,
            ReportSection.tuition,
            ReportSection.evaluation,
          },
        );

        final facilityReport = FacilityReportData(
          request: request,
          classReports: [class1],
          totalClasses: 1,
          totalStudents: 2,
          totalExpectedTuition: 1000000,
          totalCollectedTuition: 600000,
          totalDebtTuition: 400000,
          overallAttendanceRate: 0.875,
        );

        expect(
          () async => await pdfService.generateAndExportUnifiedPdf(
            facilityReport,
            action: PdfAction.preview,
          ),
          returnsNormally,
        );
      },
    );
  });
}
