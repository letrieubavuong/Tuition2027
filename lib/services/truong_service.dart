// File: lib/services/truong_service.dart

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart'; // Import DBHelper
import '../models/truong.dart'; // Import Model Truong
import 'firebase_sync_service.dart';

class TruongService {
  final dbHelper = DBHelper.instance;
  // Lấy tên bảng từ hằng số đã định nghĩa trong DBHelper
  final String tenBang = DBHelper.tenBangTruong;

  // 1. Tao Truong
  Future<Truong> taoTruong(Truong truong) async {
    final db = await dbHelper.database;
    final id = await db.insert(
      tenBang,
      truong.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    final created = truong.copyWith(id: id);
    FirebaseSyncService.instance
        .pushRecordToCloud(tenBang, id.toString(), created.toMap())
        .catchError((e) => null);
    return created;
  }

  // 2. Doc Tat Ca Truong
  Future<List<Truong>> docTatCaTruong() async {
    final db = await dbHelper.database;
    // Query dữ liệu, sắp xếp theo tên
    final result = await db.query(tenBang, orderBy: 'ten ASC');
    // Chuyển kết quả Map List sang Truong List
    return result.map((json) => Truong.fromMap(json)).toList();
  }

  // 3. Cap Nhat Truong
  Future<int> capNhatTruong(Truong truong) async {
    final db = await dbHelper.database;
    // Cập nhật theo ID
    final result = await db.update(
      tenBang,
      truong.toMap(),
      where: 'id = ?',
      whereArgs: [truong.id],
    );
    if (result > 0 && truong.id != null) {
      FirebaseSyncService.instance
          .pushRecordToCloud(tenBang, truong.id.toString(), truong.toMap())
          .catchError((e) => null);
    }
    return result;
  }

  // 4. Xoa Truong
  Future<int> xoaTruong(int id) async {
    final db = await dbHelper.database;
    // Xóa theo ID
    final result = await db.delete(tenBang, where: 'id = ?', whereArgs: [id]);
    if (result > 0) {
      FirebaseSyncService.instance
          .deleteRecordFromCloud(tenBang, id.toString())
          .catchError((e) => null);
    }
    return result;
  }
}
