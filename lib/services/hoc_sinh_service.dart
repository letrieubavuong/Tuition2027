// File: lib/services/hoc_sinh_service.dart (CẬP NHẬT)

import 'dart:developer' as developer;

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../models/hs.dart'; // Sử dụng model HS mới
import 'firebase_sync_service.dart';
import 'tuition_event_service.dart';

import 'student_event_service.dart';

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
    final savedHs = hs.copyWith(id: id);
    FirebaseSyncService.instance.pushRecordToCloud(
      tenBang,
      id.toString(),
      savedHs.toMap(),
    );
    TuitionEventService().notifyTuitionChanged();
    StudentEventService().notifyStudentCreated(savedHs);
    return savedHs;
  }

  // 2. Doc Tat Ca Hoc Sinh (Read All)
  Future<List<HS>> docTatCaHocSinh() async {
    final db = await dbHelper.database;

    final result = await db.query(tenBang, orderBy: 'ten ASC');

    // Sử dụng HS.fromMap()
    return result.map((json) => HS.fromMap(json)).toList();
  }

  Future<HS?> docHocSinhTheoId(int id) async {
    final db = await dbHelper.database;
    final result = await db.query(tenBang, where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) {
      return HS.fromMap(result.first);
    }
    return null;
  }

  /// Lấy danh sách ID các học sinh đang học trong ít nhất một lớp
  Future<Set<int>> docDanhSachIdHocSinhDangHoc() async {
    try {
      final db = await database;
      final rows = await db.rawQuery('''
        SELECT DISTINCT id_hoc_sinh 
        FROM ${DBHelper.tenBangLopHS}
        WHERE (trang_thai IS NULL OR UPPER(trang_thai) NOT IN ('NGHI_HOC', 'DA_NGHI', 'TAM_NGUNG'))
      ''');
      return rows
          .map((r) => r['id_hoc_sinh'])
          .whereType<num>()
          .map((n) => n.toInt())
          .toSet();
    } catch (e, st) {
      developer.log(
        'Lỗi lấy danh sách ID học sinh đang học: $e',
        name: 'HocSinhService',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }

  // 3. Cap Nhat Hoc Sinh (Update)
  Future<int> capNhatHocSinh(HS hs) async {
    final db = await dbHelper.database;
    final res = await db.update(
      tenBang,
      hs.toMap(),
      where: 'id = ?',
      whereArgs: [hs.id],
    );
    if (res > 0 && hs.id != null) {
      FirebaseSyncService.instance.pushRecordToCloud(
        tenBang,
        hs.id.toString(),
        hs.toMap(),
      );
      TuitionEventService().notifyTuitionChanged();
      StudentEventService().notifyStudentUpdated(hs);
    }
    return res;
  }

  Future<int> xoaHocSinh(int id) async {
    final db = await dbHelper.database;
    // Sử dụng transaction và dọn dẹp thủ công các bảng con để chống mồ côi dữ liệu (orphan records)
    final res = await db.transaction((txn) async {
      await txn.delete(
        DBHelper.tenBangLopHS,
        where: 'id_hoc_sinh = ?',
        whereArgs: [id],
      );
      await txn.rawDelete(
        '''
        DELETE FROM ${DBHelper.tenBangDanhGiaBuoiHoc}
        WHERE id_diem_danh IN (
          SELECT id FROM ${DBHelper.tenBangDiemDanh} WHERE id_hoc_sinh = ?
        )
        ''',
        [id],
      );
      await txn.delete(
        DBHelper.tenBangDiemDanh,
        where: 'id_hoc_sinh = ?',
        whereArgs: [id],
      );
      await txn.delete(
        DBHelper.tenBangThanhToan,
        where: 'id_hoc_sinh = ?',
        whereArgs: [id],
      );
      await txn.delete(
        DBHelper.tenBangKhoanThuHocSinh,
        where: 'id_hoc_sinh = ?',
        whereArgs: [id],
      );
      await txn.delete(
        DBHelper.tenBangLichHocCaNhan,
        where: 'id_hoc_sinh = ?',
        whereArgs: [id],
      );
      await txn.delete(
        DBHelper.tenBangNhiemVuHocSinh,
        where: 'id_hoc_sinh = ?',
        whereArgs: [id],
      );
      return await txn.delete(tenBang, where: 'id = ?', whereArgs: [id]);
    });
    if (res > 0) {
      FirebaseSyncService.instance.deleteRecordFromCloud(
        tenBang,
        id.toString(),
      );
      TuitionEventService().notifyTuitionChanged();
      StudentEventService().notifyStudentDeleted(id);
    }
    return res;
  }

  Future<int> capNhatSoBuoiDu(int idHocSinh, int soBuoiMoi) async {
    try {
      final db = await dbHelper.database;
      final res = await db.update(
        tenBang,
        {'so_buoi_du': soBuoiMoi},
        where: 'id = ?',
        whereArgs: [idHocSinh],
      );
      if (res > 0) {
        FirebaseSyncService.instance.pushRecordToCloud(
          tenBang,
          idHocSinh.toString(),
          {'id': idHocSinh, 'so_buoi_du': soBuoiMoi},
        );
        TuitionEventService().notifyTuitionChanged();
      }
      return res;
    } catch (e) {
      developer.log(
        'Lỗi khi cập nhật số buổi dư',
        name: 'HocSinhService',
        error: e,
      );
      return 0;
    }
  }
}
