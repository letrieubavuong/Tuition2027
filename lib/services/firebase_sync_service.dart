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
import 'sync_queue_service.dart';

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

  Future<void>? _initializeFuture;

  bool get isInitialized => _isInitialized;
  bool get isRestoringLocal => _isRestoringLocal;

  Future<FirebaseDatabase> get firebaseDb async {
    if (!_isInitialized || _db == null) {
      await initialize();
    }
    final db = _db;
    if (db == null) {
      throw StateError(
        'Firebase initialization failed: database instance is unavailable.',
      );
    }
    return db;
  }

  void pauseCloudListener() {
    _isRestoringLocal = true;
    developer.log(
      'Đã tạm ngắt Cloud Listener để khôi phục dữ liệu SQLite cục bộ',
      name: 'FirebaseSyncService',
    );
  }

  void resumeCloudListener() {
    _isRestoringLocal = false;
    developer.log(
      'Đã bật lại Cloud Listener sau khi khôi phục',
      name: 'FirebaseSyncService',
    );
  }

  /// Khởi tạo kết nối Firebase và bắt đầu lắng nghe sự kiện đồng bộ (Race-condition safe)
  Future<void> initialize() {
    return _initializeFuture ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    if (_isInitialized) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final cleanUrl = DefaultFirebaseOptions.databaseURL.replaceAll(
        RegExp(r'/$'),
        '',
      );
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
      _initializeFuture = null; // Clear future on error to allow retry
      developer.log(
        'Lỗi khởi tạo Firebase: $e',
        name: 'FirebaseSyncService',
        error: e,
      );
    }
  }

  /// PUSH một bản ghi lên persistent sync queue để đồng bộ background an toàn
  Future<void> pushRecordToCloud(
    String tableName,
    String recordId,
    Map<String, dynamic> data,
  ) async {
    await SyncQueueService.instance.enqueueMutation(
      entityType: tableName,
      recordKey: recordId,
      operation: SyncOperation.upsert,
      payload: data,
    );
  }

  /// DELETE một bản ghi khỏi persistent sync queue (Tombstone)
  Future<void> deleteRecordFromCloud(String tableName, String recordId) async {
    await SyncQueueService.instance.enqueueMutation(
      entityType: tableName,
      recordKey: recordId,
      operation: SyncOperation.delete,
    );
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

  /// Xóa cache schema các bảng SQLite (gọi sau khi DB migration)
  void clearSchemaCache() {
    _tableColumnsCache.clear();
    developer.log('Đã xóa cache schema SQLite', name: 'FirebaseSyncService');
  }

  /// Lấy danh sách cột của bảng SQLite với bộ nhớ đệm Cache
  Future<Set<String>> _getValidColumns(Database db, String tableName) async {
    if (_tableColumnsCache.containsKey(tableName)) {
      return _tableColumnsCache[tableName]!;
    }
    try {
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        'PRAGMA table_info($tableName)',
      );
      final Set<String> validColumns = columns
          .map((c) => c['name'].toString())
          .toSet();
      _tableColumnsCache[tableName] = validColumns;
      return validColumns;
    } catch (_) {
      return {};
    }
  }

  /// Đồng bộ dữ liệu Map hoặc List nhận từ Firebase vào SQLite database bằng Batch Transaction
  Future<void> _dongBoDataVaoLocal(
    String tableName,
    dynamic rawData, {
    bool clearFirst = false,
  }) async {
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
            if ((row['id_hoc_sinh'] == null || row['id_lop'] == null) &&
                rowKey != null) {
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
              developer.log(
                'Bỏ qua bản ghi lop_hoc_sinh hỏng do thiếu id_hoc_sinh/id_lop: $rowKey',
                name: 'FirebaseSyncService',
              );
              return;
            }

            // Gán giá trị mặc định cho các cột NOT NULL bắt buộc trong SQLite
            if (row['ngay_tham_gia'] == null ||
                row['ngay_tham_gia'].toString().trim().isEmpty) {
              row['ngay_tham_gia'] = DateTime.now().toIso8601String().substring(
                0,
                10,
              );
            }
            if (row['trang_thai'] == null ||
                row['trang_thai'].toString().trim().isEmpty) {
              row['trang_thai'] = 'DANG_HOC';
            }
            if (row.containsKey('id') && row['id'] == null) {
              row.remove('id');
            }
          }

          if (tableName == DBHelper.tenBangDiemDanh) {
            if ((row['id_hoc_sinh'] == null || row['id_lop'] == null) &&
                rowKey != null) {
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
            if (row['id_hoc_sinh'] == null ||
                row['id_lop'] == null ||
                row['gio_diem_danh'] == null) {
              return;
            }
            if (row.containsKey('id') && row['id'] == null) {
              row.remove('id');
            }
          }

          if (tableName == DBHelper.tenBangThanhToan) {
            if ((row['id_hoc_sinh'] == null || row['id_lop'] == null) &&
                rowKey != null) {
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
            if (row['id_hoc_sinh'] == null ||
                row['id_lop'] == null ||
                row['thang'] == null) {
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

      if (rowsToInsert.isNotEmpty || clearFirst) {
        try {
          await db.transaction((txn) async {
            if (clearFirst) {
              await txn.delete(tableName);
            }
            final batch = txn.batch();
            for (final row in rowsToInsert) {
              batch.insert(
                tableName,
                row,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
            await batch.commit(noResult: true);
          });
          developer.log(
            'Đã đồng bộ ${rowsToInsert.length} bản ghi vào bảng $tableName (clearFirst: $clearFirst)',
            name: 'FirebaseSyncService',
          );
        } catch (e) {
          developer.log(
            'Lỗi batch commit cho bảng $tableName ($e), chuyển sang insert từng bản ghi...',
            name: 'FirebaseSyncService',
          );
          if (clearFirst) {
            try {
              await db.delete(tableName);
            } catch (_) {}
          }
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
              developer.log(
                'Lỗi insert bản ghi $tableName: $row ($err)',
                name: 'FirebaseSyncService',
              );
            }
          }
          developer.log(
            'Đã insert thành công $successCount / ${rowsToInsert.length} bản ghi cho $tableName',
            name: 'FirebaseSyncService',
          );
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
  /// Sinh deterministic key chuẩn xác cho bản ghi 20 bảng (Không dùng row.hashCode hay tx_$totalPushed)
  String getDeterministicRecordKey(
    String table,
    Map<String, dynamic> row, [
    int index = 0,
  ]) {
    if (table == DBHelper.tenBangLichHocCaNhan) {
      return '${row['id_hoc_sinh']}_${row['id_lich_hoc_chung']}';
    }
    if (table == DBHelper.tenBangLopHS) {
      return '${row['id_hoc_sinh']}_${row['id_lop']}';
    }
    if (table == DBHelper.tenBangNhiemVuHocSinh) {
      return '${row['id_nhiem_vu']}_${row['id_hoc_sinh']}';
    }
    if (table == DBHelper.tenBangKhoanThuHocSinh) {
      return '${row['id_khoan_thu']}_${row['id_hoc_sinh']}';
    }
    if (table == DBHelper.tenBangThanhToan) {
      if (row['id'] != null && row['id'].toString().isNotEmpty) {
        return row['id'].toString();
      }
      return '${row['id_hoc_sinh']}_${row['id_lop']}_${row['thang']}';
    }
    if (table == DBHelper.tenBangNhanXetThang) {
      if (row['id'] != null && row['id'].toString().isNotEmpty) {
        return row['id'].toString();
      }
      return '${row['id_hoc_sinh']}_${row['id_lop']}_${row['thang']}';
    }
    if (table == DBHelper.tenBangDiemDanh) {
      if (row['id'] != null && row['id'].toString().isNotEmpty) {
        return row['id'].toString();
      }
      return '${row['id_hoc_sinh']}_${row['id_lop']}_${row['gio_diem_danh']}';
    }
    if (table == 'payment_transactions') {
      if (row['transaction_id'] != null &&
          row['transaction_id'].toString().isNotEmpty) {
        return row['transaction_id'].toString();
      }
      if (row['id'] != null && row['id'].toString().isNotEmpty) {
        return row['id'].toString();
      }
      final acc = row['account_number'] ?? '';
      final dt = row['transaction_date'] ?? '';
      final amt = row['amount'] ?? index;
      return 'tx_${acc}_${dt}_$amt';
    }
    if (table == DBHelper.tenBangCaiDat) {
      return row['khoa']?.toString() ?? 'key_$index';
    }

    if (row['id'] != null && row['id'].toString().isNotEmpty) {
      return row['id'].toString();
    }
    if (row['khoa'] != null && row['khoa'].toString().isNotEmpty) {
      return row['khoa'].toString();
    }

    return '${table}_rec_$index';
  }

  /// Đẩy TOÀN BỘ 20 BẢNG dữ liệu từ SQLite lên Firebase Cloud bằng deterministic keys & ghi đè dọn dẹp rác
  Future<int> pushAllLocalDataToCloud() async {
    if (kIsWeb) return 0;
    if (!_isInitialized) await initialize();
    if (_isPushingToCloud) return 0;

    _isPushingToCloud = true;
    int totalPushed = 0;
    final stopwatch = Stopwatch()..start();
    final syncTimestamp = DateTime.now().toIso8601String();

    try {
      final db = await DBHelper.instance.database;
      final fDb = await firebaseDb;
      final Map<String, dynamic> fullBackupPayload = {};

      for (final table in _allTables) {
        final rows = await db.query(table);
        if (rows.isEmpty) {
          fullBackupPayload[table] = {};
          continue;
        }

        final Map<String, dynamic> tablePayload = {};

        for (int i = 0; i < rows.length; i++) {
          final row = rows[i];
          final String recordId = getDeterministicRecordKey(table, row, i);

          final Map<String, dynamic> cleanData = {};
          row.forEach((key, value) {
            if (value is DateTime) {
              cleanData[key] = value.toIso8601String();
            } else {
              cleanData[key] = value;
            }
          });
          cleanData['updated_at'] = syncTimestamp;

          tablePayload[recordId] = cleanData;
          totalPushed++;
        }

        fullBackupPayload[table] = tablePayload;
      }

      // Thêm nút Manifest chứa metadata sao lưu
      fullBackupPayload['_manifest'] = {
        'backup_id': 'backup_${DateTime.now().millisecondsSinceEpoch}',
        'created_at': syncTimestamp,
        'app_version': '1.0.0',
        'schema_version': 33,
        'table_count': _allTables.length,
        'total_records': totalPushed,
      };

      // Đẩy TOÀN BỘ 20 BẢNG và Manifest lên Cloud bằng 1 lệnh Multi-Location Update duy nhất (Atomic Snapshot)
      await fDb.ref().update(fullBackupPayload);

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

  /// Tải TOÀN BỘ 20 BẢNG dữ liệu từ Firebase Cloud xuống SQLite cục bộ (Có hỗ trợ isFullMirror)
  Future<int> pullAllCloudDataToLocal({bool isFullMirror = false}) async {
    if (kIsWeb) return 0;

    int totalPulled = 0;
    try {
      debugPrint(
        '⚡ Bắt đầu pull 20 bảng từ Firebase Cloud xuống SQLite (FullMirror: $isFullMirror)...',
      );
      final fDb = await firebaseDb;
      for (final table in _allTables) {
        try {
          final snapshot = await fDb
              .ref()
              .child(table)
              .get()
              .timeout(const Duration(seconds: 4));
          if (snapshot.exists && snapshot.value != null) {
            await _dongBoDataVaoLocal(
              table,
              snapshot.value,
              clearFirst: isFullMirror,
            );
            totalPulled++;
          }
        } catch (e) {
          debugPrint('Lỗi/Timeout pull bảng $table: $e');
        }
      }
      TuitionEventService().notifyTuitionChanged();
      debugPrint(
        '✅ Pull data từ Firebase hoàn tất: $totalPulled bảng đã cập nhật vào SQLite!',
      );
    } catch (e) {
      debugPrint('❌ Lỗi pull data từ Firebase: $e');
    }
    return totalPulled;
  }

  /// Kiểm tra đối soát dữ liệu giữa CSDL SQLite máy và Firebase Realtime Database (Hỗ trợ Fast & Deep Audit)
  Future<Map<String, Map<String, dynamic>>> doiSoatDuLieuCloud({
    bool deepAudit = false,
  }) async {
    final Map<String, Map<String, dynamic>> auditResult = {};
    if (kIsWeb) return auditResult;
    if (!_isInitialized) await initialize();

    try {
      final db = await DBHelper.instance.database;
      final fDb = await firebaseDb;

      for (final table in _allTables) {
        // Đếm số lượng bản ghi trong SQLite cục bộ
        final localCountRes = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM $table',
        );
        final int localCount = Sqflite.firstIntValue(localCountRes) ?? 0;

        // Đếm số lượng bản ghi và kiểm tra deep keys trên Firebase Realtime DB
        int cloudCount = 0;
        bool isKeysMatch = true;
        try {
          final snapshot = await fDb
              .ref()
              .child(table)
              .get()
              .timeout(const Duration(seconds: 4));
          if (snapshot.exists && snapshot.value != null) {
            if (snapshot.value is Map) {
              final cloudMap = snapshot.value as Map;
              cloudCount = cloudMap.length;

              if (deepAudit && localCount == cloudCount && localCount > 0) {
                final rows = await db.query(table);
                final localKeys = <String>{};
                for (int i = 0; i < rows.length; i++) {
                  final key = getDeterministicRecordKey(table, rows[i], i);
                  localKeys.add(key);
                  if (cloudMap.containsKey(key)) {
                    final cloudVal = cloudMap[key];
                    if (cloudVal is Map) {
                      final localHash =
                          SyncQueueService.computeCanonicalContentHash(rows[i]);
                      final cloudHash =
                          SyncQueueService.computeCanonicalContentHash(
                            Map<String, dynamic>.from(cloudVal),
                          );
                      if (localHash != cloudHash) {
                        isKeysMatch = false;
                      }
                    }
                  }
                }
                final cloudKeys = cloudMap.keys
                    .map((k) => k.toString())
                    .toSet();
                if (localKeys.difference(cloudKeys).isNotEmpty) {
                  isKeysMatch = false;
                }
              }
            } else if (snapshot.value is List) {
              cloudCount = (snapshot.value as List)
                  .where((e) => e != null)
                  .length;
            }
          }
        } catch (e) {
          cloudCount = -1; // Lỗi hoặc Timeout kết nối
        }

        auditResult[table] = {
          'local': localCount,
          'cloud': cloudCount,
          'isMatch': localCount == cloudCount && isKeysMatch,
          'deepMatch': isKeysMatch,
        };
      }
    } catch (e) {
      developer.log(
        'Lỗi đối soát dữ liệu Cloud',
        error: e,
        name: 'FirebaseSyncService',
      );
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
