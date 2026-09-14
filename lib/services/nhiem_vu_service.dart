// File: lib/services/nhiem_vu_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/nhiem_vu.dart';
import '../utils/db.dart';
import 'firebase_sync_service.dart';

class NhiemVuService {
  final String _tenBang = DBHelper.tenBangNhiemVu;
  final String _tenBangNVHS = DBHelper.tenBangNhiemVuHocSinh;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  // Thêm nhiệm vụ mới
  Future<NhiemVu> themNhiemVu(NhiemVu nhiemVu) async {
    final db = await _database;
    final id = await db.insert(
      _tenBang,
      nhiemVu.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final created = nhiemVu.copyWith(id: id);
    FirebaseSyncService.instance
        .pushRecordToCloud(_tenBang, id.toString(), created.toMap())
        .catchError((e) => null);
    return created;
  }

  // Lấy danh sách nhiệm vụ theo lớp
  Future<List<NhiemVu>> layNhiemVuTheoLop(int idLop) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'id_lop = ?',
      whereArgs: [idLop],
      orderBy: 'ngay_nop DESC', // Sắp xếp theo ngày nộp gần nhất
    );

    final List<NhiemVu> result = [];
    for (var map in maps) {
      final nhiemVu = NhiemVu.fromMap(map);
      final trangThaiMaps = await db.query(
        _tenBangNVHS,
        where: 'id_nhiem_vu = ?',
        whereArgs: [nhiemVu.id],
      );
      final trangThaiHocSinh = {
        for (var item in trangThaiMaps)
          item['id_hoc_sinh'] as int: item['trang_thai'] as String,
      };
      result.add(nhiemVu.copyWith(trangThaiHocSinh: trangThaiHocSinh));
    }
    return result;
  }

  // Cập nhật nhiệm vụ
  Future<int> capNhatNhiemVu(NhiemVu nhiemVu) async {
    final db = await _database;
    final result = await db.update(
      _tenBang,
      nhiemVu.toMap(),
      where: 'id = ?',
      whereArgs: [nhiemVu.id],
    );
    if (result > 0 && nhiemVu.id != null) {
      FirebaseSyncService.instance
          .pushRecordToCloud(_tenBang, nhiemVu.id.toString(), nhiemVu.toMap())
          .catchError((e) => null);
    }
    return result;
  }

  // Xóa nhiệm vụ
  Future<int> xoaNhiemVu(int id) async {
    final db = await _database;
    final result = await db.delete(_tenBang, where: 'id = ?', whereArgs: [id]);
    if (result > 0) {
      FirebaseSyncService.instance
          .deleteRecordFromCloud(_tenBang, id.toString())
          .catchError((e) => null);
    }
    return result;
  }

  // Cập nhật trạng thái nhiệm vụ
  Future<int> capNhatTrangThai(
    int idNhiemVu,
    int idHocSinh,
    String trangThai,
  ) async {
    final db = await _database;
    final data = {
      'id_nhiem_vu': idNhiemVu,
      'id_hoc_sinh': idHocSinh,
      'trang_thai': trangThai,
    };
    final result = await db.insert(
      _tenBangNVHS,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (result > 0) {
      FirebaseSyncService.instance
          .pushRecordToCloud(_tenBangNVHS, '${idNhiemVu}_$idHocSinh', data)
          .catchError((e) => null);
    }
    return result;
  }

  // Lấy danh sách nhiệm vụ đã quá hạn của một lớp
  Future<List<NhiemVu>> layNhiemVuQuaHanCuaLop(int idLop) async {
    final db = await _database;
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'id_lop = ? AND ngay_nop < ?',
      whereArgs: [idLop, today],
    );

    final List<NhiemVu> result = [];
    for (var map in maps) {
      final nhiemVu = NhiemVu.fromMap(map);
      final trangThaiMaps = await db.query(
        _tenBangNVHS,
        where: 'id_nhiem_vu = ?',
        whereArgs: [nhiemVu.id],
      );
      final trangThaiHocSinh = {
        for (var item in trangThaiMaps)
          item['id_hoc_sinh'] as int: item['trang_thai'] as String,
      };
      result.add(nhiemVu.copyWith(trangThaiHocSinh: trangThaiHocSinh));
    }
    return result;
  }
}
