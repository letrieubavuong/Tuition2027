import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/danh_gia_lich_su_view_model.dart';
import '../../../models/su_kien_hoc_tap.dart';
import '../../../models/su_kien_lich_su_view_model.dart';

class StudentEvaluationTab extends StatelessWidget {
  final Future<List<dynamic>>? evaluationFuture;

  const StudentEvaluationTab({super.key, required this.evaluationFuture});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    return FutureBuilder<List<dynamic>>(
      future: evaluationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                isVi
                    ? 'Lỗi tải đánh giá học tập'
                    : 'Error loading academic evaluations',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }

        final List<SuKienLichSuViewModel> events =
            snapshot.data?[0] as List<SuKienLichSuViewModel>? ?? [];
        final List<DanhGiaLichSuViewModel> danhGiaList =
            snapshot.data?[1] as List<DanhGiaLichSuViewModel>? ?? [];

        // Reverse for chronological order chart (oldest to newest)
        final chartData = danhGiaList.reversed.toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. SUMMARY FOR LAST 5 SESSIONS
              _buildRecentSummaryCard(context, danhGiaList, isVi),

              const SizedBox(height: 14),

              // 2. PROGRESS CHART
              if (chartData.length >= 2) ...[
                _buildChartCard(context, chartData, isVi),
                const SizedBox(height: 14),
              ] else if (danhGiaList.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        isVi
                            ? 'Cần thêm đánh giá buổi học để vẽ biểu đồ tiến độ'
                            : 'Need more session ratings to draw progress chart',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 3. EVENT & COMPETITION LOG
              Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isVi ? 'NHẬT KÝ THI ĐUA' : 'COMPETITION LOG',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (events.isEmpty)
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        isVi
                            ? 'Chưa có nhận xét hay sự kiện thi đua nào'
                            : 'No comments or events logged yet',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final sk = events[i];
                    final isTichCuc = sk.loaiSuKien == LoaiSuKien.tichCuc;
                    final iconColor = isTichCuc
                        ? Colors.green.shade600
                        : theme.colorScheme.error;

                    return Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(
                            0.3,
                          ),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isTichCuc
                                ? Icons.add_circle_outline
                                : Icons.remove_circle_outline,
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          sk.moTa,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${sk.tenLop} • ${DateFormat('dd/MM/yyyy').format(sk.ngayHoc)}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Text(
                          '${isTichCuc ? "+" : ""}${sk.diemThayDoi}',
                          style: TextStyle(
                            color: iconColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentSummaryCard(
    BuildContext context,
    List<DanhGiaLichSuViewModel> danhGiaList,
    bool isVi,
  ) {
    final theme = Theme.of(context);

    if (danhGiaList.isEmpty) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isVi
                      ? 'Chưa đủ dữ liệu đánh giá.'
                      : 'Not enough evaluation data.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Take top 5 most recent evaluations
    final recent = danhGiaList.take(5).toList();

    double? avgThaiDo = _calcAvg(recent.map((e) => e.diemThaiDo));
    double? avgHieuBai = _calcAvg(recent.map((e) => e.diemHieuBai));
    double? avgBaiTap = _calcAvg(recent.map((e) => e.diemBaiTap));

    // Trends: compare most recent vs older items in the recent list
    String trendThaiDo = _calcTrend(recent.map((e) => e.diemThaiDo).toList());
    String trendHieuBai = _calcTrend(recent.map((e) => e.diemHieuBai).toList());
    String trendBaiTap = _calcTrend(recent.map((e) => e.diemBaiTap).toList());

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stars_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isVi
                      ? '5 BUỔI GẦN NHẤT (${recent.length} buổi)'
                      : 'LAST 5 SESSIONS (${recent.length} sessions)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    isVi ? 'Thái độ' : 'Attitude',
                    avgThaiDo,
                    trendThaiDo,
                    Colors.green.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    isVi ? 'Tiếp thu' : 'Understanding',
                    avgHieuBai,
                    trendHieuBai,
                    Colors.blue.shade600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    isVi ? 'BTVN' : 'Homework',
                    avgBaiTap,
                    trendBaiTap,
                    Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context,
    String label,
    double? score,
    String trend,
    Color accentColor,
  ) {
    final theme = Theme.of(context);
    final scoreText = score != null ? score.toStringAsFixed(1) : '--';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                scoreText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: score != null
                      ? accentColor
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (trend.isNotEmpty && score != null) ...[
                const SizedBox(width: 4),
                Text(
                  trend,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: trend == '↑'
                        ? Colors.green.shade600
                        : trend == '↓'
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(
    BuildContext context,
    List<DanhGiaLichSuViewModel> chartData,
    bool isVi,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVi ? 'BIỂU ĐỒ TIẾN BỘ HỌC TẬP' : 'ACADEMIC PROGRESS CHART',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 10,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          if (value % 2 != 0) return const SizedBox();
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= chartData.length) {
                            return const SizedBox();
                          }
                          if (chartData.length > 5 && index % 2 != 0) {
                            return const SizedBox();
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              DateFormat(
                                'dd/MM',
                              ).format(chartData[index].ngayHoc),
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    // Đường điểm Thái độ (Green)
                    LineChartBarData(
                      spots: List.generate(chartData.length, (idx) {
                        return FlSpot(
                          idx.toDouble(),
                          chartData[idx].diemThaiDo ?? 0.0,
                        );
                      }),
                      isCurved: true,
                      color: Colors.green.shade500,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: Colors.green.shade500,
                              strokeWidth: 1,
                              strokeColor: Colors.white,
                            ),
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                    // Đường điểm Hiểu bài (Blue)
                    LineChartBarData(
                      spots: List.generate(chartData.length, (idx) {
                        return FlSpot(
                          idx.toDouble(),
                          chartData[idx].diemHieuBai ?? 0.0,
                        );
                      }),
                      isCurved: true,
                      color: Colors.blue.shade500,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: Colors.blue.shade500,
                              strokeWidth: 1,
                              strokeColor: Colors.white,
                            ),
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                    // Đường điểm Bài tập về nhà (Orange)
                    LineChartBarData(
                      spots: List.generate(chartData.length, (idx) {
                        return FlSpot(
                          idx.toDouble(),
                          chartData[idx].diemBaiTap ?? 0.0,
                        );
                      }),
                      isCurved: true,
                      color: Colors.amber.shade600,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: Colors.amber.shade600,
                              strokeWidth: 1,
                              strokeColor: Colors.white,
                            ),
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  context,
                  isVi ? 'Thái độ' : 'Attitude',
                  Colors.green.shade500,
                ),
                const SizedBox(width: 16),
                _buildLegendItem(
                  context,
                  isVi ? 'Hiểu bài' : 'Understanding',
                  Colors.blue.shade500,
                ),
                const SizedBox(width: 16),
                _buildLegendItem(
                  context,
                  isVi ? 'Bài tập' : 'Homework',
                  Colors.amber.shade600,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(BuildContext context, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  double? _calcAvg(Iterable<double?> values) {
    final valid = values.whereType<double>().toList();
    if (valid.isEmpty) return null;
    final sum = valid.reduce((a, b) => a + b);
    return sum / valid.length;
  }

  String _calcTrend(List<double?> values) {
    final valid = values.whereType<double>().toList();
    if (valid.length < 2) return '';
    final latest = valid.first;
    final prevAvg = valid.skip(1).reduce((a, b) => a + b) / (valid.length - 1);
    final diff = latest - prevAvg;
    if (diff > 0.3) return '↑';
    if (diff < -0.3) return '↓';
    return '→';
  }
}
