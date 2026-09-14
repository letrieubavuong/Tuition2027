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

  FirebaseDatabase? _db;
  bool _isInitialized = false;
  bool _isPushingToCloud = false;
  bool _isRestoringLocal = false;

  final List<StreamSubscription> _subscriptions = [];
  final Map<String, Set<String>> _tableColumnsCache = {};
  Timer? _debounceNotifyTimer;

  bool get isInitialized => _isInitialized;
  bool get isRestoringLocal => _isRestoringLocal;

  Future<FirebaseDatabase> get firebaseDb async {
    if (!_isInitialized || _db == null) {
      await initialize();
    }
    return _db!;
  }

  void pauseCloudListener() {
    _isRestoringLocal = true;
    developer.log('Đã tạm ngắt Cloud Listener để khôi phục dữ liệu SQLite cục bộ', name: 'FirebaseSyncService');
  }

  void resumeCloudListener() {
    _isRestoringLocal = false;
    developer.log('Đã bật lại Cloud Listener sau khi khôi phục', name: 'FirebaseSyncService');
  }

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
          _db?.setPersistenceEnabled(true);
        } catch (_) {}
      }

      _isInitialized = true;
      developer.log(
        'Firebase Realtime Database initialized for manual backup/restore: $cleanUrl',
        name: 'FirebaseSyncService',
      );
    } catch (e) {
      developer.log(
        'Lỗi khởi tạo Firebase: $e',
        name: 'FirebaseSyncService',
        error: e,
      );
    }
  }

  /// Đẩy dữ liệu của một bản ghi lên Firebase Realtime Database (Bỏ qua tự động đẩy để giữ SQLite cục bộ 100% nhanh và không đơ)
  Future<void> pushRecordToCloud(
    String tableName,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    // Để ứng dụng chạy 100% cục bộ trên SQLite không đơ giật. Đồng bộ thủ công qua Drawer khi cần.
    return;
  }

  /// Xóa một bản ghi khỏi Firebase Realtime Database (Bỏ qua tự động xóa để giữ SQLite cục bộ 100% nhanh và không đơ)
  Future<void> deleteRecordFromCloud(String tableName, String recordId) async {
    // Để ứng dụng chạy 100% cục bộ trên SQLite không đơ giật. Đồng bộ thủ công qua Drawer khi cần.
    return;
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

  /// Lấy danh sách cột của bảng SQLite với bộ nhớ đệm Cache
  Future<Set<String>> _getValidColumns(Database db, String tableName) async {
    if (_tableColumnsCache.containsKey(tableName)) {
      return _tableColumnsCache[tableName]!;
    }
    try {
      final List<Map<String, dynamic>> columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final Set<String> validColumns = columns.map((c) => c['name'].toString()).toSet();
      _tableColumnsCache[tableName] = validColumns;
      return validColumns;
    } catch (_) {
      return {};
    }
  }

  /// Đồng bộ dữ liệu Map hoặc List nhận từ Firebase vào SQLite database bằng Batch Transaction
  Future<void> _dongBoDataVaoLocal(String tableName, dynamic rawData) async {
    try {
      final db = await DBHelper.instance.database;
      final validColumns = await _getValidColumns(db, tableName);

      final List<Map<String, dynamic>> rowsToInsert = [];

      void processRow(dynamic rowKey, dynamic val) {
        if (val is Map) {
          final Map<String, dynamic> row = {};
          val.forEach((k, v) {
            final keyStr = k.toString();
            if (validColumns.isEmpty || validColumns.contains(keyStr)) {
              row[keyStr] = v;
            }
          });

          // Xử lý phục hồi khóa ngoại bị thiếu cho bảng lop_hoc_sinh từ key (ví dụ "42_2")
          if (tableName == DBHelper.tenBangLopHS) {
            if ((row['id_hoc_sinh'] == null || row['id_lop'] == null) && rowKey != null) {
              final parts = rowKey.toString().split('_');
              if (parts.length == 2) {
                final parsedHsId = int.tryParse(parts[0]);
                final parsedLopId = int.tryParse(parts[1]);
                if (parsedHsId != null && parsedLopId != null) {
                  row['id_hoc_sinh'] ??= parsedHsId;
                  row['id_lop'] ??= parsedLopId;
                }
              }
            }
            if (row['id_hoc_sinh'] == null || row['id_lop'] == null) {
              developer.log('Bỏ qua bản ghi lop_hoc_sinh hỏng do thiếu id_hoc_sinh/id_lop: $rowKey', name: 'FirebaseSyncService');
              return;
            }

            // Gán giá trị mặc định cho các cột NOT NULL bắt buộc trong SQLite
            if (row['ngay_tham_gia'] == null || row['ngay_tham_gia'].toString().trim().isEmpty) {
              row['ngay_tham_gia'] = DateTime.now().toIso8601String().substring(0, 10);
            }
            if (row['trang_thai'] == null || row['trang_thai'].toString().trim().isEmpty) {
              row['trang_thai'] = 'DANG_HOC';
            }
            if (row.containsKey('id') && row['id'] == null) {
              row.remove('id');
            }
          }

          if (tableName == DBHelper.tenBangDiemDanh) {
            if ((row['id_hoc_sinh'] == null || row['id_lop'] == null) && rowKey != null) {
              final parts = rowKey.toString().split('_');
              if (parts.length >= 2) {
                final parsedHsId = int.tryParse(parts[0]);
                final parsedLopId = int.tryParse(parts[1]);
                if (parsedHsId != null && parsedLopId != null) {
                  row['id_hoc_sinh'] ??= parsedHsId;
                  row['id_lop'] ??= parsedLopId;
                }
              }
            }
            if (row['id_hoc_sinh'] == null || row['id_lop'] == null || row['gio_diem_danh'] == null) {
              return;
            }
            if (row.containsKey('id') && row['id'] == null) {
              row.remove('id');
            }
          }

          if (tableName == DBHelper.tenBangThanhToan) {
            if ((row['id_hoc_sinh'] == null || row['id_lop'] == null) && rowKey != null) {
              final parts = rowKey.toString().split('_');
              if (parts.length >= 2) {
                final parsedHsId = int.tryParse(parts[0]);
                final parsedLopId = int.tryParse(parts[1]);
                if (parsedHsId != null && parsedLopId != null) {
                  row['id_hoc_sinh'] ??= parsedHsId;
                  row['id_lop'] ??= parsedLopId;
                }
              }
            }
            if (row['id_hoc_sinh'] == null || row['id_lop'] == null || row['thang'] == null) {
              return;
            }
            if (row.containsKey('id') && row['id'] == null) {
              row.remove('id');
            }
          }

          if (row.isNotEmpty) {
            rowsToInsert.add(row);
          }
        }
      }

      if (rawData is Map) {
        for (final entry in rawData.entries) {
          processRow(entry.key, entry.value);
        }
      } else if (rawData is List) {
        for (int i = 0; i < rawData.length; i++) {
          processRow(i, rawData[i]);
        }
      }

      if (rowsToInsert.isNotEmpty) {
        try {
          final batch = db.batch();
          for (final row in rowsToInsert) {
            batch.insert(
              tableName,
              row,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          await batch.commit(noResult: true);
          developer.log('Đã đồng bộ ${rowsToInsert.length} bản ghi vào bảng $tableName', name: 'FirebaseSyncService');
        } catch (e) {
          developer.log('Lỗi batch commit cho bảng $tableName ($e), chuyển sang insert từng bản ghi...', name: 'FirebaseSyncService');
          int successCount = 0;
          for (final row in rowsToInsert) {
            try {
              await db.insert(
                tableName,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              successCount++;
            } catch (err) {
              developer.log('Lỗi insert bản ghi $tableName: $row ($err)', name: 'FirebaseSyncService');
            }
          }
          developer.log('Đã insert thành công $successCount / ${rowsToInsert.length} bản ghi cho $tableName', name: 'FirebaseSyncService');
        }
      }
    } catch (e) {
      developer.log(
        'Lỗi lưu local $tableName: $e',
        name: 'FirebaseSyncService',
        error: e,
      );
    }
  }

  /// Đẩy TOÀN BỘ 20 BẢNG dữ liệu từ SQLite lên Firebase Cloud bằng deterministic keys & ghi đè dọn dẹp rác
  Future<int> pushAllLocalDataToCloud() async {
    if (kIsWeb) return 0;
    if (!_isInitialized) await initialize();
    if (_isPushingToCloud) return 0;

    _isPushingToCloud = true;
    int totalPushed = 0;
    final stopwatch = Stopwatch()..start();

    try {
      final db = await DBHelper.instance.database;
      final fDb = await firebaseDb;

      for (final table in _allTables) {
        final rows = await db.query(table);
        if (rows.isEmpty) {
          // Xóa node rỗng trên Cloud để dọn dẹp triệt để các key rác cũ
          try {
            await fDb.ref(table).remove();
          } catch (_) {}
          continue;
        }

        final Map<String, dynamic> tablePayload = {};

        for (final row in rows) {
          String recordId;

          if (table == DBHelper.tenBangLichHocCaNhan) {
            recordId = '${row['id_hoc_sinh']}_${row['id_lich_hoc_chung']}';
          } else if (table == DBHelper.tenBangLopHS) {
            recordId = '${row['id_hoc_sinh']}_${row['id_lop']}';
          } else if (table == DBHelper.tenBangThanhToan) {
            recordId = (row['id'] != null && row['id'].toString().isNotEmpty)
                ? row['id'].toString()
                : '${row['id_hoc_sinh']}_${row['id_lop']}_${row['thang']}';
          } else if (table == DBHelper.tenBangDiemDanh) {
            recordId = (row['id'] != null && row['id'].toString().isNotEmpty)
                ? row['id'].toString()
                : '${row['id_hoc_sinh']}_${row['gio_diem_danh']}';
          } else if (table == DBHelper.tenBangNhiemVuHocSinh) {
            recordId = '${row['id_nhiem_vu']}_${row['id_hoc_sinh']}';
          } else if (table == DBHelper.tenBangKhoanThuHocSinh) {
            recordId = '${row['id_khoan_thu']}_${row['id_hoc_sinh']}';
          } else if (table == DBHelper.tenBangNhanXetThang) {
            recordId = (row['id'] != null && row['id'].toString().isNotEmpty)
                ? row['id'].toString()
                : '${row['id_hoc_sinh']}_${row['id_lop']}_${row['thang']}';
          } else if (table == 'payment_transactions') {
            recordId = (row['transaction_id'] != null && row['transaction_id'].toString().isNotEmpty)
                ? row['transaction_id'].toString()
                : (row['id'] != null ? row['id'].toString() : 'tx_$totalPushed');
          } else if (table == DBHelper.tenBangCaiDat) {
            recordId = row['khoa'].toString();
          } else if (row['id'] != null && row['id'].toString().isNotEmpty) {
            recordId = row['id'].toString();
          } else if (row['khoa'] != null && row['khoa'].toString().isNotEmpty) {
            recordId = row['khoa'].toString();
          } else {
            recordId = 'rec_${row.hashCode}';
          }

          final Map<String, dynamic> cleanData = {};
          row.forEach((key, value) {
            if (value is DateTime) {
              cleanData[key] = value.toIso8601String();
            } else {
              cleanData[key] = value;
            }
          });
          cleanData['updated_at'] = DateTime.now().toIso8601String();

          tablePayload[recordId] = cleanData;
          totalPushed++;
        }

        // Ghi đè toàn bộ node của bảng bằng .set() để xóa triệt để mọi key rác/item_X cũ trên Firebase
        await fDb.ref(table).set(tablePayload);
      }

      stopwatch.stop();
      developer.log(
        '🔥 BLAZING FAST & CLEAN SYNC COMPLETE: Pushed $totalPushed records across 20 tables in ${stopwatch.elapsedMilliseconds}ms!',
        name: 'FirebaseSyncService',
      );
    } catch (e) {
      developer.log(
        'Lỗi push dữ liệu local lên Firebase: $e',
        name: 'FirebaseSyncService',
        error: e,
      );
    } finally {
      // Chờ 1 giây trước khi bỏ flag để tiêu hóa hết các event echo từ Cloud
      Timer(const Duration(seconds: 1), () {
        _isPushingToCloud = false;
      });
    }
    return totalPushed;
  }

  /// Tải TOÀN BỘ 20 BẢNG dữ liệu từ Firebase Cloud xuống SQLite cục bộ
  Future<int> pullAllCloudDataToLocal() async {
    if (kIsWeb) return 0;

    int totalPulled = 0;
    try {
      debugPrint('⚡ Bắt đầu pull 20 bảng từ Firebase Cloud xuống SQLite...');
      final fDb = await firebaseDb;
      for (final table in _allTables) {
        try {
          final snapshot = await fDb
              .ref()
              .child(table)
              .get()
              .timeout(const Duration(seconds: 3));
          if (snapshot.exists && snapshot.value != null) {
            await _dongBoDataVaoLocal(table, snapshot.value);
            totalPulled++;
          }
        } catch (e) {
          debugPrint('Lỗi/Timeout pull bảng $table: $e');
        }
      }
      TuitionEventService().notifyTuitionChanged();
      debugPrint('✅ Pull data từ Firebase hoàn tất: $totalPulled bảng đã cập nhật vào SQLite!');
    } catch (e) {
      debugPrint('❌ Lỗi pull data từ Firebase: $e');
    }
    return totalPulled;
  }

  /// Kiểm tra đối soát số lượng bản ghi từng bảng giữa CSDL SQLite máy và Firebase Realtime Database
  Future<Map<String, Map<String, dynamic>>> doiSoatDuLieuCloud() async {
    final Map<String, Map<String, dynamic>> auditResult = {};
    if (kIsWeb) return auditResult;
    if (!_isInitialized) await initialize();

    try {
      final db = await DBHelper.instance.database;
      final fDb = await firebaseDb;

      for (final table in _allTables) {
        // Đếm số lượng bản ghi trong SQLite cục bộ
        final localCountRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM $table');
        final int localCount = Sqflite.firstIntValue(localCountRes) ?? 0;

        // Đếm số lượng bản ghi trên Firebase Realtime DB
        int cloudCount = 0;
        try {
          final snapshot = await fDb.ref().child(table).get().timeout(const Duration(seconds: 4));
          if (snapshot.exists && snapshot.value != null) {
            if (snapshot.value is Map) {
              cloudCount = (snapshot.value as Map).length;
            } else if (snapshot.value is List) {
              cloudCount = (snapshot.value as List).where((e) => e != null).length;
            }
          }
        } catch (e) {
          cloudCount = -1; // Lỗi hoặc Timeout kết nối
        }

        auditResult[table] = {
          'local': localCount,
          'cloud': cloudCount,
          'isMatch': localCount == cloudCount,
        };
      }
    } catch (e) {
      developer.log('Lỗi đối soát dữ liệu Cloud', error: e, name: 'FirebaseSyncService');
    }
    return auditResult;
  }

  /// Hủy các listener khi ứng dụng tắt
  void dispose() {
    _debounceNotifyTimer?.cancel();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}

