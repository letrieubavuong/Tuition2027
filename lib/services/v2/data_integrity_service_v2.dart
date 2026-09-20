// File: lib/services/v2/data_integrity_service_v2.dart

import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import '../../utils/db_v2.dart';

class DataIntegrityReport {
  final int totalErrors;
  final List<String> errorMessages;
  DataIntegrityReport(this.totalErrors, this.errorMessages);
}

class DataIntegrityServiceV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<DataIntegrityReport> runFullCheck() async {
    final db = await _dbHelper.database;
    final List<String> errors = [];

    // 1. Foreign Key Check
    final fkCheck = await db.rawQuery('PRAGMA foreign_key_check');
    if (fkCheck.isNotEmpty) {
      for (var entry in fkCheck) {
        errors.add('FK Violation: Table ${entry['table']} row ${entry['rowid']} links to missing parent in ${entry['parent']}');
      }
    }

    // 2. Orphan Checks
    await _checkOrphans(db, 'tham_gia_lop', 'id_hoc_sinh', 'hoc_sinh', errors);
    await _checkOrphans(db, 'tham_gia_lop', 'id_lop', 'lop', errors);
    await _checkOrphans(db, 'diem_danh', 'id_buoi_hoc', 'buoi_hoc', errors);
    
    // 3. Overlap Checks (Membership)
    // ...

    return DataIntegrityReport(errors.length, errors);
  }

  Future<void> _checkOrphans(Database db, String table, String fkCol, String parentTable, List<String> errors) async {
    final orphans = await db.rawQuery('''
      SELECT T.id FROM $table T 
      LEFT JOIN $parentTable P ON T.$fkCol = P.id 
      WHERE P.id IS NULL
    ''');
    if (orphans.isNotEmpty) {
      errors.add('Orphan Records in $table: ${orphans.length} rows have no valid $parentTable');
    }
  }
}
