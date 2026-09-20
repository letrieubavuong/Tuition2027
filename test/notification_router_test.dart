import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/services/notification_router.dart';

void main() {
  group('NotificationPayload Parser Tests', () {
    test('parses legacy zalo: payload correctly', () {
      final payload = NotificationPayload.parse('zalo:0912345678');
      expect(payload.type, equals('zalo'));
      expect(payload.phone, equals('0912345678'));
    });

    test('parses BANK_PAYMENT_CONFIRMED JSON payload correctly', () {
      final jsonStr =
          '{"type":"BANK_PAYMENT_CONFIRMED","studentId":15,"classId":3,"month":"2026-09","transactionId":123}';
      final payload = NotificationPayload.parse(jsonStr);
      expect(payload.type, equals('BANK_PAYMENT_CONFIRMED'));
      expect(payload.studentId, equals(15));
      expect(payload.classId, equals(3));
      expect(payload.month, equals('2026-09'));
      expect(payload.paymentTransactionId, equals(123));
    });

    test('parses BANK_PAYMENT_REVIEW JSON payload correctly', () {
      final jsonStr =
          '{"type":"BANK_PAYMENT_REVIEW","studentId":15,"classId":3,"month":"2026-09","transactionId":124}';
      final payload = NotificationPayload.parse(jsonStr);
      expect(payload.type, equals('BANK_PAYMENT_REVIEW'));
      expect(payload.studentId, equals(15));
      expect(payload.paymentTransactionId, equals(124));
    });

    test('parses BANK_PAYMENT_UNMATCHED JSON payload correctly', () {
      final jsonStr = '{"type":"BANK_PAYMENT_UNMATCHED","transactionId":125}';
      final payload = NotificationPayload.parse(jsonStr);
      expect(payload.type, equals('BANK_PAYMENT_UNMATCHED'));
      expect(payload.paymentTransactionId, equals(125));
    });

    test('handles null payload gracefully without crash', () {
      final payload = NotificationPayload.parse(null);
      expect(payload.type, equals('unknown'));
    });

    test('handles empty payload gracefully without crash', () {
      final payload = NotificationPayload.parse('');
      expect(payload.type, equals('unknown'));
    });

    test('handles malformed JSON payload gracefully without crash', () {
      final payload = NotificationPayload.parse('{invalid_json}');
      expect(payload.type, equals('unknown'));
    });

    test('parses legacy lop_id= parameter', () {
      final payload = NotificationPayload.parse('lop_id=5');
      expect(payload.type, equals('schedule_reminder'));
      expect(payload.classId, equals(5));
    });
  });
}
