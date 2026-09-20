// File: lib/screens/lop_detail.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/lop_detail_controller.dart';
import '../models/lop.dart';
import '../services/lop_service.dart';
import '../services/student_event_service.dart';
import '../services/tuition_event_service.dart';
import '../widgets/dang_ky_nghi_le_dialog.dart';
import '../widgets/gui_thong_bao_hang_loat_dialog.dart';
import '../widgets/xuat_bao_cao_pdf_dialog.dart';
import 'class_detail/tabs/class_evaluation_tab.dart';
import 'class_detail/tabs/class_overview_tab.dart';
import 'class_detail/tabs/class_schedule_tab.dart';
import 'class_detail/tabs/class_student_list_tab.dart';
import 'diem_danh_page.dart';
import 'weekly_scheduling_page.dart';

class LopDetail extends ConsumerStatefulWidget {
  final Lop lop;
  const LopDetail({super.key, required this.lop});

  @override
  ConsumerState<LopDetail> createState() => _LopDetailState();
}

class _LopDetailState extends ConsumerState<LopDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Lop _currentLop;

  StreamSubscription? _studentUpdatedSub;
  StreamSubscription? _studentCreatedSub;
  StreamSubscription? _studentDeletedSub;

  final _lopService = LopService();

  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  @override
  void initState() {
    super.initState();
    _currentLop = widget.lop;
    _tabController = TabController(length: 4, vsync: this);

    TuitionEventService().addListener(_onTuitionEventChanged);

    _studentUpdatedSub = StudentEventService().onStudentUpdated.listen((_) {
      if (mounted) {
        ref.invalidate(lopDetailControllerProvider(_currentLop.id!));
      }
    });
    _studentCreatedSub = StudentEventService().onStudentCreated.listen((_) {
      if (mounted) {
        ref.invalidate(lopDetailControllerProvider(_currentLop.id!));
      }
    });
    _studentDeletedSub = StudentEventService().onStudentDeleted.listen((_) {
      if (mounted) {
        ref.invalidate(lopDetailControllerProvider(_currentLop.id!));
      }
    });
  }

  @override
  void dispose() {
    _studentUpdatedSub?.cancel();
    _studentCreatedSub?.cancel();
    _studentDeletedSub?.cancel();
    TuitionEventService().removeListener(_onTuitionEventChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTuitionEventChanged() {
    if (mounted) {
      ref.invalidate(lopDetailControllerProvider(_currentLop.id!));
    }
  }

  void _moDiemDanhPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiemDanhPage(
          selectedLopId: _currentLop.id,
          selectedDate: DateTime.now(),
        ),
      ),
    );
  }

  void _moDialogSuaLop() async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final tenLopController = TextEditingController(text: _currentLop.ten);
    int selectedKhoi = _currentLop.khoi;
    final List<int> danhSachKhoi = [6, 7, 8, 9, 10, 11, 12];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Center(
                child: Text(
                  isVi ? 'SỬA THÔNG TIN LỚP' : 'EDIT CLASS DETAILS',
                  style: TextStyle(
                    color: lightText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: isVi ? 'Khối' : 'Grade',
                      labelStyle: TextStyle(color: secondaryText),
                      prefixIcon: Icon(Icons.school, color: secondaryText),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: darkBackground,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: selectedKhoi,
                        isDense: true,
                        dropdownColor: cardColor,
                        style: TextStyle(color: lightText, fontSize: 16),
                        items: danhSachKhoi.map((khoi) {
                          return DropdownMenuItem<int>(
                            value: khoi,
                            child: Text(isVi ? 'Khối $khoi' : 'Grade $khoi'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() => selectedKhoi = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: tenLopController,
                    autofocus: true,
                    style: TextStyle(color: lightText),
                    decoration: InputDecoration(
                      labelText: isVi ? 'Tên lớp' : 'Class Name',
                      labelStyle: TextStyle(color: secondaryText),
                      prefixIcon: Icon(Icons.class_, color: secondaryText),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: darkBackground,
                    ),
                  ),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    isVi ? 'HỦY' : 'CANCEL',
                    style: TextStyle(color: secondaryText),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final tenMoi = tenLopController.text.trim();
                    if (tenMoi.isNotEmpty) {
                      final lopToUpdate = _currentLop.copyWith(
                        ten: tenMoi,
                        khoi: selectedKhoi,
                      );
                      await _lopService.capNhatLop(lopToUpdate);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop(true);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: accentColor),
                  child: Text(
                    isVi ? 'CẬP NHẬT' : 'UPDATE',
                    style: TextStyle(color: darkBackground),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final updatedLop = await _lopService.docLop(_currentLop.id!);
      if (updatedLop != null && mounted) {
        setState(() {
          _currentLop = updatedLop;
        });
        ref.invalidate(lopDetailControllerProvider(_currentLop.id!));
      }
    }
  }

  void _moDialogDangKyNghiLe() async {
    final state = ref.read(lopDetailControllerProvider(_currentLop.id!)).value;
    final danhSachHocSinh = state?.hocSinhs ?? [];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => DangKyNghiLeDialog(
        lop: _currentLop,
        danhSachHocSinh: danhSachHocSinh,
      ),
    );
    if (result == true) {
      ref.invalidate(lopDetailControllerProvider(_currentLop.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final lopDetailAsyncValue = ref.watch(
      lopDetailControllerProvider(_currentLop.id!),
    );

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: Text(
          isVi
              ? '${_currentLop.ten} (Khối ${_currentLop.khoi})'
              : '${_currentLop.ten} (Grade ${_currentLop.khoi})',
          style: TextStyle(
            color: lightText,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
        actions: [
          IconButton(
            icon: Icon(Icons.checklist_rtl_rounded, color: accentColor),
            tooltip: isVi ? 'Điểm danh lớp' : 'Take Attendance',
            onPressed: _moDiemDanhPage,
          ),
          IconButton(
            icon: Icon(Icons.send_rounded, color: accentColor),
            tooltip: isVi ? 'Gửi thông báo lớp' : 'Send Class Notification',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => GuiThongBaoHangLoatDialog(
                  initialLopId: _currentLop.id,
                  initialOnlyUnpaid: false,
                  initialType: NotificationType.baoNghiHoc,
                  allowedTypes: const [
                    NotificationType.baoNghiHoc,
                    NotificationType.baoDoiLich,
                    NotificationType.custom,
                  ],
                  dialogTitle: isVi
                      ? 'Gửi Thông Báo Lớp Học'
                      : 'Send Class Notification',
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: lightText),
            color: darkBackground,
            onSelected: (val) {
              if (val == 'edit') {
                _moDialogSuaLop();
              } else if (val == 'weekly_schedule') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeeklySchedulingPage(
                      classId: _currentLop.id!,
                      className: _currentLop.ten,
                    ),
                  ),
                );
              } else if (val == 'holiday_leave') {
                _moDialogDangKyNghiLe();
              } else if (val == 'export_pdf') {
                showDialog(
                  context: context,
                  builder: (ctx) =>
                      XuatBaoCaoPdfDialog(initialLop: _currentLop),
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: accentColor),
                    const SizedBox(width: 12),
                    Text(
                      isVi ? 'Sửa thông tin lớp' : 'Edit class details',
                      style: TextStyle(color: lightText),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'weekly_schedule',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: accentColor),
                    const SizedBox(width: 12),
                    Text(
                      isVi ? 'Xếp lịch tuần' : 'Weekly Scheduling',
                      style: TextStyle(color: lightText),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'holiday_leave',
                child: Row(
                  children: [
                    const Icon(
                      Icons.beach_access_rounded,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isVi ? 'Đăng ký nghỉ lễ' : 'Register holiday leave',
                      style: TextStyle(color: lightText),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: accentColor),
                    const SizedBox(width: 12),
                    Text(
                      isVi ? 'Xuất báo cáo PDF' : 'Export PDF Report',
                      style: TextStyle(color: lightText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          labelColor: accentColor,
          unselectedLabelColor: secondaryText,
          tabs: [
            Tab(
              icon: const Icon(Icons.info),
              text: isVi ? 'Chi Tiết' : 'Details',
            ),
            Tab(
              icon: const Icon(Icons.group),
              text: isVi ? 'Học Sinh' : 'Students',
            ),
            Tab(
              icon: const Icon(Icons.calendar_month),
              text: isVi ? 'Lịch Học' : 'Schedule',
            ),
            Tab(
              icon: const Icon(Icons.star),
              text: isVi ? 'Đánh Giá' : 'Evaluations',
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: lopDetailAsyncValue.when(
          loading: () =>
              Center(child: CircularProgressIndicator(color: accentColor)),
          error: (err, stack) => Center(
            child: Text(
              isVi ? 'Lỗi tải dữ liệu: $err' : 'Error loading data: $err',
              style: TextStyle(color: deleteColor),
            ),
          ),
          data: (lopDetailState) {
            return TabBarView(
              controller: _tabController,
              children: [
                ClassOverviewTab(
                  state: lopDetailState,
                  tabController: _tabController,
                ),
                ClassStudentListTab(state: lopDetailState),
                ClassScheduleTab(lop: _currentLop),
                ClassEvaluationTab(lop: _currentLop),
              ],
            );
          },
        ),
      ),
    );
  }
}
