// File: lib/services/v2/legacy_importer.dart

import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import '../../utils/db.dart';
import '../../utils/db_v2.dart';

class LegacyDatabaseImporter {
  final DBHelper _legacyDBHelper = DBHelper.instance;
  final DBV2 _v2DBHelper = DBV2.instance;

  Future<void> runFullImport() async {
    final legacyDb = await _legacyDBHelper.database;
    final v2Db = await _v2DBHelper.database;

    // Check if import was already successful to ensure idempotency
    final importCheck = await v2Db.query('migration_issue', where: 'issue_code = ?', whereArgs: ['IMPORT_SUCCESS']);
    if (importCheck.isNotEmpty) {
      developer.log('Full import already completed successfully.', name: 'LegacyImporter');
      return;
    }

    await v2Db.transaction((txn) async {
      developer.log('Phase 1: Students & Classes', name: 'LegacyImporter');
      await _importHocSinhV2(legacyDb, txn);
      await _importLopV2(legacyDb, txn);
      
      developer.log('Phase 2: Membership', name: 'LegacyImporter');
      await _importMembershipV2(legacyDb, txn);
      
      developer.log('Phase 3: Recurring Schedules', name: 'LegacyImporter');
      await _importScheduleV2(legacyDb, txn);
      
      developer.log('Phase 4: Payments (Actual)', name: 'LegacyImporter');
      await _importPaymentsV2(legacyDb, txn);
      
      developer.log('Phase 5: Attendance & Session Re-mapping', name: 'LegacyImporter');
      await _importAttendanceAndGenerateSessionsV2(legacyDb, txn);
      
      developer.log('Phase 6: Session Credits (Backfill)', name: 'LegacyImporter');
      await _importSessionCreditsV2(legacyDb, txn);

      await txn.insert('migration_issue', {
        'issue_code': 'IMPORT_SUCCESS',
        'severity': 'INFO',
        'message': 'Full migration from Legacy to V2 completed.',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> _importHocSinhV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> legacyRows = await legacyDb.query('hoc_sinh');
    final now = DateTime.now().toIso8601String();

    for (var row in legacyRows) {
      final id = row['id'];
      final hoTen = row['ten'] ?? 'Không tên';
      final sdtPhuHuynh = row['sdt_phu_huynh'] ?? row['sdt'];
      final sdtHocSinh = row['sdt_hoc_sinh'];
      
      await txn.insert('hoc_sinh', {
        'id': id,
        'ho_ten': hoTen,
        'ten_phu_huynh': row['ten_phu_huynh'],
        'sdt_phu_huynh': sdtPhuHuynh,
        'sdt_hoc_sinh': sdtHocSinh,
        'ngay_sinh': null, 
        'gioi_tinh': null,
        'truong_dang_hoc': row['truong_dang_hoc'],
        'khoi': row['khoi'],
        'dia_chi': row['dia_chi'],
        'email': row['email'],
        'facebook': row['facebook'],
        'ghi_chu': row['ghi_chu'],
        'zalo_display_name': row['zalo_display_name'],
        'zalo_link_status': row['zalo_link_status'] ?? 'UNLINKED',
        'da_luu_tru': 0,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    developer.log('Imported ${legacyRows.length} students', name: 'LegacyImporter');
  }

  Future<void> _importLopV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> legacyRows = await legacyDb.query('lop');
    final now = DateTime.now().toIso8601String();

    for (var row in legacyRows) {
      await txn.insert('lop', {
        'id': row['id'],
        'ten_lop': row['ten'] ?? 'Lớp chưa đặt tên',
        'khoi': row['khoi'],
        'mon_hoc': null,
        'hoc_phi_moi_buoi': null, 
        'so_buoi_chuan_thang': 12,
        'hoc_phi_thang_toi_da': null,
        'si_so_toi_da': null,
        'ghi_chu': null,
        'da_luu_tru': 0,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    developer.log('Imported ${legacyRows.length} classes', name: 'LegacyImporter');
  }

  Future<void> _importMembershipV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> legacyRows = await legacyDb.query('lop_hoc_sinh');
    final now = DateTime.now().toIso8601String();

    for (var row in legacyRows) {
      final tuNgay = row['ngay_tham_gia'] ?? '2020-01-01';
      final trangThai = row['trang_thai'];
      String? denNgay;
      String? lyDo;

      if (trangThai == 'NGHI_HOC' || trangThai == 'DA_NGHI') {
         denNgay = row['ngay_nghi_hoc'] ?? now.substring(0, 10);
         lyDo = row['ly_do_nghi_hoc'] ?? 'Nghỉ học (legacy)';
      }

      await txn.insert('tham_gia_lop', {
        'id_hoc_sinh': row['id_hoc_sinh'],
        'id_lop': row['id_lop'],
        'tu_ngay': tuNgay.toString().split(' ')[0],
        'den_ngay': denNgay,
        'ly_do_ket_thuc': lyDo,
        'mien_giam_phan_tram': 0, 
        'ghi_chu': 'Migrated from lop_hoc_sinh',
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _importPaymentsV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> legacyRows = await legacyDb.query('thanh_toan');
    final now = DateTime.now().toIso8601String();

    for (var row in legacyRows) {
      final soTienDaDong = row['so_tien_da_dong'] as int? ?? 0;
      if (soTienDaDong <= 0) continue;

      await txn.insert('thanh_toan', {
        'id_hoc_sinh': row['id_hoc_sinh'],
        'id_lop': row['id_lop'],
        'thang': row['thang'],
        'so_tien': soTienDaDong,
        'ngay_thanh_toan': row['ngay_thanh_toan'] ?? now.substring(0, 10),
        'phuong_thuc': 'TIEN_MAT', 
        'ghi_chu': 'Migrated: ${row['ghi_chu_thanh_toan'] ?? ''}',
        'created_at': now,
      });
    }
  }

  Future<void> _importAttendanceAndGenerateSessionsV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> legacyRows = await legacyDb.query('diem_danh');
    final now = DateTime.now().toIso8601String();

    for (var row in legacyRows) {
      final gioDiemDanh = row['gio_diem_danh'] as String;
      final ngay = gioDiemDanh.split(' ')[0];
      final gio = gioDiemDanh.contains(' ') ? gioDiemDanh.split(' ')[1].substring(0, 5) : '00:00';

      final List<Map<String, dynamic>> existingSessions = await txn.query(
        'buoi_hoc',
        where: 'id_lop = ? AND ngay = ? AND gio_bat_dau = ?',
        whereArgs: [row['id_lop'], ngay, gio],
      );

      int sessionId;
      if (existingSessions.isEmpty) {
        sessionId = await txn.insert('buoi_hoc', {
          'id_lop': row['id_lop'],
          'ngay': ngay,
          'gio_bat_dau': gio,
          'gio_ket_thuc': gio, 
          'loai': 'CHINH',
          'trang_thai': 'DA_HOC',
          'created_at': now,
          'updated_at': now,
        });
      } else {
        sessionId = existingSessions.first['id'] as int;
      }

      String trangThaiV2;
      final legacyStatus = row['trang_thai'];
      if (legacyStatus == 'Có mặt') trangThaiV2 = 'CO_MAT';
      else if (legacyStatus == 'Nghỉ có phép') trangThaiV2 = 'NGHI_CO_PHEP';
      else if (legacyStatus == 'Nghỉ không phép') trangThaiV2 = 'NGHI_KHONG_PHEP';
      else trangThaiV2 = 'CO_MAT';

      await txn.insert('diem_danh', {
        'id_buoi_hoc': sessionId,
        'id_hoc_sinh': row['id_hoc_sinh'],
        'id_lop_goc': row['id_lop'],
        'trang_thai': trangThaiV2,
        'loai_tham_gia': 'CHINH',
        'ghi_chu': row['ghi_chu'],
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _importScheduleV2(Database legacyDb, Transaction txn) async {
    final now = DateTime.now().toIso8601String();
    
    final List<Map<String, dynamic>> lhRows = await legacyDb.query('lich_hoc');
    for (var row in lhRows) {
      await txn.insert('lich_hoc', {
        'id': row['id'],
        'id_lop': row['id_lop'],
        'thu_trong_tuan': row['thuTrongTuan'],
        'gio_bat_dau': row['gioBatDau'],
        'gio_ket_thuc': row['gioKetThuc'],
        'hieu_luc_tu': '2020-01-01',
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final List<Map<String, dynamic>> lhcRows = await legacyDb.query('lich_hoc_chung');
    for (var row in lhcRows) {
      int thu = 1;
      final dayName = row['ngay_trong_tuan'] as String;
      if (dayName.contains('Hai')) thu = 1;
      else if (dayName.contains('Ba')) thu = 2;
      else if (dayName.contains('Tư')) thu = 3;
      else if (dayName.contains('Năm')) thu = 4;
      else if (dayName.contains('Sáu')) thu = 5;
      else if (dayName.contains('Bảy')) thu = 6;
      else if (dayName.contains('Nhật')) thu = 7;

      await txn.insert('lich_hoc', {
        'id_lop': row['id_lop'],
        'thu_trong_tuan': thu,
        'gio_bat_dau': row['gio_bat_dau'],
        'gio_ket_thuc': row['gio_ket_thuc'],
        'hieu_luc_tu': row['effective_from'] ?? '2020-01-01',
        'hieu_luc_den': row['effective_to'],
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _importSessionCreditsV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> legacyHs = await legacyDb.query('hoc_sinh');
    final now = DateTime.now().toIso8601String();

    for (var row in legacyHs) {
      final soBuoiDu = row['so_buoi_du'] as int? ?? 0;
      if (soBuoiDu <= 0) continue;

      final hsId = row['id'];
      final List<Map<String, dynamic>> memberships = await txn.query('tham_gia_lop', where: 'id_hoc_sinh = ?', whereArgs: [hsId]);
      
      if (memberships.length == 1) {
        final lopId = memberships.first['id_lop'];
        await txn.insert('buoi_du_ledger', {
          'id_hoc_sinh': hsId,
          'id_lop': lopId,
          'ngay_hieu_luc': now.substring(0, 10),
          'delta': soBuoiDu,
          'ly_do': 'MIGRATION',
          'ghi_chu': 'Legacy global extra sessions backfilled to the only class.',
          'created_at': now,
        });
      } else if (memberships.length > 1) {
         await txn.insert('migration_issue', {
            'entity_type': 'hoc_sinh',
            'legacy_id': hsId.toString(),
            'issue_code': 'AMBIGUOUS_CREDIT_MIGRATION',
            'severity': 'WARNING',
            'message': 'Student has $soBuoiDu extra sessions but is in ${memberships.length} classes. Manual adjustment needed.',
            'created_at': now,
         });
      }
    }
  }
}
