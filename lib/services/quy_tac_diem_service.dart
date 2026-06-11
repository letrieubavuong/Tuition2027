import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../models/quy_tac_diem.dart';

class QuyTacDiemService {
  final String _tenBang = DBHelper.tenBangQuyTacDiem;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  // Thêm mới một quy tắc điểm
  Future<QuyTacDiem> taoQuyTacDiem(QuyTacDiem quyTac) async {
    final db = await _database;
    final id = await db.insert(
      _tenBang,
      quyTac.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return quyTac.copyWith(id: id);
  }

  // Đọc tất cả các quy tắc điểm
  Future<List<QuyTacDiem>> docTatCaQuyTacDiem() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      orderBy: 'thu_tu_hien_thi ASC, mo_ta ASC',
    );
    return List.generate(maps.length, (i) => QuyTacDiem.fromMap(maps[i]));
  }

  // Đọc các quy tắc điểm theo loại (cộng/trừ)
  Future<List<QuyTacDiem>> docQuyTacDiemTheoLoai(String loaiQuyTac) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'loai_quy_tac = ?',
      whereArgs: [loaiQuyTac],
      orderBy: 'thu_tu_hien_thi ASC, mo_ta ASC',
    );
    return List.generate(maps.length, (i) => QuyTacDiem.fromMap(maps[i]));
  }

  // Cập nhật một quy tắc điểm
  Future<int> capNhatQuyTacDiem(QuyTacDiem quyTac) async {
    final db = await _database;
    return await db.update(
      _tenBang,
      quyTac.toMap(),
      where: 'id = ?',
      whereArgs: [quyTac.id],
    );
  }

  // Xóa một quy tắc điểm
  Future<int> xoaQuyTacDiem(int id) async {
    final db = await _database;
    return await db.delete(_tenBang, where: 'id = ?', whereArgs: [id]);
  }
}
