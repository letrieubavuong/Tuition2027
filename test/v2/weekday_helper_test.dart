// File: test/v2/weekday_helper_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/utils/v2/weekday_helper.dart';

void main() {
  group('WeekdayHelper Tests', () {
    test('legacyToV2 mapping correctness', () {
      expect(WeekdayHelper.legacyToV2(1), 7); // Sun
      expect(WeekdayHelper.legacyToV2(2), 1); // Mon
      expect(WeekdayHelper.legacyToV2(3), 2); // Tue
      expect(WeekdayHelper.legacyToV2(4), 3); // Wed
      expect(WeekdayHelper.legacyToV2(5), 4); // Thu
      expect(WeekdayHelper.legacyToV2(6), 5); // Fri
      expect(WeekdayHelper.legacyToV2(7), 6); // Sat
    });

    test('fromVietnamese mapping correctness', () {
      expect(WeekdayHelper.fromVietnamese('Thứ Hai'), 1);
      expect(WeekdayHelper.fromVietnamese('Thứ Ba'), 2);
      expect(WeekdayHelper.fromVietnamese('Thứ Tư'), 3);
      expect(WeekdayHelper.fromVietnamese('Thứ Năm'), 4);
      expect(WeekdayHelper.fromVietnamese('Thứ Sáu'), 5);
      expect(WeekdayHelper.fromVietnamese('Thứ Bảy'), 6);
      expect(WeekdayHelper.fromVietnamese('Chủ Nhật'), 7);
    });
  });
}
