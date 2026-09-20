// File: lib/repositories/v2/schedule_repository_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../models/v2/lich_hoc_v2.dart';
import '../../utils/db_v2.dart';

class ScheduleRepositoryV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<int> insert(LichHocV2 schedule) async {
    final db = await _dbHelper.database;
    return await db.insert('lich_hoc', schedule.toMap());
  }

  Future<List<LichHocV2>> getByClassId(int lopId, {String? atDate}) async {
    final db = await _dbHelper.database;
    String where = 'id_lop = ?';
    List<dynamic> whereArgs = [lopId];
    
    if (atDate != null) {
      where += ' AND hieu_luc_tu <= ? AND (hieu_luc_den IS NULL OR hieu_luc_den >= ?)';
      whereArgs.addAll([atDate, atDate]);
    }
    
    final List<Map<String, dynamic>> maps = await db.query('lich_hoc', where: where, whereArgs: whereArgs);
    return maps.map((m) => LichHocV2.fromMap(m)).toList();
  }

  Future<int> update(LichHocV2 schedule) async {
    final db = await _dbHelper.database;
    return await db.update('lich_hoc', schedule.toMap(), where: 'id = ?', whereArgs: [schedule.id]);
  }

  Future<int> delete(int id) async {
    final db = await _dbHelper.database;
    return await db.delete('lich_hoc', where: 'id = ?', whereArgs: [id]);
  }
}
