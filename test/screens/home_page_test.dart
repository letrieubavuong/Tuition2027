import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/services/dashboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomePage & DashboardService Unit Tests', () {
    test(
      '1. DashboardData initializes with correct counts',
      () {
        final data = DashboardData(
          soLopHoc: 3,
          soHocSinh: 45,
          soCaHocHomNay: 2,
          tongTienNo: 1000000,
          tongTienThu: 4000000,
        );

        expect(data.soHocSinh, equals(45));
        expect(data.soLopHoc, equals(3));
        expect(data.soCaHocHomNay, equals(2));
      },
    );

    test(
      '2. Time formatting helper handles diverse time string inputs safely',
      () {
        String formatTimeDisplay(String? timeStr) {
          if (timeStr == null || timeStr.trim().isEmpty) return '--:--';
          final clean = timeStr.trim();
          if (clean.contains(':')) {
            final parts = clean.split(':');
            if (parts.length >= 2) {
              final hh = parts[0].padLeft(2, '0');
              final mm = parts[1].padLeft(2, '0');
              return '$hh:$mm';
            }
          }
          return clean;
        }

        expect(formatTimeDisplay('8:00'), equals('08:00'));
        expect(formatTimeDisplay('08:00:00'), equals('08:00'));
        expect(formatTimeDisplay('17:30:00'), equals('17:30'));
        expect(formatTimeDisplay(''), equals('--:--'));
        expect(formatTimeDisplay(null), equals('--:--'));
      },
    );

    test('3. Collection rate calculation handles zero debt and edge cases', () {
      // 1. Partial payment: Collected 3,000,000đ, Debt 1,000,000đ
      int tongTienThu = 3000000;
      int tongTienNo = 1000000;
      int totalPotential = tongTienThu + tongTienNo;
      double rate = totalPotential > 0 ? tongTienThu / totalPotential : 0.0;
      expect(rate, equals(0.75)); // 75%

      // 2. Fully paid: Collected 5,000,000đ, Debt 0đ
      tongTienThu = 5000000;
      tongTienNo = 0;
      totalPotential = tongTienThu + tongTienNo;
      rate = totalPotential > 0 ? tongTienThu / totalPotential : 0.0;
      expect(rate, equals(1.0)); // 100%

      // 3. Unpaid: Collected 0đ, Debt 2,000,000đ
      tongTienThu = 0;
      tongTienNo = 2000000;
      totalPotential = tongTienThu + tongTienNo;
      rate = totalPotential > 0 ? tongTienThu / totalPotential : 0.0;
      expect(rate, equals(0.0)); // 0%
    });

    test('4. CaHocHomNay model converts from map with string or int idLop', () {
      final map1 = {
        'idLop': 10,
        'tenLop': 'Toán 10A1',
        'gioBatDau': '08:00:00',
        'gioKetThuc': '09:30:00',
      };
      final caHoc1 = CaHocHomNay.fromMap(map1);
      expect(caHoc1.idLop, equals(10));
      expect(caHoc1.tenLop, equals('Toán 10A1'));

      final map2 = {
        'idLop': '15',
        'tenLop': 'Văn 11A2',
        'gioBatDau': '14:00:00',
        'gioKetThuc': '15:30:00',
      };
      final caHoc2 = CaHocHomNay.fromMap(map2);
      expect(caHoc2.idLop, equals(15));
      expect(caHoc2.tenLop, equals('Văn 11A2'));
    });
  });
}
