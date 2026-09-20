// File: test/v2/phone_normalizer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/utils/v2/phone_normalizer.dart';

void main() {
  group('PhoneNormalizer Tests', () {
    test('standard normalization', () {
      expect(PhoneNormalizer.normalize('0905123456'), '0905123456');
    });

    test('handles spaces and dots', () {
      expect(PhoneNormalizer.normalize('0905 123 456'), '0905123456');
      expect(PhoneNormalizer.normalize('0905.123.456'), '0905123456');
    });

    test('handles +84 and 84 prefix', () {
      expect(PhoneNormalizer.normalize('+84 905123456'), '0905123456');
      expect(PhoneNormalizer.normalize('84905123456'), '0905123456');
    });

    test('handles missing leading zero (9 digits)', () {
      expect(PhoneNormalizer.normalize('905123456'), '0905123456');
    });

    test('isSame detection', () {
      expect(PhoneNormalizer.isSame('0905.123.456', '+84905123456'), true);
      expect(PhoneNormalizer.isSame('0905123456', '0905111222'), false);
    });
  });
}
