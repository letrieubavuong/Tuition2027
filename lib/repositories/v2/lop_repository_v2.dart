// File: lib/repositories/v2/lop_repository_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../models/v2/lop_v2.dart';
import '../../utils/db_v2.dart';

class LopRepositoryV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<int> insert(LopV2 lop) async {
    final db = await _dbHelper.database;
    return await db.insert('lop', lop.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LopV2>> getAll({bool includeArchived = false}) async {
    final db = await _dbHelper.database;
    final where = includeArchived ? null : 'da_luu_tru = 0';
    final List<Map<String, dynamic>> maps = await db.query('lop', where: where, orderBy: 'khoi ASC, ten_lop ASC');
    return maps.map((m) => LopV2.fromMap(m)).toList();
  }

  Future<LopV2?> getById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('lop', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return LopV2.fromMap(maps.first);
  }

  Future<int> update(LopV2 lop) async {
    final db = await _dbHelper.database;
    return await db.update('lop', lop.toMap(), where: 'id = ?', whereArgs: [lop.id]);
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('lop', where: 'id = ?', whereArgs: [id]);
  }
}
