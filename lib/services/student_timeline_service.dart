// File: lib/services/student_timeline_service.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../models/student_signal.dart';
import '../models/student_timeline.dart';
import '../services/hoc_sinh_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/student_signal_service.dart';
import '../services/report_service.dart';
import '../utils/db.dart';

class StudentTimelineService {
  static final StudentTimelineService instance =
      StudentTimelineService._internal();
  factory StudentTimelineService() => instance;
  StudentTimelineService._internal();

  final _dbHelper = DBHelper.instance;
  final _hsService = HocSinhService();
  final _lhsService = LopHocSinhService();
  final _signalService = StudentSignalService.instance;
  final _reportService = ReportService();

  /// Tổng hợp Tình hình gần đây (Summary Status Header Widget)
  Future<StudentSummaryStatus> getStudentSummaryStatus(int studentId) async {
    final db = await _dbHelper.database;
    final hs = await _hsService.docHocSinhTheoId(studentId);
    if (hs == null) {
      return StudentSummaryStatus(
        attendanceSummary: 'Chưa có dữ liệu',
        homeworkSummary: 'Chưa có dữ liệu',
        attitudeSummary: 'Chưa đánh giá',
        comprehensionSummary: 'Chưa đánh giá',
        tuitionStatus: 'N/A',
        parentContactCount: 0,
        activeWarningsCount: 0,
      );
    }

    final now = DateTime.now();

    // Signals chưa giải quyết (Lọc bỏ positive streak & snoozed còn hiệu lực)
    final allSignals = await _signalService.getSignalsForStudent(
      studentId,
      activeOnly: true,
    );

    final activeWarnings = allSignals.where((sig) {
      if (sig.severity == StudentTimelineSeverity.positive) return false;
      if (sig.status == StudentSignalStatus.resolved) return false;
      if (sig.status == StudentSignalStatus.snoozed &&
          sig.snoozedUntil != null &&
          sig.snoozedUntil!.isAfter(now)) {
        return false;
      }
      return true;
    }).toList();

    final activeWarningsCount = activeWarnings.length;
    String? activeWarningMessage;
    if (activeWarnings.isNotEmpty) {
      activeWarningMessage =
          '${activeWarnings.length} vấn đề cần chú ý (${activeWarnings.first.title})';
    }

    // Đếm chuyên cần trong 30 ngày gần đây
    final thirtyDaysAgoStr = now
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .substring(0, 10);
    final attRows = await db.rawQuery(
      '''
      SELECT trang_thai FROM ${DBHelper.tenBangDiemDanh}
      WHERE id_hoc_sinh = ? AND gio_diem_danh >= ?
      ''',
      [studentId, thirtyDaysAgoStr],
    );

    int totalAtt = attRows.length;
    int attendedCount = 0;
    for (var row in attRows) {
      final st = row['trang_thai'] as String?;
      if (st == 'Có mặt' || st == 'Trễ' || st == 'Học bù') {
        attendedCount++;
      }
    }
    final attSummary = totalAtt > 0
        ? '$attendedCount/$totalAtt'
        : 'Chưa có dữ liệu';

    // Đánh giá 5 buổi gần đây
    final reviewRows = await db.rawQuery(
      '''
      SELECT d.trang_thai, r.diem_thai_do, r.diem_hieu_bai, r.diem_bai_tap, r.nhan_xet
      FROM ${DBHelper.tenBangDiemDanh} d
      LEFT JOIN ${DBHelper.tenBangDanhGiaBuoiHoc} r ON r.id_diem_danh = d.id
      WHERE d.id_hoc_sinh = ? AND d.trang_thai IN ('Có mặt', 'Trễ', 'Học bù')
      ORDER BY d.gio_diem_danh DESC
      LIMIT 5
      ''',
      [studentId],
    );

    int hwDoneCount = 0;
    int totalHwChecked = reviewRows.length;
    String attitudeSummary = reviewRows.isNotEmpty ? 'Tốt' : 'Chưa đánh giá';
    String comprehensionSummary = reviewRows.isNotEmpty
        ? 'Khá'
        : 'Chưa đánh giá';

    for (var row in reviewRows) {
      final hw = row['diem_bai_tap'];
      final nhanXet = (row['nhan_xet'] as String?) ?? '';
      if ((hw != null && (hw as num) >= 6.0) ||
          (!nhanXet.contains('Thiếu BTVN') &&
              !nhanXet.contains('Không làm BTVN') &&
              nhanXet.contains('Đầy đủ'))) {
        hwDoneCount++;
      }

      if (nhanXet.contains('Mất tập trung') ||
          nhanXet.contains('Nói chuyện') ||
          nhanXet.contains('Cần nhắc')) {
        attitudeSummary = 'Cần nhắc nhở';
      }
      if (nhanXet.contains('Cần củng cố') ||
          nhanXet.contains('chưa hiểu bài')) {
        comprehensionSummary = 'Cần củng cố';
      }
    }

    final hwSummary = totalHwChecked > 0
        ? '$hwDoneCount/$totalHwChecked'
        : 'Chưa có dữ liệu';

    // Học phí
    final studentClasses = await _lhsService.docDSLopCuaHS(studentId);
    final nowMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    int totalDebt = 0;
    for (var lop in studentClasses) {
      if (lop.id != null) {
        final rpt = await _reportService.layBaoCaoHocPhiThang(
          lop.id!,
          nowMonthStr,
          persist: false,
        );
        final debtItem = rpt.dsHocSinhConNo.firstWhere(
          (x) => x.idHocSinh == studentId,
          orElse: () => HocSinhNoHocPhi(
            idHocSinh: studentId,
            tenHocSinh: hs.ten,
            soTienCanNop: 0,
            soTienDaDong: 0,
            soTienConNo: 0,
            mienGiam: 0,
            soBuoiDu: 0,
          ),
        );
        if (debtItem.soTienConNo > 0) {
          totalDebt += debtItem.soTienConNo;
        }
      }
    }

    final tuitionStatus = totalDebt > 0
        ? 'Nợ ${NumberFormat('#,##0').format(totalDebt)}đ'
        : '✓ Hoàn thành';

    // Đếm số lần liên hệ thực tế (SENT, CONFIRMED, DONE)
    int parentContactCount = 0;
    try {
      final contactRows = await db.rawQuery(
        '''
        SELECT COUNT(*) as cnt FROM parent_communications
        WHERE id_hoc_sinh = ? AND trang_thai IN ('SENT', 'CONFIRMED', 'DONE')
        ''',
        [studentId],
      );
      if (contactRows.isNotEmpty) {
        parentContactCount = Sqflite.firstIntValue(contactRows) ?? 0;
      }
    } catch (_) {}

    return StudentSummaryStatus(
      attendanceSummary: attSummary,
      homeworkSummary: hwSummary,
      attitudeSummary: attitudeSummary,
      comprehensionSummary: comprehensionSummary,
      tuitionStatus: tuitionStatus,
      parentContactCount: parentContactCount,
      activeWarningsCount: activeWarningsCount,
      activeWarningMessage: activeWarningMessage,
    );
  }

