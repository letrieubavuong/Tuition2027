// File: lib/services/payment_coordinator.dart

import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import 'bank_parsers/bank_notification_parser.dart';
import 'payment_matching_engine.dart';
import 'report_service.dart';

class PaymentCoordinator {
  final DBHelper _dbHelper = DBHelper.instance;
  final ReportService _reportService = ReportService();

  /// Thực thi xác nhận thanh toán nguyên tố (Atomic SQLite Transaction)
  Future<int> confirmPaymentAtomic({
    required BankTransactionCandidate candidate,
    required int studentId,
    required int classId,
    required String month,
    required String matchMethod, // 'AUTO_EXACT', 'AUTO_NAME', 'MANUAL'
    int? customAmount,
    String? teacherNote,
  }) async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toIso8601String();
    final actualAmount = customAmount ?? candidate.amount;

    int transactionRecordId = 0;

    // Bắt đầu SQLite Transaction nguyên tố 100%
    await db.transaction((txn) async {
      final String? txId = candidate.transactionId;
      final String? rawFp = candidate.rawFingerprint;

      // 1. Kiểm tra xem giao dịch ngân hàng đã tồn tại hay chưa (Idempotency Check)
      List<Map<String, dynamic>> existingTx = [];
      if (txId != null && txId.trim().isNotEmpty) {
        existingTx = await txn.query(
          'payment_transactions',
          where: 'transaction_id = ?',
          whereArgs: [txId.trim()],
        );
      }
      if (existingTx.isEmpty && rawFp != null && rawFp.trim().isNotEmpty) {
        existingTx = await txn.query(
          'payment_transactions',
          where: 'raw_fingerprint = ?',
          whereArgs: [rawFp.trim()],
        );
      }

      if (existingTx.isNotEmpty) {
        // Giao dịch đã được ghi nhận trước đây -> KHÔNG double-count, giữ nguyên idempotency
        transactionRecordId = existingTx.first['id'] as int;
        developer.log(
          '⚠️ Giao dịch ngân hàng đã tồn tại (ID: $transactionRecordId). Bỏ qua không cộng lặp tiền.',
          name: 'PaymentCoordinator',
        );
        return;
      }

      // 2. Ghi nhận giao dịch ngân hàng vào payment_transactions (Không dùng ConflictAlgorithm.replace)
      transactionRecordId = await txn.insert('payment_transactions', {
        'hoc_sinh_id': studentId,
        'lop_id': classId,
        'month': month,
        'amount': actualAmount,
        'status': 'CONFIRMED',
        'transaction_id': txId ?? rawFp,
        'created_at': nowStr,
        'updated_at': nowStr,
        'bank_code': candidate.bankCode,
        'raw_content': candidate.transferContent,
        'match_method': matchMethod,
        'failure_reason': teacherNote,
        'raw_fingerprint': rawFp,
      }, conflictAlgorithm: ConflictAlgorithm.abort);

      // 3. Lấy thông tin bản ghi thanh_toan hiện tại (Sử dụng đúng schema: id_hoc_sinh, id_lop, thang)
      final ttRows = await txn.query(
        DBHelper.tenBangThanhToan,
        where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
        whereArgs: [studentId, classId, month],
      );

      if (ttRows.isEmpty) {
        // Hồ sơ thanh toán chưa tồn tại -> dùng ReportService để xác định nghĩa vụ học phí thật sự
        // Không được lấy số tiền giao dịch làm tong_thanh_toan
        TuitionCalculationResult? calcResult;
        try {
          calcResult = await _reportService.calculateTuitionReport(
            classId,
            month,
          );
        } catch (e) {
          developer.log(
            'Lỗi tính nghĩa vụ học phí từ ReportService: $e',
            name: 'PaymentCoordinator',
          );
        }

        TinhToanHocSinhResult? hsResult;
        if (calcResult != null) {
          final matches = calcResult.dsTinhToan.where(
            (element) => element.idHocSinh == studentId,
          );
          if (matches.isNotEmpty) {
            hsResult = matches.first;
          }
        }

        if (hsResult != null) {
          // Tạo mới hồ sơ thanh_toan với đúng schema chuẩn của DBHelper.tenBangThanhToan
          // CHÚ Ý: Nghỉ không phép tính 100% học phí (0% miễn giảm). so_buoi_mien_giam_50 = 0
          final newTtId = await txn.insert(DBHelper.tenBangThanhToan, {
            'id_hoc_sinh': studentId,
            'id_lop': classId,
            'thang': month,
            'tong_so_buoi': hsResult.tongSoBuoiDuKien,
            'so_buoi_mien_giam_100': hsResult.soBuoiNghiCoPhep,
            'so_buoi_mien_giam_50':
                0, // Quy tắc nghiệp vụ chuẩn: Không gán nghỉ không phép thành miễn 50%
            'so_buoi_duoc_bu_tru': hsResult.soBuoiDuocBuTru,
            'so_buoi_du_con_lai': hsResult.soBuoiDuCuoiCung,
            'tong_thanh_toan': hsResult.tongThanhToan,
            'so_tien_da_dong': actualAmount,
            'ngay_thanh_toan': nowStr,
            'ghi_chu_thanh_toan': 'Thanh toán qua Ngân hàng ($matchMethod)',
          });

          await txn.update(
            'payment_transactions',
            {'linked_payment_id': newTtId},
            where: 'id = ?',
            whereArgs: [transactionRecordId],
          );
        } else {
          // Không tính được nghĩa vụ học phí hợp lệ -> chuyển giao dịch sang NEED_REVIEW
          // KHÔNG tạo hồ sơ học phí giả
          await txn.update(
            'payment_transactions',
            {
              'status': 'NEED_REVIEW',
              'failure_reason':
                  'Chưa thể xác định nghĩa vụ học phí chuẩn từ ReportService',
            },
            where: 'id = ?',
            whereArgs: [transactionRecordId],
          );
        }
      } else {
        // Hồ sơ thanh toán đã tồn tại -> cộng khoản thanh toán mới vào so_tien_da_dong, giữ nguyên tong_thanh_toan
        final ttMap = ttRows.first;
        final ttId = ttMap['id'] as int;
        final currentPaid = ttMap['so_tien_da_dong'] as int? ?? 0;

        final newPaidTotal = currentPaid + actualAmount;

        await txn.update(
          DBHelper.tenBangThanhToan,
          {
            'so_tien_da_dong': newPaidTotal,
            'ngay_thanh_toan': nowStr,
            'ghi_chu_thanh_toan':
                'Thanh toán qua Ngân hàng ($matchMethod - +$actualAmountđ)',
          },
          where: 'id = ?',
          whereArgs: [ttId],
        );

        await txn.update(
          'payment_transactions',
          {'linked_payment_id': ttId},
          where: 'id = ?',
          whereArgs: [transactionRecordId],
        );
      }
    });

