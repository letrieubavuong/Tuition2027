// File: lib/services/v2/reconciliation_service_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../utils/db.dart';
import '../../utils/db_v2.dart';

class ReconciliationReport {
  final Map<String, dynamic> legacyStats;
  final Map<String, dynamic> v2Stats;
  final List<String> mismatches;

  ReconciliationReport(this.legacyStats, this.v2Stats, this.mismatches);
}

class ReconciliationServiceV2 {
  final DBHelper _legacyDB = DBHelper.instance;
  final DBV2 _v2DB = DBV2.instance;

  Future<ReconciliationReport> runReconciliation() async {
    final legacy = await _legacyDB.database;
    final v2 = await _v2DB.database;

    final Map<String, dynamic> legacyStats = {};
    final Map<String, dynamic> v2Stats = {};
    final List<String> mismatches = [];

    // 1. Student Count
    legacyStats['student_count'] = Sqflite.firstIntValue(await legacy.rawQuery('SELECT COUNT(*) FROM hoc_sinh'));
    v2Stats['student_count'] = Sqflite.firstIntValue(await v2.rawQuery('SELECT COUNT(*) FROM hoc_sinh'));
    if (legacyStats['student_count'] != v2Stats['student_count']) {
      mismatches.add('Student count mismatch: Legacy=${legacyStats['student_count']}, V2=${v2Stats['student_count']}');
    }

    // 2. Class Count
    legacyStats['class_count'] = Sqflite.firstIntValue(await legacy.rawQuery('SELECT COUNT(*) FROM lop'));
    v2Stats['class_count'] = Sqflite.firstIntValue(await v2.rawQuery('SELECT COUNT(*) FROM lop'));
    if (legacyStats['class_count'] != v2Stats['class_count']) {
      mismatches.add('Class count mismatch: Legacy=${legacyStats['class_count']}, V2=${v2Stats['class_count']}');
    }

    // 3. Payment Totals
    legacyStats['total_paid'] = Sqflite.firstIntValue(await legacy.rawQuery('SELECT SUM(so_tien_da_dong) FROM thanh_toan')) ?? 0;
    v2Stats['total_paid'] = Sqflite.firstIntValue(await v2.rawQuery('SELECT SUM(so_tien) FROM thanh_toan')) ?? 0;
    if (legacyStats['total_paid'] != v2Stats['total_paid']) {
      mismatches.add('Payment total mismatch: Legacy=${legacyStats['total_paid']}, V2=${v2Stats['total_paid']}');
    }

    return ReconciliationReport(legacyStats, v2Stats, mismatches);
  }
}