  /// Đọc và tổng hợp Timeline V2 cho Học Sinh có Pagination và Filter
  Future<List<StudentTimelineItem>> fetchTimeline({
    required int studentId,
    int page = 1,
    int limit = 25,
    StudentTimelineFilter filter = StudentTimelineFilter.all,
  }) async {
    final db = await _dbHelper.database;
    final allItems = <StudentTimelineItem>[];

    // 1. BUỔI HỌC (Sessions: DiemDanh + DanhGiaBuoiHoc + SessionHomework)
    if (filter == StudentTimelineFilter.all ||
        filter == StudentTimelineFilter.session ||
        filter == StudentTimelineFilter.absence ||
        filter == StudentTimelineFilter.homework) {
      final sessionItems = await _fetchSessionItems(db, studentId);
      for (var item in sessionItems) {
        if (filter == StudentTimelineFilter.absence) {
          final isAbsenceOrLate =
              item.attendanceStatus == 'Trễ' ||
              item.attendanceStatus == 'Nghỉ có phép' ||
              item.attendanceStatus == 'Nghỉ không phép' ||
              item.attendanceStatus == 'Học bù';
          if (!isAbsenceOrLate) continue;
        } else if (filter == StudentTimelineFilter.homework) {
          final hasHwInfo =
              item.assignedHomework != null ||
              item.resultBtvn != null ||
              item.diemBaiTap != null;
          if (!hasHwInfo) continue;
        }
        allItems.add(item);
      }
    }

    // 2. HỌC PHÍ (Payment Transactions)
    if (filter == StudentTimelineFilter.all ||
        filter == StudentTimelineFilter.payment) {
      final paymentItems = await _fetchPaymentItems(db, studentId);
      allItems.addAll(paymentItems);
    }

    // 3. LIÊN HỆ PHỤ HUYNH (Parent Communications - Real contact only)
    if (filter == StudentTimelineFilter.all ||
        filter == StudentTimelineFilter.parentContact) {
      final contactItems = await _fetchParentContactItems(db, studentId);
      allItems.addAll(contactItems);
    }

    // 4. CẢNH BÁO / SIGNAL (Student Signals)
    if (filter == StudentTimelineFilter.all ||
        filter == StudentTimelineFilter.warning) {
      final signalItems = await _fetchSignalItems(studentId);
      for (var sigItem in signalItems) {
        if (filter == StudentTimelineFilter.warning) {
          // Lọc bỏ positive streak khi chọn filter Cảnh báo
          if (sigItem.severity == StudentTimelineSeverity.positive) {
            continue;
          }
        }
        allItems.add(sigItem);
      }
    }

    // 5. THAM GIA / RỜI LỚP (LopHocSinh)
    if (filter == StudentTimelineFilter.all) {
      final membershipItems = await _fetchMembershipItems(db, studentId);
      allItems.addAll(membershipItems);
    }

    // Sắp xếp giảm dần theo thời gian (mới nhất lên đầu)
    allItems.sort((a, b) => b.eventDateTime.compareTo(a.eventDateTime));

    // Áp dụng Pagination (Limit per page)
    final startIndex = (page - 1) * limit;
    if (startIndex >= allItems.length) {
      return [];
    }
    final endIndex = (startIndex + limit) > allItems.length
        ? allItems.length
        : (startIndex + limit);

    return allItems.sublist(startIndex, endIndex);
  }

