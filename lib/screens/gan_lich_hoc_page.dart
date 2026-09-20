// File: lib/screens/gan_lich_hoc_page.dart

import 'package:flutter/material.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc_chung.dart';
import '../services/lich_hoc_chung_service.dart';
import '../l10n/app_localizations.dart';
import '../utils/toast_helper.dart';

// Enum cho trạng thái lọc
enum FilterStatus { all, assigned, unassigned }

class GanLichHocPage extends StatefulWidget {
  final LichHocChung lichHocChung;
  final List<HSLopViewModel> danhSachHocSinh;

  const GanLichHocPage({
    super.key,
    required this.lichHocChung,
    required this.danhSachHocSinh,
  });

  @override
  State<GanLichHocPage> createState() => _GanLichHocPageState();
}

class _GanLichHocPageState extends State<GanLichHocPage> {
  final _service = LichHocChungService();
  final Set<int> _selectedHocSinhIds = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // State cho tìm kiếm
  final TextEditingController _searchController = TextEditingController();
  List<HSLopViewModel> _filteredHocSinh = [];
  FilterStatus _filterStatus = FilterStatus.all;

  // Màu sắc
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color cardColor = Color(0xFF16213E);
  static const Color lightText = Colors.white;
  static const Color secondaryText = Colors.white70;
  static const Color accentColor = Color(0xFF00BFA5);

