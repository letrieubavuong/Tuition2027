// File: lib/screens/thong_ke_page.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/thong_ke_service.dart';
import '../services/dashboard_service.dart'; // THÊM IMPORT
import '../l10n/app_localizations.dart';

class ThongKePage extends StatefulWidget {
  const ThongKePage({super.key});

  @override
  State<ThongKePage> createState() => _ThongKePageState();
}

class _ThongKePageState extends State<ThongKePage> {
  final ThongKeService _service = ThongKeService();
  final DashboardService _dashboardService = DashboardService(); // KHỞI TẠO SERVICE
  late Future<Map<String, dynamic>> _dataFuture;

  // Theme màu
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color cardColor = Color(0xFF16213E);
  static const Color lightText = Colors.white;
  static const Color secondaryText = Colors.white70;
  static const Color accentColor = Color(0xFF00BFA5);
  static const Color incomeColor = Colors.greenAccent;
  static const Color debtColor = Colors.redAccent;
  static const Color studentColor = Colors.blueAccent;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  Future<Map<String, dynamic>> _fetchData() async {
    final studentData = await _service.getSoLuongHSHoatDong12Thang();
    final tuitionData = await _service.getHocPhi12Thang();
    final dashboardData = await _dashboardService.getDashboardData(); // LẤY DỮ LIỆU TỔNG QUAN
    return {
      'students': studentData,
      'tuition': tuitionData,
      'summary': dashboardData,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: Text(isVi ? 'THỐNG KÊ TỔNG QUAN' : 'OVERVIEW STATISTICS'),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: accentColor),
            onPressed: _loadData,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                isVi ? 'Lỗi: ${snapshot.error}' : 'Error: ${snapshot.error}',
                style: const TextStyle(color: debtColor),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(
              child: Text(
                isVi ? 'Không có dữ liệu.' : 'No data.',
                style: const TextStyle(color: secondaryText),
              ),
            );
          }

          final List<HocSinhThang> studentData =
              snapshot.data!['students'] ?? [];
          final List<HocPhiThang> tuitionData = snapshot.data!['tuition'] ?? [];
          final DashboardData summary = snapshot.data!['summary'] ?? DashboardData();
          final formatCurrency = NumberFormat('#,##0', 'vi_VN');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- QUICK SUMMARY SECTION ---
                Text(
                  isVi ? 'CHỈ SỐ TRONG THÁNG' : 'MONTHLY METRICS',
                  style: const TextStyle(
                    color: secondaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.3,
                  children: [
                    _buildMetricCard(
                      isVi ? 'Doanh Thu' : 'Revenue',
                      '${formatCurrency.format(summary.tongTienThu)}đ',
                      Icons.account_balance_wallet_outlined,
                      incomeColor,
                    ),
                    _buildMetricCard(
                      isVi ? 'Công Nợ' : 'Debt',
                      '${formatCurrency.format(summary.tongTienNo)}đ',
                      Icons.error_outline,
                      debtColor,
                    ),
                    _buildMetricCard(
                      isVi ? 'Học Sinh' : 'Students',
                      summary.soHocSinh.toString(),
                      Icons.people_outline,
                      studentColor,
                    ),
                    _buildMetricCard(
                      isVi ? 'Lớp Học' : 'Classes',
                      summary.soLopHoc.toString(),
                      Icons.class_outlined,
                      accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                _buildChartCard(
                  title: isVi ? 'Học Sinh Hoạt Động (12 Tháng)' : 'Active Students (12 Months)',
                  chart: _buildStudentChart(studentData),
                ),
                const SizedBox(height: 24),
                _buildChartCard(
                  title: isVi ? 'Học Phí (12 Tháng)' : 'Tuition Fees (12 Months)',
                  chart: _buildTuitionChart(tuitionData),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: secondaryText, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              color: lightText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({required String title, required Widget chart}) {
    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: lightText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(height: 250, child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentChart(List<HocSinhThang> data) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    if (data.isEmpty) {
      return Center(
        child: Text(isVi ? 'Không có dữ liệu' : 'No data', style: const TextStyle(color: secondaryText)),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (data.map((d) => d.soLuong).reduce((a, b) => a > b ? a : b) * 1.2)
            .toDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${data[groupIndex].thang}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: rod.toY.round().toString(),
                    style: const TextStyle(
                      color: studentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final month = data[value.toInt()].thang.substring(5);
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4.0,
                  child: Text(
                    month,
                    style: const TextStyle(
                      color: secondaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: List.generate(data.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data[index].soLuong.toDouble(),
                color: studentColor,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTuitionChart(List<HocPhiThang> data) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    if (data.isEmpty) {
      return Center(
        child: Text(isVi ? 'Không có dữ liệu' : 'No data', style: const TextStyle(color: secondaryText)),
      );
    }

    final formatCurrency = NumberFormat.compact(locale: 'vi_VN');

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String text;
              if (rod.color == incomeColor) {
                text = (isVi ? 'Thu: ' : 'Collected: ') + NumberFormat('#,##0', 'vi_VN').format(rod.toY);
              } else {
                text = (isVi ? 'Nợ: ' : 'Debt: ') + NumberFormat('#,##0', 'vi_VN').format(rod.toY);
              }
              return BarTooltipItem(
                '${data[groupIndex].thang}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: <TextSpan>[
                  TextSpan(
                    text: text,
                    style: TextStyle(
                      color: rod.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final month = data[value.toInt()].thang.substring(5);
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4.0,
                  child: Text(
                    month,
                    style: const TextStyle(
                      color: secondaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) {
                if (value == 0 || value == meta.max) return const SizedBox();
                return Text(
                  formatCurrency.format(value),
                  style: const TextStyle(color: secondaryText, fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          getDrawingHorizontalLine: (value) =>
              const FlLine(color: secondaryText, strokeWidth: 0.2),
        ),
        barGroups: List.generate(data.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                // Tổng chiều cao của cột là tổng thu + tổng nợ
                toY: (data[index].tongThu + data[index].tongNo).toDouble(),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                // Các phần xếp chồng lên nhau
                rodStackItems: [
                  // Phần đã thu (màu xanh)
                  BarChartRodStackItem(
                    0,
                    data[index].tongThu.toDouble(),
                    incomeColor,
                  ),
                  // Phần còn nợ (màu đỏ)
                  BarChartRodStackItem(
                    data[index].tongThu.toDouble(),
                    (data[index].tongThu + data[index].tongNo).toDouble(),
                    debtColor,
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}
