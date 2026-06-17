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

  // Cập nhật giá trị Setting (Tạo mới nếu chưa có)
  Future<int> capNhatCaiDat(String khoa, String giaTri) async {
    final db = await dbHelper.database;
    return db.insert(
      tenBang,
      {'khoa': khoa, 'gia_tri': giaTri},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Đọc giá trị có fallback mặc định
  Future<String> docGiaTri(String khoa, {String macDinh = ''}) async {
    final val = await layCaiDat(khoa);
    return val ?? macDinh;
  }
}