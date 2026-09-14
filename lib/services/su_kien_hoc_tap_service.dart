// File: lib/services/su_kien_hoc_tap_service.dart

import 'package:sqflite/sqflite.dart';
import '../models/su_kien_lich_su_view_model.dart';
import '../models/su_kien_hoc_tap.dart';
import '../utils/db.dart';
import 'firebase_sync_service.dart';

class SuKienHocTapService {
  final String _tenBang = DBHelper.tenBangSuKienHocTap;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  /// Lấy tất cả sự kiện của một buổi học (dựa trên id_diem_danh)
  Future<List<SuKienHocTap>> laySuKienTheoBuoiHoc(int idDiemDanh) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'id_diem_danh = ?',
      whereArgs: [idDiemDanh],
      orderBy: 'id DESC',
    );
    return maps.map((map) => SuKienHocTap.fromMap(map)).toList();
  }

  /// Thêm một sự kiện mới
  Future<int> themSuKien(SuKienHocTap suKien) async {
    final db = await _database;
    final id = await db.insert(
      _tenBang,
      suKien.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (id > 0) {
      final created = suKien.copyWith(id: id);
      FirebaseSyncService.instance
          .pushRecordToCloud(_tenBang, id.toString(), created.toMap())
          .catchError((e) => null);
    }
    return id;
  }

  /// Xóa một sự kiện
  Future<int> xoaSuKien(int idSuKien) async {
    final db = await _database;
    final result = await db.delete(_tenBang, where: 'id = ?', whereArgs: [idSuKien]);
    if (result > 0) {
      FirebaseSyncService.instance
          .deleteRecordFromCloud(_tenBang, idSuKien.toString())
          .catchError((e) => null);
    }
    return result;
  }

  /// Lấy toàn bộ lịch sử sự kiện của một học sinh, sắp xếp theo ngày mới nhất.
  Future<List<SuKienLichSuViewModel>> layLichSuSuKien(int idHocSinh) async {
    final db = await _database;

    final String sql =
        '''
      SELECT 
        L.ten as tenLop,
        DD.gio_diem_danh as ngayHoc,
        SK.mo_ta,
        SK.diem_thay_doi,
        SK.loai_su_kien
      FROM $_tenBang SK
      JOIN ${DBHelper.tenBangDiemDanh} DD ON SK.id_diem_danh = DD.id
      JOIN ${DBHelper.tenBangLop} L ON DD.id_lop = L.id
      WHERE DD.id_hoc_sinh = ?
      ORDER BY DD.gio_diem_danh DESC
    ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, [idHocSinh]);

    return List.generate(
      maps.length,
      (i) => SuKienLichSuViewModel.fromMap(maps[i]),
    );
  }
}
