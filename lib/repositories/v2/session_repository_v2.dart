// File: lib/repositories/v2/session_repository_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../models/v2/buoi_hoc_v2.dart';
import '../../utils/db_v2.dart';

class SessionRepositoryV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<int> insert(BuoiHocV2 session) async {
    final db = await _dbHelper.database;
    return await db.insert('buoi_hoc', session.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<BuoiHocV2>> getByClassAndDateRange(int lopId, String start, String end) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'buoi_hoc',
      where: 'id_lop = ? AND ngay BETWEEN ? AND ?',
      whereArgs: [lopId, start, end],
      orderBy: 'ngay ASC, gio_bat_dau ASC',
    );
    return maps.map((m) => BuoiHocV2.fromMap(m)).toList();
  }

  Future<BuoiHocV2?> getById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('buoi_hoc', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return BuoiHocV2.fromMap(maps.first);
  }

  Future<int> update(BuoiHocV2 session) async {
    final db = await _dbHelper.database;
    return await db.update('buoi_hoc', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
  }
}