  /// Truy vấn và gom nhóm 1 Buổi học thành 1 Session Card duy nhất
  Future<List<StudentSessionTimelineItem>> _fetchSessionItems(
    Database db,
    int studentId,
  ) async {
    final attRows = await db.rawQuery(
      '''
      SELECT d.id as id_diem_danh, d.id_lop, d.gio_diem_danh, d.trang_thai,
             l.ten as ten_lop,
             r.diem_thai_do, r.diem_hieu_bai, r.diem_bai_tap, r.nhan_xet
      FROM ${DBHelper.tenBangDiemDanh} d
      LEFT JOIN ${DBHelper.tenBangLop} l ON l.id = d.id_lop
      LEFT JOIN ${DBHelper.tenBangDanhGiaBuoiHoc} r ON r.id_diem_danh = d.id
      WHERE d.id_hoc_sinh = ?
      ORDER BY d.gio_diem_danh DESC
      ''',
      [studentId],
    );

    // Batch query bài tập về nhà từ session_homework
    final Map<String, String> homeworkMap = {};
    try {
      final hwRows = await db.query('session_homework');
      for (var row in hwRows) {
        final classId = row['class_id'];
        final sessionDate = row['session_date'] as String?;
        final assignment = row['assignment_content'] as String?;
        if (classId != null && sessionDate != null && assignment != null) {
          homeworkMap['${classId}_$sessionDate'] = assignment;
        }
      }
    } catch (_) {}

    // Batch query các session bị CANCELLED
    final Set<String> cancelledSessionKeys = {};
    try {
      final cancelledRows = await db.query(
        'session_completion_ledger',
        where: "session_status = 'CANCELLED' OR status = 'CANCELLED'",
      );
      for (var r in cancelledRows) {
        final cid = r['class_id'];
        final date = (r['session_date'] ?? r['date']) as String?;
        if (cid != null && date != null) {
          cancelledSessionKeys.add('${cid}_$date');
        }
      }
    } catch (_) {}

    final items = <StudentSessionTimelineItem>[];

    for (var row in attRows) {
      final attId = row['id_diem_danh'] as int;
      final classId = row['id_lop'] as int?;
      final className = row['ten_lop'] as String? ?? 'Lớp học';
      final dateTimeStr = row['gio_diem_danh'] as String;
      final dt = DateTime.tryParse(dateTimeStr) ?? DateTime.now();
      final trangThai = row['trang_thai'] as String;
      final dateStr = DateFormat('yyyy-MM-dd').format(dt);
      final timeStr = DateFormat('HH:mm').format(dt);

      // Bỏ qua nếu session đã bị CANCELLED
      if (classId != null &&
          cancelledSessionKeys.contains('${classId}_$dateStr')) {
        continue;
      }

      // Check active participation window
      if (classId != null) {
        final activeInWindow = await _lhsService.isStudentActiveOnDate(
          studentId,
          classId,
          dt,
        );
        if (!activeInWindow) continue;
      }

      final nhanXet = row['nhan_xet'] as String?;
      final num? thaiDoNum = row['diem_thai_do'] as num?;
      final num? hieuBaiNum = row['diem_hieu_bai'] as num?;
      final num? baiTapNum = row['diem_bai_tap'] as num?;

      String? resultBtvn;
      if (nhanXet != null) {
        if (nhanXet.contains('Thiếu BTVN') ||
            nhanXet.contains('chưa làm BTVN')) {
          resultBtvn = 'Thiếu';
        } else if (nhanXet.contains('Không làm BTVN')) {
          resultBtvn = 'Không làm';
        } else if (nhanXet.contains('Đầy đủ')) {
          resultBtvn = 'Đầy đủ';
        }
      }
      if (resultBtvn == null && baiTapNum != null) {
        resultBtvn = baiTapNum >= 6.0 ? 'Đầy đủ' : 'Thiếu';
      }

      // Read assigned homework
      final hwKey = '${classId}_$dateStr';
      final assignedHw = homeworkMap[hwKey];

      items.add(
        StudentSessionTimelineItem(
          id: 'session_${attId}_${studentId}_$dateStr',
          studentId: studentId,
          eventDateTime: dt,
          title: '$trangThai - $className',
          summary:
              nhanXet ?? 'Buổi học ngày ${DateFormat("dd/MM/yyyy").format(dt)}',
          classId: classId,
          className: className,
          sessionDate: dt,
          startTime: timeStr,
          attendanceStatus: trangThai,
          diemThaiDo: thaiDoNum?.toDouble(),
          diemHieuBai: hieuBaiNum?.toDouble(),
          diemBaiTap: baiTapNum?.toDouble(),
          resultBtvn: resultBtvn,
          assignedHomework: assignedHw,
          teacherComment: nhanXet,
        ),
      );
    }

    return items;
  }

