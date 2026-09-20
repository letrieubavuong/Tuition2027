import 'package:sqflite/sqflite.dart';
import 'dart:developer' as developer;
import '../models/khoan_thu.dart';
import '../utils/db.dart';
import 'firebase_sync_service.dart';

class KhoanThuService {
  Future<Database> get _db => DBHelper.instance.database;

  Future<int> taoKhoanThu({
    required int idLop,
    required String thang,
    required String ten,
    required int soTien,
    String? hanThu,
    String? ghiChu,
  }) async {
    final db = await _db;
    final parts = thang.split('-');
    final start = '$thang-01';
    final endDate = DateTime(int.parse(parts[0]), int.parse(parts[1]) + 1, 0);
    final end =
        '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    final createdAt = DateTime.now().toIso8601String();
    final id = await db.transaction((txn) async {
      final idInsert = await txn.insert(DBHelper.tenBangKhoanThu, {
        'id_lop': idLop,
        'thang': thang,
        'ten_khoan_thu': ten,
        'so_tien': soTien,
        'han_thu': hanThu,
        'ghi_chu': ghiChu,
        'created_at': createdAt,
      });
      final students = await txn.query(
        DBHelper.tenBangLopHS,
        columns: ['id_hoc_sinh'],
        where: '''id_lop = ? AND ngay_tham_gia <= ? AND (
          ngay_nghi_hoc IS NULL OR ngay_nghi_hoc > ? OR
          (ngay_hoc_lai_sau_nghi IS NOT NULL AND ngay_hoc_lai_sau_nghi <= ?)
        )''',
        whereArgs: [idLop, end, start, end],
      );
      final batch = txn.batch();
      for (final student in students) {
        batch.insert(DBHelper.tenBangKhoanThuHocSinh, {
          'id_khoan_thu': idInsert,
          'id_hoc_sinh': student['id_hoc_sinh'],
          'so_tien_da_dong': 0,
        });
      }
      await batch.commit(noResult: true);
      return idInsert;
    });

    if (id > 0) {
      FirebaseSyncService.instance
          .pushRecordToCloud(DBHelper.tenBangKhoanThu, id.toString(), {
            'id': id,
            'id_lop': idLop,
            'thang': thang,
            'ten_khoan_thu': ten,
            'so_tien': soTien,
            'han_thu': hanThu,
            'ghi_chu': ghiChu,
            'created_at': createdAt,
          })
          .catchError((e) => null);
    }
    return id;
  }

  Future<List<KhoanThu>> layKhoanThu(int idLop, String thang) async {
    final db = await _db;
    final charges = await db.query(
      DBHelper.tenBangKhoanThu,
      where: 'id_lop = ? AND thang = ?',
      whereArgs: [idLop, thang],
      orderBy: 'created_at DESC',
    );
    if (charges.isEmpty) return [];

    final chargeIds = charges.map((c) => c['id'] as int).toList();
    final placeholders = List.filled(chargeIds.length, '?').join(',');

    final allStudentsRows = await db.rawQuery('''
      SELECT KTHS.*, HS.ten, HS.sdt
      FROM ${DBHelper.tenBangKhoanThuHocSinh} KTHS
      JOIN ${DBHelper.tenBangHS} HS ON HS.id = KTHS.id_hoc_sinh
      WHERE KTHS.id_khoan_thu IN ($placeholders)
      ORDER BY HS.ten
    ''', chargeIds);

    final Map<int, List<KhoanThuHocSinh>> studentsMap = {};
    for (final row in allStudentsRows) {
      final ktId = row['id_khoan_thu'] as int;
      studentsMap
          .putIfAbsent(ktId, () => [])
          .add(
            KhoanThuHocSinh(
              idHocSinh: row['id_hoc_sinh'] as int,
              tenHocSinh: row['ten'] as String,
              sdt: row['sdt'] as String?,
              daDong: row['so_tien_da_dong'] as int? ?? 0,
              ngayThanhToan: row['ngay_thanh_toan'] as String?,
            ),
          );
    }

    return charges.map((charge) {
      final ktId = charge['id'] as int;
      return KhoanThu(
        id: ktId,
        idLop: charge['id_lop'] as int,
        thang: charge['thang'] as String,
        ten: charge['ten_khoan_thu'] as String,
        soTien: charge['so_tien'] as int,
        hanThu: charge['han_thu'] as String?,
        ghiChu: charge['ghi_chu'] as String?,
        hocSinhs: studentsMap[ktId] ?? [],
      );
    }).toList();
  }

