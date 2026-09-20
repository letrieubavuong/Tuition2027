// File: lib/services/v2/data_integrity_service_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../utils/db_v2.dart';

class DataIntegrityReport {
  final int errorCount;
  final int warningCount;
  final List<String> messages;
  final String status; // READY, NOT_READY

  DataIntegrityReport({required this.errorCount, required this.warningCount, required this.messages})
    : status = errorCount == 0 ? 'READY' : 'NOT_READY';
}

class DataIntegrityServiceV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<DataIntegrityReport> runFullCheck() async {
    final db = await _dbHelper.database;
    final List<String> messages = [];
    int errors = 0;
    int warnings = 0;

    // 1. SQLite Foreign Key Check
    final fkCheck = await db.rawQuery('PRAGMA foreign_key_check');
    if (fkCheck.isNotEmpty) {
      errors += fkCheck.length;
      for (var entry in fkCheck) {
        messages.add('ERROR: FK Violation in ${entry['table']} row ${entry['rowid']}');
      }
    }

    // 2. Overlapping Memberships
    final List<Map<String, dynamic>> overlaps = await db.rawQuery('''
      SELECT t1.id_hoc_sinh, t1.id_lop, t1.tu_ngay, t1.den_ngay, t2.id as id2
      FROM tham_gia_lop t1
      JOIN tham_gia_lop t2 ON t1.id_hoc_sinh = t2.id_hoc_sinh AND t1.id_lop = t2.id_lop AND t1.id < t2.id
      WHERE (t1.den_ngay IS NULL OR t1.den_ngay >= t2.tu_ngay)
      AND (t2.den_ngay IS NULL OR t2.den_ngay >= t1.tu_ngay)
    ''');
    if (overlaps.isNotEmpty) {
      errors += overlaps.length;
      messages.add('ERROR: Overlapping membership intervals found for ${overlaps.length} student-class pairs');
    }

    // 3. Unmapped Attendance
    final List<Map<String, dynamic>> issues = await db.query('migration_issue', where: "severity = 'ERROR' AND resolved = 0");
    if (issues.isNotEmpty) {
      errors += issues.length;
      for (var issue in issues) {
        messages.add('ERROR: Unresolved migration issue: ${issue['issue_code']} - ${issue['message']}');
      }
    }

    return DataIntegrityReport(errorCount: errors, warningCount: warnings, messages: messages);
  }
}