  /// Truy vấn giao dịch thanh toán học phí (Payment Transactions + Legacy Fallback)
  Future<List<StudentPaymentTimelineItem>> _fetchPaymentItems(
    Database db,
    int studentId,
  ) async {
    final items = <StudentPaymentTimelineItem>[];

    // Thử truy vấn bảng payment_transactions trước
    bool loadedFromTxn = false;
    try {
      final txnRows = await db.rawQuery(
        '''
        SELECT pt.*, l.ten as ten_lop
        FROM payment_transactions pt
        LEFT JOIN ${DBHelper.tenBangLop} l ON l.id = pt.class_id
        WHERE pt.student_id = ?
        ORDER BY pt.created_at DESC
        ''',
        [studentId],
      );

      if (txnRows.isNotEmpty) {
        loadedFromTxn = true;
        for (var row in txnRows) {
          final txnId = row['id'] as int?;
          final classId = row['class_id'] as int?;
          final className = row['ten_lop'] as String? ?? 'Lớp học';
          final amount = row['amount'] as int? ?? 0;
          final month = row['billing_month'] as String?;
          final method = row['payment_method'] as String? ?? 'Tiền mặt';
          final dateStr = (row['payment_date'] ?? row['created_at']) as String?;
          final dt = dateStr != null
              ? (DateTime.tryParse(dateStr) ?? DateTime.now())
              : DateTime.now();

          items.add(
            StudentPaymentTimelineItem(
              id: 'txn_${txnId ?? row.hashCode}',
              studentId: studentId,
              eventDateTime: dt,
              title:
                  'Thanh toán học phí ${month != null ? "tháng $month" : ""}',
              summary:
                  'Đã nộp ${NumberFormat("#,##0").format(amount)}đ ($method) - $className',
              transactionId: txnId,
              classId: classId,
              className: className,
              amount: amount,
              month: month,
              paymentMethod: method,
              note: row['note'] as String?,
            ),
          );
        }
      }
    } catch (_) {}

    // Fallback dữ liệu legacy từ bảng thanh_toan nếu chưa có transaction chi tiết
    if (!loadedFromTxn) {
      final payRows = await db.rawQuery(
        '''
        SELECT t.*, l.ten as ten_lop
        FROM ${DBHelper.tenBangThanhToan} t
        LEFT JOIN ${DBHelper.tenBangLop} l ON l.id = t.id_lop
        WHERE t.id_hoc_sinh = ? AND t.so_tien_da_dong > 0
        ORDER BY t.ngay_thanh_toan DESC
        ''',
        [studentId],
      );

      for (var row in payRows) {
        final payId = row['id'] as int;
        final classId = row['id_lop'] as int?;
        final className = row['ten_lop'] as String? ?? 'Lớp học';
        final thang = row['thang'] as String;
        final soTien = row['so_tien_da_dong'] as int? ?? 0;
        final dateStr = row['ngay_thanh_toan'] as String?;
        final dt = dateStr != null
            ? (DateTime.tryParse(dateStr) ?? DateTime.now())
            : DateTime.now();

        items.add(
          StudentPaymentTimelineItem(
            id: 'legacy_pay_$payId',
            studentId: studentId,
            eventDateTime: dt,
            title: 'Học phí tháng $thang',
            summary:
                'Đã thanh toán ${NumberFormat("#,##0").format(soTien)}đ - Lớp $className',
            transactionId: payId,
            classId: classId,
            className: className,
            amount: soTien,
            month: thang,
            paymentMethod: 'Tiền mặt',
          ),
        );
      }
    }

    return items;
  }

