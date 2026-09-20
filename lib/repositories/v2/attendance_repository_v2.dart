// File: lib/repositories/v2/attendance_repository_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../models/v2/diem_danh_v2.dart';
import '../../utils/db_v2.dart';

class AttendanceRepositoryV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<int> upsert(DiemDanhV2 a) async {
    final db = await _dbHelper.database;
    
    return await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query(
        'diem_danh',
        where: 'id_buoi_hoc = ? AND id_hoc_sinh = ?',
        whereArgs: [a.idBuoiHoc, a.idHocSinh],
      );

      if (existing.isNotEmpty) {
        final id = existing.first['id'] as int;
        await txn.update(
          'diem_danh',
          a.toMap()..remove('id'),
          where: 'id = ?',
          whereArgs: [id],
        );
        return id;
      } else {
        return await txn.insert('diem_danh', a.toMap());
      }
    });
  }

  Future<List<DiemDanhV2>> getBySessionId(int sessionId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('diem_danh', where: 'id_buoi_hoc = ?', whereArgs: [sessionId]);
    return maps.map((m) => DiemDanhV2.fromMap(m)).toList();
  }

  Future<DiemDanhV2?> getBySessionAndStudent(int sessionId, int studentId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'diem_danh',
      where: 'id_buoi_hoc = ? AND id_hoc_sinh = ?',
      whereArgs: [sessionId, studentId],
    );
    if (maps.isEmpty) return null;
    return DiemDanhV2.fromMap(maps.first);
  }
}
