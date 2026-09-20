// File: lib/repositories/v2/membership_repository_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../models/v2/tham_gia_lop_v2.dart';
import '../../utils/db_v2.dart';

class MembershipRepositoryV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<int> insert(ThamGiaLopV2 m) async {
    final db = await _dbHelper.database;
    return await db.insert('tham_gia_lop', m.toMap());
  }

  Future<List<ThamGiaLopV2>> getByStudentId(int hsId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('tham_gia_lop', where: 'id_hoc_sinh = ?', whereArgs: [hsId]);
    return maps.map((m) => ThamGiaLopV2.fromMap(m)).toList();
  }

  Future<List<ThamGiaLopV2>> getByClassId(int lopId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('tham_gia_lop', where: 'id_lop = ?', whereArgs: [lopId]);
    return maps.map((m) => ThamGiaLopV2.fromMap(m)).toList();
  }

  Future<List<ThamGiaLopV2>> getActiveAt(int lopId, String date) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tham_gia_lop',
      where: 'id_lop = ? AND tu_ngay <= ? AND (den_ngay IS NULL OR den_ngay >= ?)',
      whereArgs: [lopId, date, date],
    );
    return maps.map((m) => ThamGiaLopV2.fromMap(m)).toList();
  }
}