    developer.log(
      '✅ Atomic Payment Transaction Committed Successfully! (ID: $transactionRecordId, HS: #$studentId, $actualAmountđ)',
      name: 'PaymentCoordinator',
    );

    return transactionRecordId;
  }

  /// Ghi nhận giao dịch CẦN DUYỆT hoặc UNMATCHED vào CSDL mà không thay đổi thanh toán (Idempotent)
  Future<int> recordPendingOrUnmatchedTransaction({
    required BankTransactionCandidate candidate,
    required PaymentMatchResult matchResult,
  }) async {
    final db = await _dbHelper.database;
    final nowStr = DateTime.now().toIso8601String();
    final txId = candidate.transactionId;
    final rawFp = candidate.rawFingerprint;

    List<Map<String, dynamic>> existingTx = [];
    if (txId != null && txId.trim().isNotEmpty) {
      existingTx = await db.query(
        'payment_transactions',
        where: 'transaction_id = ?',
        whereArgs: [txId.trim()],
      );
    }
    if (existingTx.isEmpty && rawFp != null && rawFp.trim().isNotEmpty) {
      existingTx = await db.query(
        'payment_transactions',
        where: 'raw_fingerprint = ?',
        whereArgs: [rawFp.trim()],
      );
    }
    if (existingTx.isNotEmpty) {
      return existingTx.first['id'] as int;
    }

    final id = await db.insert('payment_transactions', {
      'hoc_sinh_id': matchResult.matchedStudentId ?? 0,
      'lop_id': matchResult.matchedClassId ?? 0,
      'month': matchResult.matchedMonth ?? '',
      'amount': candidate.amount,
      'status': matchResult.status, // 'NEED_REVIEW', 'UNMATCHED', 'REJECTED'
      'transaction_id': txId ?? rawFp,
      'created_at': nowStr,
      'updated_at': nowStr,
      'bank_code': candidate.bankCode,
      'raw_content': candidate.transferContent,
      'match_method': matchResult.matchMethod,
      'failure_reason': matchResult.reason,
      'raw_fingerprint': rawFp,
    }, conflictAlgorithm: ConflictAlgorithm.abort);

    return id;
  }
}
