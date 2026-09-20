// File: lib/services/thanh_toan_service.dart

import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../models/lich_su_thanh_toan_view_model.dart';
import 'firebase_sync_service.dart';
import 'student_signal_service.dart';
import 'tuition_event_service.dart';

class ThanhToanService {
  final String tenBangThanhToan = DBHelper.tenBangThanhToan;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  /// Cập nhật số tiền đã đóng nguyên tố (Atomic) với ghi nhận transaction theo DELTA thực tế
  Future<void> capNhatSoTienDaDong(
    int idHocSinh,
    int idLop,
    String thang,
    int soTienDaDongMoi,
    String? ghiChu, {
    DateTime? ngayThanhToan,
  }) async {
    final db = await _database;
    final nowStr = (ngayThanhToan ?? DateTime.now()).toIso8601String();

    await db.transaction((txn) async {
      // 1. Đọc bản ghi thanh_toan hiện tại để xác định oldPaid
      var ttRows = await txn.query(
        tenBangThanhToan,
        where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
        whereArgs: [idHocSinh, idLop, thang],
      );

      if (ttRows.isEmpty) {
        await txn.insert(tenBangThanhToan, {
          'id_hoc_sinh': idHocSinh,
          'id_lop': idLop,
          'thang': thang,
          'tong_so_buoi': 0,
          'tong_thanh_toan': 0,
          'so_tien_da_dong': 0,
        });
        ttRows = await txn.query(
          tenBangThanhToan,
          where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
          whereArgs: [idHocSinh, idLop, thang],
        );
      }

      final existingRow = ttRows.first;
      final ttId = existingRow['id'] as int;
      final oldPaid = (existingRow['so_tien_da_dong'] as int?) ?? 0;

      // 2. Tính delta thực sự phát sinh
      final int delta = soTienDaDongMoi - oldPaid;

      final String? ngayThanhToanStr = soTienDaDongMoi > 0
          ? (ngayThanhToan ?? DateTime.now()).toIso8601String()
          : null;

      // 3. Cập nhật bảng thanh_toan
      await txn.update(
        tenBangThanhToan,
        {
          'so_tien_da_dong': soTienDaDongMoi,
          'ghi_chu_thanh_toan': ghiChu,
          'ngay_thanh_toan': ngayThanhToanStr,
        },
        where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
        whereArgs: [idHocSinh, idLop, thang],
      );

      // 4. Nếu có phát sinh chênh lệch (delta != 0), ghi nhận giao dịch vào payment_transactions với delta
      if (delta != 0) {
        final txId =
            'MANUAL_${idHocSinh}_${idLop}_${DateTime.now().millisecondsSinceEpoch}';
        final matchMethod = delta > 0 ? 'MANUAL' : 'MANUAL_REVERSAL';
        final defaultContent = delta > 0
            ? 'Thu bổ sung học phí'
            : 'Điều chỉnh giảm/hoàn học phí';

        await txn.insert('payment_transactions', {
          'hoc_sinh_id': idHocSinh,
          'lop_id': idLop,
          'month': thang,
          'amount': delta, // Delta thực sự phát sinh, KHÔNG ghi soTienDaDongMoi
          'status': 'CONFIRMED', // Standardized canonical status
          'transaction_id': txId,
          'created_at': nowStr,
          'updated_at': nowStr,
          'bank_code': 'MANUAL',
          'raw_content': ghiChu ?? defaultContent,
          'match_method': matchMethod,
          'linked_payment_id': ttId,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });

    // 5. Post-commit notification và sync
    try {
      final rows = await db.query(
        tenBangThanhToan,
        where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
        whereArgs: [idHocSinh, idLop, thang],
      );
      if (rows.isNotEmpty) {
        FirebaseSyncService.instance.pushRecordToCloud(
          tenBangThanhToan,
          '${idHocSinh}_${idLop}_$thang',
          rows.first,
        );
      }
    } catch (e) {
      developer.log(
        'Lỗi sync cloud sau khi cập nhật học phí: $e',
        name: 'ThanhToanService',
      );
    }

    TuitionEventService().notifyTuitionChanged();
    await StudentSignalService.instance.recomputeSignalsForStudent(idHocSinh);
  }

  // ===================================================
  // LẤY LỊCH SỬ THANH TOÁN CỦA HỌC SINH
  // ===================================================
  Future<List<LichSuThanhToanViewModel>> layLichSuThanhToan(
    int idHocSinh,
  ) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
        SELECT 
            L.ten as tenLop, 
            TT.thang, 
            TT.so_tien_da_dong, 
            TT.ngay_thanh_toan, 
            TT.ghi_chu_thanh_toan
        FROM $tenBangThanhToan TT
        JOIN ${DBHelper.tenBangLop} L ON TT.id_lop = L.id
        WHERE TT.id_hoc_sinh = ? AND TT.so_tien_da_dong > 0
        ORDER BY TT.ngay_thanh_toan DESC, TT.thang DESC
    ''',
      [idHocSinh],
    );

    return maps.map((map) {
      return LichSuThanhToanViewModel(
        tenLop: map['tenLop'] as String,
        thang: map['thang'] as String,
        soTienDaDong: map['so_tien_da_dong'] as int,
        ngayThanhToan: map['ngay_thanh_toan'] as String?,
        ghiChu: map['ghi_chu_thanh_toan'] as String?,
      );
    }).toList();
  }

  Future<int> suaLichSuThanhToan({
    required int idHocSinh,
    required int idLop,
    required String thang,
    required int soTienDaDong,
    required DateTime ngayThanhToan,
    String? ghiChu,
  }) async {
    await capNhatSoTienDaDong(
      idHocSinh,
      idLop,
      thang,
      soTienDaDong,
      ghiChu,
      ngayThanhToan: ngayThanhToan,
    );
    return 1;
  }

  Future<int> xoaLichSuThanhToan({
    required int idHocSinh,
    required int idLop,
    required String thang,
  }) async {
    await capNhatSoTienDaDong(
      idHocSinh,
      idLop,
      thang,
      0,
      'Xóa/Hoàn tác thanh toán',
    );
    return 1;
  }

  /// Lấy danh sách ID các học sinh còn nợ học phí trong hệ thống (tong_thanh_toan > so_tien_da_dong)
  Future<Set<int>> layDanhSachHocSinhConNo() async {
    try {
      final db = await _database;
      final debtRows = await db.rawQuery('''
        SELECT DISTINCT id_hoc_sinh 
        FROM $tenBangThanhToan 
        WHERE (COALESCE(tong_thanh_toan, 0) - COALESCE(so_tien_da_dong, 0)) > 0
        ''');
      return debtRows
          .map((r) => r['id_hoc_sinh'])
          .whereType<num>()
          .map((n) => n.toInt())
          .toSet();
    } catch (e, st) {
      developer.log(
        'Lỗi lấy danh sách học sinh nợ học phí: $e',
        name: 'ThanhToanService',
        error: e,
        stackTrace: st,
      );
      return {};
    }
  }
}
