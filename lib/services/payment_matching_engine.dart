// File: lib/services/payment_matching_engine.dart

import 'dart:developer' as developer;
import '../utils/db.dart';
import 'bank_parsers/bank_notification_parser.dart';

class PaymentMatchResult {
  final String
  status; // 'CONFIRMED', 'NEED_REVIEW', 'UNMATCHED', 'DUPLICATE', 'REJECTED'
  final BankTransactionCandidate candidate;
  final int? matchedStudentId;
  final int? matchedClassId;
  final String? matchedMonth;
  final String? matchMethod; // 'AUTO_EXACT', 'AUTO_NAME', 'MANUAL'
  final double confidenceScore;
  final String reason;
  final String? studentName;
  final String? className;
  final int unpaidAmount;
  final int totalAmountToPay;

  PaymentMatchResult({
    required this.status,
    required this.candidate,
    this.matchedStudentId,
    this.matchedClassId,
    this.matchedMonth,
    this.matchMethod,
    required this.confidenceScore,
    required this.reason,
    this.studentName,
    this.className,
    this.unpaidAmount = 0,
    this.totalAmountToPay = 0,
  });

  bool get isConfirmed => status == 'CONFIRMED';
  bool get isNeedReview => status == 'NEED_REVIEW';
  bool get isUnmatched => status == 'UNMATCHED';
  bool get isDuplicate => status == 'DUPLICATE';
  bool get isRejected => status == 'REJECTED';

  Map<String, dynamic> toMap() {
    return {
      'status': status,
      'candidate': candidate.toMap(),
      'matchedStudentId': matchedStudentId,
      'matchedClassId': matchedClassId,
      'matchedMonth': matchedMonth,
      'matchMethod': matchMethod,
      'confidenceScore': confidenceScore,
      'reason': reason,
      'studentName': studentName,
      'className': className,
      'unpaidAmount': unpaidAmount,
      'totalAmountToPay': totalAmountToPay,
    };
  }
}

class PaymentMatchingEngine {
  final DBHelper _dbHelper = DBHelper.instance;

