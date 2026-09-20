// File: test/v2/db_value_parser_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/utils/v2/db_value_parser.dart';

void main() {
  group('DbValueParser Tests', () {
    test('parseInt handles various inputs', () {
      expect(DbValueParser.parseInt(123), 123);
      expect(DbValueParser.parseInt('456'), 456);
      expect(DbValueParser.parseInt(' 789 '), 789);
      expect(DbValueParser.parseInt(10.5), 10);
      expect(DbValueParser.parseInt(null), null);
      expect(DbValueParser.parseInt('abc'), null);
    });

    test('parseString handles various inputs', () {
      expect(DbValueParser.parseString(' hello '), 'hello');
      expect(DbValueParser.parseString(123), '123');
      expect(DbValueParser.parseString(null), null);
      expect(DbValueParser.parseString(' '), null);
    });

    test('parseBool handles various inputs', () {
      expect(DbValueParser.parseBool(true), true);
      expect(DbValueParser.parseBool(1), true);
      expect(DbValueParser.parseBool('true'), true);
      expect(DbValueParser.parseBool(0), false);
      expect(DbValueParser.parseBool(null), false);
    });
  });
}