  /// Truy vấn lịch sử liên hệ phụ huynh thực tế (SENT, CONFIRMED, DONE)
  Future<List<StudentParentContactTimelineItem>> _fetchParentContactItems(
    Database db,
    int studentId,
  ) async {
    final items = <StudentParentContactTimelineItem>[];
    try {
      final commRows = await db.rawQuery(
        '''
        SELECT * FROM parent_communications
        WHERE id_hoc_sinh = ? AND trang_thai IN ('SENT', 'CONFIRMED', 'DONE')
        ORDER BY created_at DESC
        ''',
        [studentId],
      );

      for (var row in commRows) {
        final commId = row['id'] as int?;
        final classId = row['id_lop'] as int?;
        final className = row['ten_lop'] as String? ?? 'Lớp học';
        final loai = row['loai_tin_nhan'] as String? ?? 'Zalo';
        final lyDo = row['ly_do'] as String? ?? 'Trao đổi học tập';
        final noiDung = row['noi_dung'] as String? ?? '';
        final status = row['trang_thai'] as String? ?? 'DONE';
        final dateStr = row['created_at'] as String?;
        final dt = dateStr != null
            ? (DateTime.tryParse(dateStr) ?? DateTime.now())
            : DateTime.now();

        items.add(
          StudentParentContactTimelineItem(
            id: 'comm_${commId ?? row.hashCode}',
            studentId: studentId,
            eventDateTime: dt,
            title: 'Đã liên hệ phụ huynh ($loai)',
            summary: noiDung.isNotEmpty ? noiDung : lyDo,
            commId: commId,
            classId: classId,
            className: className,
            contactType: loai,
            reason: lyDo,
            content: noiDung,
            status: status,
          ),
        );
      }
    } catch (_) {}

    return items;
  }

