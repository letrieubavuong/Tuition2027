// File: lib/services/hoc_sinh_service.dart (CẬP NHẬT)

import 'dart:developer' as developer;

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../models/hs.dart'; // Sử dụng model HS mới
import 'firebase_sync_service.dart';
import 'tuition_event_service.dart';

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
    FirebaseSyncService.instance.pushRecordToCloud(tenBang, id.toString(), savedHs.toMap());
    TuitionEventService().notifyTuitionChanged();
    return savedHs;
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
    final res = await db.update(
      tenBang,
      hs.toMap(),
      where: 'id = ?',
      whereArgs: [hs.id],
    );
    if (res > 0 && hs.id != null) {
      FirebaseSyncService.instance.pushRecordToCloud(tenBang, hs.id.toString(), hs.toMap());
      TuitionEventService().notifyTuitionChanged();
    }
    return res;
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

  Future<int> xoaHocSinh(int id) async {
    final db = await dbHelper.database;
    // Sử dụng transaction để đảm bảo tính toàn vẹn
    final res = await db.transaction((txn) async {
      // ON DELETE CASCADE sẽ tự động xóa các bản ghi liên quan trong
      // lop_hoc_sinh, diem_danh, thanh_toan, lich_hoc_ca_nhan, nhiem_vu_hoc_sinh
      return await txn.delete(tenBang, where: 'id = ?', whereArgs: [id]);
    });
    if (res > 0) {
      FirebaseSyncService.instance.deleteRecordFromCloud(tenBang, id.toString());
      TuitionEventService().notifyTuitionChanged();
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
        final hs = await docHocSinhTheoId(idHocSinh);
        if (hs != null) {
          FirebaseSyncService.instance.pushRecordToCloud(tenBang, idHocSinh.toString(), hs.toMap());
        }
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
