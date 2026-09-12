// File: lib/services/lop_service.dart

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart'; // Import DBHelper
import '../models/lop.dart'; // Import Model Lop
import 'dart:developer' as developer;

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
      LEFT JOIN ${DBHelper.tenBangLopHS} LHS
        ON L.id = LHS.id_lop
        AND (
          LHS.ngay_nghi_hoc IS NULL
          OR LHS.ngay_nghi_hoc > date('now', 'localtime')
          OR LHS.ngay_hoc_lai_sau_nghi <= date('now', 'localtime')
        )
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
    try {
      return await db.transaction((txn) async {
        // lich_hoc_chung chưa có ON DELETE CASCADE. Phải xóa các bản ghi
        // gán lịch cá nhân trước rồi mới xóa lịch chung của lớp.
        await txn.rawDelete(
          '''
          DELETE FROM ${DBHelper.tenBangLichHocCaNhan}
          WHERE id_lich_hoc_chung IN (
            SELECT id FROM ${DBHelper.tenBangLichHocChung} WHERE id_lop = ?
          )
          ''',
          [id],
        );
        await txn.delete(
          DBHelper.tenBangLichHocChung,
          where: 'id_lop = ?',
          whereArgs: [id],
        );

        // Các bảng cũ không khai báo khóa ngoại id_lop nên cần dọn rõ ràng.
        await txn.delete(
          DBHelper.tenBangThanhToan,
          where: 'id_lop = ?',
          whereArgs: [id],
        );
        await txn.delete(
          DBHelper.tenBangNhanXetThang,
          where: 'id_lop = ?',
          whereArgs: [id],
        );
        await txn.delete(
          DBHelper.tenBangLopHS,
          where: 'id_lop = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'payment_transactions',
          where: 'lop_id = ?',
          whereArgs: [id],
        );

        // Các bảng có ON DELETE CASCADE sẽ được SQLite dọn tại đây.
        return txn.delete(tenBang, where: 'id = ?', whereArgs: [id]);
      });
    } catch (error, stackTrace) {
      developer.log(
        'Không thể xóa lớp ID $id',
        name: 'LopService.xoaLop',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }
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
