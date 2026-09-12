// File: lib/services/firebase_sync_service.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../firebase_options.dart';
import '../services/tuition_event_service.dart';
import '../utils/db.dart';

class FirebaseSyncService {
  static final FirebaseSyncService instance = FirebaseSyncService._internal();
  FirebaseSyncService._internal();

  late FirebaseDatabase _db;
  bool _isInitialized = false;
  final List<StreamSubscription> _subscriptions = [];

  bool get isInitialized => _isInitialized;

  /// Khởi tạo kết nối Firebase và bắt đầu lắng nghe sự kiện đồng bộ thời gian thực
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      _db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: DefaultFirebaseOptions.databaseURL,
      );

      // Kích hoạt tính năng Persistence cho bản native (Android/iOS)
      if (!kIsWeb) {
        try {
          _db.setPersistenceEnabled(true);
        } catch (_) {}
      }

      _isInitialized = true;
      developer.log(
        'Firebase Realtime Database initialized successfully: ${DefaultFirebaseOptions.databaseURL}',
        name: 'FirebaseSyncService',
      );

      // Bắt đầu lắng nghe thay đổi dữ liệu từ Cloud về máy
      _batDauLangNgheCloudSync();
    } catch (e) {
      developer.log(
        'Lỗi khởi tạo Firebase: $e',
        name: 'FirebaseSyncService',
        error: e,
      );
    }
  }

  /// Đẩy dữ liệu của một bản ghi lên Firebase Realtime Database
  Future<void> pushRecordToCloud(
    String tableName,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    if (!_isInitialized) await initialize();
    try {
      final ref = _db.ref().child(tableName).child(recordId);
      // Chuyển đổi dữ liệu DateTime hoặc kiểu dữ liệu phức tạp thành String/num
      final Map<String, dynamic> cleanData = {};
      data.forEach((key, value) {
        if (value is DateTime) {
          cleanData[key] = value.toIso8601String();
        } else {
          cleanData[key] = value;
        }
      });
      cleanData['updated_at'] = DateTime.now().toIso8601String();
      await ref.set(cleanData);
      developer.log(
        'Pushed $tableName/$recordId to Firebase',
        name: 'FirebaseSyncService',
      );
    } catch (e) {
      developer.log(
        'Lỗi push dữ liệu $tableName/$recordId: $e',
        name: 'FirebaseSyncService',
        error: e,
      );
    }
  }

  /// Xóa một bản ghi khỏi Firebase Realtime Database
  Future<void> deleteRecordFromCloud(String tableName, String recordId) async {
    if (!_isInitialized) await initialize();
    try {
      final ref = _db.ref().child(tableName).child(recordId);
      await ref.remove();
      developer.log(
        'Deleted $tableName/$recordId from Firebase',
        name: 'FirebaseSyncService',
      );
    } catch (e) {
      developer.log(
        'Lỗi xóa dữ liệu $tableName/$recordId: $e',
        name: 'FirebaseSyncService',
        error: e,
      );
    }
  }

  /// Đăng ký lắng nghe các thay đổi thời gian thực từ Cloud và cập nhật về SQLite/UI
  void _batDauLangNgheCloudSync() {
    final tables = [
      DBHelper.tenBangHS,
      DBHelper.tenBangLop,
      DBHelper.tenBangLopHS,
      DBHelper.tenBangDiemDanh,
      DBHelper.tenBangThanhToan,
      DBHelper.tenBangNhanXetThang,
      DBHelper.tenBangCaiDat,
    ];

    for (final table in tables) {
      final ref = _db.ref().child(table);

      // Lắng nghe sự kiện thêm/sửa bản ghi trên Cloud
      final sub = ref.onValue.listen((event) async {
        if (event.snapshot.value == null) return;
        final data = event.snapshot.value;
        if (data is Map) {
          await _dongBoMapVaoLocal(table, data);
          TuitionEventService().notifyTuitionChanged();
        }
      }, onError: (err) {
        developer.log('Lỗi sync bảng $table: $err', name: 'FirebaseSyncService');
      });

      _subscriptions.add(sub);
    }
  }

  /// Đồng bộ dữ liệu Map nhận từ Firebase vào SQLite database cục bộ
  Future<void> _dongBoMapVaoLocal(String tableName, Map rawMap) async {
    if (kIsWeb) return; // Trên Web sử dụng trực tiếp dữ liệu Firebase
    try {
      final db = await DBHelper.instance.database;
      rawMap.forEach((key, val) async {
        if (val is Map) {
          final Map<String, dynamic> row = {};
          val.forEach((k, v) {
            row[k.toString()] = v;
          });
          await db.insert(
            tableName,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      developer.log(
        'Lỗi lưu local $tableName: $e',
        name: 'FirebaseSyncService',
      );
    }
  }

  /// Hủy các listener khi ứng dụng tắt
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
