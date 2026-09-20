// File: lib/services/sync_queue_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:crypto/crypto.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import 'firebase_sync_service.dart';

enum SyncOperation { upsert, delete }

class SyncQueueItem {
  final int? id;
  final String entityType;
  final String recordKey;
  final String operation; // 'UPSERT' or 'DELETE'
  final Map<String, dynamic>? payload;
  final String createdAt;
  final String status; // 'DIRTY', 'SYNCING', 'SYNCED', 'FAILED'
  final int retryCount;
  final String? lastError;

  SyncQueueItem({
    this.id,
    required this.entityType,
    required this.recordKey,
    required this.operation,
    this.payload,
    required this.createdAt,
    this.status = 'DIRTY',
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'entity_type': entityType,
      'record_key': recordKey,
      'operation': operation,
      'payload_json': payload != null ? jsonEncode(payload) : null,
      'created_at': createdAt,
      'status': status,
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic>? parsedPayload;
    if (map['payload_json'] != null &&
        map['payload_json'].toString().isNotEmpty) {
      try {
        parsedPayload =
            jsonDecode(map['payload_json'].toString()) as Map<String, dynamic>;
      } catch (_) {}
    }
    return SyncQueueItem(
      id: map['id'] as int?,
      entityType: map['entity_type'] as String,
      recordKey: map['record_key'] as String,
      operation: map['operation'] as String,
      payload: parsedPayload,
      createdAt: map['created_at'] as String,
      status: map['status'] as String? ?? 'DIRTY',
      retryCount: map['retry_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
    );
  }
}

class SyncQueueService {
  static final SyncQueueService instance = SyncQueueService._internal();
  SyncQueueService._internal();

  bool _isProcessing = false;
  Timer? _autoSyncTimer;

  /// Tính toán SHA-256 Hash chuẩn hóa cho payload (Loại bỏ các trường metadata động)
  static String computeCanonicalContentHash(Map<String, dynamic> data) {
    final cleanMap = <String, dynamic>{};
    final keys = data.keys.toList()..sort();

    for (final k in keys) {
      if (k == 'updated_at' ||
          k == 'last_synced_at' ||
          k == 'sync_status' ||
          k == 'sync_version') {
        continue;
      }
      final val = data[k];
      if (val is DateTime) {
        cleanMap[k] = val.toIso8601String();
      } else {
        cleanMap[k] = val;
      }
    }

    final canonicalJson = jsonEncode(cleanMap);
    final bytes = utf8.encode(canonicalJson);
    return sha256.convert(bytes).toString();
  }

  /// Đưa mutation vào Persistent Sync Queue (Local-first commit)
  Future<void> enqueueMutation({
    required String entityType,
    required String recordKey,
    required SyncOperation operation,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final db = await DBHelper.instance.database;
      final nowStr = DateTime.now().toIso8601String();
      final opStr = operation == SyncOperation.upsert ? 'UPSERT' : 'DELETE';

      final cleanPayload = payload != null
          ? Map<String, dynamic>.from(payload)
          : null;
      final contentHash = cleanPayload != null
          ? computeCanonicalContentHash(cleanPayload)
          : 'DELETED';

      await db.transaction((txn) async {
        // 1. Cập nhật sync_metadata
        final existingMeta = await txn.query(
          DBHelper.tenBangSyncMetadata,
          where: 'entity_type = ? AND record_key = ?',
          whereArgs: [entityType, recordKey],
        );

        int localVer = 1;
        if (existingMeta.isNotEmpty) {
          localVer = (existingMeta.first['local_version'] as int? ?? 1) + 1;
        }

        await txn.insert(
          DBHelper.tenBangSyncMetadata,
          {
            'entity_type': entityType,
            'record_key': recordKey,
            'local_version': localVer,
            'cloud_version': existingMeta.isNotEmpty
                ? existingMeta.first['cloud_version']
                : 0,
            'local_updated_at': nowStr,
            'last_synced_at': existingMeta.isNotEmpty
                ? existingMeta.first['last_synced_at']
                : null,
            'content_hash': contentHash,
            'sync_status': opStr == 'DELETE' ? 'DELETED_PENDING_SYNC' : 'DIRTY',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 2. Coalesce Queue nếu là phi tài chính (Non-financial tables)
        bool isFinancial =
            (entityType == DBHelper.tenBangThanhToan ||
            entityType == 'payment_transactions');

        if (operation == SyncOperation.upsert && !isFinancial) {
          final existingQueue = await txn.query(
            DBHelper.tenBangSyncQueue,
            where:
                'entity_type = ? AND record_key = ? AND status IN (\'DIRTY\', \'FAILED\')',
            whereArgs: [entityType, recordKey],
          );

          if (existingQueue.isNotEmpty) {
            final queueId = existingQueue.first['id'] as int;
            await txn.update(
              DBHelper.tenBangSyncQueue,
              {
                'operation': opStr,
                'payload_json': cleanPayload != null
                    ? jsonEncode(cleanPayload)
                    : null,
                'created_at': nowStr,
                'status': 'DIRTY',
                'retry_count': 0,
                'last_error': null,
              },
              where: 'id = ?',
              whereArgs: [queueId],
            );
            return;
          }
        }

        // 3. Thêm bản ghi mới vào sync_queue
        await txn.insert(DBHelper.tenBangSyncQueue, {
          'entity_type': entityType,
          'record_key': recordKey,
          'operation': opStr,
          'payload_json': cleanPayload != null
              ? jsonEncode(cleanPayload)
              : null,
          'created_at': nowStr,
          'status': 'DIRTY',
          'retry_count': 0,
          'last_error': null,
        });
      });

      developer.log(
        '📌 SyncQueue enqueued [$opStr] $entityType / $recordKey',
        name: 'SyncQueueService',
      );

      // Tự động kích hoạt Queue processing nếu không bận
      scheduleQueueProcessing();
    } catch (e, st) {
      developer.log(
        'Lỗi enqueued SyncQueue [$entityType / $recordKey]: $e',
        error: e,
        stackTrace: st,
        name: 'SyncQueueService',
      );
    }
  }

  void scheduleQueueProcessing({
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(delay, () {
      processPendingQueue();
    });
  }

  /// Xử lý các bản ghi pending trong Sync Queue đẩy lên Firebase RTDB
  Future<Map<String, int>> processPendingQueue() async {
    if (kIsWeb) return {'processed': 0, 'success': 0, 'failed': 0};
    if (_isProcessing) return {'processed': 0, 'success': 0, 'failed': 0};

    _isProcessing = true;
    int successCount = 0;
    int failedCount = 0;

    try {
      final db = await DBHelper.instance.database;
      final pendingRows = await db.query(
        DBHelper.tenBangSyncQueue,
        where: 'status IN (\'DIRTY\', \'FAILED\') AND retry_count < 5',
        orderBy: 'id ASC',
        limit: 50,
      );

      if (pendingRows.isEmpty) {
        return {'processed': 0, 'success': 0, 'failed': 0};
      }

      final fDb = await FirebaseSyncService.instance.firebaseDb;

      for (final row in pendingRows) {
        final item = SyncQueueItem.fromMap(row);
        final queueId = item.id!;

        try {
          final ref = fDb.ref().child(item.entityType).child(item.recordKey);

          if (item.operation == 'DELETE') {
            await ref.remove().timeout(const Duration(seconds: 5));
          } else {
            final payload = Map<String, dynamic>.from(item.payload ?? {});
            payload['updated_at'] = DateTime.now().toIso8601String();
            await ref.set(payload).timeout(const Duration(seconds: 5));
          }

          // Thành công -> Xóa khỏi queue và cập nhật metadata
          await db.transaction((txn) async {
            await txn.delete(
              DBHelper.tenBangSyncQueue,
              where: 'id = ?',
              whereArgs: [queueId],
            );

            await txn.update(
              DBHelper.tenBangSyncMetadata,
              {
                'last_synced_at': DateTime.now().toIso8601String(),
                'sync_status': 'SYNCED',
              },
              where: 'entity_type = ? AND record_key = ?',
              whereArgs: [item.entityType, item.recordKey],
            );
          });

          successCount++;
        } catch (e) {
          failedCount++;
          final nextRetry = item.retryCount + 1;
          final errStr = e.toString();
          final newStatus = nextRetry >= 5 ? 'FAILED' : 'DIRTY';

          await db.update(
            DBHelper.tenBangSyncQueue,
            {
              'retry_count': nextRetry,
              'last_error': errStr,
              'status': newStatus,
            },
            where: 'id = ?',
            whereArgs: [queueId],
          );

          developer.log(
            'Lỗi sync queue item #${item.id} [${item.entityType}/${item.recordKey}]: $errStr (retry: $nextRetry)',
            name: 'SyncQueueService',
          );
        }
      }

      developer.log(
        '⚡ SyncQueue processed: $successCount success, $failedCount failed',
        name: 'SyncQueueService',
      );
    } catch (e) {
      developer.log('Lỗi processPendingQueue: $e', name: 'SyncQueueService');
    } finally {
      _isProcessing = false;
    }

    return {
      'processed': successCount + failedCount,
      'success': successCount,
      'failed': failedCount,
    };
  }

  /// Lấy thống kê số lượng bản ghi chưa đồng bộ trong Sync Queue
  Future<Map<String, int>> getQueueStats() async {
    try {
      final db = await DBHelper.instance.database;
      final pendingRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DBHelper.tenBangSyncQueue} WHERE status = \'DIRTY\'',
      );
      final failedRes = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DBHelper.tenBangSyncQueue} WHERE status = \'FAILED\'',
      );

      final pending = Sqflite.firstIntValue(pendingRes) ?? 0;
      final failed = Sqflite.firstIntValue(failedRes) ?? 0;

      return {'pending': pending, 'failed': failed};
    } catch (_) {
      return {'pending': 0, 'failed': 0};
    }
  }

  void dispose() {
    _autoSyncTimer?.cancel();
  }
}
