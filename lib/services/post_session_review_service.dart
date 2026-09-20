// File: lib/services/post_session_review_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/danh_gia_buoi_hoc.dart';
import '../models/diem_danh.dart';
import '../models/nhiem_vu.dart';
import '../models/post_session_review.dart';
import '../models/lop.dart';
import '../models/lich_hoc.dart';
import '../screens/post_session_review_page.dart';
import '../utils/db.dart';
import 'danh_gia_buoi_hoc_service.dart';
import 'diem_danh_service.dart';
import 'nhiem_vu_service.dart';
import 'lop_hoc_sinh_service.dart';

class PostSessionReviewService {
  static final PostSessionReviewService instance = PostSessionReviewService();
  static const String tenBangComm = 'parent_communications';

  Future<Database> get _database async {
    final db = await DBHelper.instance.database;
    await _ensureTableExists(db);
    return db;
  }

  /// Helper mở màn hình đánh giá buổi học an toàn không query DB trực tiếp từ UI
  Future<void> openPostSessionReviewScreen(
    BuildContext context, {
    required int classId,
    int? scheduleId,
    required DateTime date,
  }) async {
    try {
      final db = await DBHelper.instance.database;
      final lopRows = await db.query(
        DBHelper.tenBangLop,
        where: 'id = ?',
        whereArgs: [classId],
      );
      if (lopRows.isEmpty) {
        throw Exception('Không tìm thấy thông tin lớp học ($classId)');
      }
      final lop = Lop.fromMap(lopRows.first);

      final lhcRows = await db.query(
        DBHelper.tenBangLichHocChung,
        where: 'id_lop = ?',
        whereArgs: [classId],
      );
      if (lhcRows.isEmpty) {
        throw Exception('Lớp ${lop.ten} chưa có lịch học nào.');
      }

      Map<String, dynamic> schMap = lhcRows.first;
      if (scheduleId != null) {
        final match = lhcRows.where((r) => r['id'] == scheduleId);
        if (match.isNotEmpty) schMap = match.first;
      }
      final caHoc = LichHoc.fromMap(schMap);

      final dsHS = await LopHocSinhService().docDSHSTheoCaHoc(caHoc.id!);

      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final attRows = await db.query(
        DBHelper.tenBangDiemDanh,
        where: 'id_lop = ? AND gio_diem_danh LIKE ?',
        whereArgs: [classId, '$dateStr%'],
      );

      final Map<String, String> currentAttMap = {};
      for (var r in attRows) {
        final hsId = r['id_hoc_sinh'];
        final st = r['trang_thai']?.toString() ?? 'Có mặt';
        currentAttMap['$hsId-${caHoc.id}'] = st;
      }

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostSessionReviewPage(
            lop: lop,
            caHoc: caHoc,
            date: date,
            danhSachHS: dsHS,
            currentAttendanceStatus: currentAttMap,
          ),
        ),
      );
    } catch (e, st) {
      developer.log(
        'Lỗi mở màn hình đánh giá buổi học',
        name: 'PostSessionReviewService',
        error: e,
        stackTrace: st,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở đánh giá buổi học: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _ensureTableExists(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tenBangComm (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_hoc_sinh INTEGER NOT NULL,
        ten_hoc_sinh TEXT NOT NULL,
        id_lop INTEGER NOT NULL,
        ten_lop TEXT NOT NULL,
        ngay_hoc TEXT NOT NULL,
        gio_hoc TEXT NOT NULL,
        sdt_phu_huynh TEXT,
        ly_do TEXT NOT NULL,
        loai_tin_nhan TEXT NOT NULL DEFAULT 'POST_SESSION_REVIEW',
        noi_dung TEXT NOT NULL,
        trang_thai TEXT NOT NULL DEFAULT 'READY',
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_parent_comm_hs_lop_session '
      'ON $tenBangComm (id_hoc_sinh, id_lop, ngay_hoc, gio_hoc)',
    );
  }

  /// Tự động sinh nội dung tin nhắn gửi phụ huynh từ dữ liệu có cấu trúc & template
  static String generateMessage({
    required StudentReviewData review,
    required String className,
    required DateTime date,
    required String timeSlot,
    String? homeworkContent,
    String? homeworkDueDate,
    String? customTemplate,
  }) {
    final dateStr = DateFormat('dd/MM/yyyy').format(date);

    if (review.isUnexcusedAbsent) {
      return 'Em ${review.studentName} vắng buổi học $dateStr lúc $timeSlot (lớp $className) và hệ thống chưa ghi nhận đơn xin nghỉ. Thầy gửi thông tin để PH nắm tình hình.';
    }

    if (customTemplate != null && customTemplate.trim().isNotEmpty) {
      String msg = customTemplate;
      msg = msg.replaceAll('{TEN_HS}', review.studentName);
      msg = msg.replaceAll('{TEN_LOP}', className);
      msg = msg.replaceAll('{NGAY_HOC}', dateStr);
      msg = msg.replaceAll('{GIO_HOC}', timeSlot);
      msg = msg.replaceAll('{THAI_DO}', review.thaiDo);
      msg = msg.replaceAll('{BAI_CU}', review.baiCu);
      msg = msg.replaceAll('{BAI_TAP}', review.baiTap);
      msg = msg.replaceAll('{TIEP_THU}', review.tiepThu);
      msg = msg.replaceAll(
        '{BTVN}',
        (homeworkContent != null && homeworkContent.isNotEmpty)
            ? homeworkContent
            : 'Không có',
      );
      msg = msg.replaceAll(
        '{HAN_BTVN}',
        (homeworkDueDate != null && homeworkDueDate.isNotEmpty)
            ? homeworkDueDate
            : 'Buổi học tiếp theo',
      );
      msg = msg.replaceAll('{NHAC_NHO}', review.attentionReason);
      return msg;
    }

    final bool isNormal = !review.isAttentionNeeded;

    if (isNormal) {
      final String hwText =
          (homeworkContent != null && homeworkContent.trim().isNotEmpty)
          ? '\n\nBTVN: $homeworkContent\nHạn: ${homeworkDueDate ?? 'buổi học tiếp theo'}.'
          : '';
      return 'Kính gửi PH em ${review.studentName}.\n'
          'Buổi học ngày $dateStr ($timeSlot), em đi học đầy đủ, thái độ học tập ${review.thaiDo.toLowerCase()}, chuẩn bị bài cũ ${review.baiCu.toLowerCase()} và hoàn thành bài tập ${review.baiTap.toLowerCase()}. Khả năng tiếp thu bài ${review.tiepThu.toLowerCase()}.$hwText';
    } else {
      final List<String> issues = [];
      if (review.baiTap != 'Đầy đủ')
        issues.add('bài tập về nhà ${review.baiTap.toLowerCase()}');
      if (review.baiCu != 'Đã chuẩn bị')
        issues.add('bài cũ ${review.baiCu.toLowerCase()}');
      if (review.thaiDo != 'Tốt')
        issues.add('thái độ học tập ${review.thaiDo.toLowerCase()}');
      if (review.tiepThu != 'Tốt')
        issues.add('tiếp thu bài ${review.tiepThu.toLowerCase()}');

      final String issueStr = issues.isNotEmpty
          ? issues.join(', ')
          : review.attentionReason;
      final String hwText =
          (homeworkContent != null && homeworkContent.trim().isNotEmpty)
          ? '\n\nBTVN: $homeworkContent\nHạn: ${homeworkDueDate ?? 'buổi học tiếp theo'}.'
          : '';

      return 'Kính gửi PH em ${review.studentName}.\n'
          'Buổi học ngày $dateStr ($timeSlot), em đi học đầy đủ nhưng cần lưu ý: $issueStr.'
          '\n\nThầy đã nhắc em hoàn thành bổ sung và tập trung hơn.$hwText'
          '\nMong PH phối hợp nhắc em chuẩn bị đầy đủ trước buổi học tiếp theo.';
    }
  }

  /// Lưu kết quả Đánh giá ca + Lưu Nhiệm vụ bài tập về nhà
  Future<void> savePostSessionBatchReview({
    required int classId,
    required DateTime date,
    required String timeSlot, // '17:30'
    required List<StudentReviewData> reviews,
    String? homeworkContent,
    String? homeworkDueDate,
    List<String> homeworkTags = const [],
  }) async {
    final db = await _database;
    final diemDanhService = DiemDanhService();
    final danhGiaService = DanhGiaBuoiHocService();
    final nhiemVuService = NhiemVuService();

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final gioDiemDanhStr = '$dateStr $timeSlot';

    await db.transaction((txn) async {
      // 1. Lưu điểm danh & Đánh giá buổi học từng học sinh
      for (var r in reviews) {
        final record = DiemDanh(
          idHocSinh: r.studentId,
          idLop: classId,
          gioDiemDanh: gioDiemDanhStr,
          trangThai: r.attendanceStatus,
          ghiChu: r.customNote,
        );

        final ddId = await diemDanhService.safeUpsertDiemDanhTxn(txn, record);

        if (ddId > 0 && !r.isAbsent) {
          // Tính điểm quy đổi
          double diemThaiDo = 10.0;
          if (r.thaiDo == 'Khá') diemThaiDo = 8.0;
          if (r.thaiDo == 'Cần nhắc' ||
              r.thaiDo == 'Mất tập trung' ||
              r.thaiDo == 'Nói chuyện')
            diemThaiDo = 6.0;

          double diemHieuBai = 10.0;
          if (r.tiepThu == 'Khá') diemHieuBai = 8.0;
          if (r.tiepThu == 'Cần củng cố') diemHieuBai = 6.0;

          double diemBaiTap = 10.0;
          if (r.baiTap == 'Thiếu') diemBaiTap = 5.0;
          if (r.baiTap == 'Không làm') diemBaiTap = 0.0;

          final jsonPayload = jsonEncode({
            'thaiDo': r.thaiDo,
            'baiCu': r.baiCu,
            'baiTap': r.baiTap,
            'tiepThu': r.tiepThu,
            'canPh': r.canPhPhoiHop,
            'note': r.customNote ?? '',
          });

          final dgRecord = DanhGiaBuoiHoc(
            idDiemDanh: ddId,
            diemThaiDo: diemThaiDo,
            diemHieuBai: diemHieuBai,
            diemBaiTap: diemBaiTap,
            nhanXet: jsonPayload,
          );

          await txn.insert(
            DBHelper.tenBangDanhGiaBuoiHoc,
            dgRecord.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    // 2. Lưu Nhiệm vụ (BTVN) nếu có nhập
    if (homeworkContent != null && homeworkContent.trim().isNotEmpty) {
      final combinedContent = homeworkTags.isNotEmpty
          ? '${homeworkContent.trim()} (${homeworkTags.join(", ")})'
          : homeworkContent.trim();

      final dueDateStr = homeworkDueDate ?? 'Buổi học tiếp theo';
      final nv = NhiemVu(
        idLop: classId,
        tenNhiemVu: combinedContent,
        ngayGiao: dateStr,
        ngayNop: dueDateStr,
      );
      await nhiemVuService.themNhiemVu(nv);
    }
  }

  /// Lấy danh sách hàng đợi thông báo phụ huynh (Lọc thông minh + Không gửi trùng)
  Future<List<ParentCommunicationRecord>> getPendingCommunicationQueue({
    required int classId,
    required String className,
    required DateTime date,
    required String timeSlot,
    required List<StudentReviewData> reviews,
    String? homeworkContent,
    String? homeworkDueDate,
    String? customTemplate,
  }) async {
    final db = await _database;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    // 1. Quét danh sách đã gửi thành công trước đó (SENT_MANUALLY_CONFIRMED)
    final List<Map<String, dynamic>> sentRows = await db.query(
      tenBangComm,
      where: 'id_lop = ? AND ngay_hoc = ? AND gio_hoc = ? AND trang_thai = ?',
      whereArgs: [classId, dateStr, timeSlot, 'SENT_MANUALLY_CONFIRMED'],
    );

    final Set<int> sentStudentIds = sentRows
        .map((r) => r['id_hoc_sinh'] as int)
        .toSet();

    final List<ParentCommunicationRecord> queue = [];

    // 2. Chỉ lọc những học sinh CẦN CHÚ Ý và CHƯA GỬI XÁC NHẬN
    for (var r in reviews) {
      if (sentStudentIds.contains(r.studentId)) continue; // Không gửi trùng!

      if (r.isAttentionNeeded) {
        final message = generateMessage(
          review: r,
          className: className,
          date: date,
          timeSlot: timeSlot,
          homeworkContent: homeworkContent,
          homeworkDueDate: homeworkDueDate,
          customTemplate: customTemplate,
        );

        queue.add(
          ParentCommunicationRecord(
            studentId: r.studentId,
            studentName: r.studentName,
            classId: classId,
            className: className,
            sessionDate: dateStr,
            sessionTime: timeSlot,
            parentPhone: r.phone,
            reason: r.attentionReason,
            messageType: r.isUnexcusedAbsent
                ? 'ABSENT_ALERT'
                : 'POST_SESSION_REVIEW',
            messageContent: message,
            status: 'READY',
            createdAt: nowStr,
          ),
        );
      }
    }

    return queue;
  }

  /// Đánh dấu bản ghi đã được giáo viên gửi thủ công qua Zalo (SENT_MANUALLY_CONFIRMED)
  Future<int> markAsSentManuallyConfirmed(
    ParentCommunicationRecord record,
  ) async {
    final db = await _database;
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final updatedRecord = record.copyWith(
      status: 'SENT_MANUALLY_CONFIRMED',
      createdAt: nowStr,
    );

    if (record.id != null) {
      return await db.update(
        tenBangComm,
        updatedRecord.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
    } else {
      return await db.insert(
        tenBangComm,
        updatedRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Đánh dấu bỏ qua bản ghi (SKIPPED)
  Future<int> markAsSkipped(ParentCommunicationRecord record) async {
    final db = await _database;
    final updatedRecord = record.copyWith(status: 'SKIPPED');

    if (record.id != null) {
      return await db.update(
        tenBangComm,
        updatedRecord.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
    } else {
      return await db.insert(
        tenBangComm,
        updatedRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
}
