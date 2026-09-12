// File: lib/services/tuition_event_service.dart

import 'package:flutter/foundation.dart';

/// Service phát sự kiện toàn cục khi học phí, điểm danh hoặc trạng thái học sinh có sự thay đổi.
/// Màn hình Học phí và các màn hình liên quan có thể đăng ký lắng nghe để tự động làm mới dữ liệu.
class TuitionEventService extends ChangeNotifier {
  static final TuitionEventService _instance = TuitionEventService._internal();

  factory TuitionEventService() {
    return _instance;
  }

  TuitionEventService._internal();

  /// Phát thông báo khi có bất kỳ thay đổi nào ảnh hưởng đến dữ liệu học phí
  void notifyTuitionChanged() {
    notifyListeners();
  }
}
