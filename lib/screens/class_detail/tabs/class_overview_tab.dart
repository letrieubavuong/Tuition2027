import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../controllers/lop_detail_controller.dart';
import '../../../models/hs_lop_view_model.dart';
import '../../../models/nhiem_vu.dart';
import '../../../widgets/nhiem_vu_dialog.dart';
import '../../../widgets/gui_thong_bao_hang_loat_dialog.dart';
import '../../../widgets/them_hs_vao_lop_dialog.dart';
import '../../diem_danh_page.dart';
import '../../weekly_scheduling_page.dart';
import '../../../services/lop_hoc_sinh_service.dart';
import '../../../services/hoc_sinh_service.dart';
import '../../../services/truong_service.dart';

class ClassOverviewTab extends ConsumerWidget {
  final LopDetailState state;
  final TabController tabController;

  const ClassOverviewTab({
    super.key,
    required this.state,
    required this.tabController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final accentColor = theme.primaryColor;
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
          // 1. Dashboard Summary Cards with onTap navigation
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildMetricCard(
                context,
                title: isVi ? 'Sĩ Số' : 'Size',
                value: state.siSo.toString(),
                icon: Icons.people_rounded,
                color: accentColor,
                subtitle: isVi ? 'Số lượng học sinh' : 'Number of students',
                onTap: () => tabController.animateTo(1),
              ),
              _buildMetricCard(
                context,
                title: isVi ? 'Lịch Học' : 'Schedule',
                value: isVi
                    ? '${state.lichHocs.length} buổi'
                    : '${state.lichHocs.length} sessions',
                icon: Icons.calendar_today_rounded,
                color: Colors.orangeAccent,
                subtitle: isVi ? 'Số buổi dạy/tuần' : 'Sessions/week',
                onTap: () => tabController.animateTo(2),
              ),
              _buildMetricCard(
                context,
                title: isVi ? 'Chuyên Cần' : 'Attendance',
                value: percentageFmt.format(state.summary.tyLeChuyenCan),
                icon: Icons.task_alt_rounded,
                color: Colors.greenAccent,
                subtitle: isVi ? 'Tỷ lệ đi học' : 'Attendance rate',
                onTap: () => tabController.animateTo(3),
              ),
              _buildMetricCard(
                context,
                title: isVi ? 'Học Phí' : 'Tuition',
                value: percentageFmt.format(collectedRate),
                icon: Icons.payments_rounded,
                color: Colors.blueAccent,
                subtitle: isVi ? 'Tỷ lệ đã thu' : 'Collection rate',
                onTap: () => tabController.animateTo(0),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 2. Quick Action Buttons Row
          _buildQuickActionsRow(context, ref, isVi),
          const SizedBox(height: 24),

          // 3. Section Header for Tasks
          _buildSectionHeader(
            context,
            isVi ? 'DANH SÁCH NHIỆM VỤ' : 'TASK LIST',
            Icons.assignment_rounded,
          ),

          // 4. Tasks Section
          _buildNhiemVuSection(context, ref, isVi),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final lightText = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryText = theme.textTheme.bodyMedium?.color ?? Colors.white70;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    child: Icon(icon, color: color, size: 18),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: secondaryText.withValues(alpha: 0.4),
                    size: 12,
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: lightText,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

  Widget _buildQuickActionsRow(BuildContext context, WidgetRef ref, bool isVi) {
    final theme = Theme.of(context);
    final accentColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionButton(
              context,
              icon: Icons.checklist_rtl_rounded,
              label: isVi ? 'Điểm danh' : 'Attendance',
              color: accentColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DiemDanhPage(
                      selectedLopId: state.lop.id,
                      selectedDate: DateTime.now(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              context,
              icon: Icons.person_add_alt_1_rounded,
              label: isVi ? 'Thêm học sinh' : 'Add Student',
              color: Colors.blueAccent,
              onTap: () => _moDialogThemHS(context, ref),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              context,
              icon: Icons.send_rounded,
              label: isVi ? 'Gửi thông báo' : 'Broadcast',
              color: Colors.amberAccent,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => GuiThongBaoHangLoatDialog(
                    initialLopId: state.lop.id,
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
            const SizedBox(width: 8),
            _buildActionButton(
              context,
              icon: Icons.add_task_rounded,
              label: isVi ? 'Thêm nhiệm vụ' : 'Add Task',
              color: Colors.greenAccent,
              onTap: () => _moDialogThemNhiemVu(context, ref),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              context,
              icon: Icons.auto_awesome_rounded,
              label: isVi ? 'Xếp lịch' : 'Schedule',
              color: Colors.purpleAccent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WeeklySchedulingPage(
                      classId: state.lop.id!,
                      className: state.lop.ten,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final lightText = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minWidth: 80, minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: lightText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final secondaryText =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: secondaryText.withValues(alpha: 0.6), size: 18),
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

  Widget _buildNhiemVuSection(BuildContext context, WidgetRef ref, bool isVi) {
    final theme = Theme.of(context);
    final secondaryText = theme.textTheme.bodyMedium?.color ?? Colors.white70;
    final accentColor = theme.primaryColor;

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
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_outline, color: accentColor),
              onPressed: () => _moDialogThemNhiemVu(context, ref),
              tooltip: isVi ? 'Thêm nhiệm vụ' : 'Add task',
            ),
          ],
        ),
        Divider(color: theme.dividerColor),
        state.nhiemVus.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
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
                itemCount: state.nhiemVus.length,
                itemBuilder: (context, index) {
                  return _buildNhiemVuCard(
                    context,
                    ref,
                    state.nhiemVus[index],
                    state.hocSinhs,
                    isVi,
                  );
                },
              ),
      ],
    );
  }

  Widget _buildNhiemVuCard(
    BuildContext context,
    WidgetRef ref,
    NhiemVu nhiemVu,
    List<HSLopViewModel> dsHocSinh,
    bool isVi,
  ) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final lightText = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final secondaryText = theme.textTheme.bodyMedium?.color ?? Colors.white70;
    final accentColor = theme.primaryColor;
    final deleteColor = theme.colorScheme.error;

    final totalStudents = dsHocSinh.length;
    final completedStudents = nhiemVu.trangThaiHocSinh.values
        .where((status) => status == 'Đã nộp')
        .length;
    final progress = totalStudents > 0
        ? completedStudents / totalStudents
        : 0.0;

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
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
              _formatOptionalDate(nhiemVu.ngayNop),
          style: TextStyle(color: secondaryText, fontSize: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
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
                  backgroundColor: secondaryText.withValues(alpha: 0.2),
                  color: accentColor,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
          ),
          Divider(color: theme.dividerColor, height: 16),
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
              onTap: () async {
                final newStatus = isCompleted ? 'Chưa nộp' : 'Đã nộp';
                await ref
                    .read(lopDetailControllerProvider(state.lop.id!).notifier)
                    .capNhatTrangThaiNhiemVu(nhiemVu.id!, hs.id!, newStatus);
              },
            );
          }),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: secondaryText),
                tooltip: isVi ? 'Sửa nhiệm vụ' : 'Edit assignment',
                onPressed: () =>
                    _moDialogThemNhiemVu(context, ref, nhiemVu: nhiemVu),
              ),
              IconButton(
                icon: Icon(Icons.delete, color: deleteColor),
                tooltip: isVi ? 'Xóa nhiệm vụ' : 'Delete assignment',
                onPressed: () => _xacNhanXoaNhiemVu(context, ref, nhiemVu),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _moDialogThemNhiemVu(
    BuildContext context,
    WidgetRef ref, {
    NhiemVu? nhiemVu,
  }) async {
    final nv =
        nhiemVu ??
        NhiemVu(
          idLop: state.lop.id!,
          tenNhiemVu: '',
          ngayGiao: DateFormat('yyyy-MM-dd').format(DateTime.now()),
          ngayNop: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );
    await showDialog(
      context: context,
      builder: (ctx) => NhiemVuDialog(
        nhiemVu: nv,
        onSave: (updatedNv) async {
          final notifier = ref.read(
            lopDetailControllerProvider(state.lop.id!).notifier,
          );
          if (updatedNv.id == null) {
            await notifier.themNhiemVu(updatedNv);
          } else {
            await notifier.capNhatNhiemVu(updatedNv);
          }
        },
      ),
    );
  }

  void _xacNhanXoaNhiemVu(
    BuildContext context,
    WidgetRef ref,
    NhiemVu nhiemVu,
  ) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text(
          isVi ? 'Xác nhận' : 'Confirm',
          style: TextStyle(color: theme.textTheme.bodyLarge?.color),
        ),
        content: Text(
          isVi
              ? 'Bạn có chắc muốn xóa nhiệm vụ "${nhiemVu.tenNhiemVu}" không?'
              : 'Are you sure you want to delete assignment "${nhiemVu.tenNhiemVu}"?',
          style: TextStyle(color: theme.textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (nhiemVu.id != null) {
                await ref
                    .read(lopDetailControllerProvider(state.lop.id!).notifier)
                    .xoaNhiemVu(nhiemVu.id!);
              }
            },
            child: Text(
              isVi ? 'Xóa' : 'Delete',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _moDialogThemHS(BuildContext context, WidgetRef ref) async {
    final hsService = HocSinhService();
    final lhsService = LopHocSinhService();
    final truongService = TruongService();

    final tatCaHS = await hsService.docTatCaHocSinh();
    final danhSachTruong = await truongService.docTatCaTruong();
    final hsTrongLopIds = state.hocSinhs.map((e) => e.id).toSet();

    final hsChuaCoLop = tatCaHS
        .where((hs) => hs.id != null && !(hsTrongLopIds.contains(hs.id)))
        .toList();

    if (!context.mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ThemHSVaoLopDialog(
        lop: state.lop,
        danhSachTatCaHS: hsChuaCoLop,
        lhsService: lhsService,
        hsService: hsService,
        danhSachTruong: danhSachTruong,
      ),
    );

    if (result == true) {
      ref
          .read(lopDetailControllerProvider(state.lop.id!).notifier)
          .refreshAll();
    }
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
