// File: lib/services/bank_parsers/vietcombank_parser.dart

import 'bank_notification_parser.dart';

class VietcombankParser extends BankNotificationParser {
  @override
  String get bankCode => 'vietcombank';

  @override
  List<String> get supportedPackages => [
    'com.vcb.vietcombank',
    'com.vietcombank.mobile',
    'vietcombank',
    'vcb',
  ];

  @override
  BankTransactionCandidate? parse({
    required String packageName,
    required String title,
    required String text,
    DateTime? receivedAt,
  }) {
    if (!canParse(packageName)) return null;

    final fullContent = '$title $text';
    final lower = fullContent.toLowerCase();

    // 1. Phân biệt CREDIT vs DEBIT
    bool isDebit =
        lower.contains('-') ||
        lower.contains('so du tk') && lower.contains('giam') ||
        lower.contains('chuyen tien') ||
        lower.contains('thanh toan');

    bool isCredit =
        lower.contains('+') ||
        lower.contains('so du tk') && lower.contains('tang') ||
        lower.contains('cộng') ||
        lower.contains('nhận');

    if (isDebit && !isCredit) {
      return BankTransactionCandidate(
        bankCode: bankCode,
        direction: 'DEBIT',
        amount: 0,
        transferContent: text,
        rawFingerprint: BankNotificationParser.generateFingerprint(
          bankCode: bankCode,
          accountHint: null,
          amount: 0,
          transferContent: text,
          rawText: fullContent,
        ),
        packageName: packageName,
        rawTitle: title,
        rawText: text,
      );
    }

    if (!isCredit) return null;

    final amount =
        BankNotificationParser.parseAmount(text) ??
        BankNotificationParser.parseAmount(title);
    if (amount == null || amount <= 0) return null;

    String? txId;
    final refMatch = RegExp(
      r'(?:ref|ma gd|magd|ft|id|gd)\s*:?\s*([a-zA-Z0-9.]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (refMatch != null) {
      txId = refMatch.group(1)?.replaceAll(RegExp(r'\.+$'), '');
    }

    String? accHint;
    final accMatch = RegExp(
      r'(?:tk|taikhoan|stk)\s*([0-9xX*]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (accMatch != null) {
      accHint = accMatch.group(1);
    }

    String content = text;
    final ndMatch = RegExp(
      r'(?:nd|noidung|noi dung)\s*:?\s*(.+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (ndMatch != null) {
      content = ndMatch.group(1)!.trim();
    }

    final fp = BankNotificationParser.generateFingerprint(
      bankCode: bankCode,
      accountHint: accHint,
      amount: amount,
      transferContent: content,
      rawText: fullContent,
    );

    return BankTransactionCandidate(
      bankCode: bankCode,
      direction: 'CREDIT',
      amount: amount,
      transactionId: txId,
      transferContent: content,
      transactionTime: receivedAt ?? DateTime.now(),
      accountHint: accHint,
      rawFingerprint: fp,
      packageName: packageName,
      rawTitle: title,
      rawText: text,
    );
  }
}
