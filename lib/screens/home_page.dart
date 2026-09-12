// File: lib/screens/home_page.dart

import 'package:flutter/material.dart';
import '../main.dart';
import '../l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart'; // Import thư viện biểu đồ
import 'package:intl/intl.dart';
import '../services/dashboard_service.dart';
import '../services/tuition_event_service.dart';
import '../widgets/main_drawer.dart';
// Import các trang cần điều hướng đến
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

  // Biến trạng thái cho biểu đồ
  int _touchedIndex = -1;

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
      body: FutureBuilder<DashboardData>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: theme.primaryColor),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi tải dữ liệu: ${snapshot.error}',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          final data = snapshot.data ?? DashboardData();
          final formatCurrency = NumberFormat('#,##0', 'vi_VN');

          final totalPotential = data.tongTienThu + data.tongTienNo;
          final collectionRate = totalPotential > 0
              ? data.tongTienThu / totalPotential
              : 0.0;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Grid View cho các Metric Cards ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                    children: [
                      _buildSummaryCard(
                        loc.homeMetricStudent,
                        data.soHocSinh.toString(),
                        Icons.group_rounded,
                        Colors.blueAccent,
                        progress: null,
                        subtitle: loc.homeSubtitleClassCount(
                          data.soLopHoc.toString(),
                        ),
                        onTap: () =>
                            widget.mainScreenKey.currentState?.onItemTapped(2),
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
                        onTap: () =>
                            widget.mainScreenKey.currentState?.onItemTapped(3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // SỬA: Thêm phần biểu đồ
                  Text(
                    loc.studentDistributionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.hintColor,
                      fontSize: 16,
                    ),
                  ),
                  Divider(color: theme.dividerColor, height: 16),
                  if (data.phanBoHocSinh.isNotEmpty)
                    _buildStudentDistributionChart(data.phanBoHocSinh)
                  else
                    _buildEmptyChartPlaceholder(),
                  const SizedBox(height: 24),
                  // Tiêu đề cho danh sách lịch học
                  Text(
                    loc.todayScheduleTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.hintColor,
                      fontSize: 16,
                    ),
                  ),
                  Divider(color: theme.dividerColor, height: 16),
                  // Danh sách lịch học
                  _buildTodayScheduleList(data.dsCaHocHomNay),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // HÀM MỚI: Widget hiển thị khi không có dữ liệu biểu đồ
  Widget _buildEmptyChartPlaceholder() {
    final loc = AppLocalizations.of(context)!;
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Text(
        loc.noStudentDataChart,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
      ),
    );
  }

  // HÀM MỚI: Widget xây dựng biểu đồ tròn và chú thích
  Widget _buildStudentDistributionChart(List<HocSinhTheoKhoi> data) {
    // Danh sách màu cho các phần của biểu đồ
    final List<Color> pieColors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          // Biểu đồ tròn
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                // SỬA: Thêm phần xử lý sự kiện chạm
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: List.generate(data.length, (i) {
                  final isTouched = i == _touchedIndex;
                  final fontSize = isTouched ? 18.0 : 14.0;
                  final radius = isTouched ? 70.0 : 60.0;
                  final item = data[i];
                  final color = pieColors[i % pieColors.length];
                  return PieChartSectionData(
                    color: color,
                    value: item.soLuong.toDouble(),
                    title: '${item.soLuong}',
                    radius: radius,
                    titleStyle: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                  );
                }),
              ),
            ),
          ),
          // Chú thích
          Expanded(
            flex: 1,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: data.length,
              itemBuilder: (context, i) {
                final item = data[i];
                final color = pieColors[i % pieColors.length];
                final loc = AppLocalizations.of(context)!;
                return _buildIndicator(
                  color: color,
                  text: loc.grade(item.khoi.toString()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // HÀM MỚI: Widget xây dựng một dòng chú thích
  Widget _buildIndicator({required Color color, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: <Widget>[
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

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
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
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
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (progress != null)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      backgroundColor: color.withValues(alpha: 0.1),
                      color: color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayScheduleList(List<CaHocHomNay> schedule) {
    final loc = AppLocalizations.of(context)!;
    if (schedule.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          child: Text(
            loc.noScheduleToday,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: schedule.length,
      itemBuilder: (context, index) {
        final caHoc = schedule[index];
        final theme = Theme.of(context);
        return Card(
          color: theme.cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white10),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.schedule, color: theme.primaryColor, size: 20),
            ),
            title: Text(
              caHoc.tenLop,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${loc.locale.languageCode == 'vi' ? 'Thời gian' : 'Time'}: ${caHoc.gioBatDau.substring(0, 5)} - ${caHoc.gioKetThuc.substring(0, 5)}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DiemDanhPage(
                    selectedLopId: caHoc.idLop,
                    selectedDate: DateTime.now(),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
