import 'package:flutter/material.dart';
import 'package:tuition2025/models/hs_lop_view_model.dart';
import 'package:tuition2025/models/lich_hoc.dart';
import 'package:tuition2025/models/lop.dart';
import 'package:tuition2025/models/student_schedule_assignment.dart';
import 'package:tuition2025/services/student_schedule_assignment_service.dart';
import 'package:tuition2025/utils/toast_helper.dart';
import 'package:tuition2025/utils/db.dart';
import 'package:tuition2025/utils/schedule_helpers.dart';

class StudentAssignmentSheet extends StatefulWidget {
  final Lop lop;
  final List<HSLopViewModel> danhSachHocSinh;
  final List<LichHoc> dsLichHoc;
  final int? initialScheduleId;
  final bool filterUnassignedOnly;

  const StudentAssignmentSheet({
    super.key,
    required this.lop,
    required this.danhSachHocSinh,
    required this.dsLichHoc,
    this.initialScheduleId,
    this.filterUnassignedOnly = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    required Lop lop,
    required List<HSLopViewModel> danhSachHocSinh,
    required List<LichHoc> dsLichHoc,
    int? initialScheduleId,
    bool filterUnassignedOnly = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentAssignmentSheet(
        lop: lop,
        danhSachHocSinh: danhSachHocSinh,
        dsLichHoc: dsLichHoc,
        initialScheduleId: initialScheduleId,
        filterUnassignedOnly: filterUnassignedOnly,
      ),
    );
  }

  @override
  State<StudentAssignmentSheet> createState() => _StudentAssignmentSheetState();
}

class _StudentAssignmentSheetState extends State<StudentAssignmentSheet> {
  final _assignmentService = StudentScheduleAssignmentService.instance;
  final _searchController = TextEditingController();

  String _searchQuery = '';
  int?
  _selectedFilterScheduleId; // null = All, -1 = Unassigned, >0 = ScheduleId
  int? _targetScheduleId; // Target schedule to assign selected students to

  final Set<int> _selectedStudentIds = {};
  Map<int, StudentScheduleAssignment?> _currentAssignmentMap = {};
  bool _isLoadingAssignments = true;
  bool _isSubmitting = false;

  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;

  @override
  void initState() {
    super.initState();
    if (widget.filterUnassignedOnly) {
      _selectedFilterScheduleId = -1;
    } else if (widget.initialScheduleId != null) {
      _selectedFilterScheduleId = widget.initialScheduleId;
      _targetScheduleId = widget.initialScheduleId;
    } else if (widget.dsLichHoc.isNotEmpty) {
      _targetScheduleId = widget.dsLichHoc.first.id;
    }

    _loadCurrentAssignments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentAssignments() async {
    final roster = await _assignmentService.getClassScheduleRoster(
      classId: widget.lop.id!,
      schedules: widget.dsLichHoc,
      activeStudents: widget.danhSachHocSinh,
    );

    if (mounted) {
      setState(() {
        _currentAssignmentMap = roster.activeAssignmentByStudentId;
        _isLoadingAssignments = false;
      });
    }
  }

  String _getScheduleLabel(LichHoc l) {
    final start = l.gioBatDau.length >= 5
        ? l.gioBatDau.substring(0, 5)
        : l.gioBatDau;
    final end = l.gioKetThuc.length >= 5
        ? l.gioKetThuc.substring(0, 5)
        : l.gioKetThuc;
    return '${_dayOfWeekInitial(l.thuTrongTuan)} $start–$end';
  }

  String _dayOfWeekInitial(int day) {
    switch (day) {
      case 1:
        return 'CN';
      case 2:
        return 'T2';
      case 3:
        return 'T3';
      case 4:
        return 'T4';
      case 5:
        return 'T5';
      case 6:
        return 'T6';
      case 7:
        return 'T7';
      default:
        return '';
    }
  }

  List<HSLopViewModel> _getFilteredStudents() {
    return widget.danhSachHocSinh.where((hs) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          hs.ten.toLowerCase().contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      final currentAss = _currentAssignmentMap[hs.id];
      if (_selectedFilterScheduleId == -1) {
        // Unassigned only
        return currentAss == null;
      } else if (_selectedFilterScheduleId != null &&
          _selectedFilterScheduleId! > 0) {
        // Specific schedule filter
        return currentAss != null &&
            currentAss.scheduleId == _selectedFilterScheduleId;
      }
      return true;
    }).toList();
  }

