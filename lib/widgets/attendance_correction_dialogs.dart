// File: lib/widgets/attendance_correction_dialogs.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/attendance_correction_service.dart';
import '../utils/toast_helper.dart';

class AttendanceCorrectionDialogs {
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color cardColor = Color(0xFF16213E);
  static const Color primaryAccent = Color(0xFF00BFA5);

  /// 1. Dialog Sửa Trạng Thái Điểm Danh 1 Học Sinh + Undo SnackBar
  static Future<void> showEditStatusDialog({
    required BuildContext context,
    required int attendanceId,
    required String studentName,
    required String currentStatus,
    required VoidCallback onRefreshed,
  }) async {
    final statuses = [
      'Có mặt',
      'Trễ',
      'Nghỉ có phép',
      'Nghỉ không phép',
      'Học bù',
    ];

    String selectedStatus = currentStatus;
    String selectedReason = 'Điểm danh nhầm';
    final reasonController = TextEditingController();

    final quickReasons = [
      'Điểm danh nhầm',
      'Học sinh đến muộn',
      'Phụ huynh đã xin phép',
      'Sửa theo yêu cầu',
      'Khác',
    ];

    bool isSubmitting = false;
    bool? confirmed = false;

    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sửa điểm danh: $studentName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Chọn trạng thái mới:',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: statuses.map((st) {
                      final isSelected = st == selectedStatus;
                      return ChoiceChip(
                        label: Text(st),
                        selected: isSelected,
                        selectedColor: primaryAccent,
                        backgroundColor: Colors.white10,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: isSubmitting
                            ? null
                            : (val) {
                                if (val) setDialogState(() => selectedStatus = st);
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Lý do điều chỉnh (Tùy chọn):',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: quickReasons.map((qr) {
                      final isSel = selectedReason == qr;
                      return ActionChip(
                        label: Text(
                          qr,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSel ? primaryAccent : Colors.white70,
                          ),
                        ),
                        backgroundColor: isSel
                            ? primaryAccent.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        onPressed: isSubmitting
                            ? null
                            : () {
                                setDialogState(() {
                                  selectedReason = qr;
                                  if (qr != 'Khác') reasonController.text = qr;
                                });
                              },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    enabled: !isSubmitting,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nhập ghi chú chi tiết...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: isSubmitting
                    ? null
                    : () {
                        setDialogState(() => isSubmitting = true);
                        Navigator.pop(ctx, true);
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Lưu thay đổi',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      );
    } finally {
      reasonController.dispose();
    }

    if (confirmed == true && context.mounted) {
      final oldStatus = currentStatus;
      final finalReason = reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : selectedReason;

      try {
        await AttendanceCorrectionService.instance.editStudentStatus(
          attendanceId: attendanceId,
          newStatus: selectedStatus,
          reason: finalReason,
        );
        onRefreshed();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Đã cập nhật điểm danh $studentName ($oldStatus → $selectedStatus)',
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'HOÀN TÁC',
                textColor: primaryAccent,
                onPressed: () async {
                  try {
                    await AttendanceCorrectionService.instance.editStudentStatus(
                      attendanceId: attendanceId,
                      newStatus: oldStatus,
                      reason: 'Hoàn tác sửa điểm danh',
                    );
                    onRefreshed();
                    if (context.mounted) {
                      ToastHelper.showSuccess(context, 'Đã hoàn tác về $oldStatus');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ToastHelper.showError(context, 'Lỗi hoàn tác: $e');
                    }
                  }
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Lỗi sửa điểm danh: $e');
        }
      }
    }
  }

  /// 2. Dialog Xóa Học Sinh Khỏi Buổi Điểm Danh
  static Future<void> showRemoveStudentDialog({
    required BuildContext context,
    required int attendanceId,
    required String studentName,
    required String sessionDateStr,
    required VoidCallback onRefreshed,
  }) async {
    final reasonController = TextEditingController(
      text: 'Học sinh được thêm nhầm vào buổi',
    );

    bool isSubmitting = false;
    bool? confirmed = false;

    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                SizedBox(width: 8),
                Text(
                  'Xác nhận xóa điểm danh',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn đang xóa điểm danh của $studentName khỏi buổi $sessionDateStr.',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dữ liệu liên quan sẽ xử lý:',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Điểm danh: 1 record',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        '• Đánh giá buổi học: Xóa cascade an toàn',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        '• Lịch sử chỉnh sửa: Ghi nhận audit log',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Lý do xóa:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonController,
                  enabled: !isSubmitting,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Lý do xóa...',
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () {
                        setDialogState(() => isSubmitting = true);
                        Navigator.pop(ctx, true);
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Xác nhận xóa',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      );
    } finally {
      reasonController.dispose();
    }

    if (confirmed == true && context.mounted) {
      try {
        await AttendanceCorrectionService.instance.removeStudentFromSession(
          attendanceId: attendanceId,
          reason: reasonController.text.trim(),
        );
        onRefreshed();
        if (context.mounted) {
          ToastHelper.showSuccess(context, 'Đã xóa điểm danh $studentName');
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Lỗi xóa điểm danh: $e');
        }
      }
    }
  }

  /// 3. Dialog Sửa Thông Tin Buổi Học (Ngày / Ca)
  static Future<void> showEditSessionDialog({
    required BuildContext context,
    required int classId,
    required String currentDateStr,
    String? currentStartTime,
    required VoidCallback onRefreshed,
  }) async {
    DateTime selectedDate = DateTime.tryParse(currentDateStr) ?? DateTime.now();
    final reasonController = TextEditingController(
      text: 'Chọn nhầm ngày buổi học',
    );

    bool isSubmitting = false;
    bool? confirmed = false;

    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.edit_calendar_rounded, color: primaryAccent),
                SizedBox(width: 8),
                Text(
                  'Sửa thông tin buổi học',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ngày học mới:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primaryAccent),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy').format(selectedDate),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today,
                          color: primaryAccent,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Lý do chỉnh sửa:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  enabled: !isSubmitting,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Lý do đổi ngày...',
                    filled: true,
                    fillColor: Colors.black26,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryAccent,
                  foregroundColor: Colors.black,
                ),
                onPressed: isSubmitting
                    ? null
                    : () {
                        setDialogState(() => isSubmitting = true);
                        Navigator.pop(ctx, true);
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Cập nhật cả buổi',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      );
    } finally {
      reasonController.dispose();
    }

    if (confirmed == true && context.mounted) {
      final newDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      if (newDateStr == currentDateStr) return;

      try {
        await AttendanceCorrectionService.instance.updateSessionDetails(
          classId: classId,
          oldDateStr: currentDateStr,
          newDateStr: newDateStr,
          oldStartTime: currentStartTime,
          reason: reasonController.text.trim(),
        );
        onRefreshed();
        if (context.mounted) {
          ToastHelper.showSuccess(
            context,
            'Đã đổi ngày buổi học sang $newDateStr',
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        if (e is StateError) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              backgroundColor: cardColor,
              title: const Text(
                'Không thể chuyển ngày',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                e.message,
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text(
                    'Đã hiểu',
                    style: TextStyle(color: primaryAccent),
                  ),
                ),
              ],
            ),
          );
        } else {
          ToastHelper.showError(context, 'Lỗi cập nhật buổi học: $e');
        }
      }
    }
  }

  /// 4. Dialog Hủy Cả Buổi Điểm Danh (Async getSessionImpact inside dialog)
  static Future<void> showCancelSessionDialog({
    required BuildContext context,
    required int classId,
    required String sessionDateStr,
    required String className,
    String? startTime,
    required VoidCallback onRefreshed,
  }) async {
    final reasonController = TextEditingController(text: 'Tạo nhầm buổi học');
    bool isSubmitting = false;
    bool? confirmed = false;

    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final impactFuture = AttendanceCorrectionService.instance.getSessionImpact(
            classId: classId,
            dateStr: sessionDateStr,
            startTime: startTime,
          );

          return StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.block_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    'HỦY BUỔI HỌC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sessionDateStr • $className',
                      style: const TextStyle(
                        color: primaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<SessionImpactSummary>(
                      future: impactFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Đang kiểm tra dữ liệu liên quan...',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Không thể tính tác động: ${snapshot.error}',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                            ),
                          );
                        }

                        final impact = snapshot.data!;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dữ liệu liên quan bị ảnh hưởng:',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '• ${impact.attendanceCount} điểm danh',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                '• ${impact.reviewCount} đánh giá học sinh',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                '• ${impact.homeworkCount} BTVN đã giao',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              Text(
                                '• ${impact.affectedStudentCount} học sinh được recompute signal',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Lý do hủy buổi:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      enabled: !isSubmitting,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Lý do hủy buổi...',
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
                  child: const Text('Không', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () {
                          setDialogState(() => isSubmitting = true);
                          Navigator.pop(ctx, true);
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Hủy buổi',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      reasonController.dispose();
    }

    if (confirmed == true && context.mounted) {
      try {
        await AttendanceCorrectionService.instance.cancelSession(
          classId: classId,
          dateStr: sessionDateStr,
          startTime: startTime,
          reason: reasonController.text.trim(),
        );
        onRefreshed();
        if (context.mounted) {
          ToastHelper.showSuccess(
            context,
            'Đã hủy buổi học ngày $sessionDateStr',
          );
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Lỗi hủy buổi học: $e');
        }
      }
    }
  }

  /// 5. Dialog Khôi Phục Buổi Học Đã Hủy
  static Future<void> showRestoreSessionDialog({
    required BuildContext context,
    required int classId,
    required String sessionDateStr,
    String? startTime,
    required VoidCallback onRefreshed,
  }) async {
    bool isSubmitting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.restore_page_rounded, color: primaryAccent),
              SizedBox(width: 8),
              Text(
                'Khôi phục buổi học',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Bạn có muốn khôi phục buổi học ngày $sessionDateStr?\n'
            'Điểm danh và dữ liệu liên quan sẽ hoạt động trở lại bình thường.',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: isSubmitting
                  ? null
                  : () {
                      setDialogState(() => isSubmitting = true);
                      Navigator.pop(ctx, true);
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Khôi phục',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await AttendanceCorrectionService.instance.restoreSession(
          classId: classId,
          dateStr: sessionDateStr,
          startTime: startTime,
          reason: 'Giáo viên chọn Khôi phục buổi học',
        );
        onRefreshed();
        if (context.mounted) {
          ToastHelper.showSuccess(
            context,
            'Đã khôi phục buổi học ngày $sessionDateStr',
          );
        }
      } catch (e) {
        if (context.mounted) {
          ToastHelper.showError(context, 'Lỗi khôi phục buổi học: $e');
        }
      }
    }
  }
}
