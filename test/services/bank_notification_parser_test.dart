// File: test/services/bank_notification_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/services/bank_parsers/bank_parser_factory.dart';
import 'package:tuition2025/services/bank_parsers/sacombank_parser.dart';
import 'package:tuition2025/services/bank_parsers/vietcombank_parser.dart';
import 'package:tuition2025/services/bank_parsers/mbbank_parser.dart';

void main() {
  group('Bank Notification Polymorphic Parsers Test', () {
    test('1. Sacombank Credit Notification Parsing', () {
      final parser = SacombankParser();
      final candidate = parser.parse(
        packageName: 'com.sacombank.mbanking',
        title: 'Biến động số dư Sacombank',
        text:
            'TK 060123456789: +800,000 VND. ND: HP 010007 202609 NGUYEN VAN A. Ref: 987654321',
      );

      expect(candidate, isNotNull);
      expect(candidate!.isCredit, isTrue);
      expect(candidate.amount, equals(800000));
      expect(candidate.bankCode, equals('sacombank'));
      expect(candidate.transactionId, equals('987654321'));
      expect(candidate.transferContent.contains('HP 010007 202609'), isTrue);
    });

    test(
      '2. Sacombank Debit Notification Parsing (MUST BE DEBIT / REJECTED)',
      () {
        final parser = SacombankParser();
        final candidate = parser.parse(
          packageName: 'com.sacombank.mbanking',
          title: 'Biến động số dư Sacombank',
          text:
              'TK 060123456789: -500,000 VND luc 15:30. ND: Thanh toan tien dien',
        );

        expect(candidate, isNotNull);
        expect(candidate!.isCredit, isFalse);
        expect(candidate.direction, equals('DEBIT'));
      },
    );

    test('3. Vietcombank Credit Notification Parsing', () {
      final parser = VietcombankParser();
      final candidate = parser.parse(
        packageName: 'com.vcb.vietcombank',
        title: 'VCB Digibank',
        text:
            'So du TK 001100123456 +300,000 VND vao 17/09/2026. Ref 11223344. ND: HP 010007 202609',
      );

      expect(candidate, isNotNull);
      expect(candidate!.isCredit, isTrue);
      expect(candidate.amount, equals(300000));
      expect(candidate.bankCode, equals('vietcombank'));
      expect(candidate.transactionId, equals('11223344'));
    });

    test('4. MBBank Credit Notification Parsing', () {
      final parser = MBBankParser();
      final candidate = parser.parse(
        packageName: 'com.mbbank.mobile',
        title: 'Thông báo MB Bank',
        text:
            'Bien dong so du: +1,000,000VND tai TK 9999. ND: HP 010007 202609',
      );

      expect(candidate, isNotNull);
      expect(candidate!.isCredit, isTrue);
      expect(candidate.amount, equals(1000000));
      expect(candidate.bankCode, equals('mbbank'));
    });

    test('5. Ignore OTP & Promotions', () {
      final candidate = BankParserFactory.parseNotification(
        packageName: 'com.mservice.momostore',
        title: 'MoMo Khuyến Mãi',
        text:
            'Nhận ngay Voucher 50.000đ khi thanh toán điện nước hôm nay! Mã OTP: 123456',
      );

      expect(candidate, isNull);
    });

    test('6. Unsupported Malicious Package', () {
      final candidate = BankParserFactory.parseNotification(
        packageName: 'com.untrusted.fakeapp',
        title: 'Bank +800,000VND',
        text: 'HP 010007 202609',
      );

      expect(candidate, isNull);
    });
  });
}
