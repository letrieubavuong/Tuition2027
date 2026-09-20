import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../controllers/lop_detail_controller.dart';
import '../../../models/hs_lop_view_model.dart';
import '../../../models/lich_hoc.dart';
import '../../../models/diem_danh.dart';
import '../../../services/lop_hoc_sinh_service.dart';
import '../../../services/lich_hoc_service.dart';
import '../../../services/diem_danh_service.dart';
import '../../../services/student_schedule_assignment_service.dart';
import '../../../services/hoc_sinh_service.dart';
import '../../../services/truong_service.dart';
import '../../../services/zalo_contact_service.dart';
import '../../../widgets/dang_ky_nghi_le_dialog.dart';
import '../../../widgets/them_hs_vao_lop_dialog.dart';
import '../../su_kien_buoi_hoc_page.dart';

enum StudentStatusFilter { active, paused, left, all }

enum StudentSortBy { name, joinDate, status }

class ClassStudentListTab extends ConsumerStatefulWidget {
  final LopDetailState state;

  const ClassStudentListTab({super.key, required this.state});

  @override
  ConsumerState<ClassStudentListTab> createState() =>
      _ClassStudentListTabState();
}

class _ClassStudentListTabState extends ConsumerState<ClassStudentListTab> {
  final TextEditingController _searchController = TextEditingController();
  StudentStatusFilter _selectedFilter = StudentStatusFilter.all;
  StudentSortBy _selectedSort = StudentSortBy.name;
  String _searchQuery = '';

  final _lhsService = LopHocSinhService();
  final _lichHocService = LichHocService();
  final _diemDanhService = DiemDanhService();
  final _hsService = HocSinhService();
  final _truongService = TruongService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HSLopViewModel> _getFilteredAndSortedStudents() {
    final allStudents = [
      ...widget.state.hocSinhs,
      ...widget.state.hocSinhsDaNghi,
    ];

    // Filter by status
    List<HSLopViewModel> list = allStudents.where((hs) {
      final isPaused = _lhsService.isStudentPaused(hs);
      final isFormer = !_lhsService.hoatDongTrongNgay(hs, DateTime.now());
      final isActive = !isFormer && !isPaused;

      switch (_selectedFilter) {
        case StudentStatusFilter.active:
          return isActive;
        case StudentStatusFilter.paused:
          return isPaused && !isFormer;
        case StudentStatusFilter.left:
          return isFormer;
        case StudentStatusFilter.all:
          return true;
      }
    }).toList();

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((hs) => hs.ten.toLowerCase().contains(q)).toList();
    }

