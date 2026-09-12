// File: lib/screens/lop_detail.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/lop_detail_controller.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc.dart';
import '../models/diem_danh.dart';
import '../models/lich_hoc_chung.dart';
import '../models/nhan_xet_thang.dart';
import '../models/lop.dart';
import '../models/nhiem_vu.dart';
import '../services/hoc_sinh_service.dart';
import '../services/diem_danh_service.dart';
import '../services/nhan_xet_service.dart';
import '../services/lich_hoc_chung_service.dart';
import '../services/lich_hoc_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/lop_service.dart';
import '../services/nhiem_vu_service.dart';
import '../services/truong_service.dart';
import '../widgets/nhiem_vu_dialog.dart';
import '../widgets/them_hs_vao_lop_dialog.dart';
import 'diem_danh_page.dart';
import 'gan_lich_hoc_page.dart';
import 'su_kien_buoi_hoc_page.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/danh_gia_dialog.dart';
import '../widgets/gui_thong_bao_hang_loat_dialog.dart';
import '../services/pdf_export_service.dart';
import '../services/calendar_sync_service.dart';
import '../utils/toast_helper.dart';
import '../utils/db.dart';

// SỬA: Chuyển sang ConsumerStatefulWidget để dùng Riverpod
class LopDetail extends ConsumerStatefulWidget {
  final Lop lop;
  const LopDetail({super.key, required this.lop});

  @override
  ConsumerState<LopDetail> createState() => _LopDetailState();
}

