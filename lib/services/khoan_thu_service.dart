import 'package:sqflite/sqflite.dart';

import '../models/khoan_thu.dart';
import '../utils/db.dart';

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
    final end = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    return db.transaction((txn) async {
      final id = await txn.insert(DBHelper.tenBangKhoanThu, {
        'id_lop': idLop,
        'thang': thang,
        'ten_khoan_thu': ten,
        'so_tien': soTien,
        'han_thu': hanThu,
        'ghi_chu': ghiChu,
        'created_at': DateTime.now().toIso8601String(),
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
          'id_khoan_thu': id,
          'id_hoc_sinh': student['id_hoc_sinh'],
          'so_tien_da_dong': 0,
        });
      }
      await batch.commit(noResult: true);
      return id;
    });
  }

  Future<List<KhoanThu>> layKhoanThu(int idLop, String thang) async {
    final db = await _db;
    final charges = await db.query(
      DBHelper.tenBangKhoanThu,
      where: 'id_lop = ? AND thang = ?',
      whereArgs: [idLop, thang],
      orderBy: 'created_at DESC',
    );
    final result = <KhoanThu>[];
    for (final charge in charges) {
      final students = await db.rawQuery('''
        SELECT KTHS.*, HS.ten, HS.sdt
        FROM ${DBHelper.tenBangKhoanThuHocSinh} KTHS
        JOIN ${DBHelper.tenBangHS} HS ON HS.id = KTHS.id_hoc_sinh
        WHERE KTHS.id_khoan_thu = ?
        ORDER BY HS.ten
      ''', [charge['id']]);
      result.add(KhoanThu(
        id: charge['id'] as int,
        idLop: charge['id_lop'] as int,
        thang: charge['thang'] as String,
        ten: charge['ten_khoan_thu'] as String,
        soTien: charge['so_tien'] as int,
        hanThu: charge['han_thu'] as String?,
        ghiChu: charge['ghi_chu'] as String?,
        hocSinhs: students.map((row) => KhoanThuHocSinh(
          idHocSinh: row['id_hoc_sinh'] as int,
          tenHocSinh: row['ten'] as String,
          sdt: row['sdt'] as String?,
          daDong: row['so_tien_da_dong'] as int? ?? 0,
          ngayThanhToan: row['ngay_thanh_toan'] as String?,
        )).toList(),
      ));
    }
    return result;
  }

  Future<Map<String, int>> layTongHop(int idLop, String thang) async {
    final charges = await layKhoanThu(idLop, thang);
    return {
      'phaiThu': charges.fold(0, (sum, item) => sum + item.tongPhaiThu),
      'daThu': charges.fold(0, (sum, item) => sum + item.tongDaThu),
      'conNo': charges.fold(0, (sum, item) => sum + item.tongConNo),
    };
  }

  Future<void> capNhatThanhToan({
    required int idKhoanThu,
    required int idHocSinh,
    required int soTienDaDong,
    String? ghiChu,
  }) async {
    final db = await _db;
    await db.update(
      DBHelper.tenBangKhoanThuHocSinh,
      {
        'so_tien_da_dong': soTienDaDong,
        'ngay_thanh_toan': DateTime.now().toIso8601String(),
        'ghi_chu': ghiChu,
      },
      where: 'id_khoan_thu = ? AND id_hoc_sinh = ?',
      whereArgs: [idKhoanThu, idHocSinh],
    );
  }

  Future<int> xoaKhoanThu(int idKhoanThu) async {
    final db = await _db;
    return db.delete(
      DBHelper.tenBangKhoanThu,
      where: 'id = ?',
      whereArgs: [idKhoanThu],
    );
  }
}
