// File: lib/repositories/v2/hoc_sinh_repository_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../models/v2/hoc_sinh_v2.dart';
import '../../utils/db_v2.dart';

class HocSinhRepositoryV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<int> insert(HocSinhV2 hs) async {
    final db = await _dbHelper.database;
    return await db.insert('hoc_sinh', hs.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<HocSinhV2>> getAll({bool includeArchived = false}) async {
    final db = await _dbHelper.database;
    final where = includeArchived ? null : 'da_luu_tru = 0';
    final List<Map<String, dynamic>> maps = await db.query('hoc_sinh', where: where, orderBy: 'ho_ten ASC');
    return maps.map((m) => HocSinhV2.fromMap(m)).toList();
  }

  Future<HocSinhV2?> getById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('hoc_sinh', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return HocSinhV2.fromMap(maps.first);
  }

  Future<int> update(HocSinhV2 hs) async {
    final db = await _dbHelper.database;
    return await db.update('hoc_sinh', hs.toMap(), where: 'id = ?', whereArgs: [hs.id]);
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('hoc_sinh', where: 'id = ?', whereArgs: [id]);
  }
}