  /// Chuẩn hóa tháng từ '202609' hoặc '09/2026' sang '2026-09'
  static String? normalizeMonthString(String raw) {
    final clean = raw.trim();
    // Dạng 202609 (6 chữ số)
    if (RegExp(r'^\d{6}$').hasMatch(clean)) {
      final y = clean.substring(0, 4);
      final m = clean.substring(4, 6);
      return '$y-$m';
    }
    // Dạng 2026-09
    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(clean)) {
      return clean;
    }
    // Dạng 09/2026
    if (clean.contains('/')) {
      final parts = clean.split('/');
      if (parts.length == 2 && parts[0].length <= 2 && parts[1].length == 4) {
        final m = parts[0].padLeft(2, '0');
        final y = parts[1];
        return '$y-$m';
      }
    }
    return null;
  }

  /// Trích xuất mã giao dịch chuẩn HP <STUDENT_ID> <YYYYMM>
  static Map<String, dynamic>? extractCanonicalReference(String text) {
    final cleanText = text.trim();
    // Match: HP 010007 202609 hoặc HP 10007 2026-09
    final reg = RegExp(
      r'HP\s+([0-9]{1,8})\s+([0-9]{6}|[0-9]{4}-[0-9]{2}|[0-9]{2}/[0-9]{4})',
      caseSensitive: false,
    );
    final match = reg.firstMatch(cleanText);
    if (match != null) {
      final rawId = match.group(1)!;
      final rawMonth = match.group(2)!;

      final studentId = int.tryParse(rawId);
      final normMonth = normalizeMonthString(rawMonth);

      if (studentId != null && normMonth != null) {
        return {'studentId': studentId, 'month': normMonth};
      }
    }
    return null;
  }

  /// Thực hiện khớp nối candidate giao dịch với nghĩa vụ học phí trong DB
  Future<PaymentMatchResult> matchTransaction(
    BankTransactionCandidate candidate, {
    required bool autoApproveEnabled,
  }) async {
    // 1. Chỉ xử lý MONEY-IN / CREDIT
    if (!candidate.isCredit) {
      return PaymentMatchResult(
        status: 'REJECTED',
        candidate: candidate,
        confidenceScore: 0.0,
        reason:
            'Giao dịch là chuyển đi (Debit) hoặc không phải biến động tăng số dư.',
      );
    }

    if (candidate.amount <= 0) {
      return PaymentMatchResult(
        status: 'REJECTED',
        candidate: candidate,
        confidenceScore: 0.0,
        reason: 'Số tiền giao dịch không hợp lệ (<= 0đ).',
      );
    }

    final db = await _dbHelper.database;

    // 2. Chống lặp (Deduplication Check) qua transaction_id hoặc raw_fingerprint
    if (candidate.transactionId != null &&
        candidate.transactionId!.trim().isNotEmpty) {
      final dupRows = await db.query(
        'payment_transactions',
        where: 'transaction_id = ?',
        whereArgs: [candidate.transactionId!.trim()],
      );
      if (dupRows.isNotEmpty) {
        return PaymentMatchResult(
          status: 'DUPLICATE',
          candidate: candidate,
          confidenceScore: 0.0,
          reason:
              'Mã giao dịch ${candidate.transactionId} đã được xử lý trước đó.',
        );
      }
    }

    final fpRows = await db.query(
      'payment_transactions',
      where: 'raw_fingerprint = ?',
      whereArgs: [candidate.rawFingerprint],
    );
    if (fpRows.isNotEmpty) {
      return PaymentMatchResult(
        status: 'DUPLICATE',
        candidate: candidate,
        confidenceScore: 0.0,
        reason:
            'Dấu vết giao dịch (fingerprint) đã trùng với bản ghi trong CSDL.',
      );
    }

    // 3. Quét cú pháp mã thanh toán chuẩn HP <STUDENT_ID> <YYYYMM>
    final fullText =
        '${candidate.transferContent} ${candidate.rawTitle} ${candidate.rawText}';
    final canonicalRef = extractCanonicalReference(fullText);

    if (canonicalRef != null) {
      final int refStudentId = canonicalRef['studentId'];
      final String refMonth = canonicalRef['month'];

      // Truy vấn thông tin học sinh theo ID
      final hsRows = await db.query(
        DBHelper.tenBangHS,
        where: 'id = ?',
        whereArgs: [refStudentId],
      );
      if (hsRows.isEmpty) {
        return PaymentMatchResult(
          status: 'UNMATCHED',
          candidate: candidate,
          matchedStudentId: refStudentId,
          matchedMonth: refMonth,
          confidenceScore: 0.0,
          reason: 'Không tìm thấy học sinh có mã #$refStudentId trong CSDL.',
        );
      }

      final studentName =
          hsRows.first['ten'] as String? ?? 'Học sinh #$refStudentId';

      // Truy vấn nghĩa vụ học phí tháng refMonth của học sinh
      final ttRows = await db.rawQuery(
        '''
        SELECT TT.*, L.ten as ten_lop
        FROM ${DBHelper.tenBangThanhToan} TT
        JOIN ${DBHelper.tenBangLop} L ON TT.id_lop = L.id
        WHERE TT.id_hoc_sinh = ? AND TT.thang = ?
      ''',
        [refStudentId, refMonth],
      );

      if (ttRows.isEmpty) {
        return PaymentMatchResult(
          status: 'NEED_REVIEW',
          candidate: candidate,
          matchedStudentId: refStudentId,
          matchedMonth: refMonth,
          matchMethod: 'AUTO_EXACT',
          confidenceScore: 8.0,
          studentName: studentName,
          reason:
              'Tìm thấy học sinh $studentName nhưng chưa có hóa đơn học phí tháng $refMonth trong CSDL.',
        );
      }

      final ttMap = ttRows.first;
      final classId = ttMap['id_lop'] as int;
      final className = ttMap['ten_lop'] as String? ?? '';
      final totalToPay = ttMap['tong_thanh_toan'] as int;
      final paidSoFar = ttMap['so_tien_da_dong'] as int;
      final unpaid = totalToPay - paidSoFar;

      // Đã đóng đủ trước đó
      if (unpaid <= 0) {
        return PaymentMatchResult(
          status: 'NEED_REVIEW',
          candidate: candidate,
          matchedStudentId: refStudentId,
          matchedClassId: classId,
          matchedMonth: refMonth,
          matchMethod: 'AUTO_EXACT',
          confidenceScore: 8.5,
          studentName: studentName,
          className: className,
          unpaidAmount: 0,
          totalAmountToPay: totalToPay,
          reason:
              'Học sinh $studentName đã đóng đủ học phí tháng $refMonth trước đó. Cần giáo viên kiểm tra khoản nộp dư.',
        );
      }

      // Xử lý chuyển thừa tiền (Overpayment) -> CẦN DUYỆT
      if (candidate.amount > unpaid) {
        return PaymentMatchResult(
          status: 'NEED_REVIEW',
          candidate: candidate,
          matchedStudentId: refStudentId,
          matchedClassId: classId,
          matchedMonth: refMonth,
          matchMethod: 'AUTO_EXACT',
          confidenceScore: 9.0,
          studentName: studentName,
          className: className,
          unpaidAmount: unpaid,
          totalAmountToPay: totalToPay,
          reason:
              'Số tiền chuyển (${candidate.amount}đ) lớn hơn số tiền còn nợ ($unpaidđ). Cần giáo viên xác nhận xử lý tiền thừa.',
        );
      }

      // Nếu cấu hình Auto-Approve bị TẮT
      if (!autoApproveEnabled) {
        return PaymentMatchResult(
          status: 'NEED_REVIEW',
          candidate: candidate,
          matchedStudentId: refStudentId,
          matchedClassId: classId,
          matchedMonth: refMonth,
          matchMethod: 'AUTO_EXACT',
          confidenceScore: 10.0,
          studentName: studentName,
          className: className,
          unpaidAmount: unpaid,
          totalAmountToPay: totalToPay,
          reason:
              'Khớp mã 100% nhưng cài đặt "Tự động duyệt học phí" đang TẮT.',
        );
      }

      // TẤT CẢ ĐIỀU KIỆN AN TOÀN ĐÃ THỎA MÃN -> AUTO CONFIRM!
      return PaymentMatchResult(
        status: 'CONFIRMED',
        candidate: candidate,
        matchedStudentId: refStudentId,
        matchedClassId: classId,
        matchedMonth: refMonth,
        matchMethod: 'AUTO_EXACT',
        confidenceScore: 10.0,
        studentName: studentName,
        className: className,
        unpaidAmount: unpaid,
        totalAmountToPay: totalToPay,
        reason:
            'Xác nhận tự động khớp 100% mã học sinh #$refStudentId, tháng $refMonth.',
      );
    }

    // 4. Nếu KHÔNG có mã máy quét (HP <ID> <MONTH>) -> Chuyển sang đối soát tên/số tiền
    // BẮT BUỘC: Không bao giờ Auto-Confirm khi thiếu mã chuẩn để tránh rủi ro trùng tên!
    final unpayableRows = await db.rawQuery('''
      SELECT TT.*, HS.ten as ten_hoc_sinh, L.ten as ten_lop
      FROM ${DBHelper.tenBangThanhToan} TT
      JOIN ${DBHelper.tenBangHS} HS ON TT.id_hoc_sinh = HS.id
      JOIN ${DBHelper.tenBangLop} L ON TT.id_lop = L.id
      WHERE TT.so_tien_da_dong < TT.tong_thanh_toan
    ''');

    String removeDiacritics(String str) {
      const withDiacritics =
          'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
      const withoutDiacritics =
          'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
      String result = str;
      for (int i = 0; i < withDiacritics.length; i++) {
        result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
      }
      return result.toLowerCase();
    }

    final normText = removeDiacritics(fullText);
    final matchedRowsByStudent = <int, List<Map<String, dynamic>>>{};

    for (var row in unpayableRows) {
      final sName = row['ten_hoc_sinh'] as String? ?? '';
      final normName = removeDiacritics(sName);
      final tokens = normName.split(' ').where((t) => t.length > 1).toList();

      int matchCount = 0;
      for (var t in tokens) {
        if (normText.contains(t)) matchCount++;
      }

      if (tokens.isNotEmpty && matchCount == tokens.length) {
        final studentId = row['id_hoc_sinh'] as int;
        matchedRowsByStudent.putIfAbsent(studentId, () => []).add(row);
      }
    }

    // CASE 0: Không match được học sinh nào
    if (matchedRowsByStudent.isEmpty) {
      developer.log(
        'Name matching result: UNMATCHED (no matching student names in debt list)',
        name: 'PaymentMatchingEngine',
      );
      return PaymentMatchResult(
        status: 'UNMATCHED',
        candidate: candidate,
        confidenceScore: 0.0,
        reason:
            'Không khớp với bất kỳ mã học sinh hay tên học sinh nào trong danh sách nợ.',
      );
    }

    // CASE C: Nhiều STUDENT ID khác nhau cùng match
    if (matchedRowsByStudent.length > 1) {
      final matchedIds = matchedRowsByStudent.keys.toList();
      developer.log(
        'Name matching result: matched student IDs: $matchedIds, ambiguity type: MULTIPLE_STUDENTS',
        name: 'PaymentMatchingEngine',
      );
      return PaymentMatchResult(
        status: 'NEED_REVIEW',
        candidate: candidate,
        matchMethod: 'AUTO_NAME',
        confidenceScore: 6.0,
        studentName:
            matchedRowsByStudent.values.first.first['ten_hoc_sinh'] as String?,
        reason:
            'Phát hiện ${matchedRowsByStudent.length} học sinh có tên phù hợp trong hệ thống. Cần giáo viên chọn đúng học sinh.',
      );
    }

    // CASE A & B: Duy nhất 1 STUDENT ID
    final singleStudentId = matchedRowsByStudent.keys.first;
    final studentRows = matchedRowsByStudent[singleStudentId]!;
    final studentName = studentRows.first['ten_hoc_sinh'] as String? ?? '';

    // CASE B: 1 Student ID nhưng có NHIỀU khoản công nợ chưa thanh toán
    if (studentRows.length > 1) {
      developer.log(
        'Name matching result: matched student IDs: [$singleStudentId], matching debt rows: ${studentRows.length}, selected student: $studentName, ambiguity type: MULTIPLE_DEBTS_SAME_STUDENT',
        name: 'PaymentMatchingEngine',
      );
      return PaymentMatchResult(
        status: 'NEED_REVIEW',
        candidate: candidate,
        matchedStudentId: singleStudentId,
        matchMethod: 'AUTO_NAME',
        confidenceScore: 6.0,
        studentName: studentName,
        reason:
            'Đã xác định học sinh $studentName nhưng có ${studentRows.length} khoản học phí chưa thanh toán. Cần xác định đúng tháng trước khi ghi nhận.',
      );
    }

    // CASE A: 1 Student ID và CHỈ CÓ 1 khoản công nợ duy nhất
    final matchedRow = studentRows.first;
    final classId = matchedRow['id_lop'] as int;
    final className = matchedRow['ten_lop'] as String? ?? '';
    final month = matchedRow['thang'] as String;
    final totalToPay = matchedRow['tong_thanh_toan'] as int;
    final paidSoFar = matchedRow['so_tien_da_dong'] as int;
    final unpaid = totalToPay - paidSoFar;

    final normName = removeDiacritics(studentName);
    final tokens = normName.split(' ').where((t) => t.length > 1).toList();
    final score = 6.0 + (tokens.length * 0.5);

    developer.log(
      'Name matching result: matched student IDs: [$singleStudentId], matching debt rows: 1, selected student: $studentName, ambiguity type: SINGLE_DEBT_SINGLE_STUDENT',
      name: 'PaymentMatchingEngine',
    );

    return PaymentMatchResult(
      status: 'NEED_REVIEW',
      candidate: candidate,
      matchedStudentId: singleStudentId,
      matchedClassId: classId,
      matchedMonth: month,
      matchMethod: 'AUTO_NAME',
      confidenceScore: score,
      studentName: studentName,
      className: className,
      unpaidAmount: unpaid,
      totalAmountToPay: totalToPay,
      reason:
          'Đã khớp tên học sinh $studentName. Giao dịch thiếu mã chuẩn HP <ID> <MONTH>, cần giáo viên duyệt.',
    );
  }
}
