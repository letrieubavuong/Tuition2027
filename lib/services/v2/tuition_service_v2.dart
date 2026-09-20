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
  final int discountPercent;
  final int discountAmount;
  final int amountDue;
  final int amountPaid;
  final int amountRemaining;
  final List<String> warnings;

  TuitionCalculationResult({
    required this.eligibleSessions,
    required this.standardSessions,
    required this.extraSessions,
    required this.creditOpening,
    required this.creditEarned,
    required this.creditUsed,
    required this.creditClosing,
    required this.grossAmount,
    required this.discountPercent,
    required this.discountAmount,
    required this.amountDue,
    required this.amountPaid,
    required this.amountRemaining,
    this.warnings = const [],
  });
}

class TuitionServiceV2 {
  final DBV2 _dbHelper = DBV2.instance;
  final SessionCreditServiceV2 _creditService = SessionCreditServiceV2();

  Future<TuitionCalculationResult> calculate(int hsId, int lopId, String month) async {
    final db = await _dbHelper.database;
    final List<String> warnings = [];

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

    // 3. Fetch Credits
    final creditSummary = await _creditService.getMonthlySummary(hsId, lopId, month);

    // 4. Identify Attendance Sessions
    final List<Map<String, dynamic>> sessions = await db.rawQuery('''
      SELECT BH.*, DD.trang_thai as att_status
      FROM buoi_hoc BH
      LEFT JOIN diem_danh DD ON BH.id = DD.id_buoi_hoc AND DD.id_hoc_sinh = ?
      WHERE BH.id_lop = ? AND BH.ngay LIKE ? AND BH.loai = 'CHINH' AND BH.trang_thai = 'DA_HOC'
      ORDER BY BH.ngay ASC, BH.gio_bat_dau ASC
    ''', [hsId, lopId, '$month%']);

    int eligibleCount = sessions.length;
    int standardCount = eligibleCount > standard ? standard : eligibleCount;
    
    // 5. Calculate Monetary values
    // standard sessions are charged, extra sessions (13+) are FREE (earned as credit but not charged)
    int grossAmount = standardCount * feePerSession;
    
    // BUT! If they missed standard sessions, they might use credits to pay for them
    // Logic: standard sessions = min(eligible, standard)
    // If they have NGHI_CO_PHEP in standard range, we might subtract from gross or use credit.
    // The policy seems to be: charge standard sessions, but extra are free.

    if (maxFee != null && grossAmount > maxFee) {
      grossAmount = maxFee;
    }
    
    final discountAmount = (grossAmount * (discountPercent / 100)).round();
    final amountDue = grossAmount - discountAmount;

    // 6. Aggregate Payments
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
      eligibleSessions: eligibleCount,
      standardSessions: standardCount,
      extraSessions: extraCount,
      creditOpening: creditSummary.opening,
      creditEarned: creditSummary.earned,
      creditUsed: creditSummary.used,
      creditClosing: creditSummary.closing,
      grossAmount: grossAmount,
      discountPercent: discountPercent,
      discountAmount: discountAmount,
      amountDue: amountDue,
      amountPaid: totalPaid,
      amountRemaining: amountDue - totalPaid,
      warnings: warnings,
    );
  }

  Future<void> recordPayment(ThanhToanV2 payment) async {
    final db = await _dbHelper.database;
    await db.insert('thanh_toan', payment.toMap());
  }
}