  /// Tính tổng hợp khoản thu trực tiếp bằng 1 SQL Aggregate Query (không khởi tạo đối tượng thừa)
  Future<Map<String, int>> layTongHop(int idLop, String thang) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT 
        SUM(KT.so_tien) as phai_thu,
        SUM(KTHS.so_tien_da_dong) as da_thu
      FROM ${DBHelper.tenBangKhoanThu} KT
      JOIN ${DBHelper.tenBangKhoanThuHocSinh} KTHS ON KT.id = KTHS.id_khoan_thu
      WHERE KT.id_lop = ? AND KT.thang = ?
    ''',
      [idLop, thang],
    );

    if (rows.isEmpty) {
      return {'phaiThu': 0, 'daThu': 0, 'conNo': 0};
    }

    final phaiThu = (rows.first['phai_thu'] as num?)?.toInt() ?? 0;
    final daThu = (rows.first['da_thu'] as num?)?.toInt() ?? 0;
    int conNo = phaiThu - daThu;
    if (conNo < 0) conNo = 0;

    return {'phaiThu': phaiThu, 'daThu': daThu, 'conNo': conNo};
  }

  Future<void> capNhatThanhToan({
    required int idKhoanThu,
    required int idHocSinh,
    required int soTienDaDong,
    String? ghiChu,
  }) async {
    final db = await _db;
    final String? ngayThanhToan = soTienDaDong > 0
        ? DateTime.now().toIso8601String()
        : null;
    final affected = await db.update(
      DBHelper.tenBangKhoanThuHocSinh,
      {
        'so_tien_da_dong': soTienDaDong,
        'ngay_thanh_toan': ngayThanhToan,
        'ghi_chu': ghiChu,
      },
      where: 'id_khoan_thu = ? AND id_hoc_sinh = ?',
      whereArgs: [idKhoanThu, idHocSinh],
    );

    if (affected == 0) {
      developer.log(
        '⚠️ capNhatThanhToan: Không tìm thấy bản ghi phù hợp (idKhoanThu: $idKhoanThu, idHocSinh: $idHocSinh)',
        name: 'KhoanThuService',
      );
      return;
    }

    FirebaseSyncService.instance
        .pushRecordToCloud(
          DBHelper.tenBangKhoanThuHocSinh,
          '${idKhoanThu}_$idHocSinh',
          {
            'id_khoan_thu': idKhoanThu,
            'id_hoc_sinh': idHocSinh,
            'so_tien_da_dong': soTienDaDong,
            'ngay_thanh_toan': ngayThanhToan,
            'ghi_chu': ghiChu,
          },
        )
        .catchError((e) => null);
  }

  Future<int> xoaKhoanThu(int idKhoanThu) async {
    final db = await _db;
    int result = 0;

    await db.transaction((txn) async {
      // 1. Cascade cleanup bản ghi con trong khoan_thu_hoc_sinh (ngăn chặn orphan records)
      await txn.delete(
        DBHelper.tenBangKhoanThuHocSinh,
        where: 'id_khoan_thu = ?',
        whereArgs: [idKhoanThu],
      );

      // 2. Xóa bản ghi cha trong khoan_thu
      result = await txn.delete(
        DBHelper.tenBangKhoanThu,
        where: 'id = ?',
        whereArgs: [idKhoanThu],
      );
    });

    if (result > 0) {
      FirebaseSyncService.instance
          .deleteRecordFromCloud(
            DBHelper.tenBangKhoanThu,
            idKhoanThu.toString(),
          )
          .catchError((e) => null);
    }
    return result;
  }
}