  /// Truy vấn tín hiệu / cảnh báo hệ thống
  Future<List<StudentSignalTimelineItem>> _fetchSignalItems(
    int studentId,
  ) async {
    final items = <StudentSignalTimelineItem>[];
    final sigRows = await _signalService.getSignalsForStudent(studentId);

    for (var sig in sigRows) {
      items.add(
        StudentSignalTimelineItem(
          id: 'sig_${sig.id}',
          studentId: studentId,
          eventDateTime: sig.createdAt,
          title: sig.title,
          summary: sig.description,
          signalId: sig.id,
          signalType: sig.signalType,
          status: sig.status,
          severity: sig.severity,
          snoozedUntil: sig.snoozedUntil,
          metadata: sig.metadata,
        ),
      );
    }

    return items;
  }

  /// Truy vấn sự kiện Tham gia / Rời lớp
  Future<List<StudentMembershipTimelineItem>> _fetchMembershipItems(
    Database db,
    int studentId,
  ) async {
    final items = <StudentMembershipTimelineItem>[];
    final lhsRows = await db.rawQuery(
      '''
      SELECT lhs.*, l.ten as ten_lop
      FROM ${DBHelper.tenBangLopHS} lhs
      LEFT JOIN ${DBHelper.tenBangLop} l ON l.id = lhs.id_lop
      WHERE lhs.id_hoc_sinh = ?
      ''',
      [studentId],
    );

    for (var row in lhsRows) {
      final classId = row['id_lop'] as int?;
      final className = row['ten_lop'] as String? ?? 'Lớp học';
      final joinDateStr = row['ngay_tham_gia'] as String?;
      final leaveDateStr = row['ngay_nghi_hoc'] as String?;

      if (joinDateStr != null && joinDateStr.isNotEmpty) {
        final dt = DateTime.tryParse(joinDateStr) ?? DateTime.now();
        items.add(
          StudentMembershipTimelineItem(
            id: 'join_${row['id']}',
            studentId: studentId,
            eventDateTime: dt,
            title: 'Tham gia lớp $className',
            summary: 'Chính thức vào học lớp $className',
            classId: classId,
            className: className,
            isJoin: true,
          ),
        );
      }

      if (leaveDateStr != null && leaveDateStr.isNotEmpty) {
        final dt = DateTime.tryParse(leaveDateStr) ?? DateTime.now();
        items.add(
          StudentMembershipTimelineItem(
            id: 'leave_${row['id']}',
            studentId: studentId,
            eventDateTime: dt,
            title: 'Rời lớp $className',
            summary: 'Đã hoàn tất / nghỉ học lớp $className',
            classId: classId,
            className: className,
            isJoin: false,
          ),
        );
      }
    }

    return items;
  }
}
