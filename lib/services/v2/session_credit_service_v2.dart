// File: lib/services/v2/session_credit_service_v2.dart

import 'package:sqflite/sqflite.dart';
import '../../models/v2/buoi_du_ledger_v2.dart';
import '../../utils/db_v2.dart';

class MonthlyCreditSummary {
  final int opening;
  final int earned;
  final int used;
  final int manual;
  final int closing;

  MonthlyCreditSummary({
    required this.opening,
    required this.earned,
    required this.used,
    required this.manual,
    required this.closing,
  });
}

class SessionCreditServiceV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<int> getBalance(int hsId, int lopId, {String? upToDate}) async {
    final db = await _dbHelper.database;
    String query = 'SELECT SUM(delta) as balance FROM buoi_du_ledger WHERE id_hoc_sinh = ? AND id_lop = ?';
    List<dynamic> args = [hsId, lopId];
    
    if (upToDate != null) {
      query += ' AND ngay_hieu_luc < ?';
      args.add(upToDate);
    }
    
    final result = await db.rawQuery(query, args);
    if (result.isEmpty || result.first['balance'] == null) return 0;
    return result.first['balance'] as int;
  }

  Future<MonthlyCreditSummary> getMonthlySummary(int hsId, int lopId, String month) async {
    final opening = await getBalance(hsId, lopId, upToDate: '$month-01');
    
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> rows = await db.query(
      'buoi_du_ledger',
      where: 'id_hoc_sinh = ? AND id_lop = ? AND ngay_hieu_luc LIKE ?',
      whereArgs: [hsId, lopId, '$month%'],
    );

    int earned = 0;
    int used = 0;
    int manual = 0;

    for (var r in rows) {
      final delta = r['delta'] as int;
      final reason = r['ly_do'] as String;
      
      if (reason == 'VUOT_SO_BUOI_CHUAN') earned += delta;
      else if (reason == 'BU_TRU_NGHI_CO_PHEP') used += delta;
      else manual += delta;
    }

    return MonthlyCreditSummary(
      opening: opening,
      earned: earned,
      used: used,
      manual: manual,
      closing: opening + earned + used + manual,
    );
  }

  /// Recalculates extra credits based on eligible sessions.
  Future<void> recalculateMonthlyCredits(int hsId, int lopId, String month) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      // 1. Clear existing automated entries
      await txn.delete(
        'buoi_du_ledger',
        where: 'id_hoc_sinh = ? AND id_lop = ? AND ngay_hieu_luc LIKE ? AND (ly_do = ? OR ly_do = ?)',
        whereArgs: [hsId, lopId, '$month%', 'VUOT_SO_BUOI_CHUAN', 'BU_TRU_NGHI_CO_PHEP'],
      );

      // 2. Load Class standard
      final lop = await txn.query('lop', columns: ['so_buoi_chuan_thang'], where: 'id = ?', whereArgs: [lopId]);
      final standard = lop.isNotEmpty ? (lop.first['so_buoi_chuan_thang'] as int? ?? 12) : 12;

      // 3. Identify eligible sessions (CHINH types)
      // Must include ALL sessions the student was supposed to attend to maintain correct index.
      final List<Map<String, dynamic>> eligibleSessions = await txn.rawQuery('''
        SELECT BH.*, DD.trang_thai as att_status
        FROM buoi_hoc BH
        LEFT JOIN diem_danh DD ON BH.id = DD.id_buoi_hoc AND DD.id_hoc_sinh = ?
        WHERE BH.id_lop = ? AND BH.ngay LIKE ? AND BH.loai = 'CHINH' AND BH.trang_thai = 'DA_HOC'
        ORDER BY BH.ngay ASC, BH.gio_bat_dau ASC
      ''', [hsId, lopId, '$month%']);

      if (eligibleSessions.isEmpty) return;

      int sessionIndex = 0;

      for (var s in eligibleSessions) {
        sessionIndex++;
        final status = s['att_status'] as String?;
        final bool isPresent = status == 'CO_MAT' || status == 'TRE';

        // Session 13+ only earns credit if student was present
        if (sessionIndex > standard && isPresent) {
          await txn.insert('buoi_du_ledger', {
            'id_hoc_sinh': hsId,
            'id_lop': lopId,
            'id_buoi_hoc': s['id'],
            'ngay_hieu_luc': s['ngay'],
            'delta': 1,
            'ly_do': 'VUOT_SO_BUOI_CHUAN',
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    });
  }
}
