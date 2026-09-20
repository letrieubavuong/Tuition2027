import 'package:flutter/material.dart';
import '../models/schedule_suggestion.dart';
import '../models/student_schedule_assignment.dart';
import '../services/smart_scheduling_service.dart';
import 'student_schedule_page.dart';

class WeeklySchedulingPage extends StatefulWidget {
  final int classId;
  final String className;

  const WeeklySchedulingPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<WeeklySchedulingPage> createState() => _WeeklySchedulingPageState();
}

class _WeeklySchedulingPageState extends State<WeeklySchedulingPage>
    with SingleTickerProviderStateMixin {
  late DateTime _weekStart;
  bool _isLoading = true;
  BatchWeeklyAnalysisResult? _analysisResult;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _loadAnalysis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _weekStartStr => _weekStart.toIso8601String().substring(0, 10);
  String get _weekEndStr => _weekStart
      .add(const Duration(days: 6))
      .toIso8601String()
      .substring(0, 10);

  Future<void> _loadAnalysis() async {
    setState(() => _isLoading = true);
    final res = await SmartSchedulingService.instance
        .analyzeBatchWeeklySchedules(
          classId: widget.classId,
          weekStartDate: _weekStartStr,
        );
    setState(() {
      _analysisResult = res;
      _isLoading = false;
    });
  }

  void _changeWeek(int offsetDays) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: offsetDays));
    });
    _loadAnalysis();
  }

  Future<void> _applySingleSuggestion(
    StudentWeeklyAnalysis item,
    ScheduleSuggestion suggestion,
  ) async {
    try {
      final resId = await SmartSchedulingService.instance
          .confirmAndApplySuggestion(
            suggestion: suggestion,
            effectiveFrom: _weekStartStr,
            effectiveTo: _weekEndStr,
            source: AssignmentSource.smartSuggestionAccepted,
            priority: 2, // Temporary weekly override
          );

      if (resId > 0 && mounted) {
        final isNewAssign = item.currentAssignment == null;
        final actionText = isNewAssign ? 'Đã gán' : 'Đã chuyển';

        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ $actionText ${item.studentName} sang ca ${suggestion.dayName} (${suggestion.startTime})!',
            ),
            action: SnackBarAction(
              label: 'HOÀN TÁC',
              textColor: Colors.amber,
              onPressed: () async {
                try {
                  await SmartSchedulingService.instance.revertAssignment(resId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✓ Đã hoàn tác phân ca!')),
                    );
                    _loadAnalysis();
                  }
                } catch (err) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Không thể hoàn tác: $err')),
                    );
                  }
                }
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
        _loadAnalysis();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Cảnh báo tài chính'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _applyAllSafeSuggestions() async {
    if (_analysisResult == null) return;
    final candidates = [
      ..._analysisResult!.conflictedStudents,
      ..._analysisResult!.suggestedChanges,
    ];

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có gợi ý nào cần áp dụng hàng loạt.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Xác nhận áp dụng hàng loạt',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Hệ thống sẽ xếp ca cho ${candidates.length} học sinh có phương án an toàn nhất trong tuần này ($_weekStartStr đến $_weekEndStr). Bạn có chắc chắn?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ÁP DỤNG'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      int appliedCount = 0;
      int skippedCount = 0;
      int failedCount = 0;

      for (var item in candidates) {
        if (item.topSuggestion != null && item.topSuggestion!.isRecommended) {
          try {
            final resId = await SmartSchedulingService.instance
                .confirmAndApplySuggestion(
                  suggestion: item.topSuggestion!,
                  effectiveFrom: _weekStartStr,
                  effectiveTo: _weekEndStr,
                  source: AssignmentSource.smartSuggestionAccepted,
                  priority: 2,
                );
            if (resId > 0) {
              appliedCount++;
            } else {
              skippedCount++;
            }
          } catch (_) {
            failedCount++;
          }
        } else {
          skippedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Kết quả xếp ca hàng loạt:\n- Đã áp dụng: $appliedCount HS\n- Bỏ qua: $skippedCount HS\n- Lỗi (Tháng đã khóa): $failedCount HS',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
        _loadAnalysis();
      }
    }
  }

  Widget _buildStudentAnalysisCard(
    StudentWeeklyAnalysis item, {
    required bool isException,
  }) {
    final top = item.topSuggestion;
    final curr = item.currentAssignment;
    final bool hasCurrentAssignment = curr != null;
    final bool isUnresolved =
        top == null || top.conflictLevel == ConflictLevel.hardConflict;
    final bool isNeedsAssignment = !hasCurrentAssignment && !isUnresolved;
    final String currentScheduleText = curr != null
        ? 'Ca hiện tại: ${curr.dayName} (${curr.startTime}–${curr.endTime})'
        : 'Ca hiện tại: Chưa gán ca';

    final Color badgeBg;
    final Color badgeFg;
    final String badgeText;

    if (isUnresolved) {
      badgeBg = Colors.red.shade100;
      badgeFg = Colors.red.shade800;
      badgeText = '✕ Chưa có phương án an toàn';
    } else if (isNeedsAssignment) {
      badgeBg = Colors.amber.shade100;
      badgeFg = Colors.amber.shade900;
      badgeText = '○ Chưa có ca hiện tại';
    } else if (item.hasConflict) {
      badgeBg = Colors.red.shade100;
      badgeFg = Colors.red.shade800;
      badgeText = item.conflictSummary;
    } else {
      badgeBg = Colors.green.shade100;
      badgeFg = Colors.green.shade800;
      badgeText = item.conflictSummary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUnresolved
              ? Colors.red.shade300
              : isNeedsAssignment
              ? Colors.amber.shade300
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: badgeFg,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              currentScheduleText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: hasCurrentAssignment
                    ? FontWeight.normal
                    : FontWeight.w600,
                color: hasCurrentAssignment
                    ? Colors.grey[800]
                    : Colors.amber.shade800,
              ),
            ),
            if (top != null && top != curr) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    isNeedsAssignment ? 'Gợi ý gán ca: ' : 'Gợi ý chuyển: ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.teal,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${top.dayName} (${top.startTime}–${top.endTime}) • ${top.score.toInt()}đ (${top.fitLabel})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.teal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (top.reasons.isNotEmpty) ...[
                const SizedBox(height: 4),
                ...top.reasons
                    .take(3)
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          r,
                          style: TextStyle(
                            fontSize: 12,
                            color: r.startsWith('✕')
                                ? Colors.red.shade700
                                : r.startsWith('•')
                                ? Colors.orange.shade800
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
              ],
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentSchedulePage(
                          studentId: item.studentId,
                          studentName: item.studentName,
                        ),
                      ),
                    ).then((_) => _loadAnalysis());
                  },
                  child: const Text('CHI TIẾT LỊCH'),
                ),
                if (!isUnresolved &&
                    top != curr &&
                    top.isRecommended) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    onPressed: () => _applySingleSuggestion(item, top),
                    child: Text(
                      isNeedsAssignment ? 'GÁN CA GỢI Ý' : 'ÁP DỤNG GỢI Ý',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exceptions = [
      ...?_analysisResult?.conflictedStudents,
      ...?_analysisResult?.suggestedChanges,
      ...?_analysisResult?.unresolvedStudents,
    ];

    final normal = _analysisResult?.unchangedStudents ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Xếp lịch tuần: ${widget.className}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'CẦN XỬ LÝ (${exceptions.length})'),
            Tab(text: 'MỌI VIỆC ỔN (${normal.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Week Selector & Action Header
                Card(
                  margin: const EdgeInsets.all(12),
                  color: Colors.indigo[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: () => _changeWeek(-7),
                            ),
                            Text(
                              'TUẦN ${_analysisResult?.weekRange ?? ''}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.indigo,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: () => _changeWeek(7),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              'Tổng: ${_analysisResult?.totalStudents ?? 0} HS',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '✓ ${normal.length} Ổn định',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '⚠ ${exceptions.length} Ngoại lệ',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (exceptions.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('ÁP DỤNG CÁC GỢI Ý AN TOÀN'),
                              onPressed: _applyAllSafeSuggestions,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Exceptions Tab
                      exceptions.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 64,
                                    color: Colors.green,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'MỌI VIỆC ỔN!\nKhông có học sinh nào bị trùng lịch trong tuần này.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: exceptions.length,
                              itemBuilder: (ctx, i) =>
                                  _buildStudentAnalysisCard(
                                    exceptions[i],
                                    isException: true,
                                  ),
                            ),

                      // Normal Tab
                      normal.isEmpty
                          ? const Center(child: Text('Chưa có danh sách'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              itemCount: normal.length,
                              itemBuilder: (ctx, i) =>
                                  _buildStudentAnalysisCard(
                                    normal[i],
                                    isException: false,
                                  ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