class _LopDetailState extends ConsumerState<LopDetail>
    with SingleTickerProviderStateMixin {
  // --- Theme Colors ---
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  // --- Controllers ---
  late TabController _tabController;

  // --- Services (vẫn cần cho các dialog) ---
  final _lopService = LopService();
  final _lhsService = LopHocSinhService();
  final _hsService = HocSinhService();
  final _lichHocService = LichHocService();
  final _lhcService = LichHocChungService();
  final _nhiemVuService = NhiemVuService();
  final _nhanXetService = NhanXetService();
  final _diemDanhService = DiemDanhService();
  final _truongService = TruongService();

  // --- State (sẽ được thay thế dần) ---
  late Lop _currentLop;
  List<NhiemVu> _danhSachNhiemVu = [];

  @override
  void initState() {
    super.initState();
    _currentLop = widget.lop;
    _tabController = TabController(length: 4, vsync: this); // SỬA: Tăng số tab
    _taiNhiemVu();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ===================================================
  // HÀM TẢI DỮ LIỆU & XỬ LÝ
  // ===================================================

  Future<void> _taiNhiemVu() async {
    final ds = await _nhiemVuService.layNhiemVuTheoLop(_currentLop.id!);
    if (mounted) {
      setState(() {
        _danhSachNhiemVu = ds;
      });
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

  // SỬA: Thay thế trang FormLop bằng Dialog để sửa nhanh
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
                  // Dropdown chọn khối
                  // SỬA: Tạo Dropdown chọn khối riêng, không dùng lại _buildDayPicker
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
                  // TextField tên lớp
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return isVi
                            ? 'Vui lòng nhập tên lớp'
                            : 'Please enter class name';
                      }
                      return null;
                    },
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
      // Tải lại dữ liệu sau khi cập nhật thành công
      ref.invalidate(lopDetailControllerProvider(_currentLop));
    }
  }

  // ===================================================
  // BUILD METHOD
  // ===================================================

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    // SỬA: Lấy provider
    final lopDetailAsyncValue = ref.watch(
      lopDetailControllerProvider(_currentLop),
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
                  dialogTitle: 'Gửi Thông Báo Lớp Học',
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.edit_note, color: accentColor),
            onPressed: _moDialogSuaLop,
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
            ), // SỬA: Thêm tab mới
          ],
        ),
      ),
      // SỬA: Dùng when để xử lý các trạng thái của provider
      body: lopDetailAsyncValue.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: accentColor)),
        error: (err, stack) => Center(
          child: Text(
            isVi ? 'Lỗi tải dữ liệu: $err' : 'Error loading data: $err',
            style: TextStyle(color: deleteColor),
          ),
        ),
        data: (lopDetailState) {
          // Khi có dữ liệu, build TabBarView
          return TabBarView(
            controller: _tabController,
            children: [
              _buildThongTinLopSection(lopDetailState),
              _buildDSHSSection(lopDetailState),
              _buildLichHocSection(lopDetailState),
              _buildDanhGiaSection(
                lopDetailState,
              ), // SỬA: Thêm nội dung tab mới
            ],
          );
        },
      ),
    );
  }

  // ===================================================
  // TAB 1: THÔNG TIN CHI TIẾT LỚP
  // ===================================================
  Widget _buildThongTinLopSection(LopDetailState state) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final percentageFmt = NumberFormat('##.#%', 'vi_VN');
    final collectedRate = state.summary.tongHocPhiDuKien > 0
        ? state.summary.tongHocPhiDaThu / state.summary.tongHocPhiDuKien
        : 0.0;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dashboard Summary
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildModernMetricCard(
                isVi ? 'Sĩ Số' : 'Size',
                state.siSo.toString(),
                Icons.people_rounded,
                accentColor,
                isVi ? 'Số lượng học sinh' : 'Number of students',
              ),
              _buildModernMetricCard(
                isVi ? 'Lịch Học' : 'Schedule',
                isVi
                    ? '${state.lichHocs.length} buổi'
                    : '${state.lichHocs.length} sessions',
                Icons.calendar_today_rounded,
                Colors.orangeAccent,
                isVi ? 'Số buổi dạy/tuần' : 'Sessions/week',
              ),
              _buildModernMetricCard(
                isVi ? 'Chuyên Cần' : 'Attendance',
                percentageFmt.format(state.summary.tyLeChuyenCan),
                Icons.task_alt_rounded,
                Colors.greenAccent,
                isVi ? 'Tỷ lệ đi học' : 'Attendance rate',
              ),
              _buildModernMetricCard(
                isVi ? 'Học Phí' : 'Tuition',
                percentageFmt.format(collectedRate),
                Icons.payments_rounded,
                Colors.blueAccent,
                isVi ? 'Tỷ lệ đã thu' : 'Collection rate',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Quick Action Button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _moDiemDanhPage,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.checklist_rtl_rounded,
                        color: darkBackground,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isVi ? 'ĐIỂM DANH LỚP' : 'CLASS ATTENDANCE',
                        style: TextStyle(
                          color: darkBackground,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          _buildSectionHeader(
            isVi ? 'DANH SÁCH NHIỆM VỤ' : 'TASK LIST',
            Icons.assignment_rounded,
          ),
          _buildNhiemVuSection(state),
        ],
      ),
    );
  }

  Widget _buildModernMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Icon(
                Icons.more_horiz,
                color: secondaryText.withValues(alpha: 0.3),
                size: 16,
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: lightText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: secondaryText.withValues(alpha: 0.5), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: secondaryText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // TAB 2: DANH SÁCH HỌC SINH
  // ===================================================
  Widget _buildDSHSSection(LopDetailState state) {
    final dsHS = state.hocSinhs;
    final dsDaNghi = state.hocSinhsDaNghi;
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    // SỬA: Bỏ Scaffold và FloatingActionButton, thay bằng Column với header
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        children: [
          // Header với nút thêm
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'DANH SÁCH HỌC SINH' : 'STUDENT LIST',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.person_add_alt_1, color: accentColor),
                onPressed: _moDialogThemHS,
                tooltip: isVi
                    ? 'Thêm học sinh vào lớp'
                    : 'Add student to class',
              ),
            ],
          ),
          Divider(color: secondaryText),
          // Danh sách
          Expanded(
            child: dsHS.isEmpty && dsDaNghi.isEmpty
                ? Center(
                    child: Text(
                      isVi
                          ? 'Chưa có học sinh nào trong lớp.'
                          : 'No students in this class.',
                      style: TextStyle(color: secondaryText),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(top: 0),
                    children: [
                      ...dsHS.map(_buildHocSinhCard),
                      if (dsDaNghi.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                          child: Text(
                            isVi
                                ? 'HỌC SINH ĐÃ NGHỈ (${dsDaNghi.length})'
                                : 'FORMER STUDENTS (${dsDaNghi.length})',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ...dsDaNghi.map(_buildHocSinhCard),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHocSinhCard(HSLopViewModel hsViewModel) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final isPaused = hsViewModel.trangThai == 'TAM_NGUNG';
    final isFormer = !_lhsService.hoatDongTrongNgay(
      hsViewModel,
      DateTime.now(),
    );
    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: InkWell(
        onTap: () => _hienThiDialogThongTinHocSinh(hsViewModel),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accentColor.withValues(alpha: 0.2),
                child: Text(
                  hsViewModel.ten.isNotEmpty
                      ? hsViewModel.ten[0].toUpperCase()
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
                      hsViewModel.ten,
                      style: TextStyle(
                        color: lightText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isPaused) ...[
                      const SizedBox(height: 4),
                      Text(
                        isVi
                            ? 'Tạm ngừng từ ${_formatOptionalDate(hsViewModel.ngayTamNgung)}'
                            : 'Paused from ${_formatOptionalDate(hsViewModel.ngayTamNgung)}',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (isFormer) ...[
                      const SizedBox(height: 4),
                      Text(
                        isVi
                            ? 'Đã nghỉ từ ${_formatOptionalDate(hsViewModel.ngayNghiHoc)}'
                            : 'Left from ${_formatOptionalDate(hsViewModel.ngayNghiHoc)}',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      isVi
                          ? 'Ngày tham gia: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(hsViewModel.ngayThamGia))}'
                          : 'Joined: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(hsViewModel.ngayThamGia))}',
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: secondaryText),
                color: darkBackground,
                onSelected: (value) {
                  if (value == 'reactivate') {
                    _kichHoatHocLai(hsViewModel);
                  } else if (value == 'leave') {
                    _moDialogDangKyNghi(hsViewModel);
                  } else if (value == 'pause') {
                    _moDialogTamNgung(hsViewModel);
                  } else if (value == 'resume') {
                    _choHocLai(hsViewModel);
                  } else if (value == 'edit_date') {
                    _moDialogSuaNgayThamGia(hsViewModel);
                  } else if (value == 'evaluate') {
                    _moDialogDanhGiaNhanh(hsViewModel);
                  } else if (value == 'delete') {
                    _xacNhanXoaHS(hsViewModel);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (isFormer)
                    PopupMenuItem<String>(
                      value: 'reactivate',
                      child: Row(
                        children: [
                          const Icon(Icons.person_add_alt, color: Colors.greenAccent),
                          const SizedBox(width: 12),
                          Text(
                            isVi ? 'Cho học lại' : 'Reactivate',
                            style: TextStyle(color: lightText),
                          ),
                        ],
                      ),
                    ),
                  if (!isFormer)
                    PopupMenuItem<String>(
                      value: 'leave',
                      child: Row(
                        children: [
                          const Icon(Icons.event_busy, color: Colors.amber),
                          const SizedBox(width: 12),
                          Text(isVi ? 'Đăng ký nghỉ có phép' : 'Excused leave', style: TextStyle(color: lightText)),
                        ],
                      ),
                    ),
                  if (!isFormer)
                    PopupMenuItem<String>(
                      value: isPaused ? 'resume' : 'pause',
                      child: Row(
                        children: [
                          Icon(isPaused ? Icons.play_arrow : Icons.pause, color: Colors.orangeAccent),
                          const SizedBox(width: 12),
                          Text(
                            isPaused ? (isVi ? 'Cho học lại' : 'Resume') : (isVi ? 'Tạm ngừng học' : 'Pause study'),
                            style: TextStyle(color: lightText),
                          ),
                        ],
                      ),
                    ),
                  if (!isFormer)
                    PopupMenuItem<String>(
                      value: 'edit_date',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_calendar, color: Colors.blueAccent),
                          const SizedBox(width: 12),
                          Text(
                            isVi ? 'Sửa ngày' : 'Edit date',
                            style: TextStyle(color: lightText),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem<String>(
                    value: 'evaluate',
                    child: Row(
                      children: [
                        Icon(Icons.edit_note, color: accentColor),
                        const SizedBox(width: 12),
                        Text(
                          isVi ? 'Đánh giá' : 'Evaluate',
                          style: TextStyle(color: lightText),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: deleteColor),
                        const SizedBox(width: 12),
                        Text(
                          isVi ? 'Cho nghỉ học' : 'Leave class',
                          style: TextStyle(color: deleteColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _hienThiDialogThongTinHocSinh(HSLopViewModel hsViewModel) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');
    final thangCurrent = DateFormat('yyyy-MM').format(DateTime.now());
    final formattedThang = DateFormat('MM/yyyy').format(DateTime.now());

    // 1. Đếm số buổi nghỉ học của tháng
    final counts = await _diemDanhService.demSoBuoiTheoTrangThai(
      hsViewModel.id!,
      _currentLop.id!,
      thangCurrent,
    );
    final int nghiCoPhep = counts['nghiCoPhep'] ?? 0;
    final int nghiKhongPhep = counts['nghiKhongPhep'] ?? 0;
    final int tongNghi = nghiCoPhep + nghiKhongPhep;

    // 2. Đọc thông tin thanh toán từ cơ sở dữ liệu
    final db = await DBHelper.instance.database;
    final List<Map<String, dynamic>> records = await db.query(
      DBHelper.tenBangThanhToan,
      where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
      whereArgs: [hsViewModel.id!, _currentLop.id!, thangCurrent],
    );

    int tongThanhToan = 0;
    int soTienDaDong = 0;
    if (records.isNotEmpty) {
      tongThanhToan = records.first['tong_thanh_toan'] as int? ?? 0;
      soTienDaDong = records.first['so_tien_da_dong'] as int? ?? 0;
    }

    final int conNo = tongThanhToan - soTienDaDong;
    final bool isDaDong = records.isNotEmpty && conNo <= 0;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: accentColor.withValues(alpha: 0.2),
              child: Text(
                hsViewModel.ten.isNotEmpty ? hsViewModel.ten[0].toUpperCase() : '?',
                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hsViewModel.ten,
                style: TextStyle(color: lightText, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 8),
            _buildDialogInfoRow(
              Icons.account_balance_wallet_outlined,
              isVi ? 'Số buổi dư tích lũy:' : 'Rollover sessions:',
              '${hsViewModel.soBuoiDu} buổi',
              valueColor: accentColor,
            ),
            const SizedBox(height: 14),
            _buildDialogInfoRow(
              Icons.event_busy_outlined,
              isVi ? 'Số buổi nghỉ học (Tháng $formattedThang):' : 'Absences ($formattedThang):',
              '$tongNghi buổi ($nghiCoPhep có phép, $nghiKhongPhep không phép)',
              valueColor: tongNghi > 0 ? Colors.orangeAccent : lightText,
            ),
            const SizedBox(height: 14),
            _buildDialogInfoRow(
              Icons.payment_outlined,
              isVi ? 'Trạng thái học phí:' : 'Tuition status:',
              records.isEmpty
                  ? (isVi ? 'Chưa khởi tạo' : 'Not initialized')
                  : (isDaDong
                      ? (isVi ? 'Đã đóng đủ' : 'Fully paid')
                      : (isVi
                          ? 'Chưa đóng (Còn nợ: ${formatCurrency.format(conNo)}đ)'
                          : 'Unpaid (Debt: ${formatCurrency.format(conNo)}đ)')),
              valueColor: isDaDong ? Colors.greenAccent : deleteColor,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isVi ? 'Đóng' : 'Close', style: TextStyle(color: secondaryText)),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: secondaryText),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: secondaryText, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? lightText,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatOptionalDate(String? value) {
    final date = value == null ? null : DateTime.tryParse(value);
    return date == null ? '--' : DateFormat('dd/MM/yyyy').format(date);
  }

  Future<DateTime?> _pickLeaveDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
  }

  Future<void> _moDialogDangKyNghi(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    DateTime from = DateTime.now();
    DateTime to = DateTime.now();
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          title: Text(isVi ? 'Đăng ký nghỉ có phép' : 'Excused leave', style: TextStyle(color: lightText)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(isVi ? 'Từ ngày' : 'From', style: TextStyle(color: secondaryText)),
                trailing: Text(DateFormat('dd/MM/yyyy').format(from), style: TextStyle(color: lightText)),
                onTap: () async {
                  final value = await _pickLeaveDate(from);
                  if (value != null) setDialogState(() { from = value; if (to.isBefore(from)) to = from; });
                },
              ),
              ListTile(
                title: Text(isVi ? 'Đến ngày' : 'To', style: TextStyle(color: secondaryText)),
                trailing: Text(DateFormat('dd/MM/yyyy').format(to), style: TextStyle(color: lightText)),
                onTap: () async {
                  final value = await _pickLeaveDate(to);
                  if (value != null && !value.isBefore(from)) setDialogState(() => to = value);
                },
              ),
              TextField(
                controller: reason,
                style: TextStyle(color: lightText),
                decoration: InputDecoration(labelText: isVi ? 'Lý do' : 'Reason'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(isVi ? 'Hủy' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(isVi ? 'Lưu' : 'Save')),
          ],
        ),
      ),
    );
    if (saved != true) { reason.dispose(); return; }
    await _lhsService.dangKyNghiCoPhep(
      idLop: _currentLop.id!, idHocSinh: hs.id!,
      tuNgay: DateFormat('yyyy-MM-dd').format(from),
      denNgay: DateFormat('yyyy-MM-dd').format(to), lyDo: reason.text.trim(),
    );
    reason.dispose();
    if (mounted) _showInfoDialog(isVi ? 'Đã lưu' : 'Saved', isVi ? 'Các ca học trong khoảng nghỉ sẽ mặc định là nghỉ có phép.' : 'Sessions in this range will default to excused absence.');
  }

  Future<void> _moDialogTamNgung(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    DateTime start = DateTime.now();
    DateTime? expected;
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          title: Text(isVi ? 'Tạm ngừng học' : 'Pause study', style: TextStyle(color: lightText)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              title: Text(isVi ? 'Bắt đầu' : 'Start', style: TextStyle(color: secondaryText)),
              trailing: Text(DateFormat('dd/MM/yyyy').format(start), style: TextStyle(color: lightText)),
              onTap: () async { final v = await _pickLeaveDate(start); if (v != null) setDialogState(() => start = v); },
            ),
            ListTile(
              title: Text(isVi ? 'Dự kiến học lại' : 'Expected return', style: TextStyle(color: secondaryText)),
              trailing: Text(expected == null ? '--' : DateFormat('dd/MM/yyyy').format(expected!), style: TextStyle(color: lightText)),
              onTap: () async { final v = await _pickLeaveDate(expected ?? start); if (v != null && !v.isBefore(start)) setDialogState(() => expected = v); },
            ),
            TextField(controller: reason, style: TextStyle(color: lightText), decoration: InputDecoration(labelText: isVi ? 'Lý do' : 'Reason')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(isVi ? 'Hủy' : 'Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(isVi ? 'Xác nhận' : 'Confirm')),
          ],
        ),
      ),
    );
    if (saved != true) { reason.dispose(); return; }
    await _lhsService.tamNgungHoc(
      idLop: _currentLop.id!, idHocSinh: hs.id!,
      ngayBatDau: DateFormat('yyyy-MM-dd').format(start),
      ngayDuKienHocLai: expected == null ? null : DateFormat('yyyy-MM-dd').format(expected!),
      lyDo: reason.text.trim(),
    );
    reason.dispose();
    ref.invalidate(lopDetailControllerProvider(_currentLop));
  }

  Future<void> _choHocLai(HSLopViewModel hs) async {
    final date = await _pickLeaveDate(DateTime.now());
    if (date == null) return;
    await _lhsService.choHocLai(
      idLop: _currentLop.id!, idHocSinh: hs.id!,
      ngayHocLai: DateFormat('yyyy-MM-dd').format(date),
    );
    ref.invalidate(lopDetailControllerProvider(_currentLop));
  }

  Future<void> _kichHoatHocLai(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final earliest = hs.ngayNghiHoc == null
        ? DateTime.now()
        : DateTime.tryParse(hs.ngayNghiHoc!) ?? DateTime.now();
    final date = await _pickLeaveDate(DateTime.now().isBefore(earliest) ? earliest : DateTime.now());
    if (date == null || date.isBefore(earliest)) return;
    final updated = await _lhsService.kichHoatHocLai(
      idLop: _currentLop.id!,
      idHocSinh: hs.id!,
      ngayHocLai: DateFormat('yyyy-MM-dd').format(date),
    );
    if (updated > 0) {
      ref.invalidate(lopDetailControllerProvider(_currentLop));
      if (mounted) {
        _showInfoDialog(
          isVi ? 'Đã kích hoạt' : 'Reactivated',
          isVi
              ? '${hs.ten} sẽ đi học lại từ ${DateFormat('dd/MM/yyyy').format(date)}.'
              : '${hs.ten} returns from ${DateFormat('dd/MM/yyyy').format(date)}.',
        );
      }
    }
  }

  // HÀM MỚI: Sửa ngày nhập học của học sinh trong lớp
  void _moDialogSuaNgayThamGia(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    DateTime initialDate;
    try {
      initialDate = DateTime.parse(hs.ngayThamGia);
    } catch (e) {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
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

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      final updatedCount = await _lhsService.capNhatNgayThamGia(
        _currentLop.id!,
        hs.id!,
        formattedDate,
      );

      if (updatedCount > 0) {
        ref.invalidate(lopDetailControllerProvider(_currentLop));
        if (mounted) {
          _showInfoDialog(
            isVi ? 'Thành công' : 'Success',
            isVi
                ? 'Đã cập nhật ngày nhập học thành công!'
                : 'Enrollment date updated successfully!',
          );
        }
      }
    }
  }

  // HÀM MỚI: Mở dialog đánh giá nhanh từ danh sách học sinh
  void _moDialogDanhGiaNhanh(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final now = DateTime.now();
    final ngayStr = DateFormat('yyyy-MM-dd').format(now);
    final int thuTrongTuanDB = (now.weekday == 7) ? 1 : now.weekday + 1;

    // 1. Tìm ca học hôm nay của lớp
    final allCaHoc = await _lichHocService.layLichHocTheoLop(_currentLop.id!);
    final caHocHomNay = allCaHoc
        .where((lh) => lh.thuTrongTuan == thuTrongTuanDB)
        .toList();

    if (caHocHomNay.isEmpty) {
      if (mounted) {
        _showInfoDialog(
          isVi ? 'Thông báo' : 'Notification',
          isVi
              ? 'Hôm nay lớp không có ca học nào.'
              : 'No sessions scheduled for today.',
          titleColor: Colors.orangeAccent,
        );
      }
      return;
    }

    // Giả sử ta đánh giá cho ca học đầu tiên trong ngày
    final caHoc = caHocHomNay.first;

    // 2. Tìm hoặc tạo bản ghi điểm danh cho học sinh trong ca học đó
    // Tạo một bản ghi tạm thời
    final diemDanhRecord = DiemDanh(
      idHocSinh: hs.id!,
      idLop: _currentLop.id!,
      gioDiemDanh: '$ngayStr ${caHoc.gioBatDau}',
      trangThai: 'Có mặt',
    );

    // Dùng `themDiemDanh` với `replace` để đảm bảo bản ghi tồn tại và lấy được ID
    final idDiemDanh = await _diemDanhService.themDiemDanh(diemDanhRecord);

    // 3. Mở trang đánh giá
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) =>
              SuKienBuoiHocPage(idDiemDanh: idDiemDanh, tenHocSinh: hs.ten),
        ),
      );
    }
  }

  void _moDialogThemHS() async {
    final tatCaHS = await _hsService.docTatCaHocSinh();
    final danhSachTruong = await _truongService.docTatCaTruong();
    final hsTrongLopIds = ref
        .read(lopDetailControllerProvider(_currentLop))
        .value
        ?.hocSinhs
        .map((e) => e.id)
        .toSet();

    final hsChuaCoLop = tatCaHS
        .where(
          (hs) => hs.id != null && !(hsTrongLopIds?.contains(hs.id) ?? false),
        )
        .toList();

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemHSVaoLopDialog(
        lop: _currentLop,
        danhSachTatCaHS: hsChuaCoLop,
        lhsService: _lhsService,
        hsService: _hsService,
        danhSachTruong: danhSachTruong,
      ),
    );

    if (result == true) {
      ref.invalidate(lopDetailControllerProvider(_currentLop));
    }
  }

  void _xacNhanXoaHS(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    DateTime leaveDate = DateTime.now();
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            isVi ? 'Cho học sinh nghỉ học' : 'Student leaves class',
            style: TextStyle(color: lightText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isVi
                    ? 'Học phí và điểm danh sẽ dừng từ ngày này. Lịch sử trước đó vẫn được giữ.'
                    : 'Tuition and attendance stop from this date. Earlier history is preserved.',
                style: TextStyle(color: secondaryText),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isVi ? 'Ngày nghỉ học' : 'Leaving date',
                  style: TextStyle(color: secondaryText),
                ),
                trailing: Text(
                  DateFormat('dd/MM/yyyy').format(leaveDate),
                  style: TextStyle(color: lightText),
                ),
                onTap: () async {
                  final picked = await _pickLeaveDate(leaveDate);
                  if (picked != null) {
                    setDialogState(() => leaveDate = picked);
                  }
                },
              ),
              TextField(
                controller: reason,
                style: TextStyle(color: lightText),
                decoration: InputDecoration(
                  labelText: isVi ? 'Lý do (không bắt buộc)' : 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                isVi ? 'Hủy' : 'Cancel',
                style: TextStyle(color: secondaryText),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                isVi ? 'Xác nhận nghỉ' : 'Confirm',
                style: TextStyle(color: deleteColor),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      reason.dispose();
      return;
    }
    final updated = await _lhsService.choHocSinhNghiHoc(
      idLop: _currentLop.id!,
      idHocSinh: hs.id!,
      ngayNghiHoc: DateFormat('yyyy-MM-dd').format(leaveDate),
      lyDo: reason.text.trim(),
    );
    reason.dispose();
    if (updated > 0) {
      ref.invalidate(lopDetailControllerProvider(_currentLop));
      if (mounted) {
        _showInfoDialog(
          isVi ? 'Thành công' : 'Success',
          isVi
              ? 'Đã ghi nhận ${hs.ten} nghỉ từ ${DateFormat('dd/MM/yyyy').format(leaveDate)}.'
              : '${hs.ten} leaves from ${DateFormat('dd/MM/yyyy').format(leaveDate)}.',
        );
      }
    }
  }
  // ===================================================
  // TAB 3: LỊCH HỌC
  // ===================================================
  Widget _buildLichHocSection(LopDetailState state) {
    final dsLichHoc = state.lichHocs;
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'DANH SÁCH LỊCH HỌC' : 'SCHEDULE LIST',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add_circle_outline, color: accentColor),
                onPressed: () => _moDialogThemLichHoc(),
                tooltip: isVi ? 'Thêm lịch học' : 'Add schedule',
              ),
            ],
          ),
          Divider(color: secondaryText),
          Expanded(
            child: dsLichHoc.isEmpty
                ? Center(
                    child: Text(
                      isVi ? 'Chưa thiết lập lịch học.' : 'No schedule set.',
                      style: TextStyle(color: secondaryText),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 0),
                    itemCount: dsLichHoc.length,
                    itemBuilder: (context, index) {
                      return _buildLichHocCard(dsLichHoc[index], state.hocSinhs);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLichHocCard(LichHoc lichHoc, List<HSLopViewModel> dsHocSinh) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final gioBatDauFormatted = lichHoc.gioBatDau.substring(0, 5);
    final gioKetThucFormatted = lichHoc.gioKetThuc.substring(0, 5);
    final tenThu = _translateDayOfWeek(_dayOfWeekName(lichHoc.thuTrongTuan), isVi);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accentColor.withValues(alpha: 0.2),
          child: Text(
            _dayOfWeekInitial(lichHoc.thuTrongTuan),
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          tenThu,
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '$gioBatDauFormatted - $gioKetThucFormatted',
          style: TextStyle(color: secondaryText, fontSize: 14),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: secondaryText),
          color: darkBackground,
          onSelected: (value) async {
            if (value == 'calendar') {
              final schedule = LichHocCoTenLop(
                lichHoc: lichHoc,
                tenLop: _currentLop.ten,
                khoi: _currentLop.khoi,
                siSo: dsHocSinh.length,
              );
              final success = await CalendarSyncService.themCaHocVaoCalendar(schedule);
              if (mounted) {
                if (success) {
                  ToastHelper.showSuccess(
                    context,
                    isVi
                        ? 'Đã mở ứng dụng Lịch để đồng bộ ca dạy!'
                        : 'Calendar opened for schedule sync!',
                  );
                } else {
                  ToastHelper.showError(
                    context,
                    isVi ? 'Không thể đồng bộ vào Lịch' : 'Failed to sync with Calendar',
                  );
                }
              }
            } else if (value == 'copy') {
              _moDialogThemLichHoc(lichHoc: lichHoc, isCopy: true);
            } else if (value == 'edit') {
              _moDialogThemLichHoc(lichHoc: lichHoc);
            } else if (value == 'assign') {
              _moTrangGanLichHoc(lichHoc, dsHocSinh);
            } else if (value == 'delete') {
              _xacNhanXoaLichHoc(lichHoc);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'calendar',
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  Text(
                    isVi ? 'Thêm vào Lịch điện thoại' : 'Add to Phone Calendar',
                    style: TextStyle(color: lightText),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'copy',
              child: Row(
                children: [
                  const Icon(Icons.copy, color: Colors.amberAccent),
                  const SizedBox(width: 12),
                  Text(
                    isVi ? 'Copy Lịch Học' : 'Copy Schedule',
                    style: TextStyle(color: lightText),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.greenAccent),
                  const SizedBox(width: 12),
                  Text(
                    isVi ? 'Sửa Lịch Học' : 'Edit Schedule',
                    style: TextStyle(color: lightText),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'assign',
              child: Row(
                children: [
                  Icon(Icons.person_add, color: accentColor),
                  const SizedBox(width: 12),
                  Text(
                    isVi ? 'Gán Học Sinh' : 'Assign Students',
                    style: TextStyle(color: lightText),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: deleteColor),
                  const SizedBox(width: 12),
                  Text(
                    isVi ? 'Xóa Lịch Học' : 'Delete Schedule',
                    style: TextStyle(color: deleteColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // SỬA: Khôi phục lại chức năng thêm/sửa lịch học
  void _moDialogThemLichHoc({LichHoc? lichHoc, bool isCopy = false}) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final isEditing = lichHoc != null && !isCopy;
    int? selectedDay =
        lichHoc?.thuTrongTuan ?? 2; // Mặc định là Thứ 2 hoặc theo lịch cũ
    TimeOfDay? startTime = (isEditing || isCopy) && lichHoc != null
        ? TimeOfDay(
            hour: int.parse(lichHoc.gioBatDau.split(':')[0]),
            minute: int.parse(lichHoc.gioBatDau.split(':')[1]),
          )
        : const TimeOfDay(hour: 18, minute: 0);
    TimeOfDay? endTime = (isEditing || isCopy) && lichHoc != null
        ? TimeOfDay(
            hour: int.parse(lichHoc.gioKetThuc.split(':')[0]),
            minute: int.parse(lichHoc.gioKetThuc.split(':')[1]),
          )
        : const TimeOfDay(hour: 20, minute: 0);

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
                style: TextStyle(color: lightText),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // SỬA: Thay thế DropdownButton bằng InputDecorator
                    _buildDayPicker(
                      selectedDay: selectedDay,
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() => selectedDay = value);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    // SỬA: Thay thế ListTile bằng InputDecorator
                    _buildTimePicker(
                      label: isVi ? 'Giờ bắt đầu' : 'Start time',
                      time: startTime,
                      onTap: () async {
                        final picked = await _showCustomTimePicker(
                          context,
                          initialTime:
                              startTime ?? const TimeOfDay(hour: 18, minute: 0),
                        );
                        if (picked != null) {
                          setStateDialog(() => startTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    // SỬA: Thay thế ListTile bằng InputDecorator
                    _buildTimePicker(
                      label: isVi ? 'Giờ kết thúc' : 'End time',
                      time: endTime,
                      onTap: () async {
                        final picked = await _showCustomTimePicker(
                          context,
                          initialTime:
                              endTime ?? const TimeOfDay(hour: 20, minute: 0),
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
                TextButton(
                  onPressed: () async {
                    // SỬA: Thêm kiểm tra null để đảm bảo an toàn
                    if (startTime == null || endTime == null) {
                      // Hiển thị thông báo lỗi nếu cần
                      return;
                    }

                    // KIỂM TRA RÀNG BUỘC: Giờ kết thúc phải lớn hơn giờ bắt đầu
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
                              style: TextStyle(
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
                                child: Text(
                                  isVi ? 'Đóng' : 'Close',
                                  style: TextStyle(color: accentColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return;
                    }

                    final newLichHoc = LichHoc(
                      id: isEditing ? lichHoc.id : null,
                      idLop: _currentLop.id!,
                      thuTrongTuan: selectedDay!,
                      gioBatDau:
                          '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}:00',
                      gioKetThuc:
                          '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}:00',
                    );
                    final success = isEditing
                        ? await ref
                              .read(
                                lopDetailControllerProvider(
                                  _currentLop,
                                ).notifier,
                              )
                              .capNhatLichHoc(newLichHoc)
                        : await ref
                              .read(
                                lopDetailControllerProvider(
                                  _currentLop,
                                ).notifier,
                              )
                              .themLichHoc(newLichHoc);
                    if (success) {
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    } else {
                      if (ctx.mounted) {
                        showDialog(
                          context: ctx,
                          builder: (errCtx) => AlertDialog(
                            backgroundColor: cardColor,
                            title: Text(
                              isVi
                                  ? 'Trùng hoặc Chồng lấn lịch'
                                  : 'Schedule Conflict',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: Text(
                              isVi
                                  ? 'Không thể lưu lịch học. Vui lòng kiểm tra xem lịch học này đã tồn tại hoặc có bị chồng lấn với ca học khác trong ngày không.'
                                  : 'Could not save schedule. Please check if this schedule already exists or overlaps with another shift on that day.',
                              style: TextStyle(color: lightText),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(errCtx).pop(),
                                child: Text(
                                  isVi ? 'Đồng ý' : 'OK',
                                  style: TextStyle(color: accentColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                  child: Text(isVi ? 'Lưu' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
    // Không cần làm gì thêm vì provider sẽ tự cập nhật UI
  }

  // HÀM MỚI: Helper để hiển thị TimePicker với theme tùy chỉnh
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
            // SỬA: Áp dụng theme màu đồng bộ
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              onPrimary: darkBackground,
              surface: cardColor,
              onSurface: lightText,
            ),
            // Đảm bảo chế độ 24 giờ
            timePickerTheme: TimePickerThemeData(
              backgroundColor: cardColor,
              hourMinuteTextColor: lightText,
              dialHandColor: accentColor,
              dialTextColor: lightText,
              entryModeIconColor: secondaryText,
              helpTextStyle: TextStyle(color: secondaryText),
            ),
            dialogTheme: DialogThemeData(backgroundColor: cardColor),
          ),
          // Bọc trong MediaQuery để ép kiểu 24h
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
  }

  // HÀM MỚI: Helper để build Dropdown chọn ngày
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
          style: TextStyle(color: lightText, fontSize: 16),
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

  // HÀM MỚI: Helper để build ô chọn giờ
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
            fontSize: 16,
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
          isVi ? 'Xác nhận' : 'Confirm',
          style: TextStyle(color: lightText),
        ),
        content: Text(
          isVi
              ? 'Bạn có chắc muốn xóa lịch học này không?'
              : 'Are you sure you want to delete this schedule?',
          style: TextStyle(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isVi ? 'Hủy' : 'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (lichHoc.id != null) {
                await _lichHocService.xoaLichHoc(lichHoc.id!);
                ref.invalidate(lopDetailControllerProvider(_currentLop));
                if (mounted) {
                  _showInfoDialog(
                    isVi ? 'Thành công' : 'Success',
                    isVi
                        ? 'Đã xóa lịch học thành công!'
                        : 'Schedule deleted successfully!',
                  );
                }
              }
            },
            child: Text(
              isVi ? 'Xóa' : 'Delete',
              style: TextStyle(color: deleteColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _moTrangGanLichHoc(
    LichHoc lichHoc,
    List<HSLopViewModel> dsHocSinh,
  ) async {
    LichHocChung? finalLhc = await _lhcService.themLichHocChung(
      LichHocChung(
        idLop: _currentLop.id!,
        ngayTrongTuan: _dayOfWeekName(lichHoc.thuTrongTuan),
        gioBatDau: lichHoc.gioBatDau.substring(0, 5),
        gioKetThuc: lichHoc.gioKetThuc.substring(0, 5),
      ),
    );

    finalLhc ??= await _lhcService.findLichHocChung(
      LichHocChung(
        idLop: _currentLop.id!,
        ngayTrongTuan: _dayOfWeekName(lichHoc.thuTrongTuan),
        gioBatDau: lichHoc.gioBatDau.substring(0, 5),
        gioKetThuc: lichHoc.gioKetThuc.substring(0, 5),
      ),
    );

    if (finalLhc?.id == null) {
      if (mounted) {
        _showInfoDialog(
          'Lỗi',
          'Không thể tạo hoặc tìm thấy lịch học chung.',
          titleColor: deleteColor,
        );
      }
      return;
    }

    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) =>
            GanLichHocPage(lichHocChung: finalLhc!, danhSachHocSinh: dsHocSinh),
      ),
    );

    if (result == true) {
      ref.invalidate(lopDetailControllerProvider(_currentLop));
    }
  }

  // ===================================================
  // PHẦN NHIỆM VỤ (TRONG TAB CHI TIẾT)
  // ===================================================
  Widget _buildNhiemVuSection(LopDetailState state) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isVi ? 'NHIỆM VỤ & BÀI TẬP' : 'ASSIGNMENTS & HOMEWORK',
              style: TextStyle(
                color: secondaryText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: accentColor),
              onPressed: _moDialogThemNhiemVu,
            ),
          ],
        ),
        Divider(color: secondaryText),
        _danhSachNhiemVu.isEmpty
            ? Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    isVi
                        ? 'Chưa có nhiệm vụ nào.'
                        : 'No assignments created yet.',
                    style: TextStyle(color: secondaryText),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _danhSachNhiemVu.length,
                itemBuilder: (context, index) {
                  // SỬA: Truyền danh sách học sinh vào card
                  return _buildNhiemVuCard(
                    _danhSachNhiemVu[index],
                    state.hocSinhs,
                  );
                },
              ),
      ],
    );
  }

  // SỬA: Cải tiến toàn bộ giao diện Card Nhiệm vụ
  Widget _buildNhiemVuCard(NhiemVu nhiemVu, List<HSLopViewModel> dsHocSinh) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final totalStudents = dsHocSinh.length;
    final completedStudents = nhiemVu.trangThaiHocSinh.values
        .where((status) => status == 'Đã nộp')
        .length;
    final progress = totalStudents > 0
        ? completedStudents / totalStudents
        : 0.0;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          nhiemVu.tenNhiemVu,
          style: TextStyle(
            color: lightText,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          (isVi ? 'Hạn nộp: ' : 'Due date: ') +
              DateFormat('dd/MM/yyyy').format(DateTime.parse(nhiemVu.ngayNop)),
          style: TextStyle(color: secondaryText, fontSize: 12),
        ),
        children: [
          // Thanh tiến trình và thông tin
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi ? 'Tiến độ' : 'Progress',
                      style: TextStyle(color: secondaryText),
                    ),
                    Text(
                      isVi
                          ? '$completedStudents/$totalStudents đã nộp'
                          : '$completedStudents/$totalStudents submitted',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: secondaryText.withValues(alpha: 0.3),
                  color: accentColor,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          Divider(color: secondaryText, height: 12),
          // Danh sách chi tiết học sinh
          ...dsHocSinh.map((hs) {
            final status = nhiemVu.trangThaiHocSinh[hs.id] ?? 'Chưa nộp';
            final isCompleted = status == 'Đã nộp';
            return ListTile(
              dense: true,
              leading: Icon(
                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isCompleted ? Colors.greenAccent : secondaryText,
                size: 20,
              ),
              title: Text(hs.ten, style: TextStyle(color: lightText)),
              trailing: Text(
                isVi ? status : (isCompleted ? 'Submitted' : 'Not submitted'),
                style: TextStyle(
                  color: isCompleted ? Colors.greenAccent : secondaryText,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
              // Thêm chức năng tick để cập nhật trạng thái
              onTap: () async {
                final newStatus = isCompleted ? 'Chưa nộp' : 'Đã nộp';
                await _nhiemVuService.capNhatTrangThai(
                  nhiemVu.id!,
                  hs.id!,
                  newStatus,
                );
                _taiNhiemVu(); // Tải lại để cập nhật UI
              },
            );
          }),
          // Các nút hành động
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: secondaryText),
                tooltip: isVi ? 'Sửa nhiệm vụ' : 'Edit assignment',
                onPressed: () => _moDialogThemNhiemVu(nhiemVu: nhiemVu),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: deleteColor),
                tooltip: isVi ? 'Xóa nhiệm vụ' : 'Delete assignment',
                onPressed: () => _xacNhanXoaNhiemVu(nhiemVu),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _moDialogThemNhiemVu({NhiemVu? nhiemVu}) async {
    final nv =
        nhiemVu ??
        NhiemVu(
          idLop: _currentLop.id!,
          tenNhiemVu: '',
          ngayGiao: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          ngayNop: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
    await showDialog(
      context: context,
      builder: (ctx) => NhiemVuDialog(
        nhiemVu: nv,
        onSave: (updatedNv) async {
          if (updatedNv.id == null) {
            await _nhiemVuService.themNhiemVu(updatedNv);
          } else {
            await _nhiemVuService.capNhatNhiemVu(updatedNv);
          }
          _taiNhiemVu();
        },
      ),
    );
  }

  // HÀM MỚI: Xác nhận xóa nhiệm vụ
  void _xacNhanXoaNhiemVu(NhiemVu nhiemVu) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isVi ? 'Xác nhận' : 'Confirm',
          style: TextStyle(color: lightText),
        ),
        content: Text(
          isVi
              ? 'Bạn có chắc muốn xóa nhiệm vụ "${nhiemVu.tenNhiemVu}" không?'
              : 'Are you sure you want to delete assignment "${nhiemVu.tenNhiemVu}"?',
          style: TextStyle(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _nhiemVuService.xoaNhiemVu(nhiemVu.id!);
              _taiNhiemVu(); // Tải lại danh sách nhiệm vụ
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
            },
            child: Text(
              isVi ? 'Xóa' : 'Delete',
              style: TextStyle(color: deleteColor),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // HELPER METHODS & TRANSLATIONS
  // ===================================================

  String _translateRank(String? rank, bool isVi) {
    if (rank == null) return isVi ? 'Chưa xếp' : 'Not ranked';
    if (isVi) return rank;
    switch (rank) {
      case 'Thách Đấu':
        return 'Challenger';
      case 'Cao Thủ':
        return 'Master';
      case 'Tinh Anh':
        return 'Hero';
      case 'Kim Cương':
        return 'Diamond';
      case 'Bạch Kim':
        return 'Platinum';
      case 'Vàng':
        return 'Gold';
      case 'Bạc':
        return 'Silver';
      case 'Đồng':
        return 'Bronze';
      default:
        return rank;
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

  String _translateDayOfWeekInitial(String initial, bool isVi) {
    if (isVi) return initial;
    switch (initial) {
      case 'CN':
        return 'Sun';
      case 'T2':
        return 'Mon';
      case 'T3':
        return 'Tue';
      case 'T4':
        return 'Wed';
      case 'T5':
        return 'Thu';
      case 'T6':
        return 'Fri';
      case 'T7':
        return 'Sat';
      default:
        return initial;
    }
  }

  void _showInfoDialog(String title, String message, {Color? titleColor}) {
    final effectiveTitleColor = titleColor ?? accentColor;
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          title,
          style: TextStyle(
            color: effectiveTitleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: TextStyle(color: lightText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isVi ? 'Đóng' : 'Close',
              style: TextStyle(color: secondaryText),
            ),
          ),
        ],
      ),
    );
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

  // ===================================================
  // TAB 4: ĐÁNH GIÁ
  // ===================================================
  Widget _buildDanhGiaSection(LopDetailState state) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    // SỬA: Đảm bảo format tháng đồng bộ với database (YYYY-MM)
    final String thang = DateFormat('yyyy-MM').format(DateTime.now());

    return FutureBuilder<List<NhanXetThang>>(
      future: _nhanXetService.layDanhSachNhanXet(_currentLop.id!, thang),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: accentColor));
        }

        final dsNhanXet = snapshot.data ?? [];
        final dsHocSinh = state.hocSinhs;

        if (dsHocSinh.isEmpty) {
          return Center(
            child: Text(
              isVi
                  ? 'Chưa có học sinh nào trong lớp.'
                  : 'No students in this class.',
              style: TextStyle(color: secondaryText),
            ),
          );
        }

        // HÀM MỚI: Ghép dữ liệu và sắp xếp theo điểm trung bình giảm dần
        final List<Map<String, dynamic>> dsXepHang = dsHocSinh.map((hs) {
          final nhanXet = dsNhanXet.firstWhere(
            (nx) => nx.idHocSinh == hs.id,
            orElse: () => NhanXetThang(
              idHocSinh: hs.id!,
              idLop: _currentLop.id!,
              thang: thang,
            ),
          );
          return {'hs': hs, 'nx': nhanXet};
        }).toList();

        // Sắp xếp: Điểm cao đứng trước
        dsXepHang.sort(
          (a, b) => (b['nx'] as NhanXetThang).diemTrungBinh.compareTo(
            (a['nx'] as NhanXetThang).diemTrungBinh,
          ),
        );

        return Column(
          children: [
            // ... (Phần nút Tổng hợp giữ nguyên)
            Padding(
              padding: EdgeInsets.all(4.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Hiển thị loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: cardColor,
                        content: Row(
                          children: [
                            CircularProgressIndicator(color: accentColor),
                            SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                isVi
                                    ? 'Đang tổng hợp và cập nhật xếp hạng...'
                                    : 'Aggregating and updating ranks...',
                                style: TextStyle(color: lightText),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    // Gọi hàm tổng hợp
                    await _nhanXetService.tongHopVaCapNhatNhanXetThang(
                      dsHocSinh,
                      _currentLop.id!,
                      thang,
                    );
                    if (context.mounted) {
                      Navigator.of(context).pop(); // Đóng loading dialog
                      _showInfoDialog(
                        isVi ? 'Thành công' : 'Success',
                        isVi
                            ? 'Đã tổng hợp và cập nhật xếp hạng xong!'
                            : 'Aggregation and ranking completed successfully!',
                      );
                      // Tải lại dữ liệu để cập nhật UI
                      setState(() {});
                    }
                  },
                  icon: Icon(Icons.calculate, color: darkBackground),
                  label: Text(
                    isVi
                        ? 'Tổng hợp & Cập nhật Xếp hạng'
                        : 'Aggregate & Update Ranks',
                    style: TextStyle(color: darkBackground),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                itemCount: dsXepHang.length,
                itemBuilder: (context, index) {
                  final item = dsXepHang[index];
                  return _buildDanhGiaCard(item['hs'], item['nx'], index + 1);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDanhGiaCard(
    HSLopViewModel hs,
    NhanXetThang nhanXet,
    int rankPosition,
  ) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final rankData = _getRankData(nhanXet.xepHang);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              backgroundColor: rankData['color'].withOpacity(0.2),
              child: Icon(rankData['icon'], color: rankData['color'], size: 24),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: cardColor, width: 1),
                ),
                child: Text(
                  '$rankPosition',
                  style: TextStyle(
                    color: darkBackground,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          hs.ten,
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${isVi ? "Điểm TB" : "Avg Score"}: ${nhanXet.diemTrungBinh.toStringAsFixed(2)} - ${isVi ? "Hạng" : "Rank"}: ${_translateRank(nhanXet.xepHang, isVi)}',
          style: TextStyle(color: rankData['color'], fontSize: 13),
        ),
        trailing: Icon(Icons.info_outline, color: secondaryText),
        onTap: () => _hienThiChiTietDiem(hs, nhanXet),
      ),
    );
  }

  void _chiaSeNhanXetPhuHuynh(HSLopViewModel hs, NhanXetThang nhanXet) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final String formattedThang = DateFormat('MM/yyyy').format(DateTime.now());

    final String message = isVi
        ? '''
[BÁO CÁO HỌC TẬP THÁNG $formattedThang]
Kính gửi Phụ huynh em ${hs.ten},
Dưới đây là kết quả học tập trong tháng qua tại lớp ${_currentLop.ten}:

- Chuyên cần: ${nhanXet.diemChuyenCan.toStringAsFixed(1)}/10
- Thái độ học: ${nhanXet.diemThaiDo.toStringAsFixed(1)}/10
- Bài tập về nhà: ${nhanXet.diemBaiTap.toStringAsFixed(1)}/10
- Hiểu bài & Kiểm tra: ${nhanXet.diemKiemTra.toStringAsFixed(1)}/10
-------------------------
* ĐIỂM TRUNG BÌNH: ${nhanXet.diemTrungBinh.toStringAsFixed(2)}
* XẾP HẠNG: ${_translateRank(nhanXet.xepHang, true)}

* NHẬN XÉT CHUNG:
${nhanXet.nhanXetChung ?? 'Con ngoan, học tập chăm chỉ.'}

Trân trọng gửi đến phụ huynh!
'''
        : '''
[MONTHLY ACADEMIC REPORT - $formattedThang]
Dear Parents of ${hs.ten},
Here is the learning progress for this month in class ${_currentLop.ten}:

- Attendance: ${nhanXet.diemChuyenCan.toStringAsFixed(1)}/10
- Learning Attitude: ${nhanXet.diemThaiDo.toStringAsFixed(1)}/10
- Homework: ${nhanXet.diemBaiTap.toStringAsFixed(1)}/10
- Tests & Understanding: ${nhanXet.diemKiemTra.toStringAsFixed(1)}/10
-------------------------
* AVERAGE SCORE: ${nhanXet.diemTrungBinh.toStringAsFixed(2)}
* RANK: ${_translateRank(nhanXet.xepHang, false)}

* GENERAL REMARKS:
${nhanXet.nhanXetChung ?? 'Good student, studied hard.'}

Best regards!
''';

    await SharePlus.instance.share(ShareParams(text: message));
  }

  void _hienThiChiTietDiem(HSLopViewModel hs, NhanXetThang nhanXet) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final String currentThangStr = DateFormat('yyyy-MM').format(DateTime.now());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isVi ? 'CHI TIẾT ĐIỂM: ${hs.ten}' : 'SCORE DETAILS: ${hs.ten}',
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDiemRow(
                isVi ? 'Chuyên cần' : 'Attendance',
                nhanXet.diemChuyenCan,
              ),
              _buildDiemRow(
                isVi ? 'Thái độ học' : 'Attitude',
                nhanXet.diemThaiDo,
              ),
              _buildDiemRow(
                isVi ? 'Bài tập về nhà' : 'Homework',
                nhanXet.diemBaiTap,
              ),
              _buildDiemRow(
                isVi ? 'Hiểu bài & KT' : 'Understanding & Tests',
                nhanXet.diemKiemTra,
              ),
              Divider(color: secondaryText),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isVi ? 'ĐIỂM TRUNG BÌNH' : 'AVERAGE SCORE',
                    style: TextStyle(
                      color: lightText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    nhanXet.diemTrungBinh.toStringAsFixed(2),
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isVi ? 'XẾP HẠNG' : 'RANK',
                    style: TextStyle(color: lightText),
                  ),
                  Text(
                    _translateRank(nhanXet.xepHang, isVi),
                    style: TextStyle(
                      color: _getRankData(nhanXet.xepHang)['color'],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (nhanXet.nhanXetChung != null &&
                  nhanXet.nhanXetChung!.trim().isNotEmpty) ...[
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    isVi ? 'NHẬN XÉT CHUNG:' : 'GENERAL REMARKS:',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nhanXet.nhanXetChung!,
                    style: TextStyle(
                      color: lightText,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx); // Đóng hộp thoại chi tiết
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) => DanhGiaDialog(
                      idHocSinh: hs.id!,
                      tenHocSinh: hs.ten,
                      idLop: _currentLop.id!,
                      thang: currentThangStr,
                    ),
                  );
                  if (result == true) {
                    setState(() {}); // Làm mới danh sách đánh giá
                  }
                },
                icon: const Icon(Icons.edit, size: 16),
                label: Text(isVi ? 'Nhận xét' : 'Remark'),
              ),
              TextButton.icon(
                onPressed: () {
                  _chiaSeNhanXetPhuHuynh(hs, nhanXet);
                },
                icon: const Icon(Icons.share, size: 16),
                label: Text(isVi ? 'Gửi PHHS' : 'Send'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final pdfService = PdfExportService();
                  await pdfService.generateAndOpenBaoCaoHocTapPdf(
                    hs,
                    nhanXet,
                    _currentLop.ten,
                    currentThangStr,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: Text(isVi ? 'Xuất PDF' : 'PDF'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final pdfService = PdfExportService();
                  await pdfService.generateAndShareBaoCaoHocTapImage(
                    hs,
                    nhanXet,
                    _currentLop.ten,
                    currentThangStr,
                  );
                },
                icon: const Icon(Icons.image, size: 16),
                label: Text(isVi ? 'Gửi ảnh' : 'Send Image'),
              ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isVi ? 'Đóng' : 'Close',
              style: TextStyle(color: secondaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiemRow(String label, double diem) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: secondaryText)),
          Text(
            diem.toStringAsFixed(1),
            style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getRankData(String? rank) {
    switch (rank) {
      case 'Thách Đấu':
        return {'color': Colors.redAccent, 'icon': Icons.local_fire_department};
      case 'Cao Thủ':
        return {'color': Colors.orangeAccent, 'icon': Icons.military_tech};
      case 'Tinh Anh':
        return {'color': Colors.purpleAccent, 'icon': Icons.auto_awesome};
      case 'Kim Cương':
        return {'color': Colors.cyanAccent, 'icon': Icons.diamond};
      case 'Bạch Kim':
        return {'color': Colors.grey.shade300, 'icon': Icons.shield};
      case 'Vàng':
        return {'color': Colors.amberAccent, 'icon': Icons.star};
      case 'Bạc':
        return {'color': Colors.blueGrey.shade300, 'icon': Icons.verified};
      case 'Đồng':
        return {
          'color': Colors.brown.shade300,
          'icon': Icons.workspace_premium,
        };
      default:
        return {'color': secondaryText, 'icon': Icons.help_outline};
    }
  }
}
