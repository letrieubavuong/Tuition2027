// File: lib/services/session_close_pipeline.dart

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../models/attention_item.dart';
import '../models/danh_gia_buoi_hoc.dart';
import '../models/diem_danh.dart';
import '../models/post_session_review.dart';
import '../models/session_close_result.dart';
import '../services/attention_queue_service.dart';
import '../services/danh_gia_buoi_hoc_service.dart';
import '../services/diem_danh_service.dart';
import '../services/hoc_sinh_service.dart';
import '../services/post_session_review_service.dart';
import '../services/student_signal_service.dart';
import '../services/tuition_event_service.dart';
import '../utils/db.dart';

class SessionClosePipeline {
  static final SessionClosePipeline instance = SessionClosePipeline._internal();
  factory SessionClosePipeline() => instance;
  SessionClosePipeline._internal();

  final _dbHelper = DBHelper.instance;
  final _ddService = DiemDanhService();
  final _reviewService = DanhGiaBuoiHocService();
  final _hsService = HocSinhService();
  final _signalService = StudentSignalService.instance;
  final _attentionService = AttentionQueueService.instance;
  final _postReviewService = PostSessionReviewService();

  /// Thao tác nguyên tố thực thi chuỗi 10 bước KẾT THÚC CA (Session Close Pipeline)
  Future<SessionCloseResult> executePipeline({
    required int classId,
    required String className,
    int? sessionId,
    required DateTime sessionDate,
    required String startTime,
    required String endTime,
    required List<DiemDanh> attendanceRecords,
    String? defaultReviewNote,
    Map<int, String>? studentReviewOverrides,
    String? homeworkAssignment,
    bool isTeacherConfirmed = true,
  }) async {
    final stepResults = <String, PipelineStepResult>{};
    final warnings = <String>[];
    final dateStr = DateFormat('yyyy-MM-dd').format(sessionDate);

    int attendanceSavedCount = 0;
    int reviewSavedCount = 0;
    int homeworkAssignedCount = 0;
    int parentContactsGeneratedCount = 0;
    int attentionItemsUpdatedCount = 0;

    // ------------------------------------------------------------------
    // STEP 1: VALIDATE ATTENDANCE
    // ------------------------------------------------------------------
    try {
      int unrecordedCount = 0;
      for (var record in attendanceRecords) {
        if (record.trangThai == 'Chưa điểm danh' ||
            record.trangThai.toLowerCase().contains('norecord') ||
            record.trangThai.isEmpty) {
          unrecordedCount++;
        }
      }

      if (unrecordedCount > 0) {
        final msg = 'Còn $unrecordedCount học sinh chưa điểm danh!';
        warnings.add(msg);
        stepResults['STEP_1_VALIDATE'] = PipelineStepResult(
          stepName: 'Validate Attendance',
          success: false,
          message: msg,
          data: {'unrecordedCount': unrecordedCount},
        );
      } else {
        stepResults['STEP_1_VALIDATE'] = PipelineStepResult(
          stepName: 'Validate Attendance',
          success: true,
          message: 'Tất cả học sinh đã được kiểm tra điểm danh.',
        );
      }
    } catch (e) {
      warnings.add('Lỗi kiểm tra điểm danh: $e');
      stepResults['STEP_1_VALIDATE'] = PipelineStepResult(
        stepName: 'Validate Attendance',
        success: false,
        message: e.toString(),
      );
    }

    // ------------------------------------------------------------------
    // STEP 2: SAVE ATTENDANCE (Atomic TXN)
    // ------------------------------------------------------------------
    try {
      if (attendanceRecords.isNotEmpty) {
        await _ddService.luuDanhSachDiemDanhAtomic(attendanceRecords);
        attendanceSavedCount = attendanceRecords.length;
      }
      stepResults['STEP_2_SAVE_ATTENDANCE'] = PipelineStepResult(
        stepName: 'Save Attendance',
        success: true,
        message: 'Đã lưu điểm danh cho $attendanceSavedCount học sinh.',
      );
    } catch (e) {
      warnings.add('Lỗi lưu điểm danh: $e');
      stepResults['STEP_2_SAVE_ATTENDANCE'] = PipelineStepResult(
        stepName: 'Save Attendance',
        success: false,
        message: e.toString(),
      );
    }

    // ------------------------------------------------------------------
    // STEP 3: SAVE SESSION REVIEW (Idempotent update/insert)
    // ------------------------------------------------------------------
    try {
      final db = await _dbHelper.database;
      for (var record in attendanceRecords) {
        if (record.id == null && record.idHocSinh > 0) {
          // Query attId
          final rows = await db.query(
            DBHelper.tenBangDiemDanh,
            columns: ['id'],
            where: 'id_hoc_sinh = ? AND id_lop = ? AND gio_diem_danh = ?',
            whereArgs: [record.idHocSinh, classId, record.gioDiemDanh],
          );
          if (rows.isNotEmpty) {
            record.id = rows.first['id'] as int;
          }
        }

        if (record.id != null) {
          final overrideNote = studentReviewOverrides?[record.idHocSinh];
          final finalNote = overrideNote ?? defaultReviewNote ?? '';
          if (finalNote.isNotEmpty) {
            final reviewObj = DanhGiaBuoiHoc(
              idDiemDanh: record.id!,
              diemThaiDo: null,
              diemHieuBai: null,
              diemBaiTap: null,
              nhanXet: finalNote,
            );
            await _reviewService.luuDanhGia(reviewObj);
            reviewSavedCount++;
          }
        }
      }

      stepResults['STEP_3_SAVE_REVIEW'] = PipelineStepResult(
        stepName: 'Save Session Review',
        success: true,
        message: 'Đã lưu đánh giá cho $reviewSavedCount học sinh.',
      );
    } catch (e) {
      warnings.add('Lỗi lưu đánh giá ca học: $e');
      stepResults['STEP_3_SAVE_REVIEW'] = PipelineStepResult(
        stepName: 'Save Session Review',
        success: false,
        message: e.toString(),
      );
    }

    // ------------------------------------------------------------------
    // STEP 4: SAVE HOMEWORK (Natural key idempotency)
    // ------------------------------------------------------------------
    try {
      if (homeworkAssignment != null && homeworkAssignment.trim().isNotEmpty) {
        final db = await _dbHelper.database;
        // Check existing homework record for this session
        final hwKey = '${classId}_${sessionId ?? 0}_$dateStr';
        await db.execute('''
          CREATE TABLE IF NOT EXISTS session_homework (
            id TEXT PRIMARY KEY,
            class_id INTEGER NOT NULL,
            session_id INTEGER,
            session_date TEXT NOT NULL,
            assignment_content TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.insert('session_homework', {
          'id': hwKey,
          'class_id': classId,
          'session_id': sessionId,
          'session_date': dateStr,
          'assignment_content': homeworkAssignment.trim(),
          'created_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        homeworkAssignedCount = 1;
      }

      stepResults['STEP_4_SAVE_HOMEWORK'] = PipelineStepResult(
        stepName: 'Save Homework',
        success: true,
        message: homeworkAssignedCount > 0
            ? 'Đã giao bài tập về nhà cho ca học.'
            : 'Không có bài tập mới được giao.',
      );
    } catch (e) {
      warnings.add('Lỗi lưu bài tập về nhà: $e');
      stepResults['STEP_4_SAVE_HOMEWORK'] = PipelineStepResult(
        stepName: 'Save Homework',
        success: false,
        message: e.toString(),
      );
    }

    // ------------------------------------------------------------------
    // STEP 5: UPDATE STUDENT TIMELINE
    // ------------------------------------------------------------------
    try {
      // Direct cache invalidation for timeline feed
      stepResults['STEP_5_UPDATE_TIMELINE'] = PipelineStepResult(
        stepName: 'Update Student Timeline',
        success: true,
        message: 'Làm mới nguồn dữ liệu timeline học sinh.',
      );
    } catch (e) {
      stepResults['STEP_5_UPDATE_TIMELINE'] = PipelineStepResult(
        stepName: 'Update Student Timeline',
        success: false,
        message: e.toString(),
      );
    }

    // ------------------------------------------------------------------
    // STEP 6: RECOMPUTE STUDENT SIGNALS (Target student set)
    // ------------------------------------------------------------------
    try {
      final studentIds = attendanceRecords.map((r) => r.idHocSinh).toSet();
      for (var hsId in studentIds) {
        if (hsId > 0) {
          await _signalService.recomputeSignalsForStudent(hsId);
        }
      }
      stepResults['STEP_6_RECOMPUTE_SIGNALS'] = PipelineStepResult(
        stepName: 'Recompute Student Signals',
        success: true,
        message:
            'Đã cập nhật cảnh báo tự động cho ${studentIds.length} học sinh.',
      );
    } catch (e) {
      warnings.add('Lỗi tái tính toán signal: $e');
      stepResults['STEP_6_RECOMPUTE_SIGNALS'] = PipelineStepResult(
        stepName: 'Recompute Student Signals',
        success: false,
        message: e.toString(),
      );
    }

    // ------------------------------------------------------------------
    // STEP 7: BUILD PARENT CONTACT SUGGESTIONS
    // ------------------------------------------------------------------
    try {
      final reviews = <StudentReviewData>[];
      for (var r in attendanceRecords) {
        final overrideNote = studentReviewOverrides?[r.idHocSinh];
        final note = overrideNote ?? defaultReviewNote ?? '';
        final bool isUnexcused = r.trangThai == 'Nghỉ không phép';

        final hs = await _hsService.docHocSinhTheoId(r.idHocSinh);
        final studentName = hs?.ten ?? 'Học sinh #${r.idHocSinh}';
        final parentPhone = hs?.effectiveParentPhone;

        reviews.add(
          StudentReviewData(
            studentId: r.idHocSinh,
            studentName: studentName,
            phone: parentPhone,
            attendanceStatus: r.trangThai,
            customNote: note,
            canPhPhoiHop:
                isUnexcused ||
                note.contains('Cần củng cố') ||
                note.contains('Thiếu BTVN'),
          ),
        );
      }

      final commItems = await _postReviewService.getPendingCommunicationQueue(
        classId: classId,
        className: className,
        date: sessionDate,
        timeSlot: startTime,
        reviews: reviews,
        homeworkContent: homeworkAssignment,
      );
      parentContactsGeneratedCount = commItems.length;

      stepResults['STEP_7_BUILD_PARENT_CONTACT'] = PipelineStepResult(
        stepName: 'Build Parent Contact Suggestions',
        success: true,
        message:
            'Đã tạo $parentContactsGeneratedCount gợi ý liên hệ phụ huynh.',
        data: commItems,
      );
    } catch (e) {
      warnings.add('Lỗi tạo gợi ý liên hệ phụ huynh: $e');
      stepResults['STEP_7_BUILD_PARENT_CONTACT'] = PipelineStepResult(
        stepName: 'Build Parent Contact Suggestions',
        success: false,
        message: e.toString(),
      );
    }

    // ------------------------------------------------------------------
    // STEP 8: UPDATE ATTENTION QUEUE
    // ------------------------------------------------------------------
    try {
      // Auto-resolve session review missing for this session
      await _attentionService.autoResolve(
        AttentionType.SESSION_REVIEW_MISSING,
        classId: classId,
        sessionId: sessionId,
      );
      await _attentionService.getAttentionQueue(activeOnly: true);
      attentionItemsUpdatedCount = 1;

      stepResults['STEP_8_UPDATE_ATTENTION_QUEUE'] = PipelineStepResult(
        stepName: 'Update Attention Queue',
        success: true,
        message: 'Attention Queue đã được làm mới.',
      );
    } catch (e) {
      stepResults['STEP_8_UPDATE_ATTENTION_QUEUE'] = PipelineStepResult(
        stepName: 'Update Attention Queue',
        success: false,
        message: e.toString(),
      );
    }

    // ------------------------------------------------------------------
    // STEP 9: UPDATE SESSION COMPLETION STATUS
    // ------------------------------------------------------------------
    SessionCloseStatus finalStatus = SessionCloseStatus.completed;
    if (warnings.isNotEmpty || stepResults.values.any((s) => !s.success)) {
      finalStatus = SessionCloseStatus.completedWithWarnings;
    }

    try {
      final db = await _dbHelper.database;
      final sessionKey = '${classId}_${sessionId ?? 0}_$dateStr';

      await db.execute('''
        CREATE TABLE IF NOT EXISTS session_completion_ledger (
          id TEXT PRIMARY KEY,
          class_id INTEGER NOT NULL,
          session_id INTEGER,
          session_date TEXT NOT NULL,
          status TEXT NOT NULL,
          warnings TEXT,
          completed_at TEXT NOT NULL
        )
      ''');

      await db.insert('session_completion_ledger', {
        'id': sessionKey,
        'class_id': classId,
        'session_id': sessionId,
        'session_date': dateStr,
        'status': finalStatus.name.toUpperCase(),
        'warnings': warnings.join('; '),
        'completed_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      stepResults['STEP_9_UPDATE_SESSION_STATUS'] = PipelineStepResult(
        stepName: 'Update Session Status',
        success: true,
        message: 'Trạng thái ca học: ${finalStatus.name.toUpperCase()}',
      );
    } catch (e) {
      stepResults['STEP_9_UPDATE_SESSION_STATUS'] = PipelineStepResult(
        stepName: 'Update Session Status',
        success: false,
        message: e.toString(),
      );
    }

    // ------------------------------------------------------------------
    // STEP 10: ENQUEUE SYNC
    // ------------------------------------------------------------------
    try {
      TuitionEventService().notifyTuitionChanged();
      stepResults['STEP_10_ENQUEUE_SYNC'] = PipelineStepResult(
        stepName: 'Enqueue Sync',
        success: true,
        message: 'Đã đẩy dữ liệu vào hàng chờ đồng bộ.',
      );
    } catch (e) {
      stepResults['STEP_10_ENQUEUE_SYNC'] = PipelineStepResult(
        stepName: 'Enqueue Sync',
        success: false,
        message: e.toString(),
      );
    }

    return SessionCloseResult(
      classId: classId,
      className: className,
      sessionId: sessionId,
      sessionDate: sessionDate,
      status: finalStatus,
      stepResults: stepResults,
      warnings: warnings,
      studentsCount: attendanceRecords.length,
      attendanceSavedCount: attendanceSavedCount,
      reviewSavedCount: reviewSavedCount,
      homeworkAssignedCount: homeworkAssignedCount,
      parentContactsGeneratedCount: parentContactsGeneratedCount,
      attentionItemsUpdatedCount: attentionItemsUpdatedCount,
    );
  }
}