  @override
  void initState() {
    super.initState();
    _filteredHocSinh = widget.danhSachHocSinh;
    _searchController.addListener(_applyFilters);
    _loadDanhSachDaGan();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalizeString(String text) {
    const vietnamese =
        'aAàÀảẢãÃáÁạẠăĂằẰẳẲẵẴắẮặẶâÂầẦẩẨẫẪấẤậẬbBcCdDđĐeEèÈẻẺẽẼéÉẹẸêÊềỀểỂễỄếẾệỆfFgGhHiIìÌỉỈĩĨíÍịỊjJkKlLmMnNoOòÒỏỎõÕóÓọỌôÔồỒổỔỗỖốỐộỘơƠờỜởỞỡỠớỚợỢpPqQrRsStTuUùÙủỦũŨúÚụỤưƯừỪửỬữỮứỨựỰvVwWxXyYỳỲỷỶỹỸýÝỵỴzZ';
    const latin =
        'aAaAaAaAaAaAaAaAaAaAaAaAaAaAaAaAaAaAaBbCcDdDdeEeEeEeEeEeEeEeEeEeEeEeFfGgHhIiIiIiIiIiJjKkLlMmNnOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoOoPpQqRrSsTtUuUuUuUuUuUuUuUuUuUuUuVvWwXxYyYyYyYyYyZz';
    String result = text;
    final maxLen = vietnamese.length < latin.length
        ? vietnamese.length
        : latin.length;
    for (int i = 0; i < maxLen; i++) {
      result = result.replaceAll(vietnamese[i], latin[i]);
    }
    return result.toLowerCase();
  }

  void _applyFilters() {
    final query = _normalizeString(_searchController.text.trim());
    List<HSLopViewModel> tempFilteredList = widget.danhSachHocSinh;

    // 1. Lọc theo trạng thái gán
    if (_filterStatus == FilterStatus.assigned) {
      tempFilteredList = tempFilteredList
          .where((hs) => _selectedHocSinhIds.contains(hs.id))
          .toList();
    } else if (_filterStatus == FilterStatus.unassigned) {
      tempFilteredList = tempFilteredList
          .where((hs) => !_selectedHocSinhIds.contains(hs.id))
          .toList();
    }

    // 2. Lọc theo tên tìm kiếm
    if (query.isNotEmpty) {
      tempFilteredList = tempFilteredList.where((hs) {
        return _normalizeString(hs.ten).contains(query);
      }).toList();
    }

    setState(() {
      _filteredHocSinh = tempFilteredList;
    });
  }

  Future<void> _loadDanhSachDaGan() async {
    setState(() => _isLoading = true);
    try {
      if (widget.lichHocChung.id != null) {
        final assignedIds = await _service.layDanhSachHocSinhDaGan(
          widget.lichHocChung.id!,
        );
        _selectedHocSinhIds.clear();
        _selectedHocSinhIds.addAll(assignedIds);
      }
    } catch (e) {
      if (mounted) {
        final isVi = Localizations.localeOf(context).languageCode == 'vi';
        ToastHelper.showError(
          context,
          isVi
              ? 'Không thể tải danh sách gán lịch: $e'
              : 'Failed to load schedule assignments: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _applyFilters();
      }
    }
  }

  Future<void> _luuThayDoi() async {
    if (_isSaving || _isLoading || widget.lichHocChung.id == null) return;
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    setState(() => _isSaving = true);
    try {
      await _service.luuPhanCongLichHocHangLoat(
        idLichHocChung: widget.lichHocChung.id!,
        desiredHocSinhIds: _selectedHocSinhIds,
      );
      if (mounted) {
        ToastHelper.showSuccess(
          context,
          isVi
              ? 'Cập nhật lịch học thành công!'
              : 'Schedule updated successfully!',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(
          context,
          isVi
              ? 'Không thể cập nhật lịch học: $e'
              : 'Failed to update schedule: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: Text(isVi ? 'GÁN LỊCH HỌC' : 'ASSIGN SCHEDULE'),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: lightText,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.save, color: accentColor),
                  onPressed: _isLoading ? null : _luuThayDoi,
                  tooltip: isVi ? 'Lưu thay đổi' : 'Save changes',
                ),
        ],
      ),
      body: Column(
        children: [
          // Header thông tin lịch học
          _buildHeader(),
          // Thanh tìm kiếm và các nút chọn nhanh
          _buildSearchAndActions(),
          // Danh sách học sinh
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: accentColor),
                  )
                : _filteredHocSinh.isEmpty
                ? Center(
                    child: Text(
                      isVi
                          ? 'Không tìm thấy học sinh nào.'
                          : 'No students found.',
                      style: const TextStyle(color: secondaryText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _filteredHocSinh.length,
                    itemBuilder: (context, index) {
                      final hs = _filteredHocSinh[index];
                      final isSelected = _selectedHocSinhIds.contains(hs.id);
                      return Card(
                        color: darkBackground,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: CheckboxListTile(
                          value: isSelected,
                          onChanged: (_isSaving || _isLoading || hs.id == null)
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedHocSinhIds.add(hs.id!);
                                    } else {
                                      _selectedHocSinhIds.remove(hs.id!);
                                    }
                                  });
                                },
                          title: Text(
                            hs.ten,
                            style: const TextStyle(color: lightText),
                          ),
                          subtitle: hs.sdt != null
                              ? Text(
                                  hs.sdt!,
                                  style: const TextStyle(
                                    color: secondaryText,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                          activeColor: accentColor,
                          checkColor: darkBackground,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    return Container(
      width: double.infinity,
      color: cardColor,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                (isVi ? 'Lịch học: ' : 'Schedule: ') +
                    widget.lichHocChung.ngayTrongTuan,
                style: const TextStyle(
                  color: lightText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time, color: accentColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '${isVi ? 'Thời gian: ' : 'Time: '}${widget.lichHocChung.gioBatDau} - ${widget.lichHocChung.gioKetThuc}',
                style: const TextStyle(color: secondaryText, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndActions() {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    final isDisabled = _isSaving || _isLoading;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Thanh tìm kiếm
          TextField(
            controller: _searchController,
            enabled: !isDisabled,
            style: const TextStyle(color: lightText),
            decoration: InputDecoration(
              hintText: isVi ? 'Tìm kiếm học sinh...' : 'Search student...',
              hintStyle: const TextStyle(color: secondaryText),
              prefixIcon: const Icon(Icons.search, color: secondaryText),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: cardColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(height: 12),
          // Bộ lọc trạng thái
          SegmentedButton<FilterStatus>(
            segments: [
              ButtonSegment<FilterStatus>(
                value: FilterStatus.all,
                label: Text(isVi ? 'Tất cả' : 'All'),
              ),
              ButtonSegment<FilterStatus>(
                value: FilterStatus.assigned,
                label: Text(isVi ? 'Đã gán' : 'Assigned'),
              ),
              ButtonSegment<FilterStatus>(
                value: FilterStatus.unassigned,
                label: Text(isVi ? 'Chưa gán' : 'Unassigned'),
              ),
            ],
            selected: {_filterStatus},
            onSelectionChanged: isDisabled
                ? null
                : (Set<FilterStatus> newSelection) {
                    setState(() {
                      _filterStatus = newSelection.first;
                      _applyFilters();
                    });
                  },
            style: SegmentedButton.styleFrom(
              backgroundColor: cardColor,
              foregroundColor: secondaryText,
              selectedForegroundColor: accentColor,
            ),
          ),
          const SizedBox(height: 12),
          // Các nút chọn nhanh
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${isVi ? 'Đã chọn: ' : 'Selected: '}${_selectedHocSinhIds.length}/${widget.danhSachHocSinh.length}',
                style: const TextStyle(color: secondaryText),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: isDisabled
                        ? null
                        : () {
                            setState(() {
                              // Chỉ chọn tất cả các học sinh đang được hiển thị và khác null
                              _selectedHocSinhIds.addAll(
                                _filteredHocSinh
                                    .where((hs) => hs.id != null)
                                    .map((hs) => hs.id!),
                              );
                            });
                          },
                    child: Text(
                      isVi ? 'Chọn tất cả' : 'Select all',
                      style: TextStyle(
                        color: isDisabled ? Colors.grey : accentColor,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: isDisabled
                        ? null
                        : () {
                            setState(() {
                              // Phương án B: Bỏ chọn tất cả học sinh
                              _selectedHocSinhIds.clear();
                            });
                          },
                    child: Text(
                      isVi ? 'Bỏ chọn tất cả' : 'Deselect all',
                      style: TextStyle(
                        color: isDisabled ? Colors.grey : accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
