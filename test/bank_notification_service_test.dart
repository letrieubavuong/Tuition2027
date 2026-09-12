import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/services/bank_notification_service.dart';

void main() {
  group('BankNotificationService security helpers', () {
    test('only trusts Sacombank application packages', () {
      expect(
        BankNotificationService.isTrustedBankPackage(
          'com.sacombank.msacombank',
        ),
        isTrue,
      );
      expect(
        BankNotificationService.isTrustedBankPackage('com.fake.notifications'),
        isFalse,
      );
    });

    test('does not trust bank names appearing only in notification text', () {
      expect(
        BankNotificationService.isTrustedBankPackage('com.example.fake'),
        isFalse,
      );
    });

    test('creates stable, content-sensitive notification fingerprints', () {
      final first = BankNotificationService.notificationFingerprint(
        'com.sacombank.msacombank',
        'Sacombank',
        'GD: +600,000 VND',
      );
      final same = BankNotificationService.notificationFingerprint(
        'com.sacombank.msacombank',
        'Sacombank',
        'GD: +600,000 VND',
      );
      final different = BankNotificationService.notificationFingerprint(
        'com.sacombank.msacombank',
        'Sacombank',
        'GD: +700,000 VND',
      );

      expect(first, same);
      expect(first, isNot(different));
    });
  });
}
