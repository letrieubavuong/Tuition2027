// File: lib/services/v2/session_credit_service_v2.dart

import '../../models/v2/buoi_du_ledger_v2.dart';
import '../../utils/db_v2.dart';

class SessionCreditServiceV2 {
  final DBV2 _dbHelper = DBV2.instance;

  Future<int> getBalance(int hsId, int lopId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT SUM(delta) as balance FROM buoi_du_ledger WHERE id_hoc_sinh = ? AND id_lop = ?',
      [hsId, lopId],
    );
    if (result.isEmpty || result.first['balance'] == null) return 0;
    return result.first['balance'] as int;
  }

  Future<void> addCredit(BuoiDuLedgerV2 entry) async {
    final db = await _dbHelper.database;
    await db.insert('buoi_du_ledger', entry.toMap());
  }

  /// Recalculates and persists extra credits for a student in a class for a month.
  /// Standard sessions: 1-12. Extra candidates: 13+.
  Future<void> recalculateMonthlyCredits(int hsId, int lopId, String month) async {
    final db = await _dbHelper.database;

    // 1. Delete existing automated credits for this month to maintain idempotency
    await db.delete(
      'buoi_du_ledger',
      where: 'id_hoc_sinh = ? AND id_lop = ? AND ngay_hieu_luc LIKE ? AND (ly_do = ? OR ly_do = ?)',
      whereArgs: [hsId, lopId, '$month%', 'VUOT_SO_BUOI_CHUAN', 'BU_TRU_NGHI_CO_PHEP'],
    );

    // 2. Fetch class standard
    final List<Map<String, dynamic>> lop = await db.query('lop', columns: ['so_buoi_chuan_thang'], where: 'id = ?', whereArgs: [lopId]);
    final standard = lop.isNotEmpty ? (lop.first['so_buoi_chuan_thang'] as int? ?? 12) : 12;

    // 3. Fetch all MAIN sessions of the month where the student is present
    final List<Map<String, dynamic>> sessions = await db.rawQuery('''
      SELECT BH.*, DD.trang_thai as att_status
      FROM buoi_hoc BH
      JOIN diem_danh DD ON BH.id = DD.id_buoi_hoc
      WHERE BH.id_lop = ? AND BH.ngay LIKE ? AND BH.loai = 'CHINH' AND BH.trang_thai = 'DA_HOC' AND DD.id_hoc_sinh = ?
      ORDER BY BH.ngay ASC, BH.gio_bat_dau ASC
    ''', [lopId, '$month%', hsId]);

    if (sessions.isEmpty) return;

    int presentCount = 0;
    int sessionIndex = 0;

    for (var s in sessions) {
      sessionIndex++;
      final status = s['att_status'] as String;
      final bool isPresent = status == 'CO_MAT' || status == 'TRE';

      if (sessionIndex > standard && isPresent) {
        // Earned extra credit
        await db.insert('buoi_du_ledger', {
          'id_hoc_sinh': hsId,
          'id_lop': lopId,
          'id_buoi_hoc': s['id'],
          'ngay_hieu_luc': s['ngay'],
          'delta': 1,
          'ly_do': 'VUOT_SO_BUOI_CHUAN',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      
      if (isPresent) presentCount++;
    }
  }
}
