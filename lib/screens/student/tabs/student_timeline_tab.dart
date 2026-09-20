// File: lib/screens/student/tabs/student_timeline_tab.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/student_timeline.dart';
import '../../../services/student_timeline_service.dart';

class StudentTimelineTab extends StatefulWidget {
  final int studentId;

  const StudentTimelineTab({super.key, required this.studentId});

  @override
  State<StudentTimelineTab> createState() => _StudentTimelineTabState();
}

class _StudentTimelineTabState extends State<StudentTimelineTab> {
  final _timelineService = StudentTimelineService.instance;
  StudentTimelineFilter _currentFilter = StudentTimelineFilter.all;

  List<StudentTimelineItem> _timelineItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    setState(() => _loading = true);
    try {
      final items = await _timelineService.fetchTimeline(
        studentId: widget.studentId,
        filter: _currentFilter,
        limit: 50,
      );
      if (mounted) {
        setState(() {
          _timelineItems = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).primaryColor;

    return Column(
      children: [
        // Filter bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('Tất cả', StudentTimelineFilter.all),
              const SizedBox(width: 6),
              _buildFilterChip('Buổi học', StudentTimelineFilter.session),
              const SizedBox(width: 6),
              _buildFilterChip('Nghỉ / Trễ', StudentTimelineFilter.absence),
              const SizedBox(width: 6),
              _buildFilterChip('Học phí', StudentTimelineFilter.payment),
              const SizedBox(width: 6),
              _buildFilterChip('Cảnh báo', StudentTimelineFilter.warning),
            ],
          ),
        ),

        // Timeline Feed with Visual Line
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: accentColor))
              : _timelineItems.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có dữ liệu dòng thời gian.',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTimeline,
                  color: accentColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _timelineItems.length,
                    itemBuilder: (context, index) {
                      final item = _timelineItems[index];
                      final isLast = index == _timelineItems.length - 1;
                      return _buildTimelineTile(context, item, isLast);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, StudentTimelineFilter filter) {
    final isSelected = _currentFilter == filter;
    final accentColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() => _currentFilter = filter);
          _loadTimeline();
        }
      },
      selectedColor: accentColor,
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildTimelineTile(
    BuildContext context,
    StudentTimelineItem item,
    bool isLast,
  ) {
    final cardColor = Theme.of(context).cardColor;
    final accentColor = Theme.of(context).primaryColor;

    IconData iconData = Icons.event_note_rounded;
    Color nodeColor = accentColor;

    if (item is StudentSessionTimelineItem) {
      if (item.attendanceStatus == 'Có mặt') {
        iconData = Icons.check_circle_outline;
        nodeColor = Colors.greenAccent;
      } else if (item.attendanceStatus == 'Trễ') {
        iconData = Icons.access_time_rounded;
        nodeColor = Colors.orangeAccent;
      } else {
        iconData = Icons.cancel_outlined;
        nodeColor = Colors.redAccent;
      }
    } else if (item is StudentPaymentTimelineItem) {
      iconData = Icons.account_balance_wallet_outlined;
      nodeColor = Colors.lightBlueAccent;
    }

    final dateFormatted = DateFormat(
      'dd/MM/yyyy • HH:mm',
    ).format(item.eventDateTime);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual Vertical Connector Column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: nodeColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: nodeColor, width: 1.5),
                  ),
                  child: Icon(iconData, size: 13, color: nodeColor),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: Colors.white12)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Timeline Item Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        dateFormatted,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.summary,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  if (item is StudentSessionTimelineItem &&
                      item.teacherComment != null &&
                      item.teacherComment!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '💬 ${item.teacherComment!}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
