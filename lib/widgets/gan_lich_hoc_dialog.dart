// File: lib/widgets/gan_lich_hoc_dialog.dart

import 'package:flutter/material.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc_chung.dart';
import '../services/lich_hoc_chung_service.dart';
import '../utils/toast_helper.dart';

class GanLichHocDialog extends StatefulWidget {
  final LichHocChung lichHocChung;
  final List<HSLopViewModel> danhSachHocSinh;

  const GanLichHocDialog({
    super.key,
    required this.lichHocChung,
    required this.danhSachHocSinh,
  });

  @override
  State<GanLichHocDialog> createState() => _GanLichHocDialogState();
}

class _GanLichHocDialogState extends State<GanLichHocDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final _service = LichHocChungService();
  final Set<int> _selectedHocSinhIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // Màu sắc
  // static const Color darkBackground = Color(0xFF1A1A2E);
  // static const Color cardColor = Color(0xFF16213E);
  // static const Color lightText = Colors.white;
  // static const Color secondaryText = Colors.white70;
  // static const Color accentColor = Color(0xFF00BFA5); // Teal Accent

  @override
  void initState() {
    super.initState();
    _loadDanhSachDaGan();
  }

  Future<void> _loadDanhSachDaGan() async {
    setState(() => _isLoading = true);

    try {
      // Kiểm tra từng học sinh xem đã được gán lịch học này chưa
      for (var hs in widget.danhSachHocSinh) {
        if (hs.id != null) {
          final daGan = await _service.kiemTraHocSinhCoLichHoc(
            hs.id!,
            widget.lichHocChung.id!,
          );
          if (daGan) {
            _selectedHocSinhIds.add(hs.id!);
          }
        }
      }
    } catch (e) {
      debugPrint('Lỗi khi load danh sách đã gán: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _luuThayDoi() async {
    setState(() => _isSaving = true);

    try {
      int successCount = 0;
      int failCount = 0;

      // Duyệt qua tất cả học sinh
      for (var hs in widget.danhSachHocSinh) {
        if (hs.id == null) continue;

        final isSelected = _selectedHocSinhIds.contains(hs.id!);
        final daGan = await _service.kiemTraHocSinhCoLichHoc(
          hs.id!,
          widget.lichHocChung.id!,
        );

        if (isSelected && !daGan) {
          // Cần gán
          final result = await _service.ganLichHocChoHocSinh(
            hs.id!,
            widget.lichHocChung.id!,
          );
          if (result) {
            successCount++;
          } else {
            failCount++;
          }
        } else if (!isSelected && daGan) {
          // Cần hủy gán
          final result = await _service.huyGanLichHocChoHocSinh(
            hs.id!,
            widget.lichHocChung.id!,
          );
          if (result) {
            successCount++;
          } else {
            failCount++;
          }
        }
      }

      if (mounted) {
        final isVi = Localizations.localeOf(context).languageCode == 'vi';
        String message = '';
        if (successCount > 0 && failCount == 0) {
          message = isVi
              ? '✅ Cập nhật lịch học thành công cho $successCount học sinh!'
              : '✅ Schedule updated successfully for $successCount students!';
        } else if (successCount > 0 && failCount > 0) {
          message = isVi
              ? '⚠️ Cập nhật thành công $successCount, thất bại $failCount học sinh'
              : '⚠️ Updated successfully $successCount, failed $failCount students';
        } else if (failCount > 0) {
          message = isVi
              ? '❌ Cập nhật thất bại cho $failCount học sinh'
              : '❌ Update failed for $failCount students';
        } else {
          message = isVi ? 'ℹ️ Không có thay đổi nào' : 'ℹ️ No changes made';
        }

        if (failCount > 0) {
          ToastHelper.showWarning(context, message);
        } else {
          ToastHelper.showSuccess(context, message);
        }

        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        final isVi = Localizations.localeOf(context).languageCode == 'vi';
        ToastHelper.showError(context, isVi ? 'Lỗi: $e' : 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return AlertDialog(
      backgroundColor: cardColor,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVi ? 'GÁN LỊCH HỌC CHO HỌC SINH' : 'ASSIGN SCHEDULE TO STUDENTS',
            style: TextStyle(
              color: lightText,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: darkBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      widget.lichHocChung.ngayTrongTuan,
                      style: TextStyle(
                        color: lightText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.lichHocChung.gioBatDau} - ${widget.lichHocChung.gioKetThuc}',
                      style: TextStyle(color: secondaryText),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : widget.danhSachHocSinh.isEmpty
            ? Center(
                child: Text(
                  isVi
                      ? 'Không có học sinh nào trong lớp'
                      : 'No students in the class',
                  style: TextStyle(color: secondaryText),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      isVi
                          ? 'Chọn học sinh (${_selectedHocSinhIds.length}/${widget.danhSachHocSinh.length})'
                          : 'Select students (${_selectedHocSinhIds.length}/${widget.danhSachHocSinh.length})',
                      style: TextStyle(color: secondaryText, fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.danhSachHocSinh.length,
                      itemBuilder: (context, index) {
                        final hs = widget.danhSachHocSinh[index];
                        final isSelected = _selectedHocSinhIds.contains(hs.id);

                        return Card(
                          color: darkBackground,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true && hs.id != null) {
                                  _selectedHocSinhIds.add(hs.id!);
                                } else if (hs.id != null) {
                                  _selectedHocSinhIds.remove(hs.id!);
                                }
                              });
                            },
                            title: Text(
                              hs.ten,
                              style: TextStyle(color: lightText),
                            ),
                            subtitle: hs.sdt != null
                                ? Text(
                                    hs.sdt!,
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 12,
                                    ),
                                  )
                                : null,
                            activeColor: accentColor,
                            checkColor: lightText,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(
            isVi ? 'Hủy' : 'Cancel',
            style: TextStyle(color: secondaryText),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _luuThayDoi,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            disabledBackgroundColor: secondaryText,
          ),
          child: _isSaving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(lightText),
                  ),
                )
              : Text(
                  isVi ? 'Lưu' : 'Save',
                  style: TextStyle(color: darkBackground),
                ),
        ),
      ],
    );
  }
}
