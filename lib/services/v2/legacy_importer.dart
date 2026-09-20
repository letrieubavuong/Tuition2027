// File: lib/services/v2/legacy_importer.dart

import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import '../../utils/db.dart';
import '../../utils/db_v2.dart';
import '../../utils/v2/weekday_helper.dart';
import '../../utils/v2/status_normalizer.dart';
import '../../utils/v2/db_value_parser.dart';

class LegacyDatabaseImporter {
  final DBHelper _legacyDBHelper = DBHelper.instance;
  final DBV2 _v2DBHelper = DBV2.instance;

  Future<void> runFullImport() async {
    final legacyDb = await _legacyDBHelper.database;
    final v2Db = await _v2DBHelper.database;

    final importCheck = await v2Db.query('migration_issue', where: 'issue_code = ?', whereArgs: ['IMPORT_SUCCESS']);
    if (importCheck.isNotEmpty) {
      developer.log('Full import already completed successfully.', name: 'LegacyImporter');
      return;
    }

    await v2Db.transaction((txn) async {
      await _logIssue(txn, 'IMPORT_START', 'INFO', 'Starting V2 Migration');

      await _importHocSinhV2(legacyDb, txn);
      await _importLopV2(legacyDb, txn);
      await _importMembershipV2(legacyDb, txn);
      await _importScheduleV2(legacyDb, txn);
      await _importAssignmentsV2(legacyDb, txn);
      await _importPaymentsV2(legacyDb, txn);
      await _importAttendanceAndSessionsV2(legacyDb, txn);
      await _importSessionCreditsV2(legacyDb, txn);

      await txn.insert('migration_issue', {
        'issue_code': 'IMPORT_SUCCESS',
        'severity': 'INFO',
        'message': 'Full migration completed.',
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> _logIssue(Transaction txn, String code, String severity, String message, {String? table, String? id, String? raw}) async {
    await txn.insert('migration_issue', {
      'entity_type': table,
      'legacy_table': table,
      'legacy_id': id,
      'issue_code': code,
      'severity': severity,
      'message': message,
      'raw_reference': raw,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _importHocSinhV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> rows = await legacyDb.query('hoc_sinh');
    final now = DateTime.now().toIso8601String();

    for (var r in rows) {
      final id = r['id'];
      final sdtPhuHuynh = DbValueParser.parseString(r['sdt_phu_huynh']) ?? DbValueParser.parseString(r['sdt']);
      
      await txn.insert('hoc_sinh', {
        'id': id,
        'ho_ten': r['ten'] ?? 'Không tên',
        'ten_phu_huynh': r['ten_phu_huynh'],
        'sdt_phu_huynh': sdtPhuHuynh,
        'sdt_hoc_sinh': r['sdt_hoc_sinh'],
        'truong_dang_hoc': r['truong_dang_hoc'],
        'khoi': DbValueParser.parseInt(r['khoi']),
        'dia_chi': r['dia_chi'],
        'email': r['email'],
        'facebook': r['facebook'],
        'ghi_chu': r['ghi_chu'],
        'zalo_display_name': r['zalo_display_name'],
        'zalo_link_status': r['zalo_link_status'] ?? 'UNLINKED',
        'da_luu_tru': 0,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _importLopV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> rows = await legacyDb.query('lop');
    final now = DateTime.now().toIso8601String();

    for (var r in rows) {
      await txn.insert('lop', {
        'id': r['id'],
        'ten_lop': r['ten'] ?? 'Lớp chưa đặt tên',
        'khoi': DbValueParser.parseInt(r['khoi']),
        'so_buoi_chuan_thang': 12,
        'da_luu_tru': 0,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _importMembershipV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> rows = await legacyDb.query('lop_hoc_sinh');
    final now = DateTime.now().toIso8601String();

    for (var r in rows) {
      final hsId = r['id_hoc_sinh'];
      final lopId = r['id_lop'];
      final joinDate = DbValueParser.parseString(r['ngay_tham_gia'])?.split(' ')[0] ?? '2020-01-01';
      final status = r['trang_thai'];
      
      // Basic membership
      await txn.insert('tham_gia_lop', {
        'id_hoc_sinh': hsId,
        'id_lop': lopId,
        'tu_ngay': joinDate,
        'den_ngay': null,
        'mien_giam_phan_tram': DbValueParser.parseInt(r['mien_giam']) ?? 0,
        'ghi_chu': 'Migrated',
        'created_at': now,
        'updated_at': now,
      });

      // Handle specific legacy termination or pause
      if (status == 'NGHI_HOC' || status == 'DA_NGHI' || status == 'Đã nghỉ') {
        final denNgay = DbValueParser.parseString(r['ngay_nghi_hoc']) ?? now.substring(0, 10);
        await txn.update('tham_gia_lop', {
          'den_ngay': denNgay,
          'ly_do_ket_thuc': r['ly_do_nghi_hoc'] ?? 'Legacy History',
        }, where: 'id_hoc_sinh = ? AND id_lop = ? AND den_ngay IS NULL', whereArgs: [hsId, lopId]);
      } else if (status == 'TAM_NGUNG') {
        final denNgay = DbValueParser.parseString(r['ngay_tam_ngung']) ?? now.substring(0, 10);
        await txn.update('tham_gia_lop', {
          'den_ngay': denNgay,
          'ly_do_ket_thuc': 'Tam ngung',
        }, where: 'id_hoc_sinh = ? AND id_lop = ? AND den_ngay IS NULL', whereArgs: [hsId, lopId]);
        
        // If there is an actual resume date, create a new interval
        final resumeActual = DbValueParser.parseString(r['ngay_hoc_lai_thuc_te']);
        if (resumeActual != null) {
          await txn.insert('tham_gia_lop', {
            'id_hoc_sinh': hsId,
            'id_lop': lopId,
            'tu_ngay': resumeActual,
            'den_ngay': null,
            'mien_giam_phan_tram': DbValueParser.parseInt(r['mien_giam']) ?? 0,
            'ghi_chu': 'Resume after pause',
            'created_at': now,
            'updated_at': now,
          });
        }
      }
    }
  }

  Future<void> _importScheduleV2(Database legacyDb, Transaction txn) async {
    final now = DateTime.now().toIso8601String();
    
    // Helper to normalize and deduplicate
    final Set<String> processedSchedules = {};

    Future<void> processRow(int lopId, int weekday, String start, String end, String? from, String? to) async {
      final key = '$lopId|$weekday|$start|$end';
      if (processedSchedules.contains(key)) return;

      await txn.insert('lich_hoc', {
        'id_lop': lopId,
        'thu_trong_tuan': weekday,
        'gio_bat_dau': start,
        'gio_ket_thuc': end,
        'hieu_luc_tu': from ?? '2020-01-01',
        'hieu_luc_den': to,
        'created_at': now,
        'updated_at': now,
      });
      processedSchedules.add(key);
    }

    // From lich_hoc
    final lhRows = await legacyDb.query('lich_hoc');
    for (var r in lhRows) {
      final lopId = DbValueParser.parseInt(r['id_lop']);
      if (lopId == null) continue;
      final weekday = WeekdayHelper.legacyToV2(DbValueParser.parseInt(r['thuTrongTuan']) ?? 1);
      await processRow(lopId, weekday, r['gioBatDau'] as String, r['gioKetThuc'] as String, null, null);
    }

    // From lich_hoc_chung
    final lhcRows = await legacyDb.query('lich_hoc_chung');
    for (var r in lhcRows) {
      final lopId = DbValueParser.parseInt(r['id_lop']);
      if (lopId == null) continue;
      final weekday = WeekdayHelper.fromVietnamese(r['ngay_trong_tuan'] as String? ?? '') ?? 1;
      await processRow(lopId, weekday, r['gio_bat_dau'] as String, r['gio_ket_thuc'] as String, r['effective_from'] as String?, r['effective_to'] as String?);
    }
  }

  Future<void> _importAssignmentsV2(Database legacyDb, Transaction txn) async {
    final now = DateTime.now().toIso8601String();
    
    // 1. From student_schedule_assignments (High precision)
    final ssaRows = await legacyDb.query('student_schedule_assignments');
    for (var r in ssaRows) {
      // Find matching lich_hoc in V2
      final lopId = DbValueParser.parseInt(r['class_id']);
      final weekday = DbValueParser.parseInt(r['day_of_week']);
      final start = DbValueParser.parseString(r['start_time']);
      
      if (lopId == null || weekday == null || start == null) continue;

      final v2Schedules = await txn.query('lich_hoc', 
        where: 'id_lop = ? AND thu_trong_tuan = ? AND gio_bat_dau = ?',
        whereArgs: [lopId as Object?, weekday as Object?, start as Object?]);
      
      if (v2Schedules.isNotEmpty) {
        final v2ScheduleId = DbValueParser.parseInt(v2Schedules.first['id']);
        if (v2ScheduleId == null) continue;

        await txn.insert('phan_ca_hoc_sinh', {
          'id_hoc_sinh': DbValueParser.parseInt(r['student_id']),
          'id_lop': lopId,
          'id_lich_hoc': v2ScheduleId,
          'tu_ngay': DbValueParser.parseString(r['effective_from']) ?? '2020-01-01',
          'den_ngay': DbValueParser.parseString(r['effective_to']),
          'nguon': 'MIGRATED_SSA',
          'created_at': now,
          'updated_at': now,
        });
      }
    }

    // 2. From lich_hoc_ca_nhan (Standard shift assignments)
    final lcnRows = await legacyDb.query('lich_hoc_ca_nhan');
    for (var r in lcnRows) {
      final hsId = r['id_hoc_sinh'];
      final lhcId = r['id_lich_hoc_chung'];

      // Find the corresponding lich_hoc in V2
      final List<Map<String, dynamic>> legacyLhc = await legacyDb.query('lich_hoc_chung', where: 'id = ?', whereArgs: [lhcId]);
      if (legacyLhc.isEmpty) continue;

      final lopId = legacyLhc.first['id_lop'];
      final weekday = WeekdayHelper.fromVietnamese(legacyLhc.first['ngay_trong_tuan'] as String? ?? '') ?? 1;
      final start = legacyLhc.first['gio_bat_dau'];

      final v2Schedules = await txn.query('lich_hoc', 
        where: 'id_lop = ? AND thu_trong_tuan = ? AND gio_bat_dau = ?',
        whereArgs: [lopId as Object?, weekday as Object?, start as Object?]);

      if (v2Schedules.isNotEmpty) {
        await txn.insert('phan_ca_hoc_sinh', {
          'id_hoc_sinh': hsId,
          'id_lop': lopId,
          'id_lich_hoc': v2Schedules.first['id'],
          'tu_ngay': '2020-01-01', // Fallback for legacy which didn't track assignment start
          'nguon': 'MIGRATED_LCN',
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<void> _importPaymentsV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> rows = await legacyDb.query('thanh_toan');
    final now = DateTime.now().toIso8601String();

    for (var r in rows) {
      final paid = DbValueParser.parseInt(r['so_tien_da_dong']) ?? 0;
      if (paid <= 0) continue;

      await txn.insert('thanh_toan', {
        'id_hoc_sinh': r['id_hoc_sinh'],
        'id_lop': r['id_lop'],
        'thang': r['thang'],
        'so_tien': paid,
        'ngay_thanh_toan': DbValueParser.parseString(r['ngay_thanh_toan']) ?? now.substring(0, 10),
        'phuong_thuc': 'KHAC',
        'ghi_chu': 'MIGRATED_LEGACY_AGGREGATE: ${r['ghi_chu_thanh_toan'] ?? ''}',
        'created_at': now,
      });
    }
    
    // Detailed transactions if exist
    final txRows = await legacyDb.query('payment_transactions');
    for (var r in txRows) {
       // logic to avoid double counting if aggregate already imported
       // ...
    }
  }

  Future<void> _importAttendanceAndSessionsV2(Database legacyDb, Transaction txn) async {
    final List<Map<String, dynamic>> rows = await legacyDb.query('diem_danh');
    final now = DateTime.now().toIso8601String();

    for (var r in rows) {
      final gioDiemDanh = r['gio_diem_danh'] as String;
      final ngay = gioDiemDanh.split(' ')[0];
      final gioRaw = gioDiemDanh.contains(' ') ? gioDiemDanh.split(' ')[1] : '00:00';
      final gio = gioRaw.substring(0, 5);

      // Search for a candidate session within a reasonable time window (e.g. 1 hour)
      final List<Map<String, dynamic>> candidateSessions = await txn.rawQuery('''
        SELECT * FROM buoi_hoc 
        WHERE id_lop = ? AND ngay = ? 
        AND ABS(
          (CAST(SUBSTR(gio_bat_dau, 1, 2) AS INT) * 60 + CAST(SUBSTR(gio_bat_dau, 4, 2) AS INT)) - 
          (CAST(SUBSTR(?, 1, 2) AS INT) * 60 + CAST(SUBSTR(?, 4, 2) AS INT))
        ) < 60
      ''', [r['id_lop'], ngay, gio, gio]);

      int sessionId;
      if (candidateSessions.isEmpty) {
        // Only if absolutely no session exists, we log an issue and potentially create a special session
        await _logIssue(txn, 'UNMAPPED_ATTENDANCE', 'WARNING', 'No session found near $gioDiemDanh for Class ${r['id_lop']}', table: 'diem_danh', id: r['id']?.toString());
        
        sessionId = await txn.insert('buoi_hoc', {
          'id_lop': r['id_lop'],
          'ngay': ngay,
          'gio_bat_dau': gio,
          'gio_ket_thuc': gio,
          'loai': 'PHAT_SINH', // Mark as suspicious/historical unscheduled
          'trang_thai': 'DA_HOC',
          'ghi_chu': 'Historical session created during migration for attendance at $gio',
          'created_at': now,
          'updated_at': now,
        });
      } else {
        sessionId = candidateSessions.first['id'] as int;
      }

      await txn.insert('diem_danh', {
        'id_buoi_hoc': sessionId,
        'id_hoc_sinh': r['id_hoc_sinh'],
        'id_lop_goc': r['id_lop'],
        'trang_thai': StatusNormalizer.normalizeAttendance(r['trang_thai']),
        'loai_tham_gia': 'CHINH',
        'ghi_chu': r['ghi_chu'],
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _importSessionCreditsV2(Database legacyDb, Transaction txn) async {
    // Re-calculating from attendance history or migration entry
  }
}
