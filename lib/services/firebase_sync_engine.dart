// File: lib/services/firebase_sync_engine.dart

import 'dart:developer' as developer;
import 'firebase_sync_service.dart';

class FirebaseSyncEngine {
  static final FirebaseSyncEngine instance = FirebaseSyncEngine._internal();
  FirebaseSyncEngine._internal();

  /// 1. Push 1 bản ghi đơn lẻ lên Cloud
  Future<void> pushOne(
    String tableName,
    String recordKey,
    Map<String, dynamic> data,
  ) async {
    try {
      await FirebaseSyncService.instance.pushRecordToCloud(
        tableName,
        recordKey,
        data,
      );
    } catch (e, st) {
      developer.log(
        'FirebaseSyncEngine.pushOne Error [$tableName / $recordKey]: $e',
        error: e,
        stackTrace: st,
        name: 'FirebaseSyncEngine',
      );
    }
  }

  /// 2. Push danh sách bản ghi theo Batch lên Cloud
  Future<void> pushBatch(
    String tableName,
    Map<String, Map<String, dynamic>> records,
  ) async {
    if (records.isEmpty) return;
    try {
      for (final entry in records.entries) {
        await FirebaseSyncService.instance.pushRecordToCloud(
          tableName,
          entry.key,
          entry.value,
        );
      }
    } catch (e, st) {
      developer.log(
        'FirebaseSyncEngine.pushBatch Error [$tableName]: $e',
        error: e,
        stackTrace: st,
        name: 'FirebaseSyncEngine',
      );
    }
  }

  /// 3. Xóa 1 bản ghi đơn lẻ khỏi Cloud
  Future<void> deleteOne(String tableName, String recordKey) async {
    try {
      await FirebaseSyncService.instance.deleteRecordFromCloud(
        tableName,
        recordKey,
      );
    } catch (e, st) {
      developer.log(
        'FirebaseSyncEngine.deleteOne Error [$tableName / $recordKey]: $e',
        error: e,
        stackTrace: st,
        name: 'FirebaseSyncEngine',
      );
    }
  }

  /// 4. Xóa danh sách bản ghi theo Batch khỏi Cloud
  Future<void> deleteBatch(String tableName, List<String> recordKeys) async {
    if (recordKeys.isEmpty) return;
    try {
      for (final key in recordKeys) {
        await FirebaseSyncService.instance.deleteRecordFromCloud(
          tableName,
          key,
        );
      }
    } catch (e, st) {
      developer.log(
        'FirebaseSyncEngine.deleteBatch Error [$tableName]: $e',
        error: e,
        stackTrace: st,
        name: 'FirebaseSyncEngine',
      );
    }
  }
}
