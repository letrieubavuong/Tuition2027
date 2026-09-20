import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import 'firebase_sync_service.dart';
import 'tuition_event_service.dart';

class CaiDatService {
  final dbHelper = DBHelper.instance;
  final String tenBang = DBHelper.tenBangCaiDat;

  // Lấy giá trị Setting theo Key
  Future<String?> layCaiDat(String khoa) async {
    try {
      final db = await dbHelper.database;
      final result = await db.query(
        tenBang,
        columns: ['gia_tri'],
        where: 'khoa = ?',
        whereArgs: [khoa],
      );
      if (result.isNotEmpty) {
        return result.first['gia_tri'] as String;
      }
    } catch (e, st) {
      developer.log(
        '❌ Lỗi đọc cài đặt cho khóa $khoa',
        name: 'CaiDatService',
        error: e,
        stackTrace: st,
      );
    }
    return null;
  }

  // Cập nhật giá trị Setting (Tạo mới nếu chưa có)
  Future<int> capNhatCaiDat(String khoa, String giaTri) async {
    try {
      final db = await dbHelper.database;
      final result = await db.insert(tenBang, {
        'khoa': khoa,
        'gia_tri': giaTri,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      if (result > 0) {
        FirebaseSyncService.instance
            .pushRecordToCloud(tenBang, khoa, {'khoa': khoa, 'gia_tri': giaTri})
            .catchError((e) => null);
        TuitionEventService().notifyTuitionChanged();
      }
      return result;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi cập nhật cài đặt cho khóa $khoa',
        name: 'CaiDatService',
        error: e,
        stackTrace: st,
      );
      return 0;
    }
  }

  // Cập nhật hàng loạt cài đặt trong một SQLite transaction duy nhất
  Future<bool> capNhatCaiDatBatch(Map<String, String> danhSachCaiDat) async {
    try {
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var entry in danhSachCaiDat.entries) {
          batch.insert(tenBang, {
            'khoa': entry.key,
            'gia_tri': entry.value,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });

      for (var entry in danhSachCaiDat.entries) {
        FirebaseSyncService.instance
            .pushRecordToCloud(tenBang, entry.key, {
              'khoa': entry.key,
              'gia_tri': entry.value,
            })
            .catchError((e) => null);
      }
      TuitionEventService().notifyTuitionChanged();
      return true;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi cập nhật cài đặt theo batch',
        name: 'CaiDatService',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  // Đọc giá trị có fallback mặc định
  Future<String> docGiaTri(String khoa, {String macDinh = ''}) async {
    final val = await layCaiDat(khoa);
    return val ?? macDinh;
  }
}
