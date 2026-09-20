// File: lib/repositories/v2/attendance_repository_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../models/v2/diem_danh_v2.dart';
import '../../utils/db_v2.dart';

class AttendanceRepositoryV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<int> insert(DiemDanhV2 a) async {
    final db = await _dbHelper.database;
    return await db.insert('diem_danh', a.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<int> update(DiemDanhV2 a) async {
    final db = await _dbHelper.database;
    return await db.update('diem_danh', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }
}
