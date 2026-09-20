// File: lib/services/bank_parsers/bank_notification_parser.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';

class BankTransactionCandidate {
  final String bankCode;
  final String direction; // 'CREDIT' or 'DEBIT'
  final int amount;
  final String? transactionId;
  final String transferContent;
  final DateTime? transactionTime;
  final String? accountHint;
  final String rawFingerprint;
  final String packageName;
  final String rawTitle;
  final String rawText;

  BankTransactionCandidate({
    required this.bankCode,
    required this.direction,
    required this.amount,
    this.transactionId,
    required this.transferContent,
    this.transactionTime,
    this.accountHint,
    required this.rawFingerprint,
    required this.packageName,
    required this.rawTitle,
    required this.rawText,
  });

  bool get isCredit => direction.toUpperCase() == 'CREDIT';

  Map<String, dynamic> toMap() {
    return {
      'bankCode': bankCode,
      'direction': direction,
      'amount': amount,
      'transactionId': transactionId,
      'transferContent': transferContent,
      'transactionTime': transactionTime?.toIso8601String(),
      'accountHint': accountHint,
      'rawFingerprint': rawFingerprint,
      'packageName': packageName,
      'rawTitle': rawTitle,
      'rawText': rawText,
    };
  }
}

abstract class BankNotificationParser {
  String get bankCode;
  List<String> get supportedPackages;

  bool canParse(String packageName) {
    final pkg = packageName.toLowerCase();
    return supportedPackages.any((p) => pkg.contains(p.toLowerCase()));
  }

  BankTransactionCandidate? parse({
    required String packageName,
    required String title,
    required String text,
    DateTime? receivedAt,
  });

  /// Tạo fingerprint xác định duy nhất giao dịch (Dùng SHA-256)
  static String generateFingerprint({
    required String bankCode,
    required String? accountHint,
    required int amount,
    required String transferContent,
    required String rawText,
  }) {
    final cleanContent = transferContent
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final payload =
        '$bankCode|${accountHint ?? ''}|$amount|$cleanContent|${rawText.trim()}';
    final bytes = utf8.encode(payload);
    return sha256.convert(bytes).toString();
  }

  /// Trích xuất số tiền theo định dạng Việt Nam (100.000, 100,000, 100000)
  static int? parseAmount(String input) {
    if (input.isEmpty) return null;
    // Tìm các cụm số tiền đứng sau dấu + hoặc đứng trước VND, đ, d
    final regexes = [
      RegExp(r'\+\s*([0-9,.]+)\s*(?:VND|đ|d)?', caseSensitive: false),
      RegExp(
        r'(?:cộng|nhận|co:|\+)\s*:?\s*\+?\s*([0-9,.]+)\s*(?:VND|đ|d)?',
        caseSensitive: false,
      ),
      RegExp(r'([0-9,.]+)\s*(?:VND|đ|d)', caseSensitive: false),
      RegExp(r'([0-9]{1,3}(?:[.,]\d{3})+)', caseSensitive: false),
    ];

    for (var reg in regexes) {
      final match = reg.firstMatch(input);
      if (match != null) {
        String rawNum = match.group(1)!;
        // Loại bỏ tất cả dấu chấm, phẩy
        String cleanNum = rawNum.replaceAll('.', '').replaceAll(',', '').trim();
        final parsed = int.tryParse(cleanNum);
        if (parsed != null && parsed >= 1000) {
          return parsed;
        }
      }
    }
    return null;
  }
}
