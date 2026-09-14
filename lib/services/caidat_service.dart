// File: lib/services/caidat_service.dart

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
      final db = await dbHelper.database.timeout(const Duration(seconds: 1));
      final result = await db.query(
        tenBang,
        columns: ['gia_tri'],
        where: 'khoa = ?',
        whereArgs: [khoa],
      ).timeout(const Duration(seconds: 1));
      if (result.isNotEmpty) {
        return result.first['gia_tri'] as String;
      }
    } catch (e) {
      // Fallback khi DB timeout hoac loi tren web
    }
    return null;
  }

  // Cập nhật giá trị Setting (Tạo mới nếu chưa có)
  Future<int> capNhatCaiDat(String khoa, String giaTri) async {
    try {
      final db = await dbHelper.database.timeout(const Duration(seconds: 1));
      final result = await db.insert(tenBang, {
        'khoa': khoa,
        'gia_tri': giaTri,
      }, conflictAlgorithm: ConflictAlgorithm.replace).timeout(const Duration(seconds: 1));
      if (result > 0) {
        FirebaseSyncService.instance
            .pushRecordToCloud(tenBang, khoa, {'khoa': khoa, 'gia_tri': giaTri})
            .catchError((e) => null);
        TuitionEventService().notifyTuitionChanged();
      }
      return result;
    } catch (e) {
      return 0;
    }
  }

  // Đọc giá trị có fallback mặc định
  Future<String> docGiaTri(String khoa, {String macDinh = ''}) async {
    final val = await layCaiDat(khoa);
    return val ?? macDinh;
  }
}
