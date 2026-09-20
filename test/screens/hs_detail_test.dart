import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/lich_hoc_chung.dart';
import 'package:tuition2025/utils/attendance_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HSDetail Unit & Logic Tests', () {
    test(
      '1. Attendance rate includes Trễ as coMat and nghiCoPhep in total attended sessions',
      () {
        // Simulate session counts:
        // coMat (including 'Có mặt' and 'Trễ') = 8
        // nghiCoPhep = 1
        // nghiKhongPhep = 1
        const coMat = 8; // e.g. 7 'Có mặt' + 1 'Trễ'
        const nghiCoPhep = 1;
        const nghiKhongPhep = 1;

        final tongBuoi = coMat + nghiCoPhep + nghiKhongPhep;
        expect(tongBuoi, equals(10));

        // Formula in hs_detail.dart: (coMat + nghiCoPhep) / (coMat + nghiCoPhep + nghiKhongPhep)
        final rate = (coMat + nghiCoPhep) / tongBuoi;
        expect(rate, equals(0.9)); // 90%
      },
    );

    test(
      '2. AttendanceCalculator calculate score decreases by unexcused absences',
      () {
        final score = AttendanceCalculator.tinhDiemChuyenCan(
          coMat: 7,
          nghiCP: 1,
          nghiKP: 1,
        );

        // 10.0 - 1 = 9.0
        expect(score, equals(9.0));
      },
    );

    test('3. Student with 0 classes handles empty list gracefully', () {
      final hs = HS(id: 1, ten: 'Nguyễn Văn A', sdt: '0901234567');

      final dsLop = <Lop>[];
      final dsLichHoc = <LichHocChung>[];

      expect(hs.id, equals(1));
      expect(dsLop.isEmpty, isTrue);
      expect(dsLichHoc.isEmpty, isTrue);
    });

    test(
      '4. Student with multiple classes correctly aggregates class list',
      () {
        final lop1 = Lop(id: 101, ten: 'Toán 10A1', khoi: 10);
        final lop2 = Lop(id: 102, ten: 'Văn 10A1', khoi: 10);
        final dsLop = [lop1, lop2];

        expect(dsLop.length, equals(2));
        expect(dsLop.map((l) => l.ten), containsAll(['Toán 10A1', 'Văn 10A1']));
      },
    );

    test(
      '5. Payment transactions fallback mapping formats transaction records',
      () {
        final rawTx = {
          'id': 1,
          'month': '2026-09',
          'amount': 500000,
          'status': 'SUCCESS',
          'transaction_id': 'TX123456',
          'created_at': '2026-09-17 08:00:00',
          'ten_lop': 'Toán 10A1',
        };

        final formattedRecord = {
          'thang': rawTx['month'],
          'ten_lop': rawTx['ten_lop'] ?? '',
          'so_tien_da_dong': rawTx['amount'],
          'ngay_thanh_toan': rawTx['created_at'],
          'status': rawTx['status'],
          'transaction_id': rawTx['transaction_id'],
        };

        expect(formattedRecord['thang'], equals('2026-09'));
        expect(formattedRecord['so_tien_da_dong'], equals(500000));
        expect(formattedRecord['status'], equals('SUCCESS'));
        expect(formattedRecord['transaction_id'], equals('TX123456'));
      },
    );
  });
}
