// File: lib/services/v2/reconciliation_service_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../utils/db.dart';
import '../../utils/db_v2.dart';

class ReconciliationSummary {
  final Map<String, int> legacyCounts;
  final Map<String, int> v2Counts;
  final List<String> mismatches;
  final String status; // READY, NOT_READY

  ReconciliationSummary(this.legacyCounts, this.v2Counts, this.mismatches)
    : status = mismatches.isEmpty ? 'READY' : 'NOT_READY';
}

class ReconciliationServiceV2 {
  final DBHelper _legacyDB = DBHelper.instance;
  final DBV2 _v2DB = DBV2.instance;

  Future<ReconciliationSummary> runReconciliation() async {
    final legacy = await _legacyDB.database;
    final v2 = await _v2DB.database;

    final legacyCounts = <String, int>{};
    final v2Counts = <String, int>{};
    final mismatches = <String, String>{};

    // Helper to compare counts
    Future<void> compare(String label, String legacyTable, String v2Table, {String? legacyWhere, String? v2Where}) async {
      legacyCounts[label] = Sqflite.firstIntValue(await legacy.rawQuery('SELECT COUNT(*) FROM $legacyTable ${legacyWhere ?? ''}')) ?? 0;
      v2Counts[label] = Sqflite.firstIntValue(await v2.rawQuery('SELECT COUNT(*) FROM $v2Table ${v2Where ?? ''}')) ?? 0;
      
      if (legacyCounts[label] != v2Counts[label]) {
        mismatches[label] = 'Count mismatch for $label: Legacy=${legacyCounts[label]}, V2=${v2Counts[label]}';
      }
    }

    await compare('Students', 'hoc_sinh', 'hoc_sinh');
    await compare('Classes', 'lop', 'lop');
    await compare('Memberships', 'lop_hoc_sinh', 'tham_gia_lop');
    await compare('Attendance', 'diem_danh', 'diem_danh');

    // Deep Audit: Student Names and IDs
    final List<Map<String, dynamic>> legacyStudents = await legacy.query('hoc_sinh', columns: ['id', 'ten']);
    for (var s in legacyStudents) {
      final id = s['id'];
      final List<Map<String, dynamic>> v2S = await v2.query('hoc_sinh', where: 'id = ?', whereArgs: [id]);
      if (v2S.isEmpty) {
        mismatches.add('Missing Student in V2: ID=$id, Name=${s['ten']}');
      } else if (v2S.first['ho_ten'] != s['ten']) {
        mismatches.add('Student Name Mismatch: ID=$id, Legacy=${s['ten']}, V2=${v2S.first['ho_ten']}');
      }
    }

    // Compare total money
    final legacyMoneyRow = await legacy.rawQuery('SELECT SUM(so_tien_da_dong) as total FROM thanh_toan');
    final v2MoneyRow = await v2.rawQuery('SELECT SUM(so_tien) as total FROM thanh_toan');
    final legacyMoney = (legacyMoneyRow.first['total'] as num? ?? 0).toInt();
    final v2Money = (v2MoneyRow.first['total'] as num? ?? 0).toInt();

    if (legacyMoney != v2Money) {
       mismatches.add('Total payment mismatch: Legacy=$legacyMoney, V2=$v2Money');
    }

    return ReconciliationSummary(legacyCounts, v2Counts, mismatches.values.toList());
  }
}
