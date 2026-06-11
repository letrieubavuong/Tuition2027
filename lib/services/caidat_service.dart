// File: lib/services/caidat_service.dart

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';

class CaiDatService {
  final dbHelper = DBHelper.instance;
  final String tenBang = DBHelper.tenBangCaiDat;

  // Lấy giá trị Setting theo Key
  Future<String?> layCaiDat(String khoa) async {
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
    return null;
  }

  // Cập nhật giá trị Setting
  Future<int> capNhatCaiDat(String khoa, String giaTri) async {
    final db = await dbHelper.database;
    return db.update(
      tenBang,
      {'gia_tri': giaTri},
      where: 'khoa = ?',
      whereArgs: [khoa],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}