    // Sort
    list.sort((a, b) {
      switch (_selectedSort) {
        case StudentSortBy.name:
          return a.ten.compareTo(b.ten);
        case StudentSortBy.joinDate:
          return (a.ngayThamGia).compareTo(b.ngayThamGia);
        case StudentSortBy.status:
          return a.trangThai.compareTo(b.trangThai);
      }
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final cardColor = theme.cardColor;
    final lightText = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryText = theme.textTheme.bodyMedium?.color ?? Colors.white70;
    final accentColor = theme.primaryColor;

    final filteredStudents = _getFilteredAndSortedStudents();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // 1. Search Bar & Add Student Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: lightText),
                  decoration: InputDecoration(
                    hintText: isVi
                        ? 'Tìm tên học sinh...'
                        : 'Search student...',
                    hintStyle: TextStyle(
                      color: secondaryText.withValues(alpha: 0.6),
                    ),
                    prefixIcon: Icon(Icons.search, color: secondaryText),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: secondaryText),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.beach_access_rounded,
                  color: Colors.orangeAccent,
                ),
                onPressed: () => _moDialogDangKyNghiLe(widget.state.hocSinhs),
                tooltip: isVi ? 'Đăng ký nghỉ lễ' : 'Batch holiday',
              ),
              IconButton(
                icon: Icon(Icons.person_add_alt_1_rounded, color: accentColor),
                onPressed: _moDialogThemHS,
                tooltip: isVi ? 'Thêm học sinh' : 'Add student',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Filter & Sort Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text(
                    isVi
                        ? 'Tất cả (${widget.state.siSo + widget.state.hocSinhsDaNghi.length})'
                        : 'All',
                  ),
                  selected: _selectedFilter == StudentStatusFilter.all,
                  onSelected: (_) =>
                      setState(() => _selectedFilter = StudentStatusFilter.all),
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: Text(
                    isVi
                        ? 'Đang học (${widget.state.hocSinhs.length})'
                        : 'Active',
                  ),
                  selected: _selectedFilter == StudentStatusFilter.active,
                  onSelected: (_) => setState(
                    () => _selectedFilter = StudentStatusFilter.active,
                  ),
                ),
                const SizedBox(width: 4),
                FilterChip(
                  label: Text(
                    isVi
                        ? 'Đã nghỉ (${widget.state.hocSinhsDaNghi.length})'
                        : 'Left',
                  ),
                  selected: _selectedFilter == StudentStatusFilter.left,
                  onSelected: (_) => setState(
                    () => _selectedFilter = StudentStatusFilter.left,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<StudentSortBy>(
                  icon: Icon(Icons.sort_rounded, color: secondaryText),
                  tooltip: isVi ? 'Sắp xếp' : 'Sort',
                  onSelected: (sort) => setState(() => _selectedSort = sort),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: StudentSortBy.name,
                      child: Text(isVi ? 'Theo tên' : 'By name'),
                    ),
                    PopupMenuItem(
                      value: StudentSortBy.joinDate,
                      child: Text(isVi ? 'Theo ngày tham gia' : 'By join date'),
                    ),
                    PopupMenuItem(
                      value: StudentSortBy.status,
                      child: Text(isVi ? 'Theo trạng thái' : 'By status'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 3. Student List
          Expanded(
            child: filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: secondaryText.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isVi
                              ? 'Không tìm thấy học sinh phù hợp.'
                              : 'No matching students found.',
                          style: TextStyle(color: secondaryText),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredStudents.length,
                    itemBuilder: (ctx, index) {
                      return _buildHocSinhCard(filteredStudents[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHocSinhCard(HSLopViewModel hsViewModel) {
    final theme = Theme.of(context);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final cardColor = theme.cardColor;
    final lightText = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryText = theme.textTheme.bodyMedium?.color ?? Colors.white70;
    final accentColor = theme.primaryColor;
    final deleteColor = theme.colorScheme.error;

    final isPaused = _lhsService.isStudentPaused(hsViewModel);
    final isFormer = !_lhsService.hoatDongTrongNgay(
      hsViewModel,
      DateTime.now(),
    );

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: () => _hienThiDialogThongTinHocSinh(hsViewModel),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: accentColor.withValues(alpha: 0.15),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            hsViewModel.ten,
                            style: TextStyle(
                              color: lightText,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isFormer) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isVi ? 'Đã nghỉ' : 'Left',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ] else if (isPaused) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isVi ? 'Tạm ngừng' : 'Paused',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVi
                          ? 'Tham gia: ${_formatOptionalDate(hsViewModel.ngayThamGia)}'
                          : 'Joined: ${_formatOptionalDate(hsViewModel.ngayThamGia)}',
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ZaloContactService.instance.buildZaloQuickButton(
                context,
                hsViewModel,
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: secondaryText),
                color: Theme.of(context).scaffoldBackgroundColor,
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
                          const Icon(
                            Icons.person_add_alt,
                            color: Colors.greenAccent,
                          ),
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
                          Text(
                            isVi ? 'Đăng ký nghỉ có phép' : 'Excused leave',
                            style: TextStyle(color: lightText),
                          ),
                        ],
                      ),
                    ),
                  if (!isFormer)
                    PopupMenuItem<String>(
                      value: isPaused ? 'resume' : 'pause',
                      child: Row(
                        children: [
                          Icon(
                            isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isPaused
                                ? (isVi ? 'Cho học lại' : 'Resume')
                                : (isVi ? 'Tạm ngừng học' : 'Pause study'),
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
                          const Icon(
                            Icons.edit_calendar,
                            color: Colors.blueAccent,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isVi ? 'Sửa ngày nhập học' : 'Edit join date',
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
                          isVi ? 'Đánh giá buổi học' : 'Evaluate session',
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

  // Requirement 4: UI decouples raw SQLite queries; uses LopHocSinhService.docStudentSummary()
  void _hienThiDialogThongTinHocSinh(HSLopViewModel hsViewModel) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');
    final thangCurrent = DateFormat('yyyy-MM').format(DateTime.now());
    final formattedThang = DateFormat('MM/yyyy').format(DateTime.now());
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final lightText = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryText = theme.textTheme.bodyMedium?.color ?? Colors.white70;
    final accentColor = theme.primaryColor;
    final deleteColor = theme.colorScheme.error;

    // Call service DTO instead of raw db queries!
    final summary = await _lhsService.docStudentSummary(
      studentId: hsViewModel.id!,
      classId: widget.state.lop.id!,
      month: thangCurrent,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: accentColor.withValues(alpha: 0.15),
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
              child: Text(
                hsViewModel.ten,
                style: TextStyle(
                  color: lightText,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
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
              context,
              Icons.account_balance_wallet_outlined,
              isVi ? 'Số buổi dư tích lũy:' : 'Rollover sessions:',
              '${summary.soBuoiDu} buổi',
              valueColor: accentColor,
            ),
            const SizedBox(height: 14),
            _buildDialogInfoRow(
              context,
              Icons.event_busy_outlined,
              isVi
                  ? 'Số buổi nghỉ học (Tháng $formattedThang):'
                  : 'Absences ($formattedThang):',
              '${summary.tongNghi} buổi (${summary.nghiCoPhep} có phép, ${summary.nghiKhongPhep} không phép)',
              valueColor: summary.tongNghi > 0
                  ? Colors.orangeAccent
                  : lightText,
            ),
            if (summary.facebook != null &&
                summary.facebook!.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              _buildDialogInfoRow(
                context,
                Icons.facebook,
                'Facebook:',
                summary.facebook!,
                valueColor: Colors.blueAccent,
              ),
            ],
            const SizedBox(height: 14),
            _buildDialogInfoRow(
              context,
              Icons.payment_outlined,
              isVi ? 'Trạng thái học phí:' : 'Tuition status:',
              !summary.isKhoiTao
                  ? (isVi ? 'Chưa khởi tạo' : 'Not initialized')
                  : (summary.isDaDong
                        ? (isVi ? 'Đã đóng đủ' : 'Fully paid')
                        : (isVi
                              ? 'Chưa đóng (Còn nợ: ${formatCurrency.format(summary.conNo)}đ)'
                              : 'Unpaid (Debt: ${formatCurrency.format(summary.conNo)}đ)')),
              valueColor: summary.isDaDong ? Colors.greenAccent : deleteColor,
            ),
          ],
        ),
        actions: [
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

  Widget _buildDialogInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final secondaryText =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
    final lightText =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;

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

  // Requirement 8: Multi-session Quick Evaluation safety
  void _moDialogDanhGiaNhanh(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final now = DateTime.now();
    final ngayStr = DateFormat('yyyy-MM-dd').format(now);
    final int thuTrongTuanDB = (now.weekday == 7) ? 1 : now.weekday + 1;

    // 1. Fetch today's shifts for this class
    final allCaHoc = await _lichHocService.layLichHocTheoLop(
      widget.state.lop.id!,
    );
    if (allCaHoc.isEmpty) {
      if (mounted) {
        _showInfoDialog(
          isVi ? 'Thông báo' : 'Notification',
          isVi ? 'Lớp chưa có ca học nào.' : 'No sessions scheduled.',
          titleColor: Colors.orangeAccent,
        );
      }
      return;
    }

    LichHoc? selectedShift;

    // Check student's active assignment for today
    final activeAsgn = await StudentScheduleAssignmentService.instance
        .getActiveAssignmentForStudentOnDate(hs.id!, ngayStr);

    if (activeAsgn != null && activeAsgn.scheduleId != null) {
      final matching = allCaHoc.cast<LichHoc?>().firstWhere(
        (lh) => lh?.id == activeAsgn.scheduleId,
        orElse: () => null,
      );
      if (matching != null) {
        selectedShift = matching;
      }
    }

    if (selectedShift == null) {
      final caHocHomNay = allCaHoc
          .where((lh) => lh.thuTrongTuan == thuTrongTuanDB)
          .toList();

      if (caHocHomNay.isEmpty) {
        selectedShift = allCaHoc.first;
      } else if (caHocHomNay.length == 1) {
        selectedShift = caHocHomNay.first;
      } else {
        if (!mounted) return;
        final pickedShift = await showDialog<LichHoc>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isVi ? 'Chọn ca học hôm nay' : 'Select Today Shift'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: caHocHomNay.map((shift) {
                final startStr = shift.gioBatDau.substring(0, 5);
                final endStr = shift.gioKetThuc.substring(0, 5);
                return ListTile(
                  leading: const Icon(Icons.access_time_rounded),
                  title: Text('$startStr - $endStr'),
                  onTap: () => Navigator.pop(ctx, shift),
                );
              }).toList(),
            ),
          ),
        );
        if (pickedShift == null) return;
        selectedShift = pickedShift;
      }
    }

    // 2. Find or create attendance record with exact date + start time
    final startStr = selectedShift.gioBatDau.substring(0, 5);
    final existingRecords = await _diemDanhService.layDiemDanhTheoLopVaNgay(
      widget.state.lop.id!,
      ngayStr,
    );
    final existingRecord = existingRecords.cast<DiemDanh?>().firstWhere(
      (dd) =>
          dd?.idHocSinh == hs.id &&
          (dd?.gioDiemDanh.contains(startStr) ?? false),
      orElse: () => null,
    );

    int idDiemDanh;
    if (existingRecord != null && existingRecord.id != null) {
      idDiemDanh = existingRecord.id!;
    } else {
      final diemDanhRecord = DiemDanh(
        idHocSinh: hs.id!,
        idLop: widget.state.lop.id!,
        gioDiemDanh: '$ngayStr ${selectedShift.gioBatDau}',
        trangThai: 'Có mặt',
      );
      idDiemDanh = await _diemDanhService.themDiemDanh(diemDanhRecord);
    }

    // 3. Open evaluation screen
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

  void _moDialogDangKyNghiLe(List<HSLopViewModel> danhSachHocSinh) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => DangKyNghiLeDialog(
        lop: widget.state.lop,
        danhSachHocSinh: danhSachHocSinh,
      ),
    );
    if (result == true) {
      ref
          .read(lopDetailControllerProvider(widget.state.lop.id!).notifier)
          .refreshAll();
    }
  }

  void _moDialogThemHS() async {
    final tatCaHS = await _hsService.docTatCaHocSinh();
    final danhSachTruong = await _truongService.docTatCaTruong();
    final hsTrongLopIds = widget.state.hocSinhs.map((e) => e.id).toSet();

    final hsChuaCoLop = tatCaHS
        .where((hs) => hs.id != null && !(hsTrongLopIds.contains(hs.id)))
        .toList();

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemHSVaoLopDialog(
        lop: widget.state.lop,
        danhSachTatCaHS: hsChuaCoLop,
        lhsService: _lhsService,
        hsService: _hsService,
        danhSachTruong: danhSachTruong,
      ),
    );

    if (result == true) {
      ref
          .read(lopDetailControllerProvider(widget.state.lop.id!).notifier)
          .refreshAll();
    }
  }

  Future<void> _moDialogDangKyNghi(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final cardColor = Theme.of(context).cardColor;
    final lightText =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryText =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;

    DateTime from = DateTime.now();
    DateTime to = DateTime.now();
    final reason = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            isVi ? 'Đăng ký nghỉ có phép' : 'Excused leave',
            style: TextStyle(color: lightText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  isVi ? 'Từ ngày' : 'From',
                  style: TextStyle(color: secondaryText),
                ),
                trailing: Text(
                  DateFormat('dd/MM/yyyy').format(from),
                  style: TextStyle(color: lightText),
                ),
                onTap: () async {
                  final value = await _pickLeaveDate(from);
                  if (value != null) {
                    setDialogState(() {
                      from = value;
                      if (to.isBefore(from)) to = from;
                    });
                  }
                },
              ),
              ListTile(
                title: Text(
                  isVi ? 'Đến ngày' : 'To',
                  style: TextStyle(color: secondaryText),
                ),
                trailing: Text(
                  DateFormat('dd/MM/yyyy').format(to),
                  style: TextStyle(color: lightText),
                ),
                onTap: () async {
                  final value = await _pickLeaveDate(to);
                  if (value != null && !value.isBefore(from))
                    setDialogState(() => to = value);
                },
              ),
              TextField(
                controller: reason,
                style: TextStyle(color: lightText),
                decoration: InputDecoration(
                  labelText: isVi ? 'Lý do' : 'Reason',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(isVi ? 'Hủy' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isVi ? 'Lưu' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      reason.dispose();
      return;
    }

    await _lhsService.dangKyNghiCoPhep(
      idLop: widget.state.lop.id!,
      idHocSinh: hs.id!,
      tuNgay: DateFormat('yyyy-MM-dd').format(from),
      denNgay: DateFormat('yyyy-MM-dd').format(to),
      lyDo: reason.text.trim(),
    );
    reason.dispose();

    if (mounted) {
      _showInfoDialog(
        isVi ? 'Đã lưu' : 'Saved',
        isVi
            ? 'Các ca học trong khoảng nghỉ sẽ mặc định là nghỉ có phép.'
            : 'Sessions in range will default to excused leave.',
      );
    }
  }

  Future<void> _moDialogTamNgung(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final cardColor = Theme.of(context).cardColor;
    final lightText =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryText =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;

    DateTime start = DateTime.now();
    DateTime? expected;
    final reason = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            isVi ? 'Tạm ngừng học' : 'Pause study',
            style: TextStyle(color: lightText),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  isVi ? 'Bắt đầu' : 'Start',
                  style: TextStyle(color: secondaryText),
                ),
                trailing: Text(
                  DateFormat('dd/MM/yyyy').format(start),
                  style: TextStyle(color: lightText),
                ),
                onTap: () async {
                  final v = await _pickLeaveDate(start);
                  if (v != null) setDialogState(() => start = v);
                },
              ),
              ListTile(
                title: Text(
                  isVi ? 'Dự kiến học lại' : 'Expected return',
                  style: TextStyle(color: secondaryText),
                ),
                trailing: Text(
                  expected == null
                      ? '--'
                      : DateFormat('dd/MM/yyyy').format(expected!),
                  style: TextStyle(color: lightText),
                ),
                onTap: () async {
                  final v = await _pickLeaveDate(expected ?? start);
                  if (v != null && !v.isBefore(start))
                    setDialogState(() => expected = v);
                },
              ),
              TextField(
                controller: reason,
                style: TextStyle(color: lightText),
                decoration: InputDecoration(
                  labelText: isVi ? 'Lý do' : 'Reason',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(isVi ? 'Hủy' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isVi ? 'Xác nhận' : 'Confirm'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      reason.dispose();
      return;
    }

    await _lhsService.tamNgungHoc(
      idLop: widget.state.lop.id!,
      idHocSinh: hs.id!,
      ngayBatDau: DateFormat('yyyy-MM-dd').format(start),
      ngayDuKienHocLai: expected == null
          ? null
          : DateFormat('yyyy-MM-dd').format(expected!),
      lyDo: reason.text.trim(),
    );
    reason.dispose();
    ref
        .read(lopDetailControllerProvider(widget.state.lop.id!).notifier)
        .refreshAll();
  }

  Future<void> _choHocLai(HSLopViewModel hs) async {
    final date = await _pickLeaveDate(DateTime.now());
    if (date == null) return;
    await _lhsService.choHocLai(
      idLop: widget.state.lop.id!,
      idHocSinh: hs.id!,
      ngayHocLai: DateFormat('yyyy-MM-dd').format(date),
    );
    ref
        .read(lopDetailControllerProvider(widget.state.lop.id!).notifier)
        .refreshAll();
  }

  Future<void> _kichHoatHocLai(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final earliest = hs.ngayNghiHoc == null
        ? DateTime.now()
        : DateTime.tryParse(hs.ngayNghiHoc!) ?? DateTime.now();

    final date = await _pickLeaveDate(
      DateTime.now().isBefore(earliest) ? earliest : DateTime.now(),
    );
    if (date == null || date.isBefore(earliest)) return;

    final updated = await _lhsService.kichHoatHocLai(
      idLop: widget.state.lop.id!,
      idHocSinh: hs.id!,
      ngayHocLai: DateFormat('yyyy-MM-dd').format(date),
    );

    if (updated > 0) {
      ref
          .read(lopDetailControllerProvider(widget.state.lop.id!).notifier)
          .refreshAll();
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

  void _moDialogSuaNgayThamGia(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    DateTime initialDate;
    try {
      initialDate = DateTime.parse(hs.ngayThamGia);
    } catch (_) {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      final updatedCount = await _lhsService.capNhatNgayThamGia(
        widget.state.lop.id!,
        hs.id!,
        formattedDate,
      );

      if (updatedCount > 0) {
        ref
            .read(lopDetailControllerProvider(widget.state.lop.id!).notifier)
            .refreshAll();
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

  void _xacNhanXoaHS(HSLopViewModel hs) async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final cardColor = Theme.of(context).cardColor;
    final lightText =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryText =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
    final deleteColor = Theme.of(context).colorScheme.error;

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
                    : 'Tuition and attendance stop from this date. History is preserved.',
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
                  if (picked != null) setDialogState(() => leaveDate = picked);
                },
              ),
              TextField(
                controller: reason,
                style: TextStyle(color: lightText),
                decoration: InputDecoration(
                  labelText: isVi
                      ? 'Lý do (không bắt buộc)'
                      : 'Reason (optional)',
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
      idLop: widget.state.lop.id!,
      idHocSinh: hs.id!,
      ngayNghiHoc: DateFormat('yyyy-MM-dd').format(leaveDate),
      lyDo: reason.text.trim(),
    );
    reason.dispose();

    if (updated > 0) {
      ref
          .read(lopDetailControllerProvider(widget.state.lop.id!).notifier)
          .refreshAll();
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

  Future<DateTime?> _pickLeaveDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
  }

  void _showInfoDialog(String title, String message, {Color? titleColor}) {
    final theme = Theme.of(context);
    final effectiveTitleColor = titleColor ?? theme.primaryColor;
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          title,
          style: TextStyle(
            color: effectiveTitleColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isVi ? 'Đóng' : 'Close',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color),
            ),
          ),
        ],
      ),
    );
  }

  String _formatOptionalDate(String? value) {
    if (value == null || value.trim().isEmpty) return '--';
    try {
      final date = DateTime.parse(value);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return '--';
    }
  }
}
