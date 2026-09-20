// File: lib/widgets/zalo_link_dialog.dart

import 'package:flutter/material.dart';
import '../models/hs.dart';
import '../services/hoc_sinh_service.dart';
import '../services/student_event_service.dart';
import '../services/zalo_contact_service.dart';
import '../utils/toast_helper.dart';

class ZaloLinkDialog extends StatefulWidget {
  final HS student;

  const ZaloLinkDialog({super.key, required this.student});

  @override
  State<ZaloLinkDialog> createState() => _ZaloLinkDialogState();
}

class _ZaloLinkDialogState extends State<ZaloLinkDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;

  late TextEditingController _tenPhuHuynhController;
  late TextEditingController _sdtPhuHuynhController;
  late TextEditingController _sdtHocSinhController;
  late TextEditingController _zaloNameController;
  late TextEditingController _zaloPhoneController;
  late TextEditingController _zaloLinkController;
  late TextEditingController _zaloNoteController;

  late String _currentStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tenPhuHuynhController = TextEditingController(
      text: widget.student.tenPhuHuynh,
    );
    _sdtPhuHuynhController = TextEditingController(
      text: widget.student.sdtPhuHuynh ?? widget.student.sdt,
    );
    _sdtHocSinhController = TextEditingController(
      text: widget.student.sdtHocSinh,
    );
    _zaloNameController = TextEditingController(
      text: widget.student.zaloDisplayName,
    );
    _zaloPhoneController = TextEditingController(
      text: widget.student.zaloPhone,
    );
    _zaloLinkController = TextEditingController(
      text: widget.student.zaloProfileLink,
    );
    _zaloNoteController = TextEditingController(text: widget.student.zaloNote);
    _currentStatus = widget.student.zaloLinkStatus;
  }

  @override
  void dispose() {
    _tenPhuHuynhController.dispose();
    _sdtPhuHuynhController.dispose();
    _sdtHocSinhController.dispose();
    _zaloNameController.dispose();
    _zaloPhoneController.dispose();
    _zaloLinkController.dispose();
    _zaloNoteController.dispose();
    super.dispose();
  }

  HS _buildUpdatedHS({String? forceStatus}) {
    final tenPhuHuynh = _tenPhuHuynhController.text.trim();
    final sdtPhuHuynh = _sdtPhuHuynhController.text.trim();
    final sdtHocSinh = _sdtHocSinhController.text.trim();
    final zaloName = _zaloNameController.text.trim();
    final zaloPhone = _zaloPhoneController.text.trim();
    final zaloLink = _zaloLinkController.text.trim();
    final zaloNote = _zaloNoteController.text.trim();

    String status = forceStatus ?? _currentStatus;
    if (status != 'VERIFIED') {
      if (zaloLink.isNotEmpty) {
        status = 'PROFILE_LINKED';
      } else if (zaloName.isNotEmpty || zaloNote.isNotEmpty) {
        status = 'MANUAL_NAME';
      } else if (sdtPhuHuynh.isNotEmpty || zaloPhone.isNotEmpty) {
        status = 'PHONE_AVAILABLE';
      } else {
        status = 'UNLINKED';
      }
    }

    final updated = widget.student.copyWith();
    updated.id = widget.student.id;
    updated.tenPhuHuynh = tenPhuHuynh.isEmpty ? null : tenPhuHuynh;
    updated.sdtPhuHuynh = sdtPhuHuynh.isEmpty ? null : sdtPhuHuynh;
    updated.sdt = sdtPhuHuynh.isEmpty ? widget.student.sdt : sdtPhuHuynh;
    updated.sdtHocSinh = sdtHocSinh.isEmpty ? null : sdtHocSinh;
    updated.zaloDisplayName = zaloName.isEmpty ? null : zaloName;
    updated.zaloPhone = zaloPhone.isEmpty ? null : zaloPhone;
    updated.zaloProfileLink = zaloLink.isEmpty ? null : zaloLink;
    updated.zaloNote = zaloNote.isEmpty ? null : zaloNote;
    updated.zaloLinkStatus = status;

    return updated;
  }

  Future<void> _handleSave({String? forceStatus}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final updatedHs = _buildUpdatedHS(forceStatus: forceStatus);
      final res = await HocSinhService().capNhatHocSinh(updatedHs);
      if (res > 0 && mounted) {
        StudentEventService().notifyStudentUpdated(updatedHs);
        ToastHelper.showSuccess(
          context,
          forceStatus == 'VERIFIED'
              ? '✓ Đã xác minh liên kết Zalo PH!'
              : 'Đã lưu thông tin Zalo PH!',
        );
        Navigator.of(context).pop(updatedHs);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi lưu thông tin Zalo: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildStatusHeader() {
    final effective = _buildUpdatedHS().effectiveZaloStatus;
    Color statusBgColor;
    String statusText;

    switch (effective) {
      case 'VERIFIED':
        statusBgColor = Colors.green;
        statusText = '✓ ĐÃ XÁC MINH PHỤ HUYNH';
        break;
      case 'PROFILE_LINKED':
        statusBgColor = Colors.blueAccent;
        statusText = '! ĐÃ LƯU LINK PROFILE';
        break;
      case 'MANUAL_NAME':
        statusBgColor = Colors.orangeAccent;
        statusText = '! CHỈ CÓ TÊN/GHI CHÚ ZALO';
        break;
      case 'PHONE_AVAILABLE':
        statusBgColor = Colors.amber.shade700;
        statusText = '! CÓ SĐT (CHƯA XÁC MINH ZALO)';
        break;
      default:
        statusBgColor = Colors.grey;
        statusText = '○ CHƯA LIÊN KẾT ZALO';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusBgColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusBgColor, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_rounded, color: statusBgColor, size: 18),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
              color: statusBgColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: accentColor.withValues(alpha: 0.2),
                  child: Text(
                    widget.student.ten.isNotEmpty
                        ? widget.student.ten[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIÊN KẾT ZALO PHỤ HUYNH',
                        style: TextStyle(
                          color: lightText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Học sinh: ${widget.student.ten}',
                        style: TextStyle(color: secondaryText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: secondaryText),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusHeader(),
            const SizedBox(height: 16),

            // Form inputs
            _buildTextField(
              _tenPhuHuynhController,
              'Tên Phụ Huynh (VD: Bố/Mẹ em ${widget.student.ten})',
              Icons.person_outline,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _sdtPhuHuynhController,
                    'SĐT Phụ Huynh',
                    Icons.phone,
                    isNumeric: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    _sdtHocSinhController,
                    'SĐT Học Sinh (nếu có)',
                    Icons.phone_android,
                    isNumeric: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    _zaloNameController,
                    'Tên Zalo (VD: Anh Tuấn)',
                    Icons.badge_outlined,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    _zaloPhoneController,
                    'SĐT Zalo (nếu khác)',
                    Icons.phone_paused_outlined,
                    isNumeric: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _zaloLinkController,
              'Link Profile Zalo / QR (VD: https://zalo.me/...)',
              Icons.link_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _zaloNoteController,
              'Ghi chú nhận diện (VD: Avatar áo xanh, nick mẹ)',
              Icons.note_alt_outlined,
              maxLines: 2,
            ),
            const SizedBox(height: 20),

            // Nút Thao Tác
            OutlinedButton.icon(
              onPressed: () {
                final tempHs = _buildUpdatedHS();
                ZaloContactService.instance.openParentZalo(context, tempHs);
              },
              icon: const Icon(
                Icons.open_in_new_rounded,
                color: Color(0xFF0068FF),
              ),
              label: const Text(
                'MỞ ZALO THỬ NGHIỆM / TÌM KIẾM',
                style: TextStyle(
                  color: Color(0xFF0068FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0068FF)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => _handleSave(forceStatus: 'VERIFIED'),
                    icon: const Icon(Icons.verified_user_rounded, size: 18),
                    label: const Text(
                      'XÁC NHẬN (✓)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _handleSave(),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text(
                      'LƯU THÔNG TIN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: darkBackground,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumeric = false,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.phone : TextInputType.text,
      style: TextStyle(color: lightText, fontSize: 14),
      maxLines: maxLines,
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        labelStyle: TextStyle(color: secondaryText, fontSize: 13),
        prefixIcon: Icon(icon, color: secondaryText, size: 18),
        filled: true,
        fillColor: darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 12,
        ),
      ),
    );
  }
}
