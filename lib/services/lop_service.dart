// File: lib/services/lop_service.dart

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart'; // Import DBHelper
import '../models/lop.dart'; // Import Model Lop

class LopService {
  final dbHelper = DBHelper.instance;
  // Lấy tên bảng từ hằng số đã định nghĩa trong DBHelper
  final String tenBang = DBHelper.tenBangLop;

  // 1. Tao Lop (Create)
  Future<Lop> taoLop(Lop lop) async {
    final db = await dbHelper.database;
    final id = await db.insert(
      tenBang,
      lop.toMap(),
      // Đảm bảo không tạo trùng lặp
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Trả về đối tượng Lop với ID mới được gán
    final savedLop = lop.copyWith(id: id);
    return savedLop;
  }

  // 2. Doc Tat Ca Lop (Read All)
  Future<List<Lop>> docTatCaLop() async {
    final db = await dbHelper.database;
    // SỬA: Dùng rawQuery để JOIN và đếm sĩ số
    final result = await db.rawQuery('''
      SELECT 
        L.*, 
        COUNT(LHS.id_hoc_sinh) as si_so
      FROM $tenBang L
      LEFT JOIN ${DBHelper.tenBangLopHS} LHS ON L.id = LHS.id_lop
      GROUP BY L.id
      ORDER BY L.khoi ASC, L.ten ASC
    ''');
    // Chuyển kết quả Map List sang Lop List
    return result.map((json) => Lop.fromMap(json)).toList();
  }

  Future<int> capNhatLop(Lop lop) async {
    final db = await dbHelper.database;
    // Cập nhật theo ID
    return await db.update(
      tenBang,
      lop.toMap(),
      where: 'id = ?',
      whereArgs: [lop.id],
    );
  }

  Future<int> xoaLop(int id) async {
    final db = await dbHelper.database;
    // Xóa theo ID
    return await db.delete(tenBang, where: 'id = ?', whereArgs: [id]);
  }

  // 5. Doc Lop Theo ID (Optional Read Single)
  Future<Lop?> docLop(int id) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      tenBang,
      columns: ['id', 'ten', 'khoi'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Lop.fromMap(maps.first);
    } else {
      return null;
    }
  }
}