  Future<void> _executeBatchAssign() async {
    if (_selectedStudentIds.isEmpty || _targetScheduleId == null) return;
    setState(() => _isSubmitting = true);

    if (_targetScheduleId == -1) {
      final count = await _assignmentService.unassignStudentsFromClassSchedules(
        classId: widget.lop.id!,
        studentIds: _selectedStudentIds.toList(),
      );
      if (mounted) {
        setState(() => _isSubmitting = false);
        ToastHelper.showSuccess(
          context,
          'Đã hủy gán ca thành công cho $count học sinh',
        );
        Navigator.of(context).pop(true);
      }
      return;
    }

    final targetLich = widget.dsLichHoc.firstWhere(
      (l) => l.id == _targetScheduleId,
    );

    final startStr = targetLich.gioBatDau.length >= 5
        ? targetLich.gioBatDau.substring(0, 5)
        : targetLich.gioBatDau;
    final endStr = targetLich.gioKetThuc.length >= 5
        ? targetLich.gioKetThuc.substring(0, 5)
        : targetLich.gioKetThuc;

    final res = await _assignmentService.batchAssignStudentsToSchedule(
      classId: widget.lop.id!,
      scheduleId: targetLich.id!,
      dayOfWeek: targetLich.thuTrongTuan,
      startTime: startStr,
      endTime: endStr,
      studentIds: _selectedStudentIds.toList(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      final success = res['success'] ?? 0;
      final skipped = res['skipped'] ?? 0;

      ToastHelper.showSuccess(
        context,
        'Đã gán / chuyển ca thành công: $success học sinh${skipped > 0 ? " (Bỏ qua: $skipped)" : ""}',
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _quickAssignStudent(int studentId, int? targetSchId) async {
    if (targetSchId == -1) {
      await _assignmentService.unassignStudentsFromClassSchedules(
        classId: widget.lop.id!,
        studentIds: [studentId],
      );
      ToastHelper.showSuccess(context, 'Đã hủy gán ca cho học sinh');
    } else if (targetSchId != null) {
      final targetLich = widget.dsLichHoc.firstWhere((l) => l.id == targetSchId);
      final startStr = targetLich.gioBatDau.length >= 5
          ? targetLich.gioBatDau.substring(0, 5)
          : targetLich.gioBatDau;
      final endStr = targetLich.gioKetThuc.length >= 5
          ? targetLich.gioKetThuc.substring(0, 5)
          : targetLich.gioKetThuc;

      await _assignmentService.batchAssignStudentsToSchedule(
        classId: widget.lop.id!,
        scheduleId: targetLich.id!,
        dayOfWeek: targetLich.thuTrongTuan,
        startTime: startStr,
        endTime: endStr,
        studentIds: [studentId],
      );
      ToastHelper.showSuccess(context, 'Đã chuyển ca cho học sinh');
    }
    await _loadCurrentAssignments();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredStudents();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Sheet Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: secondaryText.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUẢN LÝ HỌC SINH THEO CA',
                      style: TextStyle(
                        color: lightText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Lớp ${widget.lop.ten} • ${widget.danhSachHocSinh.length} Học sinh',
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: secondaryText),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Filter Chips (All, Unassigned, Slot 1, Slot 2...)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Tất cả (${widget.danhSachHocSinh.length})'),
                  selected: _selectedFilterScheduleId == null,
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedFilterScheduleId = null);
                  },
                  selectedColor: accentColor.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: _selectedFilterScheduleId == null
                        ? accentColor
                        : lightText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(
                    'Chưa gán (${widget.danhSachHocSinh.where((h) => _currentAssignmentMap[h.id] == null).length})',
                  ),
                  selected: _selectedFilterScheduleId == -1,
                  onSelected: (sel) {
                    if (sel) setState(() => _selectedFilterScheduleId = -1);
                  },
                  selectedColor: Colors.amber.shade900.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: _selectedFilterScheduleId == -1
                        ? Colors.amber.shade400
                        : lightText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ...widget.dsLichHoc.map((lich) {
                  final count = widget.danhSachHocSinh.where((h) {
                    final a = _currentAssignmentMap[h.id];
                    return a != null && a.scheduleId == lich.id;
                  }).length;
                  final isSel = _selectedFilterScheduleId == lich.id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text('${_getScheduleLabel(lich)} ($count)'),
                      selected: isSel,
                      onSelected: (sel) {
                        if (sel)
                          setState(() => _selectedFilterScheduleId = lich.id);
                      },
                      selectedColor: accentColor.withValues(alpha: 0.3),
                      labelStyle: TextStyle(
                        color: isSel ? accentColor : lightText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Search & Multi-select Helpers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: lightText, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '🔍 Tìm tên học sinh...',
                      hintStyle: TextStyle(color: secondaryText, fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedStudentIds.length == filteredList.length) {
                        _selectedStudentIds.clear();
                      } else {
                        _selectedStudentIds.addAll(
                          filteredList.map((h) => h.id!),
                        );
                      }
                    });
                  },
                  child: Text(
                    _selectedStudentIds.length == filteredList.length
                        ? 'Bỏ chọn'
                        : 'Chọn tất cả',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 12),

          // Student List
          Expanded(
            child: _isLoadingAssignments
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : filteredList.isEmpty
                ? Center(
                    child: Text(
                      'Không tìm thấy học sinh phù hợp.',
                      style: TextStyle(color: secondaryText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    itemCount: filteredList.length,
                    itemBuilder: (ctx, index) {
                      final hs = filteredList[index];
                      final isChecked = _selectedStudentIds.contains(hs.id);
                      final currentAss = _currentAssignmentMap[hs.id];

                      final String currentBadgeText;
                      final Color currentBadgeColor;
                      if (currentAss == null) {
                        currentBadgeText = '○ Chưa gán ca';
                        currentBadgeColor = Colors.amber.shade700;
                      } else {
                        final targetLich = widget.dsLichHoc.firstWhere(
                          (l) =>
                              l.id == currentAss.scheduleId ||
                              (currentAss.dayOfWeek != null &&
                                  l.thuTrongTuan == currentAss.dayOfWeek &&
                                  (currentAss.startTime == null ||
                                      normalizeTime(l.gioBatDau) ==
                                          normalizeTime(currentAss.startTime!))),
                          orElse: () => LichHoc(
                            idLop: widget.lop.id!,
                            thuTrongTuan: currentAss.dayOfWeek ?? 2,
                            gioBatDau: currentAss.startTime ?? '00:00',
                            gioKetThuc: currentAss.endTime ?? '00:00',
                          ),
                        );
                        currentBadgeText = _getScheduleLabel(targetLich);
                        currentBadgeColor = Colors.teal;
                      }

                      return Card(
                        color: isChecked
                            ? accentColor.withValues(alpha: 0.15)
                            : darkBackground,
                        margin: const EdgeInsets.only(bottom: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isChecked
                                ? accentColor
                                : secondaryText.withValues(alpha: 0.1),
                          ),
                        ),
                        child: CheckboxListTile(
                          value: isChecked,
                          activeColor: accentColor,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedStudentIds.add(hs.id!);
                              } else {
                                _selectedStudentIds.remove(hs.id);
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  hs.ten,
                                  style: TextStyle(
                                    color: lightText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: currentBadgeColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  currentBadgeText,
                                  style: TextStyle(
                                    color: currentBadgeColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              PopupMenuButton<int>(
                                icon: Icon(
                                  Icons.more_vert,
                                  color: secondaryText,
                                  size: 18,
                                ),
                                color: cardColor,
                                onSelected: (targetSchId) =>
                                    _quickAssignStudent(hs.id!, targetSchId),
                                itemBuilder: (ctx) => [
                                  ...widget.dsLichHoc.map((l) => PopupMenuItem<int>(
                                    value: l.id,
                                    child: Text(
                                      'Chuyển sang: ${_getScheduleLabel(l)}',
                                      style: TextStyle(color: lightText, fontSize: 12),
                                    ),
                                  )),
                                  if (currentAss != null)
                                    const PopupMenuItem<int>(
                                      value: -1,
                                      child: Text(
                                        '❌ Hủy gán ca',
                                        style: TextStyle(color: Colors.redAccent, fontSize: 12),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Mã HS: #${hs.id}',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: darkBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Thao tác ca: ',
                      style: TextStyle(
                        color: secondaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _targetScheduleId == -1
                                ? Colors.redAccent
                                : accentColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _targetScheduleId,
                            isExpanded: true,
                            dropdownColor: cardColor,
                            style: TextStyle(
                              color: lightText,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            items: [
                              ...widget.dsLichHoc.map((l) {
                                return DropdownMenuItem<int>(
                                  value: l.id,
                                  child: Text(_getScheduleLabel(l)),
                                );
                              }),
                              DropdownMenuItem<int>(
                                value: -1,
                                child: Text(
                                  '○ Hủy gán ca (Chưa gán ca)',
                                  style: TextStyle(color: Colors.amber.shade400),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _targetScheduleId = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _targetScheduleId == -1
                          ? Colors.red.shade800
                          : accentColor,
                      foregroundColor: _targetScheduleId == -1
                          ? Colors.white
                          : darkBackground,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: (_selectedStudentIds.isEmpty || _isSubmitting)
                        ? null
                        : _executeBatchAssign,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _targetScheduleId == -1
                                ? 'XÓA / HỦY GÁN ${_selectedStudentIds.length} HỌC SINH KHỎI CA'
                                : 'GÁN / CHUYỂN ${_selectedStudentIds.length} HỌC SINH VÀO CA NÀY',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
