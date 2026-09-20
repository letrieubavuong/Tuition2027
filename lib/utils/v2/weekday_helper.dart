// File: lib/utils/v2/weekday_helper.dart

class WeekdayHelper {
  /// Converts legacy Sunday-based weekday to V2 Monday-based weekday.
  /// Legacy: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
  /// V2: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun (compatible with DateTime.weekday)
  static int legacyToV2(int legacy) {
    if (legacy == 1) return 7; // Sun
    if (legacy >= 2 && legacy <= 7) return legacy - 1;
    return 1; // Fallback to Mon
  }

  /// Converts Vietnamese day name to V2 weekday (1..7).
  static int? fromVietnamese(String name) {
    final s = name.trim().toLowerCase();
    if (s.contains('hai')) return 1;
    if (s.contains('ba')) return 2;
    if (s.contains('tư')) return 3;
    if (s.contains('năm')) return 4;
    if (s.contains('sáu')) return 5;
    if (s.contains('bảy')) return 6;
    if (s.contains('nhật')) return 7;
    return null;
  }

  static String toVietnamese(int v2) {
    switch (v2) {
      case 1: return 'Thứ Hai';
      case 2: return 'Thứ Ba';
      case 3: return 'Thứ Tư';
      case 4: return 'Thứ Năm';
      case 5: return 'Thứ Sáu';
      case 6: return 'Thứ Bảy';
      case 7: return 'Chủ Nhật';
      default: return 'Không rõ';
    }
  }
}
