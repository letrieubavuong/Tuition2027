// File: lib/services/student_event_service.dart

import 'dart:async';
import '../models/hs.dart';

/// Service quản lý sự kiện thay đổi thông tin học sinh toàn ứng dụng (Central Student-Changed Event).
/// Giúp các màn hình đang mở (DS Học sinh, Chi tiết học sinh, Chi tiết lớp...)
/// lập tức cập nhật dữ liệu khi có thay đổi (Thêm/Sửa/Xóa) mà không cần restart app.
class StudentEventService {
  static final StudentEventService instance = StudentEventService._internal();
  factory StudentEventService() => instance;
  StudentEventService._internal();

  final _updatedController = StreamController<HS>.broadcast();
  final _createdController = StreamController<HS>.broadcast();
  final _deletedController = StreamController<int>.broadcast();

  Stream<HS> get onStudentUpdated => _updatedController.stream;
  Stream<HS> get onStudentCreated => _createdController.stream;
  Stream<int> get onStudentDeleted => _deletedController.stream;

  void notifyStudentUpdated(HS hs) {
    _updatedController.add(hs);
  }

  void notifyStudentCreated(HS hs) {
    _createdController.add(hs);
  }

  void notifyStudentDeleted(int studentId) {
    _deletedController.add(studentId);
  }
}
