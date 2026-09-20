// File: lib/services/bank_parsers/bank_parser_factory.dart

import 'bank_notification_parser.dart';
import 'sacombank_parser.dart';
import 'vietcombank_parser.dart';
import 'mbbank_parser.dart';
import 'bidv_parser.dart';
import 'vietinbank_parser.dart';
import 'generic_bank_parser.dart';

class BankParserFactory {
  static final List<BankNotificationParser> _parsers = [
    SacombankParser(),
    VietcombankParser(),
    MBBankParser(),
    BIDVParser(),
    VietinBankParser(),
    GenericBankParser(),
  ];

  /// Lấy parser phù hợp với packageName
  static BankNotificationParser? getParser(String packageName) {
    for (var parser in _parsers) {
      if (parser.canParse(packageName)) {
        return parser;
      }
    }
    return null;
  }

  /// Parse trực tiếp thông báo thành candidate
  static BankTransactionCandidate? parseNotification({
    required String packageName,
    required String title,
    required String text,
    DateTime? receivedAt,
  }) {
    final parser = getParser(packageName);
    if (parser == null) return null;
    return parser.parse(
      packageName: packageName,
      title: title,
      text: text,
      receivedAt: receivedAt,
    );
  }
}
