import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/services/dashboard_service.dart';
import 'package:tuition2025/utils/schedule_helpers.dart';
import 'package:tuition2025/models/dashboard_action_item.dart';

void main() {
  group('Dashboard Data Pipeline Tests', () {
    test('databaseWeekdayFromDate maps DateTime.weekday correctly', () {
      // Dart 1 (Monday) -> DB 2 (Thứ Hai)
      expect(databaseWeekdayFromDate(DateTime(2026, 9, 21)), equals(2)); // Mon
      // Dart 7 (Sunday) -> DB 1 (Chủ Nhật)
      expect(databaseWeekdayFromDate(DateTime(2026, 9, 20)), equals(1)); // Sun
      // Dart 6 (Saturday) -> DB 7 (Thứ Bảy)
      expect(databaseWeekdayFromDate(DateTime(2026, 9, 19)), equals(7)); // Sat
    });

    test('DashboardData initializes with safe defaults', () {
      final data = DashboardData();
      expect(data.soLopHoc, equals(0));
      expect(data.soHocSinh, equals(0));
      expect(data.soCaHocHomNay, equals(0));
      expect(data.tongTienNo, equals(0));
      expect(data.tongTienThu, equals(0));
      expect(data.dsCaHocHomNay, isEmpty);
    });

    test('DashboardActionItem handles critical and info priorities correctly', () {
      final item = DashboardActionItem(
        id: 'test_1',
        type: DashboardItemType.attendance,
        priority: DashboardPriority.critical,
        title: 'Test Title',
        description: 'Test Desc',
        actionType: 'attendance',
        actionLabel: 'Điểm danh',
      );
      expect(item.priority, equals(DashboardPriority.critical));
      expect(item.id, equals('test_1'));
    });
  });
}
