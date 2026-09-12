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

      final cleanUrl = DefaultFirebaseOptions.databaseURL.replaceAll(RegExp(r'/$'), '');
      _db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: cleanUrl,
      );

      // Kích hoạt tính năng Persistence cho bản native (Android/iOS)
      if (!kIsWeb) {
        try {
          _db.setPersistenceEnabled(true);
        } catch (_) {}
      }

      _isInitialized = true;
      developer.log(
        'Firebase Realtime Database initialized successfully: $cleanUrl',
        name: 'FirebaseSyncService',
      );

      // Đẩy bản tin hệ thống để khôi phục nút gốc Firebase không bị null
      try {
        await _db.ref().child('system_info').set({
          'app_name': 'Tuition2026',
          'last_sync': DateTime.now().toIso8601String(),
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        });
      } catch (e) {
        developer.log('System info ping error: $e');
      }

      // Bắt đầu lắng nghe thay đổi dữ liệu từ Cloud về máy
      _batDauLangNgheCloudSync();

      // Đẩy toàn bộ dữ liệu SQLite cũ từ điện thoại lên Cloud (tránh mất dữ liệu)
      if (!kIsWeb) {
        unawaited(pushAllLocalDataToCloud());
      }
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

  List<String> get _allTables => [
        DBHelper.tenBangHS,
        DBHelper.tenBangLop,
        DBHelper.tenBangLopHS,
        DBHelper.tenBangLichHoc,
        DBHelper.tenBangDiemDanh,
        DBHelper.tenBangThanhToan,
        DBHelper.tenBangNhanXetThang,
        DBHelper.tenBangCaiDat,
        DBHelper.tenBangQuyTacDiem,
        DBHelper.tenBangSuKienHocTap,
        DBHelper.tenBangTruong,
        DBHelper.tenBangLichHocChung,
        DBHelper.tenBangLichHocCaNhan,
        DBHelper.tenBangNhiemVu,
        DBHelper.tenBangNhiemVuHocSinh,
        DBHelper.tenBangDanhGiaBuoiHoc,
        DBHelper.tenBangDonNghiHoc,
        DBHelper.tenBangKhoanThu,
        DBHelper.tenBangKhoanThuHocSinh,
        'payment_transactions',
      ];

  /// Đăng ký lắng nghe các thay đổi thời gian thực từ Cloud và cập nhật về SQLite/UI
  void _batDauLangNgheCloudSync() {
    for (final table in _allTables) {
      final ref = _db.ref().child(table);

      // Lắng nghe sự kiện thêm/sửa bản ghi trên Cloud
      final sub = ref.onValue.listen((event) async {
        if (event.snapshot.value == null) return;
        final data = event.snapshot.value;
        await _dongBoDataVaoLocal(table, data);
        TuitionEventService().notifyTuitionChanged();
      }, onError: (err) {
        developer.log('Lỗi sync bảng $table: $err', name: 'FirebaseSyncService');
      });

      _subscriptions.add(sub);
    }
  }

  /// Đồng bộ dữ liệu Map hoặc List nhận từ Firebase vào SQLite database cục bộ
  Future<void> _dongBoDataVaoLocal(String tableName, dynamic rawData) async {
    try {
      final db = await DBHelper.instance.database;

      // Lấy thông tin cột của bảng SQLite cục bộ để bỏ qua các trường không hợp lệ
      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final Set<String> validColumns = columns.map((c) => c['name'].toString()).toSet();

      if (rawData is Map) {
        for (final entry in rawData.entries) {
          final val = entry.value;
          if (val is Map) {
            final Map<String, dynamic> row = {};
            val.forEach((k, v) {
              final keyStr = k.toString();
              if (validColumns.isEmpty || validColumns.contains(keyStr)) {
                row[keyStr] = v;
              }
            });
            if (row.isNotEmpty) {
              await db.insert(
                tableName,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      } else if (rawData is List) {
        for (final val in rawData) {
          if (val is Map) {
            final Map<String, dynamic> row = {};
            val.forEach((k, v) {
              final keyStr = k.toString();
              if (validColumns.isEmpty || validColumns.contains(keyStr)) {
                row[keyStr] = v;
              }
            });
            if (row.isNotEmpty) {
              await db.insert(
                tableName,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        }
      }
    } catch (e) {
      developer.log(
        'Lỗi lưu local $tableName: $e',
        name: 'FirebaseSyncService',
      );
    }
  }

  /// Đẩy toàn bộ dữ liệu SQLite hiện có từ điện thoại lên Firebase Realtime Database
  Future<int> pushAllLocalDataToCloud() async {
    if (kIsWeb) return 0;
    if (!_isInitialized) await initialize();

    int totalPushed = 0;
    try {
      final db = await DBHelper.instance.database;
      for (final table in _allTables) {
        final rows = await db.query(table);
        int idx = 0;
        for (final row in rows) {
          String recordId;
          if (row['id'] != null && row['id'].toString().isNotEmpty) {
            recordId = row['id'].toString();
          } else if (row['khoa'] != null && row['khoa'].toString().isNotEmpty) {
            recordId = row['khoa'].toString();
          } else if (row['id_hoc_sinh'] != null && row['id_lop'] != null) {
            recordId = '${row['id_hoc_sinh']}_${row['id_lop']}';
          } else if (row['id_nhiem_vu'] != null && row['id_hoc_sinh'] != null) {
            recordId = '${row['id_nhiem_vu']}_${row['id_hoc_sinh']}';
          } else if (row['id_khoan_thu'] != null && row['id_hoc_sinh'] != null) {
            recordId = '${row['id_khoan_thu']}_${row['id_hoc_sinh']}';
          } else if (row['transaction_id'] != null && row['transaction_id'].toString().isNotEmpty) {
            recordId = row['transaction_id'].toString();
          } else {
            recordId = 'item_$idx';
          }
          await pushRecordToCloud(table, recordId, row);
          totalPushed++;
          idx++;
        }
      }
      developer.log(
        'Successfully pushed $totalPushed records across all 20 SQLite tables to Firebase!',
        name: 'FirebaseSyncService',
      );
    } catch (e) {
      developer.log(
        'Lỗi push dữ liệu local lên Firebase: $e',
        name: 'FirebaseSyncService',
        error: e,
      );
    }
    return totalPushed;
  }

  /// Hủy các listener khi ứng dụng tắt
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
