// File: lib/services/bank_parsers/sacombank_parser.dart

import 'bank_notification_parser.dart';

class SacombankParser extends BankNotificationParser {
  @override
  String get bankCode => 'sacombank';

  @override
  List<String> get supportedPackages => ['com.sacombank.mbanking', 'sacombank'];

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

    // 1. Phân biệt CREDIT vs DEBIT/Khác
    // Nếu có dấu trừ "-" hoặc chứa "tru", "thanh toan", "phi", "chuyen di", "rut tien" mà KHÔNG có dấu "+" -> DEBIT
    bool isDebit =
        lower.contains('-') ||
        lower.contains('trừ') ||
        lower.contains('chuyen di') ||
        lower.contains('chuyển đi') ||
        lower.contains('thanhtoan') ||
        lower.contains('thanh toán');

    bool isCredit =
        lower.contains('+') ||
        lower.contains('cộng') ||
        lower.contains('nhận') ||
        lower.contains('nhan tien') ||
        lower.contains('co:');

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

    // 2. Parse số tiền
    final amount =
        BankNotificationParser.parseAmount(text) ??
        BankNotificationParser.parseAmount(title);
    if (amount == null || amount <= 0) return null;

    // 3. Extract transaction ID / Ref if present
    String? txId;
    final refMatch = RegExp(
      r'(?:ref|ma gd|magd|ft|id|stk|so gd)\s*:?\s*([a-zA-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (refMatch != null) {
      txId = refMatch.group(1);
    }

    // 4. Extract account hint
    String? accHint;
    final accMatch = RegExp(
      r'(?:tk|taikhoan|stk)\s*([0-9xX*]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (accMatch != null) {
      accHint = accMatch.group(1);
    }

    // 5. Extract transfer content (Nội dung)
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
