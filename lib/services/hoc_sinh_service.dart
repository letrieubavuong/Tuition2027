// File: lib/services/hoc_sinh_service.dart (CẬP NHẬT)

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../models/hs.dart'; // Sử dụng model HS mới

class HocSinhService {
  final dbHelper = DBHelper.instance;
  final String tenBang = DBHelper.tenBangHS;

  Future<Database> get database async => await dbHelper.database;

  // 1. Tao Hoc Sinh (Create)
  Future<HS> taoHocSinh(HS hs) async {
    final db = await dbHelper.database;
    final id = await db.insert(
      tenBang,
      hs.toMap(), // Sử dụng toMap() của HS
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return hs.copyWith(id: id);
  }

  // 2. Doc Tat Ca Hoc Sinh (Read All)
  Future<List<HS>> docTatCaHocSinh() async {
    final db = await dbHelper.database;

    final result = await db.query(tenBang, orderBy: 'ten ASC');

    // Sử dụng HS.fromMap()
    return result.map((json) => HS.fromMap(json)).toList();
  }

  // 3. Cap Nhat Hoc Sinh (Update)
  Future<int> capNhatHocSinh(HS hs) async {
    final db = await dbHelper.database;
    return db.update(tenBang, hs.toMap(), where: 'id = ?', whereArgs: [hs.id]);
  }

  Future<HS?> docHocSinhTheoId(int id) async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tenBang,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      // Trả về Model HS
      return HS.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // 4. Xoa Hoc Sinh (Delete)
  Future<int> xoaHocSinh(int id) async {
    final db = await dbHelper.database;
    // Sử dụng transaction để đảm bảo tính toàn vẹn
    return await db.transaction((txn) async {
      // ON DELETE CASCADE sẽ tự động xóa các bản ghi liên quan trong
      // lop_hoc_sinh, diem_danh, thanh_toan, lich_hoc_ca_nhan, nhiem_vu_hoc_sinh
      return await txn.delete(tenBang, where: 'id = ?', whereArgs: [id]);
    });
  }

  // Thêm mới: Cập nhật số buổi học dư của học sinh
  Future<int> capNhatSoBuoiDu(int idHocSinh, int soBuoiMoi) async {
    try {
      final db = await dbHelper.database;
      return await db.update(
        tenBang,
        {'so_buoi_du': soBuoiMoi},
        where: 'id = ?',
        whereArgs: [idHocSinh],
      );
    } catch (e) {
      print('Lỗi khi cập nhật số buổi dư: $e');
      return 0;
    }
  }
}
