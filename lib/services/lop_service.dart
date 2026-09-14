// File: lib/services/lop_service.dart

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart'; // Import DBHelper
import '../models/lop.dart'; // Import Model Lop
import 'dart:developer' as developer;
import 'firebase_sync_service.dart';

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
    FirebaseSyncService.instance.pushRecordToCloud(tenBang, id.toString(), savedLop.toMap());
    return savedLop;
  }

  // 2. Doc Tat Ca Lop (Read All)
  Future<List<Lop>> docTatCaLop() async {
    final db = await dbHelper.database;
    // SỬA: Dùng rawQuery để JOIN ép kiểu mềm và đếm sĩ số chuẩn xác
    final result = await db.rawQuery('''
      SELECT 
        L.*, 
        COUNT(DISTINCT CASE WHEN (LHS.trang_thai IS NULL OR (UPPER(LHS.trang_thai) != 'NGHI_HOC' AND UPPER(LHS.trang_thai) != 'DA_NGHI')) THEN LHS.id_hoc_sinh END) as si_so
      FROM $tenBang L
      LEFT JOIN ${DBHelper.tenBangLopHS} LHS ON (L.id = LHS.id_lop OR CAST(L.id AS TEXT) = CAST(LHS.id_lop AS TEXT))
      GROUP BY L.id
      ORDER BY L.khoi ASC, L.ten ASC
    ''');
    // Chuyển kết quả Map List sang Lop List
    return result.map((json) => Lop.fromMap(json)).toList();
  }

  Future<int> capNhatLop(Lop lop) async {
    final db = await dbHelper.database;
    final res = await db.update(
      tenBang,
      lop.toMap(),
      where: 'id = ?',
      whereArgs: [lop.id],
    );
    if (res > 0 && lop.id != null) {
      FirebaseSyncService.instance.pushRecordToCloud(tenBang, lop.id.toString(), lop.toMap());
    }
    return res;
  }

  Future<int> xoaLop(int id) async {
    final db = await dbHelper.database;
    try {
      final res = await db.transaction((txn) async {
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
      if (res > 0) {
        FirebaseSyncService.instance.deleteRecordFromCloud(tenBang, id.toString());
      }
      return res;
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
