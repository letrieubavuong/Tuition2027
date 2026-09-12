// File: lib/widgets/them_hs_vao_lop_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hs.dart';
import '../models/lop.dart';
import '../models/truong.dart';
import '../models/lop_hoc_sinh.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/hoc_sinh_service.dart';
import 'hs_form.dart';
import '../utils/toast_helper.dart';

class ThemHSVaoLopDialog extends StatefulWidget {
  final Lop lop;
  final List<HS> danhSachTatCaHS;
  final LopHocSinhService lhsService;
  final HocSinhService hsService;
  final List<Truong> danhSachTruong;

  const ThemHSVaoLopDialog({
    super.key,
    required this.lop,
    required this.danhSachTatCaHS,
    required this.lhsService,
    required this.hsService,
    required this.danhSachTruong,
  });

  @override
  State<ThemHSVaoLopDialog> createState() => _ThemHSVaoLopDialogState();
}

class _ThemHSVaoLopDialogState extends State<ThemHSVaoLopDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedHsIds = {};
  DateTime _ngayThamGia = DateTime.now();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HS> get _filteredStudents {
    if (_searchQuery.isEmpty) return widget.danhSachTatCaHS;
    return widget.danhSachTatCaHS.where((hs) {
      final name = hs.ten.toLowerCase();
      final phone = (hs.sdt ?? '').replaceAll(RegExp(r'[^\d]'), '');
      return name.contains(_searchQuery) || phone.contains(_searchQuery);
    }).toList();
  }

  Future<void> _chonNgayThamGia(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _ngayThamGia,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              onPrimary: darkBackground,
              surface: cardColor,
              onSurface: lightText,
            ),
            dialogTheme: DialogThemeData(backgroundColor: cardColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _ngayThamGia) {
      setState(() {
        _ngayThamGia = picked;
      });
    }
  }

  Future<void> _handleTaoMoiVaThem() async {
    final newHs = await showHocSinhFormDialog(
      context: context,
      danhSachTruong: widget.danhSachTruong,
      hsService: widget.hsService,
    );

    if (newHs != null && newHs.id != null) {
      try {
        final lhs = LopHocSinh(
          idLop: widget.lop.id!,
          idHocSinh: newHs.id!,
          ngayThamGia: DateFormat('yyyy-MM-dd').format(_ngayThamGia),
        );

        await widget.lhsService.themHocSinhVaoLop(lhs);

        if (mounted) {
          ToastHelper.showSuccess(
            context,
            'Đã tạo mới và thêm ${newHs.ten} vào lớp!',
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ToastHelper.showError(context, 'Lỗi thêm học sinh mới vào lớp: $e');
        }
      }
    }
  }

  void _handleThemHS() async {
    if (_selectedHsIds.isEmpty) {
      ToastHelper.showWarning(context, 'Vui lòng chọn ít nhất 1 học sinh!');
      return;
    }

    try {
      final ngayThamGiaStr = DateFormat('yyyy-MM-dd').format(_ngayThamGia);
      int addedCount = 0;

      for (final idHs in _selectedHsIds) {
        final lhs = LopHocSinh(
          idLop: widget.lop.id!,
          idHocSinh: idHs,
          ngayThamGia: ngayThamGiaStr,
        );
        await widget.lhsService.themHocSinhVaoLop(lhs);
        addedCount++;
      }

      if (mounted) {
        ToastHelper.showSuccess(
          context,
          'Đã thêm thành công $addedCount học sinh vào lớp!',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi khi thêm học sinh vào lớp: $e');
      }
    }
  }

  void _toggleSelectAll() {
    final filtered = _filteredStudents;
    final allSelected = filtered.every((hs) => _selectedHsIds.contains(hs.id));

    setState(() {
      if (allSelected) {
        for (var hs in filtered) {
          if (hs.id != null) _selectedHsIds.remove(hs.id!);
        }
      } else {
        for (var hs in filtered) {
          if (hs.id != null) _selectedHsIds.add(hs.id!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final filteredList = _filteredStudents;
    final bool isAllSelected = filteredList.isNotEmpty &&
        filteredList.every((hs) => _selectedHsIds.contains(hs.id));

    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.94,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Title & Close Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_add_alt_1_rounded, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'THÊM HỌC SINH VÀO LỚP' : 'ADD STUDENTS TO CLASS',
                        style: TextStyle(
                          color: lightText,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.lop.ten,
                        style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: secondaryText),
                  onPressed: () => Navigator.of(context).pop(false),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nút Tạo mới học sinh
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: _handleTaoMoiVaThem,
                icon: Icon(Icons.add_circle_outline_rounded, size: 18, color: accentColor),
                label: Text(
                  isVi ? 'TẠO MỚI HỌC SINH MỚI PHÁT SINH' : 'CREATE NEW STUDENT',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Ô Tìm kiếm Học Sinh
            TextField(
              controller: _searchController,
              style: TextStyle(color: lightText, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: isVi ? 'Tìm học sinh theo tên hoặc SĐT...' : 'Search by name or phone...',
                hintStyle: TextStyle(color: secondaryText.withValues(alpha: 0.6), fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: accentColor, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: secondaryText, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: darkBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
            ),
            const SizedBox(height: 10),

            // Ngày tham gia & Chọn tất cả
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => _chonNgayThamGia(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: darkBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 16, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          '${isVi ? "Ngày vào:" : "Joined:"} ${DateFormat("dd/MM/yyyy").format(_ngayThamGia)}',
                          style: TextStyle(color: lightText, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                if (filteredList.isNotEmpty)
                  TextButton.icon(
                    onPressed: _toggleSelectAll,
                    icon: Icon(
                      isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                      size: 16,
                      color: accentColor,
                    ),
                    label: Text(
                      isAllSelected
                          ? (isVi ? 'Bỏ chọn hết' : 'Deselect all')
                          : (isVi ? 'Chọn tất cả (${filteredList.length})' : 'Select all'),
                      style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Danh sách Học sinh dạng Checkbox ListView
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Text(
                        widget.danhSachTatCaHS.isEmpty
                            ? (isVi
                                ? 'Tất cả học sinh trong hệ thống đã thuộc lớp này.'
                                : 'All students are already in this class.')
                            : (isVi
                                ? 'Không tìm thấy học sinh phù hợp.'
                                : 'No matching students found.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: secondaryText, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (context, index) {
                        final hs = filteredList[index];
                        final isSelected = hs.id != null && _selectedHsIds.contains(hs.id);

                        return Card(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.15)
                              : darkBackground,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected
                                  ? accentColor
                                  : secondaryText.withValues(alpha: 0.1),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? val) {
                              if (hs.id == null) return;
                              setState(() {
                                if (val == true) {
                                  _selectedHsIds.add(hs.id!);
                                } else {
                                  _selectedHsIds.remove(hs.id!);
                                }
                              });
                            },
                            activeColor: accentColor,
                            checkColor: darkBackground,
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            title: Text(
                              hs.ten,
                              style: TextStyle(
                                color: lightText,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: (hs.sdt != null && hs.sdt!.isNotEmpty)
                                ? Text(
                                    'SĐT: ${hs.sdt}',
                                    style: TextStyle(color: secondaryText, fontSize: 12),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),

            // Bottom Actions
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      isVi ? 'HỦY' : 'CANCEL',
                      style: TextStyle(color: secondaryText, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _selectedHsIds.isEmpty ? null : _handleThemHS,
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      isVi
                          ? 'THÊM (${_selectedHsIds.length} HS)'
                          : 'ADD (${_selectedHsIds.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: darkBackground,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: darkBackground,
                      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
}
