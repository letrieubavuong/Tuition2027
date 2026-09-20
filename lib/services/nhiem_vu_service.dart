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

  // Helper batch prefetch trạng thái học sinh của danh sách nhiệm vụ (1 Query duy nhất)
  Future<List<NhiemVu>> _populateNhiemVuList(
    Database db,
    List<Map<String, dynamic>> nvMaps,
  ) async {
    if (nvMaps.isEmpty) return [];

    final nvIds = nvMaps.map((m) => (m['id'] as num).toInt()).toList();
    final placeholders = List.filled(nvIds.length, '?').join(',');

    final List<Map<String, dynamic>> statusMaps = await db.rawQuery(
      'SELECT id_nhiem_vu, id_hoc_sinh, trang_thai FROM $_tenBangNVHS WHERE id_nhiem_vu IN ($placeholders)',
      nvIds,
    );

    final Map<int, Map<int, String>> nvStatusMap = {};
    for (var row in statusMaps) {
      final nvId = (row['id_nhiem_vu'] as num).toInt();
      final hsId = (row['id_hoc_sinh'] as num).toInt();
      final st = row['trang_thai'] as String;
      nvStatusMap.putIfAbsent(nvId, () => {})[hsId] = st;
    }

    return nvMaps.map((map) {
      final nhiemVu = NhiemVu.fromMap(map);
      final statusMap = nvStatusMap[nhiemVu.id] ?? {};
      return nhiemVu.copyWith(trangThaiHocSinh: statusMap);
    }).toList();
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

    return _populateNhiemVuList(db, maps);
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

  // Lấy danh sách nhiệm vụ đã quá hạn của một lớp (Tự động loại bỏ học sinh đã hoàn thành)
  Future<List<NhiemVu>> layNhiemVuQuaHanCuaLop(int idLop) async {
    final db = await _database;
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'id_lop = ? AND ngay_nop < ?',
      whereArgs: [idLop, today],
    );

    final rawList = await _populateNhiemVuList(db, maps);
    // Tự động loại bỏ những học sinh đã hoàn thành nhiệm vụ ra khỏi danh sách báo quá hạn
    return rawList
        .map((nv) {
          final incompleteMap = Map<int, String>.from(nv.trangThaiHocSinh)
            ..removeWhere(
              (_, st) => st == 'Đã hoàn thành' || st == 'DA_HOAN_THANH',
            );
          return nv.copyWith(trangThaiHocSinh: incompleteMap);
        })
        .where((nv) => nv.trangThaiHocSinh.isNotEmpty)
        .toList();
  }
}
