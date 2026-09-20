// File: lib/screens/home_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import '../main.dart';
import '../l10n/app_localizations.dart';
import '../services/dashboard_service.dart';
import '../services/tuition_event_service.dart';
import '../services/post_session_review_service.dart';
import '../widgets/main_drawer.dart';
import '../widgets/xuat_bao_cao_pdf_dialog.dart';
import '../models/home_widget_snapshot.dart';
import '../services/widget_snapshot_service.dart';
import '../widgets/home_widget_snapshot_card.dart';

// Import screens for navigation
import 'daily_brief_page.dart';
import 'attention_queue_page.dart';
import 'diem_danh_page.dart';

class HomePage extends StatefulWidget {
  final GlobalKey<MainScreenState> mainScreenKey;
  final int selectedIndex;
  const HomePage({
    super.key,
    required this.mainScreenKey,
    required this.selectedIndex,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DashboardService _dashboardService = DashboardService();
  late Future<DashboardData> _dashboardDataFuture;
  late Future<HomeWidgetSnapshot> _widgetSnapshotFuture;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    TuitionEventService().addListener(_onTuitionEventChanged);
  }

  void _onTuitionEventChanged() {
    if (mounted) {
      _loadDashboardData();
    }
  }

  @override
  void dispose() {
    TuitionEventService().removeListener(_onTuitionEventChanged);
    super.dispose();
  }

  void _loadDashboardData() {
    setState(() {
      _dashboardDataFuture = _dashboardService.getDashboardData();
      _widgetSnapshotFuture = WidgetSnapshotService.instance.buildSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(loc.homePageHeader),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: theme.primaryColor),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      drawer: MainDrawer(
        mainScreenKey: widget.mainScreenKey,
        selectedIndex: widget.selectedIndex,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadDashboardData();
          await _dashboardDataFuture;
        },
        child: FutureBuilder<DashboardData>(
          future: _dashboardDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: theme.primaryColor),
              );
            }

            if (snapshot.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orangeAccent),
                      const SizedBox(height: 12),
                      Text(
                        'Không thể tải một số dữ liệu.',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hãy kéo xuống để thử lại.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadDashboardData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data ?? DashboardData();
            final formatCurrency = NumberFormat('#,##0', 'vi_VN');
            final totalPotential = data.tongTienThu + data.tongTienNo;
            final collectionRate = totalPotential > 0 ? data.tongTienThu / totalPotential : 0.0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. TODAY CONTROL CENTER WIDGET ---
                    FutureBuilder<HomeWidgetSnapshot>(
                      future: _widgetSnapshotFuture,
                      builder: (context, widgetSnapshot) {
                        if (!widgetSnapshot.hasData) {
                          return const SizedBox.shrink();
                        }
                        return HomeWidgetSnapshotCard(
                          snapshot: widgetSnapshot.data!,
                          onRefresh: _loadDashboardData,
                          onNavigatePayload: (payload) {
                            switch (payload.action) {
                              case HomeWidgetAction.attendance:
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DiemDanhPage(
                                      selectedLopId: payload.classId,
                                      selectedDate: payload.date ?? DateTime.now(),
                                      selectedScheduleId: payload.scheduleId,
                                    ),
                                  ),
                                );
                                break;
                              case HomeWidgetAction.sessionClose:
                                if (payload.classId != null && payload.classId! > 0) {
                                  PostSessionReviewService.instance.openPostSessionReviewScreen(
                                    context,
                                    classId: payload.classId!,
                                    scheduleId: payload.scheduleId,
                                    date: payload.date ?? DateTime.now(),
                                  );
                                }
                                break;
                              case HomeWidgetAction.dailyBrief:
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DailyBriefPage(),
                                  ),
                                );
                                break;
                              case HomeWidgetAction.refresh:
                                _loadDashboardData();
                                break;
                              case HomeWidgetAction.tuition:
                                widget.mainScreenKey.currentState?.onItemTapped(3);
                                break;
                              case HomeWidgetAction.students:
                              case HomeWidgetAction.parents:
                                widget.mainScreenKey.currentState?.onItemTapped(2);
                                break;
                              case HomeWidgetAction.attention:
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AttentionQueuePage(),
                                  ),
                                );
                                break;
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // --- 2. CÔNG CỤ NHANH (QUICK ACTIONS ROW) ---
                    _buildQuickActionsRow(theme),
                    const SizedBox(height: 20),

                    // --- 3. SECTION: VIỆC HÔM NAY (TODAY'S SCHEDULE & WORK) ---
                    _buildTodayWorkSection(theme, data.dsCaHocHomNay),
                    const SizedBox(height: 24),

                    // --- 4. THỐNG KÊ TỔNG QUAN (COMPACT METRIC CARDS) ---
                    Text(
                      data.monthKey.length >= 7
                          ? 'THỐNG KÊ HỌC PHÍ THÁNG ${data.monthKey.substring(5)}/${data.monthKey.substring(0, 4)}'
                          : 'THỐNG KÊ TỔNG QUAN',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.15,
                      children: [
                        _buildSummaryCard(
                          loc.homeMetricStudent,
                          data.soHocSinh.toString(),
                          Icons.group_rounded,
                          Colors.blueAccent,
                          progress: null,
                          subtitle: loc.homeSubtitleClassCount(data.soLopHoc.toString()),
                          onTap: () => widget.mainScreenKey.currentState?.onItemTapped(2),
                        ),
                        _buildSummaryCard(
                          loc.homeMetricClass,
                          data.soCaHocHomNay.toString(),
                          Icons.calendar_today_rounded,
                          Colors.orangeAccent,
                          progress: null,
                          subtitle: loc.homeSubtitleToday,
                        ),
                        _buildSummaryCard(
                          loc.homeMetricRevenue,
                          '${formatCurrency.format(data.tongTienThu)}đ',
                          Icons.account_balance_wallet_rounded,
                          Colors.tealAccent,
                          progress: collectionRate,
                          subtitle: loc.homeSubtitleCollectionRate,
                        ),
                        _buildSummaryCard(
                          loc.homeMetricDebt,
                          '${formatCurrency.format(data.tongTienNo)}đ',
                          Icons.error_outline_rounded,
                          Colors.pinkAccent,
                          progress: null,
                          subtitle: loc.homeSubtitleRemainingDebt,
                          onTap: () => widget.mainScreenKey.currentState?.onItemTapped(3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- SECTION: CÔNG CỤ NHANH ---
  Widget _buildQuickActionsRow(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickActionButton(
            theme,
            icon: Icons.assignment_turned_in_rounded,
            label: 'Điểm danh',
            color: Colors.blueAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiemDanhPage()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            theme,
            icon: Icons.monetization_on_rounded,
            label: 'Học phí',
            color: Colors.teal,
            onTap: () => widget.mainScreenKey.currentState?.onItemTapped(3),
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            theme,
            icon: Icons.person_search_rounded,
            label: 'Học sinh',
            color: Colors.purpleAccent,
            onTap: () => widget.mainScreenKey.currentState?.onItemTapped(2),
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            theme,
            icon: Icons.notification_important_rounded,
            label: 'Việc cần làm',
            color: Colors.orangeAccent,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttentionQueuePage()),
            ),
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            theme,
            icon: Icons.picture_as_pdf_rounded,
            label: 'Xuất Báo Cáo',
            color: Colors.redAccent,
            onTap: () => showDialog(
              context: context,
              builder: (_) => const XuatBaoCaoPdfDialog(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SECTION: VIỆC HÔM NAY (TODAY'S WORK) ---
  Widget _buildTodayWorkSection(
    ThemeData theme,
    List<CaHocHomNay> schedule,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_note_rounded, color: Colors.blueAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'VIỆC HÔM NAY',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (schedule.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor),
            ),
            child: const Text(
              'Hôm nay không có ca học.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: schedule.length,
            itemBuilder: (context, index) {
              final ca = schedule[index];
              return _buildScheduleItemCard(theme, ca);
            },
          ),
      ],
    );
  }

  Widget _buildScheduleItemCard(ThemeData theme, CaHocHomNay ca) {
    Color chipColor;
    switch (ca.status) {
      case 'Đang diễn ra':
        chipColor = Colors.green;
        break;
      case 'Chưa điểm danh':
        chipColor = Colors.redAccent;
        break;
      case 'Cần đánh giá':
        chipColor = Colors.orangeAccent;
        break;
      case 'Hoàn tất':
        chipColor = Colors.purple;
        break;
      case 'Đã điểm danh':
        chipColor = Colors.teal;
        break;
      case 'Đã kết thúc':
        chipColor = Colors.grey;
        break;
      case 'Sắp bắt đầu':
      default:
        chipColor = Colors.blue;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    ca.gioBatDau,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: chipColor,
                    ),
                  ),
                  Text(
                    ca.gioKetThuc,
                    style: TextStyle(
                      fontSize: 11,
                      color: chipColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lớp ${ca.tenLop}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${ca.attendedCount}/${ca.totalStudentsCount} học sinh • ${ca.status}',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: chipColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(80, 32),
              ),
              onPressed: () {
                if (!ca.attendanceDone) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiemDanhPage(
                        selectedLopId: ca.idLop,
                        selectedDate: DateTime.now(),
                        selectedScheduleId: ca.idLichHoc,
                      ),
                    ),
                  );
                } else if (!ca.reviewDone) {
                  PostSessionReviewService.instance.openPostSessionReviewScreen(
                    context,
                    classId: ca.idLop,
                    scheduleId: ca.idLichHoc,
                    date: DateTime.now(),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiemDanhPage(
                        selectedLopId: ca.idLop,
                        selectedDate: DateTime.now(),
                        selectedScheduleId: ca.idLichHoc,
                      ),
                    ),
                  );
                }
              },
              child: Text(
                !ca.attendanceDone
                    ? 'Điểm danh'
                    : (!ca.reviewDone ? 'Đánh giá' : 'Chi tiết'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SUMMARY CARD ---
  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    double? progress,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final cardWidget = Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                if (progress != null)
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.titleLarge?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.hintColor.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: cardWidget,
      );
    }
    return cardWidget;
  }
}
