import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/utils/vietqr_util.dart';

/// EMVCo TLV Parser Helper for verifying generated QR payload structure
Map<String, String> parseEmvTags(String payload) {
  final Map<String, String> tags = {};
  int index = 0;
  while (index < payload.length) {
    if (index + 4 > payload.length) break;
    final tag = payload.substring(index, index + 2);
    final length = int.tryParse(payload.substring(index + 2, index + 4));
    if (length == null || index + 4 + length > payload.length) break;
    final value = payload.substring(index + 4, index + 4 + length);
    tags[tag] = value;
    index += 4 + length;
  }
  return tags;
}

/// Computes CRC16-CCITT to verify CRC field
String calculateCRC(String data) {
  int crc = 0xFFFF;
  List<int> bytes = data.codeUnits;
  for (int byte in bytes) {
    crc ^= (byte << 8) & 0xFFFF;
    for (int i = 0; i < 8; i++) {
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
      } else {
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  return (crc & 0xFFFF).toRadixString(16).padLeft(4, '0').toUpperCase();
}

void main() {
  group('1. removeVietnameseAccents Unit Tests', () {
    test('Bỏ dấu tiếng Việt có hoa/thường chuẩn', () {
      expect(
        VietQRUtil.removeVietnameseAccents('Nguyễn Văn Ánh'),
        equals('Nguyen Van Anh'),
      );
      expect(
        VietQRUtil.removeVietnameseAccents('Đỗ Đức Đạt'),
        equals('Do Duc Dat'),
      );
    });

    test('Loại bỏ ký tự đặc biệt và khoảng trắng thừa', () {
      expect(
        VietQRUtil.removeVietnameseAccents(r'Trần Thị B (#123)! @$%'),
        equals('Tran Thi B 123'),
      );
      expect(
        VietQRUtil.removeVietnameseAccents('Lê   Hoàng  C'),
        equals('Le Hoang C'),
      );
    });
  });

  group('2. getBankBin Audit & Fail-Fast Tests', () {
    test('Nhận diện tên ngân hàng viết thường/hoa/viết tắt', () {
      expect(VietQRUtil.getBankBin('sacombank'), equals('970403'));
      expect(VietQRUtil.getBankBin('vietcombank'), equals('970436'));
      expect(VietQRUtil.getBankBin('VCB'), equals('970436'));
      expect(VietQRUtil.getBankBin('mbbank'), equals('970422'));
      expect(VietQRUtil.getBankBin('MB'), equals('970422'));
    });

    test('BIN 6 chữ số nhập trực tiếp giữ nguyên', () {
      expect(VietQRUtil.getBankBin('970403'), equals('970403'));
      expect(VietQRUtil.getBankBin('970422'), equals('970422'));
    });

    test(
      'Tên/mã ngân hàng không nhận diện được => Throws ArgumentError (Fail-fast)',
      () {
        expect(
          () => VietQRUtil.getBankBin('unknown_bank'),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => VietQRUtil.getBankBin('agri_invalid'),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('Tên/mã ngân hàng rỗng => Throws ArgumentError (Fail-fast)', () {
      expect(() => VietQRUtil.getBankBin(''), throwsA(isA<ArgumentError>()));
      expect(() => VietQRUtil.getBankBin('   '), throwsA(isA<ArgumentError>()));
    });
  });

  group(
    '3. generateVietQRPayload Validation Tests (Fail-Fast Payment Safety)',
    () {
      test('bankId không hợp lệ => Throws ArgumentError', () {
        expect(
          () => VietQRUtil.generateVietQRPayload(
            bankId: 'invalid_bank',
            accountNo: '060123456789',
            amount: 500000,
            description: 'Hoc phi',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accountNo rỗng => Throws ArgumentError', () {
        expect(
          () => VietQRUtil.generateVietQRPayload(
            bankId: 'sacombank',
            accountNo: '',
            amount: 500000,
            description: 'Hoc phi',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('accountNo có ký tự đặc biệt => Throws ArgumentError', () {
        expect(
          () => VietQRUtil.generateVietQRPayload(
            bankId: 'sacombank',
            accountNo: '123-456#',
            amount: 500000,
            description: 'Hoc phi',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('amount = 0 => Throws ArgumentError', () {
        expect(
          () => VietQRUtil.generateVietQRPayload(
            bankId: 'sacombank',
            accountNo: '060123456789',
            amount: 0,
            description: 'Hoc phi',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('amount âm => Throws ArgumentError', () {
        expect(
          () => VietQRUtil.generateVietQRPayload(
            bankId: 'sacombank',
            accountNo: '060123456789',
            amount: -100000,
            description: 'Hoc phi',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('description rỗng => Throws ArgumentError', () {
        expect(
          () => VietQRUtil.generateVietQRPayload(
            bankId: 'sacombank',
            accountNo: '060123456789',
            amount: 500000,
            description: '   ',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    },
  );

  group('4. VietQR Golden Tests & EMVCo Decoder Verification', () {
    test('Golden Test 1: Sacombank payload structure & CRC', () {
      final payload = VietQRUtil.generateVietQRPayload(
        bankId: 'sacombank',
        accountNo: '060123456789',
        amount: 500000,
        description: 'Hoc phi Tran Van A',
      );

      expect(payload, startsWith('000201010212'));

      // Decode EMVCo TLV Tags
      final tags = parseEmvTags(payload);
      expect(tags['00'], equals('01'));
      expect(tags['01'], equals('12'));
      expect(tags['53'], equals('704'));
      expect(tags['54'], equals('500000'));
      expect(tags['58'], equals('VN'));

      // Parse Tag 38 Merchant Info
      final tag38Sub = parseEmvTags(tags['38']!);
      expect(tag38Sub['00'], equals('A000000727'));
      expect(tag38Sub['02'], equals('QRIBFTTA'));

      // Parse Tag 38 Sub-tag 01 Bank Info
      final bankInfo = parseEmvTags(tag38Sub['01']!);
      expect(bankInfo['00'], equals('970403')); // Sacombank BIN
      expect(bankInfo['01'], equals('060123456789')); // Account Number

      // Parse Tag 62 Additional Data
      final tag62Sub = parseEmvTags(tags['62']!);
      expect(tag62Sub['08'], equals('Hoc phi Tran Van A'));

      // Verify CRC (Tag 63)
      final String payloadWithoutCRC = payload.substring(0, payload.length - 4);
      final String crcInPayload = payload.substring(payload.length - 4);
      final String expectedCRC = calculateCRC(payloadWithoutCRC);
      expect(crcInPayload, equals(expectedCRC));
    });

    test('Golden Test 2: Vietcombank / VCB payload structure & CRC', () {
      final payload = VietQRUtil.generateVietQRPayload(
        bankId: 'vcb',
        accountNo: '0071000123456',
        amount: 1200000,
        description: 'Hoc phi Nguyen Thi B',
      );

      final tags = parseEmvTags(payload);
      final tag38Sub = parseEmvTags(tags['38']!);
      final bankInfo = parseEmvTags(tag38Sub['01']!);

      expect(bankInfo['00'], equals('970436')); // VCB BIN
      expect(bankInfo['01'], equals('0071000123456'));
      expect(tags['54'], equals('1200000'));

      final String payloadWithoutCRC = payload.substring(0, payload.length - 4);
      final String crcInPayload = payload.substring(payload.length - 4);
      expect(crcInPayload, equals(calculateCRC(payloadWithoutCRC)));
    });

    test('Golden Test 3: BIN nhập trực tiếp (970422 - MBBank)', () {
      final payload = VietQRUtil.generateVietQRPayload(
        bankId: '970422',
        accountNo: '1234567890',
        amount: 350000,
        description: 'Hoc phi Do C',
      );

      final tags = parseEmvTags(payload);
      final tag38Sub = parseEmvTags(tags['38']!);
      final bankInfo = parseEmvTags(tag38Sub['01']!);

      expect(bankInfo['00'], equals('970422'));
      expect(bankInfo['01'], equals('1234567890'));
      expect(tags['54'], equals('350000'));
    });

    test('Golden Test 4: Description dài', () {
      final longDesc = 'Hoc phi hoc sinh Nguyen Van A lop 12A1 thang 09 2026';
      final payload = VietQRUtil.generateVietQRPayload(
        bankId: 'sacombank',
        accountNo: '060123456789',
        amount: 850000,
        description: longDesc,
      );

      final tags = parseEmvTags(payload);
      final tag62Sub = parseEmvTags(tags['62']!);
      expect(tag62Sub['08'], equals(longDesc));

      final String payloadWithoutCRC = payload.substring(0, payload.length - 4);
      final String crcInPayload = payload.substring(payload.length - 4);
      expect(crcInPayload, equals(calculateCRC(payloadWithoutCRC)));
    });
  });

  group('5. taoNoiDungThongBaoHocPhi Optional Attendance Parameters', () {
    test(
      'Hiển thị đầy đủ số buổi có mặt, nghỉ có phép, nghỉ không phép khi được truyền vào',
      () {
        final msg = VietQRUtil.taoNoiDungThongBaoHocPhi(
          tenHocSinh: 'Nguyễn Văn A',
          tenLop: '10A1',
          thang: '2026-09',
          soBuoiDu: 2,
          tongSoBuoi: 12,
          soBuoiCoMat: 10,
          soBuoiNghiCoPhep: 1,
          soBuoiNghiKhongPhep: 1,
          soTienCanNop: 1000000,
          soTienDaDong: 0,
          soTienConNo: 1000000,
          bankId: 'Sacombank',
          accountNo: '060123456789',
          accountName: 'NGUYEN VAN B',
          isVi: true,
        );

        expect(msg, contains('- Số buổi có mặt: 10 buổi'));
        expect(msg, contains('- Số buổi nghỉ có phép: 1 buổi'));
        expect(msg, contains('- Số buổi nghỉ không phép: 1 buổi'));
        expect(msg, contains('- Số buổi dư tích lũy: 2 buổi'));
        expect(msg, contains('- Số buổi dự kiến: 12 buổi'));
        expect(msg, contains('Hoc phi Nguyen Van A thang 09/2026'));
      },
    );
  });
}
