// File: lib/widgets/dang_ky_nghi_le_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lop.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../utils/toast_helper.dart';

class DangKyNghiLeDialog extends StatefulWidget {
  final Lop lop;
  final List<HSLopViewModel> danhSachHocSinh;

  const DangKyNghiLeDialog({
    super.key,
    required this.lop,
    required this.danhSachHocSinh,
  });

  @override
  State<DangKyNghiLeDialog> createState() => _DangKyNghiLeDialogState();
}

class _DangKyNghiLeDialogState extends State<DangKyNghiLeDialog> {
  late DateTime _tuNgay;
  late DateTime _denNgay;
  final TextEditingController _lyDoController = TextEditingController();
  final LopHocSinhService _lhsService = LopHocSinhService();
  final Set<int> _selectedHsIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tuNgay = DateTime(now.year, now.month, now.day);
    _denNgay = DateTime(now.year, now.month, now.day);
    _lyDoController.text = 'Nghỉ lễ';

    // Mặc định chọn tất cả học sinh đang học trong lớp
    for (var hs in widget.danhSachHocSinh) {
      if (hs.id != null && hs.trangThai == 'DANG_HOC') {
        _selectedHsIds.add(hs.id!);
      }
    }
  }

  @override
  void dispose() {
    _lyDoController.dispose();
    super.dispose();
  }

  void _applyPreset(String reason, int days) {
    final now = DateTime.now();
    setState(() {
      _tuNgay = DateTime(now.year, now.month, now.day);
      _denNgay = _tuNgay.add(Duration(days: days > 0 ? days - 1 : 0));
      _lyDoController.text = reason;
    });
  }

  Future<void> _pickDate(bool isTuNgay) async {
    final initial = isTuNgay ? _tuNgay : _denNgay;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isTuNgay) {
          _tuNgay = picked;
          if (_denNgay.isBefore(_tuNgay)) {
            _denNgay = _tuNgay;
          }
        } else {
          _denNgay = picked;
          if (_denNgay.isBefore(_tuNgay)) {
            _tuNgay = _denNgay;
          }
        }
      });
    }
  }

  Future<void> _handleConfirm() async {
    if (_selectedHsIds.isEmpty) {
      ToastHelper.showWarning(context, 'Vui lòng chọn ít nhất 1 học sinh!');
      return;
    }

    setState(() => _isSaving = true);
    final tuNgayStr = DateFormat('yyyy-MM-dd').format(_tuNgay);
    final denNgayStr = DateFormat('yyyy-MM-dd').format(_denNgay);
    final lyDo = _lyDoController.text.trim().isEmpty
        ? 'Nghỉ lễ'
        : _lyDoController.text.trim();

    final count = await _lhsService.dangKyNghiCoPhepHangLoat(
      idLop: widget.lop.id!,
      dsHocSinhIds: _selectedHsIds.toList(),
      tuNgay: tuNgayStr,
      denNgay: denNgayStr,
      lyDo: lyDo,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (count > 0) {
        ToastHelper.showSuccess(
          context,
          'Đã đăng ký nghỉ phép thành công cho $count học sinh!',
        );
        Navigator.pop(context, true);
      } else {
        ToastHelper.showError(context, 'Lỗi đăng ký nghỉ phép!');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeStudents = widget.danhSachHocSinh
        .where((hs) => hs.trangThai == 'DANG_HOC')
        .toList();
    final allSelected =
        activeStudents.isNotEmpty &&
        _selectedHsIds.length == activeStudents.length;

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.beach_access_rounded, color: Colors.orange, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đăng Ký Nghỉ Lễ / Nghỉ Hè',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Lớp: ${widget.lop.ten}',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mẫu chọn nhanh
              const Text(
                'Chọn mẫu nhanh:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('🌴 Nghỉ lễ 1 ngày', style: TextStyle(fontSize: 11)),
                    selected: false,
                    onSelected: (_) => _applyPreset('Nghỉ lễ', 1),
                  ),
                  ChoiceChip(
                    label: const Text('🎉 Nghỉ 3 ngày', style: TextStyle(fontSize: 11)),
                    selected: false,
                    onSelected: (_) => _applyPreset('Nghỉ lễ', 3),
                  ),
                  ChoiceChip(
                    label: const Text('☀️ Nghỉ hè 7 ngày', style: TextStyle(fontSize: 11)),
                    selected: false,
                    onSelected: (_) => _applyPreset('Nghỉ hè', 7),
                  ),
                  ChoiceChip(
                    label: const Text('🧧 Nghỉ Tết 10 ngày', style: TextStyle(fontSize: 11)),
                    selected: false,
                    onSelected: (_) => _applyPreset('Nghỉ Tết', 10),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Chọn Từ ngày - Đến ngày
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(true),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Từ ngày', style: TextStyle(fontSize: 10, color: theme.hintColor)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.orange),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_tuNgay),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(false),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Đến ngày', style: TextStyle(fontSize: 10, color: theme.hintColor)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.event_available_rounded, size: 14, color: Colors.orange),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormat('dd/MM/yyyy').format(_denNgay),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Lý do
              TextField(
                controller: _lyDoController,
                decoration: InputDecoration(
                  labelText: 'Lý do nghỉ',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),

              // Danh sách học sinh chọn
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Học sinh áp dụng (${_selectedHsIds.length}/${activeStudents.length}):',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedHsIds.clear();
                        } else {
                          for (var hs in activeStudents) {
                            if (hs.id != null) _selectedHsIds.add(hs.id!);
                          }
                        }
                      });
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    child: Text(
                      allSelected ? 'Bỏ chọn hết' : 'Chọn tất cả',
                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: activeStudents.length,
                  itemBuilder: (ctx, idx) {
                    final hs = activeStudents[idx];
                    final isChecked = _selectedHsIds.contains(hs.id);
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(hs.ten, style: const TextStyle(fontSize: 12.5)),
                      value: isChecked,
                      activeColor: Colors.orange,
                      onChanged: (val) {
                        if (hs.id == null) return;
                        setState(() {
                          if (val == true) {
                            _selectedHsIds.add(hs.id!);
                          } else {
                            _selectedHsIds.remove(hs.id!);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_rounded, size: 16),
          label: Text('Đăng ký (${_selectedHsIds.length})'),
        ),
      ],
    );
  }
}
