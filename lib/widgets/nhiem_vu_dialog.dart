// File: lib/widgets/nhiem_vu_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/nhiem_vu.dart';

// --- Hằng số màu sắc ---
// const Color darkBackground = Color(0xFF1A1A2E);
// const Color cardColor = Color(0xFF16213E);
// const Color lightText = Colors.white;
// const Color secondaryText = Colors.white70;
// const Color accentColor = Color(0xFF00BFA5);

class NhiemVuDialog extends StatefulWidget {
  final NhiemVu? nhiemVu;
  final Function(NhiemVu) onSave;

  const NhiemVuDialog({super.key, this.nhiemVu, required this.onSave});

  @override
  State<NhiemVuDialog> createState() => _NhiemVuDialogState();
}

class _NhiemVuDialogState extends State<NhiemVuDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tenController;
  late DateTime _ngayGiao;
  late DateTime _ngayNop;

  // SỬA: Xác định chế độ sửa dựa trên ID, không phải sự tồn tại của đối tượng
  bool get _isEditing => widget.nhiemVu?.id != null;

  @override
  void initState() {
    super.initState();
    _tenController = TextEditingController(
      text: widget.nhiemVu?.tenNhiemVu ?? '',
    );
    // SỬA: Chỉ parse ngày tháng khi ở chế độ sửa, ngược lại dùng ngày hiện tại
    _ngayGiao = _isEditing
        ? DateTime.parse(widget.nhiemVu!.ngayGiao)
        : DateTime.now();
    _ngayNop = _isEditing
        ? DateTime.parse(widget.nhiemVu!.ngayNop)
        : DateTime.now().add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _tenController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context, bool isNgayGiao) async {
    final initialDate = isNgayGiao ? _ngayGiao : _ngayNop;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              onPrimary: darkBackground,
              surface: cardColor,
              onSurface: lightText,
            ),
            dialogBackgroundColor: cardColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != initialDate) {
      setState(() {
        if (isNgayGiao) {
          _ngayGiao = picked;
        } else {
          _ngayNop = picked;
        }
      });
    }
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final nhiemVuMoi = NhiemVu(
        id: widget.nhiemVu?.id,
        // SỬA: Lấy idLop từ widget.nhiemVu, vì nó luôn được truyền vào
        idLop: widget.nhiemVu!.idLop,
        tenNhiemVu: _tenController.text.trim(),
        ngayGiao: DateFormat('yyyy-MM-dd').format(_ngayGiao),
        ngayNop: DateFormat('yyyy-MM-dd').format(_ngayNop),
      );
      widget.onSave(nhiemVuMoi);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Center(
        child: Text(
          _isEditing 
              ? (isVi ? 'SỬA NHIỆM VỤ' : 'EDIT TASK') 
              : (isVi ? 'THÊM NHIỆM VỤ' : 'ADD TASK'),
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _tenController,
                autofocus: true,
                style: TextStyle(color: lightText),
                decoration: InputDecoration(
                  labelText: isVi ? 'Tên nhiệm vụ' : 'Task Name',
                  labelStyle: TextStyle(color: secondaryText),
                  prefixIcon: Icon(
                    Icons.assignment,
                    color: secondaryText,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: darkBackground,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isVi ? 'Vui lòng nhập tên nhiệm vụ' : 'Please enter task name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildDatePicker(
                isVi ? 'Ngày giao' : 'Assigned Date',
                _ngayGiao,
                () => _pickDate(context, true),
              ),
              const SizedBox(height: 20),
              _buildDatePicker(
                isVi ? 'Ngày nộp' : 'Due Date',
                _ngayNop,
                () => _pickDate(context, false),
              ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(isVi ? 'HỦY' : 'CANCEL', style: TextStyle(color: secondaryText)),
        ),
        ElevatedButton.icon(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: darkBackground,
          ),
          icon: const Icon(Icons.save),
          label: Text(isVi ? 'LƯU' : 'SAVE'),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime date, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryText),
          prefixIcon: Icon(Icons.calendar_month, color: secondaryText),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: darkBackground,
        ),
        child: Text(
          // SỬA: Chuẩn hóa định dạng ngày
          DateFormat('dd/MM/yyyy').format(date),
          style: TextStyle(
            color: lightText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
