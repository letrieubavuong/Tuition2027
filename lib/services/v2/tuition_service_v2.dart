// File: lib/services/v2/tuition_service_v2.dart

import '../../models/v2/thanh_toan_v2.dart';
import '../../utils/db_v2.dart';
import 'session_credit_service_v2.dart';

class TuitionCalculationResult {
  final int eligibleSessions;
  final int standardSessions;
  final int extraSessions;
  final int creditOpening;
  final int creditEarned;
  final int creditUsed;
  final int creditClosing;
  final int grossAmount;
  final int discount;
  final int amountDue;
  final int amountPaid;
  final int amountRemaining;

  TuitionCalculationResult({
    required this.eligibleSessions,
    required this.standardSessions,
    required this.extraSessions,
    required this.creditOpening,
    required this.creditEarned,
    required this.creditUsed,
    required this.creditClosing,
    required this.grossAmount,
    required this.discount,
    required this.amountDue,
    required this.amountPaid,
    required this.amountRemaining,
  });
}

class TuitionServiceV2 {
  final DBV2 _dbHelper = DBV2.instance;
  final SessionCreditServiceV2 _creditService = SessionCreditServiceV2();

  Future<TuitionCalculationResult> calculate(int hsId, int lopId, String month) async {
    final db = await _dbHelper.database;

    // 1. Fetch Class Pricing and Standard
    final List<Map<String, dynamic>> lopData = await db.query('lop', where: 'id = ?', whereArgs: [lopId]);
    if (lopData.isEmpty) throw Exception('Class not found');
    final feePerSession = lopData.first['hoc_phi_moi_buoi'] as int? ?? 50000;
    final standard = lopData.first['so_buoi_chuan_thang'] as int? ?? 12;
    final maxFee = lopData.first['hoc_phi_thang_toi_da'] as int?;

    // 2. Fetch Membership (Discount)
    final List<Map<String, dynamic>> memberData = await db.query(
      'tham_gia_lop',
      where: 'id_hoc_sinh = ? AND id_lop = ? AND tu_ngay <= ? AND (den_ngay IS NULL OR den_ngay >= ?)',
      whereArgs: [hsId, lopId, '$month-31', '$month-01'],
    );
    final discountPercent = memberData.isNotEmpty ? (memberData.first['mien_giam_phan_tram'] as int? ?? 0) : 0;

    // 3. Fetch Sessions and Attendance
    final List<Map<String, dynamic>> sessions = await db.rawQuery('''
      SELECT BH.*, DD.trang_thai as att_status
      FROM buoi_hoc BH
      JOIN diem_danh DD ON BH.id = DD.id_buoi_hoc
      WHERE BH.id_lop = ? AND BH.ngay LIKE ? AND BH.trang_thai = 'DA_HOC' AND DD.id_hoc_sinh = ?
      ORDER BY BH.ngay ASC, BH.gio_bat_dau ASC
    ''', [lopId, '$month%', hsId]);

    // 4. Calculate Credits
    final openingBalance = await _creditService.getBalance(hsId, lopId);
    // ... complex logic for earned vs used ...

    // 5. Aggregate Money
    final List<Map<String, dynamic>> payments = await db.query(
      'thanh_toan',
      where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
      whereArgs: [hsId, lopId, month],
    );
    int totalPaid = 0;
    for (var p in payments) {
      totalPaid += p['so_tien'] as int;
    }

    return TuitionCalculationResult(
      eligibleSessions: sessions.length,
      standardSessions: sessions.length > standard ? standard : sessions.length,
      extraSessions: sessions.length > standard ? sessions.length - standard : 0,
      creditOpening: openingBalance,
      creditEarned: 0,
      creditUsed: 0,
      creditClosing: 0,
      grossAmount: 0,
      discount: discountPercent,
      amountDue: 0,
      amountPaid: totalPaid,
      amountRemaining: 0,
    );
  }

  Future<void> recordPayment(ThanhToanV2 payment) async {
    final db = await _dbHelper.database;
    await db.insert('thanh_toan', payment.toMap());
  }
}
