import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../controllers/lop_detail_controller.dart';
import '../../../models/hs_lop_view_model.dart';
import '../../../models/lich_hoc.dart';
import '../../../models/lop.dart';
import '../../../services/calendar_sync_service.dart';
import '../../../services/lich_hoc_service.dart';
import '../../../services/student_schedule_assignment_service.dart';
import '../../weekly_scheduling_page.dart';
import '../widgets/student_assignment_sheet.dart';

class ClassScheduleTab extends ConsumerStatefulWidget {
  final Lop lop;

  const ClassScheduleTab({super.key, required this.lop});

  @override
  ConsumerState<ClassScheduleTab> createState() => _ClassScheduleTabState();
}

class _ClassScheduleTabState extends ConsumerState<ClassScheduleTab> {
  final _lichHocService = LichHocService();

  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  String _formatTimeDisplay(String rawTime) {
    if (rawTime.isEmpty) return '--:--';
    final parts = rawTime.split(':');
    if (parts.length >= 2) {
      final hh = parts[0].padLeft(2, '0');
      final mm = parts[1].padLeft(2, '0');
      return '$hh:$mm';
    }
    return rawTime;
  }

  String _dayOfWeekName(int day) {
    switch (day) {
      case 1:
        return 'Chủ Nhật';
      case 2:
        return 'Thứ Hai';
      case 3:
        return 'Thứ Ba';
      case 4:
        return 'Thứ Tư';
      case 5:
        return 'Thứ Năm';
      case 6:
        return 'Thứ Sáu';
      case 7:
        return 'Thứ Bảy';
      default:
        return '';
    }
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

  String _translateDayOfWeek(String dayName, bool isVi) {
    if (isVi) return dayName;
    switch (dayName) {
      case 'Chủ Nhật':
        return 'Sunday';
      case 'Thứ Hai':
        return 'Monday';
      case 'Thứ Ba':
        return 'Tuesday';
      case 'Thứ Tư':
        return 'Wednesday';
      case 'Thứ Năm':
        return 'Thursday';
      case 'Thứ Sáu':
        return 'Friday';
      case 'Thứ Bảy':
        return 'Saturday';
      default:
        return dayName;
    }
  }

  void _moDialogThemLichHoc({LichHoc? lichHoc, bool isCopy = false}) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final isEditing = lichHoc != null && !isCopy;
    int? selectedDay = lichHoc?.thuTrongTuan ?? 2;

    TimeOfDay? startTime;
    TimeOfDay? endTime;

    if (lichHoc != null) {
      final startParts = lichHoc.gioBatDau.split(':');
      final endParts = lichHoc.gioKetThuc.split(':');
      if (startParts.length >= 2) {
        startTime = TimeOfDay(
          hour: int.tryParse(startParts[0]) ?? 18,
          minute: int.tryParse(startParts[1]) ?? 0,
        );
      }
      if (endParts.length >= 2) {
        endTime = TimeOfDay(
          hour: int.tryParse(endParts[0]) ?? 20,
          minute: int.tryParse(endParts[1]) ?? 0,
        );
      }
    }
    startTime ??= const TimeOfDay(hour: 18, minute: 0);
    endTime ??= const TimeOfDay(hour: 20, minute: 0);

    await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: cardColor,
              title: Text(
                isCopy
                    ? (isVi ? 'Copy Lịch Học' : 'Copy Schedule')
                    : (isEditing
                          ? (isVi ? 'Sửa Lịch Học' : 'Edit Schedule')
                          : (isVi ? 'Thêm Lịch Học' : 'Add Schedule')),
                style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDayPicker(
                      selectedDay: selectedDay,
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() => selectedDay = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTimePicker(
                      label: isVi ? 'Giờ bắt đầu' : 'Start time',
                      time: startTime,
                      onTap: () async {
                        final picked = await _showCustomTimePicker(
                          context,
                          initialTime: startTime!,
                        );
                        if (picked != null) {
                          setStateDialog(() => startTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildTimePicker(
                      label: isVi ? 'Giờ kết thúc' : 'End time',
                      time: endTime,
                      onTap: () async {
                        final picked = await _showCustomTimePicker(
                          context,
                          initialTime: endTime!,
                        );
                        if (picked != null) {
                          setStateDialog(() => endTime = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(isVi ? 'Hủy' : 'Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  onPressed: () async {
                    if (startTime == null || endTime == null) return;

                    final startMinutes =
                        startTime!.hour * 60 + startTime!.minute;
                    final endMinutes = endTime!.hour * 60 + endTime!.minute;

                    if (endMinutes <= startMinutes) {
                      if (ctx.mounted) {
                        showDialog(
                          context: ctx,
                          builder: (errCtx) => AlertDialog(
                            backgroundColor: cardColor,
                            title: Text(
                              isVi
                                  ? 'Giờ học không hợp lệ'
                                  : 'Invalid Time Range',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              isVi
                                  ? 'Giờ kết thúc phải sau giờ bắt đầu. Vui lòng chọn lại!'
                                  : 'The end time must be after the start time. Please select again!',
                              style: TextStyle(color: lightText),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(errCtx).pop(),
                                child: Text(isVi ? 'Đóng' : 'Close'),
                              ),
                            ],
                          ),
                        );
                      }
                      return;
                    }

                    final newLichHoc = LichHoc(
                      id: isEditing ? lichHoc.id : null,
                      idLop: widget.lop.id!,
                      thuTrongTuan: selectedDay!,
                      gioBatDau:
                          '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00',
                      gioKetThuc:
                          '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00',
                    );

                    final notifier = ref.read(
                      lopDetailControllerProvider(widget.lop.id!).notifier,
                    );
                    final success = isEditing
                        ? await notifier.capNhatLichHoc(newLichHoc)
                        : await notifier.themLichHoc(newLichHoc);

                    if (success) {
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    } else {
                      if (ctx.mounted) {
                        showDialog(
                          context: ctx,
                          builder: (errCtx) => AlertDialog(
                            backgroundColor: cardColor,
                            title: Text(
                              isVi ? 'Trùng lịch học' : 'Schedule Conflict',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              isVi
                                  ? 'Không thể lưu lịch học do bị chồng lấn.'
                                  : 'Could not save schedule due to overlap.',
                              style: TextStyle(color: lightText),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(errCtx).pop(),
                                child: Text(isVi ? 'Đồng ý' : 'OK'),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    isVi ? 'Lưu' : 'Save',
                    style: TextStyle(color: darkBackground),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<TimeOfDay?> _showCustomTimePicker(
    BuildContext context, {
    required TimeOfDay initialTime,
  }) {
    return showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              onPrimary: darkBackground,
              surface: cardColor,
              onSurface: lightText,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Widget _buildDayPicker({
    required int? selectedDay,
    required ValueChanged<int?> onChanged,
  }) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: isVi ? 'Thứ trong tuần' : 'Day of week',
        labelStyle: TextStyle(color: secondaryText),
        prefixIcon: Icon(Icons.calendar_today, color: secondaryText),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: darkBackground,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedDay,
          isDense: true,
          dropdownColor: cardColor,
          style: TextStyle(color: lightText, fontSize: 15),
          items: [
            DropdownMenuItem(
              value: 2,
              child: Text(isVi ? 'Thứ Hai' : 'Monday'),
            ),
            DropdownMenuItem(
              value: 3,
              child: Text(isVi ? 'Thứ Ba' : 'Tuesday'),
            ),
            DropdownMenuItem(
              value: 4,
              child: Text(isVi ? 'Thứ Tư' : 'Wednesday'),
            ),
            DropdownMenuItem(
              value: 5,
              child: Text(isVi ? 'Thứ Năm' : 'Thursday'),
            ),
            DropdownMenuItem(
              value: 6,
              child: Text(isVi ? 'Thứ Sáu' : 'Friday'),
            ),
            DropdownMenuItem(
              value: 7,
              child: Text(isVi ? 'Thứ Bảy' : 'Saturday'),
            ),
            DropdownMenuItem(
              value: 1,
              child: Text(isVi ? 'Chủ Nhật' : 'Sunday'),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final displayTime = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
        : (isVi ? 'Chưa chọn' : 'Not set');
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: secondaryText),
          prefixIcon: Icon(Icons.access_time, color: secondaryText),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: darkBackground,
        ),
        child: Text(
          displayTime,
          style: TextStyle(
            color: lightText,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _xacNhanXoaLichHoc(LichHoc lichHoc) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isVi ? 'Xác nhận xóa' : 'Confirm Delete',
          style: TextStyle(color: lightText),
        ),
        content: Text(
          isVi
              ? 'Bạn có chắc muốn xóa lịch học này không?'
              : 'Delete this schedule slot?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: deleteColor),
            onPressed: () async {
              Navigator.pop(ctx);
              if (lichHoc.id != null) {
                await _lichHocService.xoaLichHoc(lichHoc.id!);
                ref.invalidate(lopDetailControllerProvider(widget.lop.id!));
              }
            },
            child: Text(
              isVi ? 'Xóa' : 'Delete',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _unassignStudentFromCard(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isVi ? 'Hủy gán ca học' : 'Unassign Schedule',
          style: TextStyle(color: lightText),
        ),
        content: Text(
          isVi
              ? 'Hủy gán ca học của học sinh ${hs.ten}?'
              : 'Unassign schedule slot for ${hs.ten}?',
          style: TextStyle(color: lightText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: deleteColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isVi ? 'Xóa khỏi ca' : 'Unassign',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StudentScheduleAssignmentService.instance
          .unassignStudentsFromClassSchedules(
        classId: widget.lop.id!,
        studentIds: [hs.id!],
      );
      ref.invalidate(lopDetailControllerProvider(widget.lop.id!));
    }
  }

  void _moAssignmentSheet({
    required List<HSLopViewModel> dsHocSinh,
    required List<LichHoc> dsLichHoc,
    int? scheduleId,
    bool filterUnassignedOnly = false,
  }) async {
    final result = await StudentAssignmentSheet.show(
      context,
      lop: widget.lop,
      danhSachHocSinh: dsHocSinh,
      dsLichHoc: dsLichHoc,
      initialScheduleId: scheduleId,
      filterUnassignedOnly: filterUnassignedOnly,
    );
    if (result == true) {
      ref.invalidate(lopDetailControllerProvider(widget.lop.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(lopDetailControllerProvider(widget.lop.id!));
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    return stateAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: accentColor)),
      error: (err, _) => Center(
        child: Text(
          isVi ? 'Lỗi tải lịch: $err' : 'Error loading schedule: $err',
          style: TextStyle(color: deleteColor),
        ),
      ),
      data: (state) {
        final dsLichHoc = state.lichHocs;
        final dsHocSinh = state.hocSinhs;

        return FutureBuilder<ClassScheduleRoster>(
          future: StudentScheduleAssignmentService.instance.getClassScheduleRoster(
            classId: widget.lop.id!,
            schedules: dsLichHoc,
            activeStudents: dsHocSinh,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: accentColor));
            }

            final Map<int, List<int>> fallbackMap = {};
            for (final sch in dsLichHoc) {
              if (sch.id != null) fallbackMap[sch.id!] = [];
            }

            final roster = snapshot.data ??
                ClassScheduleRoster(
                  schedules: dsLichHoc,
                  activeStudents: dsHocSinh,
                  activeAssignmentByStudentId: {},
                  studentIdsByScheduleId: fallbackMap,
                  unassignedStudentIds:
                      dsHocSinh.map((h) => h.id).whereType<int>().toSet(),
                );

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(lopDetailControllerProvider(widget.lop.id!));
              },
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    // Quick Actions Header Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LỊCH HỌC NGUYÊN BẢN',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                side: BorderSide(color: accentColor),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => WeeklySchedulingPage(
                                      classId: widget.lop.id!,
                                      className: widget.lop.ten,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.auto_awesome,
                                color: accentColor,
                                size: 16,
                              ),
                              label: Text(
                                '✨ Gợi ý xếp ca',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: darkBackground,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                              onPressed: () => _moDialogThemLichHoc(),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text(
                                '+ Ca',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Batch Unassigned Quick Action Card
                    InkWell(
                      onTap: () {
                        _moAssignmentSheet(
                          dsHocSinh: dsHocSinh,
                          dsLichHoc: dsLichHoc,
                          filterUnassignedOnly: true,
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade900.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.amber.shade700.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_add_alt_1,
                              color: Colors.amber.shade400,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                roster.unassignedStudentIds.isNotEmpty
                                    ? 'CHƯA GÁN (${roster.unassignedStudentIds.length} HS) • Chạm để gán ca'
                                    : 'QUẢN LÝ GÁN HỌC SINH THEO CA',
                                style: TextStyle(
                                  color: Colors.amber.shade300,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.amber.shade400,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: dsLichHoc.isEmpty
                          ? Center(
                              child: Text(
                                isVi
                                    ? 'Chưa thiết lập lịch học cho lớp này.'
                                    : 'No schedule set.',
                                style: TextStyle(color: secondaryText),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: dsLichHoc.length,
                              itemBuilder: (context, index) {
                                return _buildCompactLichHocCard(
                                  dsLichHoc[index],
                                  dsHocSinh,
                                  dsLichHoc,
                                  index + 1,
                                  roster,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompactLichHocCard(
    LichHoc lichHoc,
    List<HSLopViewModel> dsHocSinh,
    List<LichHoc> allLichHocs,
    int slotIndex,
    ClassScheduleRoster roster,
  ) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final gioBatDauFormatted = _formatTimeDisplay(lichHoc.gioBatDau);
    final gioKetThucFormatted = _formatTimeDisplay(lichHoc.gioKetThuc);
    final tenThu = _translateDayOfWeek(
      _dayOfWeekName(lichHoc.thuTrongTuan),
      isVi,
    );

    final assignedIds = roster.studentIdsByScheduleId[lichHoc.id] ?? [];
    final assignedStudents =
        dsHocSinh.where((h) => assignedIds.contains(h.id)).toList();

    final String studentNamesText = assignedStudents.isEmpty
        ? 'Chưa có học sinh gán ca này'
        : assignedStudents.take(3).map((h) => h.ten).join(', ') +
            (assignedStudents.length > 3
                ? ' +${assignedStudents.length - 3}'
                : '');

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: accentColor.withValues(alpha: 0.2),
                  child: Text(
                    _dayOfWeekInitial(lichHoc.thuTrongTuan),
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Suất $slotIndex • $tenThu',
                            style: TextStyle(
                              color: lightText,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$gioBatDauFormatted – $gioKetThucFormatted',
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: secondaryText, size: 20),
                  color: darkBackground,
                  onSelected: (value) async {
                    if (value == 'calendar') {
                      final schedule = LichHocCoTenLop(
                        lichHoc: lichHoc,
                        tenLop: widget.lop.ten,
                        khoi: widget.lop.khoi,
                        siSo: dsHocSinh.length,
                      );
                      await CalendarSyncService.themCaHocVaoCalendar(schedule);
                    } else if (value == 'copy') {
                      _moDialogThemLichHoc(lichHoc: lichHoc, isCopy: true);
                    } else if (value == 'edit') {
                      _moDialogThemLichHoc(lichHoc: lichHoc);
                    } else if (value == 'delete') {
                      _xacNhanXoaLichHoc(lichHoc);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'calendar',
                      child: Text('Thêm vào Lịch điện thoại'),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Text('Copy ca học'),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Sửa ca học'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Xóa ca học',
                        style: TextStyle(color: deleteColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Đã gán: ${assignedStudents.length} HS',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        studentNamesText,
                        style: TextStyle(color: secondaryText, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: darkBackground,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    _moAssignmentSheet(
                      dsHocSinh: dsHocSinh,
                      dsLichHoc: allLichHocs,
                      scheduleId: lichHoc.id,
                    );
                  },
                  icon: const Icon(Icons.group_add, size: 14),
                  label: const Text(
                    'Quản lý HS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            if (assignedStudents.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: assignedStudents.map((hs) {
                  return InputChip(
                    avatar: CircleAvatar(
                      backgroundColor: accentColor.withValues(alpha: 0.3),
                      child: Text(
                        hs.ten.isNotEmpty ? hs.ten[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    label: Text(
                      hs.ten,
                      style: TextStyle(color: lightText, fontSize: 11),
                    ),
                    deleteIcon: Icon(
                      Icons.cancel,
                      size: 14,
                      color: Colors.redAccent.shade100,
                    ),
                    onDeleted: () => _unassignStudentFromCard(hs),
                    backgroundColor: darkBackground,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
