import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/models/hs.dart';
import 'package:tuition2025/models/lich_hoc.dart';
import 'package:tuition2025/models/lop_hoc_sinh.dart';
import 'package:tuition2025/services/lich_hoc_service.dart';
import 'package:tuition2025/utils/schedule_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LichDayPage & Schedule Recommendation Unit Tests', () {
    test('1. normalizeTime converts "17:30:00" to "17:30"', () {
      expect(normalizeTime('17:30:00'), equals('17:30'));
      expect(normalizeTime('8:5:00'), equals('08:05'));
      expect(normalizeTime('19:30'), equals('19:30'));
    });

    test(
      '2. LopHocSinh model constructs correctly for schedule assignment',
      () {
        final lhs = LopHocSinh(
          idLop: 10,
          idHocSinh: 5,
          ngayThamGia: '2026-09-17',
          trangThai: 'DANG_HOC',
        );

        final map = lhs.toMap();
        expect(map['id_lop'], equals(10));
        expect(map['id_hoc_sinh'], equals(5));
        expect(map['ngay_tham_gia'], equals('2026-09-17'));
        expect(map['trang_thai'], equals('DANG_HOC'));
      },
    );

    test(
      '3. LichHocCoTenLop model holds class & schedule metadata correctly',
      () {
        final lichHoc = LichHoc(
          id: 1,
          idLop: 10,
          thuTrongTuan: 2,
          gioBatDau: '17:30:00',
          gioKetThuc: '19:00:00',
        );

        final item = LichHocCoTenLop(
          lichHoc: lichHoc,
          tenLop: 'Lớp Toán 10A1',
          khoi: 10,
          siSo: 15,
        );

        expect(item.tenLop, equals('Lớp Toán 10A1'));
        expect(item.khoi, equals(10));
        expect(item.siSo, equals(15));
        expect(normalizeTime(item.lichHoc.gioBatDau), equals('17:30'));
        expect(normalizeTime(item.lichHoc.gioKetThuc), equals('19:00'));
      },
    );
  });
}
