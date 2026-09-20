// File: test/utils/student_status_and_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/utils/student_status.dart';
import 'package:tuition2025/utils/attendance_calculator.dart';

void main() {
  group('StudentStatus Tests', () {
    test('StudentStatus enum formatting and parsing', () {
      expect(StudentStatus.dangHoc.toDbString(), 'DANG_HOC');
      expect(StudentStatus.tamNgung.toDbString(), 'TAM_NGUNG');
      expect(StudentStatus.nghiHoc.toDbString(), 'NGHI_HOC');

      expect(StudentStatus.parse('DANG_HOC'), StudentStatus.dangHoc);
      expect(StudentStatus.parse('TAM_NGUNG'), StudentStatus.tamNgung);
      expect(StudentStatus.parse('PAUSED'), StudentStatus.tamNgung);
      expect(StudentStatus.parse('NGHI_HOC'), StudentStatus.nghiHoc);
      expect(StudentStatus.parse('STOPPED'), StudentStatus.nghiHoc);
      expect(StudentStatus.parse(null), StudentStatus.dangHoc);
    });

    test('StudentStatus helper getters', () {
      expect(StudentStatus.dangHoc.isStudying, isTrue);
      expect(StudentStatus.tamNgung.isPaused, isTrue);
      expect(StudentStatus.nghiHoc.isStopped, isTrue);
    });
  });

  group('AttendanceCalculator Tests', () {
    test('isStudentPaused check', () {
      expect(AttendanceCalculator.isStudentPaused('TAM_NGUNG'), isTrue);
      expect(AttendanceCalculator.isStudentPaused('Tạm ngừng'), isTrue);
      expect(AttendanceCalculator.isStudentPaused('DANG_HOC'), isFalse);
      expect(AttendanceCalculator.isStudentPaused(null), isFalse);
    });

    test('tinhDiemChuyenCan score calculation', () {
      // 10.0 - nghiKP
      expect(
        AttendanceCalculator.tinhDiemChuyenCan(coMat: 10, nghiCP: 2, nghiKP: 0),
        10.0,
      );
      expect(
        AttendanceCalculator.tinhDiemChuyenCan(coMat: 8, nghiCP: 1, nghiKP: 2),
        8.0,
      );
      expect(
        AttendanceCalculator.tinhDiemChuyenCan(coMat: 0, nghiCP: 0, nghiKP: 15),
        0.0,
      );
    });

    test('isDateInParticipationWindow mốc tham gia và tạm ngưng', () {
      final joinDate = DateTime(2026, 1, 10);
      final pauseDate = DateTime(2026, 2, 1);
      final resumeDate = DateTime(2026, 2, 15);

      // Trước ngày tham gia -> false
      expect(
        AttendanceCalculator.isDateInParticipationWindow(
          date: DateTime(2026, 1, 5),
          ngayThamGia: joinDate,
        ),
        isFalse,
      );

      // Trong khoảng đang học -> true
      expect(
        AttendanceCalculator.isDateInParticipationWindow(
          date: DateTime(2026, 1, 15),
          ngayThamGia: joinDate,
          ngayTamNgung: pauseDate,
        ),
        isTrue,
      );

      // Trong khoảng tạm ngưng -> false
      expect(
        AttendanceCalculator.isDateInParticipationWindow(
          date: DateTime(2026, 2, 5),
          ngayThamGia: joinDate,
          ngayTamNgung: pauseDate,
          ngayHocLai: resumeDate,
        ),
        isFalse,
      );

      // Sau khi học lại -> true
      expect(
        AttendanceCalculator.isDateInParticipationWindow(
          date: DateTime(2026, 2, 20),
          ngayThamGia: joinDate,
          ngayTamNgung: pauseDate,
          ngayHocLai: resumeDate,
        ),
        isTrue,
      );
    });
  });
}
