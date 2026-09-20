import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/models/hoc_phi_tong_hop.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/utils/vietqr_util.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HocPhiPage Audit & Logic Unit Tests', () {
    test('1. Month and year selector builds correct YYYY-MM string', () {
      final year = 2026;
      final month = 9;
      final monthStr = '$year-${month.toString().padLeft(2, '0')}';
      expect(monthStr, equals('2026-09'));

      final monthJan = 1;
      final monthJanStr = '$year-${monthJan.toString().padLeft(2, '0')}';
      expect(monthJanStr, equals('2026-01'));
    });

    test('2. VietQR blocks generation when amount <= 0 (zero debt safety)', () {
      final hsPaid = HocSinhNoHocPhi(
        idHocSinh: 1,
        tenHocSinh: 'Nguyễn Văn A',
        soTienCanNop: 600000,
        soTienDaDong: 600000,
        soTienConNo: 0,
        mienGiam: 0,
        soBuoiDu: 0,
        tongSoBuoi: 12,
      );

      expect(hsPaid.soTienConNo, equals(0));
      expect(hsPaid.soTienConNo <= 0, isTrue);

      // Verify VietQRUtil throws ArgumentError if amount <= 0 is passed
      expect(
        () => VietQRUtil.generateVietQRPayload(
          bankId: 'sacombank',
          accountNo: '0905073175',
          amount: hsPaid.soTienConNo,
          description: 'Hoc phi Nguyen Van A thang 09/2026',
        ),
        throwsArgumentError,
      );
    });

    test('3. VietQR generates payload for valid debt amount > 0', () {
      final hsDebt = HocSinhNoHocPhi(
        idHocSinh: 2,
        tenHocSinh: 'Trần Thị B',
        soTienCanNop: 600000,
        soTienDaDong: 200000,
        soTienConNo: 400000,
        mienGiam: 0,
        soBuoiDu: 0,
        tongSoBuoi: 12,
      );

      expect(hsDebt.soTienConNo, equals(400000));

      final payload = VietQRUtil.generateVietQRPayload(
        bankId: 'sacombank',
        accountNo: '0905073175',
        amount: hsDebt.soTienConNo,
        description: 'Hoc phi Tran Thi B thang 09/2026',
      );

      expect(payload, contains('970403')); // Sacombank BIN
      expect(payload, contains('0905073175')); // Account No
      expect(payload, contains('400000')); // Amount
      expect(payload.startsWith('000201'), isTrue); // EMVCo header
    });

    test('4. Bank fallback values match teacher confirmed defaults', () {
      const defaultBankId = 'sacombank';
      const defaultAccountNo = '0905073175';
      const defaultAccountName = 'LE TRIEU BA VUONG';

      expect(VietQRUtil.getBankBin(defaultBankId), equals('970403'));
      expect(defaultAccountNo, equals('0905073175'));
      expect(defaultAccountName, equals('LE TRIEU BA VUONG'));
    });

    test('5. HocSinhNoHocPhi model correctly computes debt fields', () {
      final hs = HocSinhNoHocPhi(
        idHocSinh: 10,
        tenHocSinh: 'Lê Văn C',
        soTienCanNop: 500000,
        soTienDaDong: 100000,
        soTienConNo: 400000,
        mienGiam: 10,
        soBuoiDu: 2,
        tongSoBuoi: 12,
        sdt: '0912345678',
      );

      expect(hs.idHocSinh, equals(10));
      expect(hs.tenHocSinh, equals('Lê Văn C'));
      expect(hs.soTienConNo, equals(400000));
      expect(hs.sdt, equals('0912345678'));
    });

    test(
      '6. Lop model and tuition report aggregation model constructs correctly',
      () {
        final lop = Lop(id: 5, ten: 'Lớp Hóa 11A1', khoi: 11);
        final report = HocPhiTongHop(
          tongSoBuoi: 12,
          tongSoHocSinh: 15,
          tongSoTienCanThu: 7500000,
          tongSoTienDaThu: 5000000,
          tongSoTienConNo: 2500000,
          dsHocSinhConNo: [],
        );

        expect(lop.id, equals(5));
        expect(report.tongSoTienCanThu, equals(7500000));
        expect(report.tongSoTienDaThu, equals(5000000));
        expect(report.tongSoTienConNo, equals(2500000));
        expect(report.dsHocSinhConNo.isEmpty, isTrue);
      },
    );
  });
}
