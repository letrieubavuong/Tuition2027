import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../models/quy_tac_diem.dart';
import 'firebase_sync_service.dart';

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
    final created = quyTac.copyWith(id: id);
    FirebaseSyncService.instance
        .pushRecordToCloud(_tenBang, id.toString(), created.toMap())
        .catchError((e) => null);
    return created;
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
    final result = await db.update(
      _tenBang,
      quyTac.toMap(),
      where: 'id = ?',
      whereArgs: [quyTac.id],
    );
    if (result > 0 && quyTac.id != null) {
      FirebaseSyncService.instance
          .pushRecordToCloud(_tenBang, quyTac.id.toString(), quyTac.toMap())
          .catchError((e) => null);
    }
    return result;
  }

  // Xóa một quy tắc điểm
  Future<int> xoaQuyTacDiem(int id) async {
    final db = await _database;
    final result = await db.delete(_tenBang, where: 'id = ?', whereArgs: [id]);
    if (result > 0) {
      FirebaseSyncService.instance
          .deleteRecordFromCloud(_tenBang, id.toString())
          .catchError((e) => null);
    }
    return result;
  }

  // Tự động phân bổ điểm nguyên tố (Atomic Transaction)
  Future<void> tuDongChiaDiemAtomic() async {
    final db = await _database;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> maps = await txn.query(
        _tenBang,
        orderBy: 'thu_tu_hien_thi ASC, mo_ta ASC',
      );
      final listQuyTac = List.generate(
        maps.length,
        (i) => QuyTacDiem.fromMap(maps[i]),
      );
      if (listQuyTac.isEmpty) return;

      final positiveRules = listQuyTac
          .where((r) => r.loaiQuyTac == 'CONG_DIEM')
          .toList();
      final negativeRules = listQuyTac
          .where((r) => r.loaiQuyTac == 'TRU_DIEM')
          .toList();

      if (positiveRules.isNotEmpty) {
        double sumAllocated = 0.0;
        for (int i = 0; i < positiveRules.length; i++) {
          double share;
          if (i == positiveRules.length - 1) {
            share = 10.0 - sumAllocated;
          } else {
            share = double.parse(
              (10.0 / positiveRules.length).toStringAsFixed(2),
            );
            sumAllocated += share;
          }
          share = double.parse(share.toStringAsFixed(2));
          final updated = positiveRules[i].copyWith(diemThayDoi: share);
          await txn.update(
            _tenBang,
            updated.toMap(),
            where: 'id = ?',
            whereArgs: [updated.id],
          );
        }
      }

      if (negativeRules.isNotEmpty) {
        double sumAllocated = 0.0;
        for (int i = 0; i < negativeRules.length; i++) {
          double share;
          if (i == negativeRules.length - 1) {
            share = -5.0 - sumAllocated;
          } else {
            share = double.parse(
              (-5.0 / negativeRules.length).toStringAsFixed(2),
            );
            sumAllocated += share;
          }
          share = double.parse(share.toStringAsFixed(2));
          final updated = negativeRules[i].copyWith(diemThayDoi: share);
          await txn.update(
            _tenBang,
            updated.toMap(),
            where: 'id = ?',
            whereArgs: [updated.id],
          );
        }
      }
    });
  }
}
