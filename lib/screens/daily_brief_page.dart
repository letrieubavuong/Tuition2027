// File: lib/screens/daily_brief_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_brief.dart';
import '../services/daily_brief_service.dart';
import '../services/hoc_sinh_service.dart';
import 'attention_queue_page.dart';
import 'hs_detail.dart';

class DailyBriefPage extends StatefulWidget {
  const DailyBriefPage({Key? key}) : super(key: key);

  @override
  State<DailyBriefPage> createState() => _DailyBriefPageState();
}

class _DailyBriefPageState extends State<DailyBriefPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _briefService = DailyBriefService.instance;

  MorningBrief? _morning;
  EveningBrief? _evening;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBriefs();
    _briefService.addListener(_loadBriefs);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _briefService.removeListener(_loadBriefs);
    super.dispose();
  }

  Future<void> _loadBriefs() async {
    try {
      final morning = await _briefService.getMorningBrief(forceRefresh: true);
      final evening = await _briefService.getEveningBrief(forceRefresh: true);
      if (mounted) {
        setState(() {
          _morning = morning;
          _evening = evening;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Brief — $dateStr'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.wb_sunny_rounded), text: 'Buổi Sáng'),
            Tab(icon: Icon(Icons.nights_stay_rounded), text: 'Cuối Ngày'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildMorningView(_morning),
                _buildEveningView(_evening),
              ],
            ),
    );
  }

  Widget _buildMorningView(MorningBrief? brief) {
    if (brief == null || brief.isEmpty) {
      return _buildEmptyBrief('Buổi sáng ổn định — Không có việc tồn đọng.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          '📅 CA DẠY HÔM NAY',
          '${brief.todaySessions.length} ca',
        ),
        ...brief.todaySessions.map(
          (s) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.class_rounded, size: 20),
              ),
              title: Text('${s.timeRange} — Lớp ${s.className}'),
              subtitle: Text('Sĩ số: ${s.totalStudents} học sinh'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (brief.preClassStudentAlerts.isNotEmpty) ...[
          _buildSectionHeader(
            '⚠ CẦN LƯU Ý TRƯỚC KHI DẠY',
            '${brief.preClassStudentAlerts.length} học sinh',
          ),
          ...brief.preClassStudentAlerts.map(
            (item) => Card(
              color: Colors.amber.withValues(alpha: 0.1),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.title),
                subtitle: Text(item.summary),
                trailing: TextButton(
                  onPressed: () {
                    if (item.studentId != null) {
                      _navigateToStudent(item.studentId!);
                    }
                  },
                  child: const Text('Xem'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildSectionHeader('💰 HỌC PHÍ & GIAO DỊCH', ''),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildMetricRow(
                  'Học phí đến hạn nhắc',
                  '${brief.tuitionRemindersDueCount} PH',
                ),
                const Divider(),
                _buildMetricRow(
                  'Giao dịch ngân hàng cần duyệt',
                  '${brief.pendingPaymentReviewsCount} GD',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('📋 VIỆC CÒN TỒN', ''),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildMetricRow(
                  'PH chưa liên hệ',
                  '${brief.uncontactedParentsCount} PH',
                ),
                const Divider(),
                _buildMetricRow(
                  'Ca hôm qua chưa đánh giá',
                  '${brief.unreviewedYesterdaySessionsCount} ca',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEveningView(EveningBrief? brief) {
    if (brief == null) {
      return _buildEmptyBrief('Chưa có tổng kết cho ngày hôm nay.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          '📊 TỔNG KẾT VẬN HÀNH HÔM NAY',
          '${brief.completedSessionsCount}/${brief.totalSessionsCount} ca hoàn tất',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildMetricRow('Có mặt', '${brief.totalAttended} HS'),
                _buildMetricRow('Nghỉ có phép', '${brief.totalExcused} HS'),
                _buildMetricRow(
                  'Nghỉ không phép',
                  '${brief.totalUnexcused} HS',
                ),
                _buildMetricRow('Đi trễ', '${brief.totalLate} HS'),
                _buildMetricRow('Học bù', '${brief.totalMakeup} HS'),
                const Divider(),
                _buildMetricRow(
                  'Ca đã giao BTVN',
                  '${brief.homeworkAssignedCount} ca',
                ),
                _buildMetricRow(
                  'PH đã liên hệ',
                  '${brief.parentContactsMadeCount} PH',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (brief.studentsToWatchTomorrow.isNotEmpty) ...[
          _buildSectionHeader('⭐ HỌC SINH CẦN THEO DÕI NGÀY MAI', ''),
          ...brief.studentsToWatchTomorrow.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.title),
                subtitle: Text(item.summary),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  if (item.studentId != null) {
                    _navigateToStudent(item.studentId!);
                  }
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _navigateToStudent(int studentId) async {
    final hs = await HocSinhService().docHocSinhTheoId(studentId);
    if (hs != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HSDetail(hocSinh: hs)),
      );
    }
  }

  Widget _buildSectionHeader(String title, String trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          if (trailing.isNotEmpty)
            Text(
              trailing,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBrief(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wb_sunny_outlined, size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
