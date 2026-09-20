import 'package:flutter/material.dart';
import '../models/schedule_suggestion.dart';
import '../models/student_busy_schedule.dart';
import '../models/student_schedule_assignment.dart';
import '../services/smart_scheduling_service.dart';
import '../services/student_busy_schedule_service.dart';
import '../widgets/add_busy_schedule_dialog.dart';

class StudentSchedulePage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentSchedulePage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentSchedulePage> createState() => _StudentSchedulePageState();
}

class _StudentSchedulePageState extends State<StudentSchedulePage> {
  late DateTime _weekStart;
  bool _isLoading = true;
  List<StudentBusySchedule> _busySchedules = [];
  List<ScheduleSuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    // Default to current Monday
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _loadData();
  }

  String get _weekStartStr => _weekStart.toIso8601String().substring(0, 10);
  String get _weekEndStr => _weekStart
      .add(const Duration(days: 6))
      .toIso8601String()
      .substring(0, 10);

  String get _weekLabel {
    final end = _weekStart.add(const Duration(days: 6));
    return 'TUẦN ${formatDateShort(_weekStart)} – ${formatDateShort(end)}';
  }

  String formatDateShort(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final busy = await StudentBusyScheduleService.instance
        .getBusySchedulesForStudentInRange(
          widget.studentId,
          _weekStartStr,
          _weekEndStr,
        );

    final suggestions = await SmartSchedulingService.instance
        .getSuggestionsForStudent(
          studentId: widget.studentId,
          weekStartDate: _weekStartStr,
        );

    setState(() {
      _busySchedules = busy;
      _suggestions = suggestions;
      _isLoading = false;
    });
  }

  void _changeWeek(int offsetDays) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: offsetDays));
    });
    _loadData();
  }

  Future<void> _openAddBusyDialog([StudentBusySchedule? existing]) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AddBusyScheduleDialog(
        studentId: widget.studentId,
        initialSchedule: existing,
        initialWeekStart: _weekStartStr,
      ),
    );
    if (res == true) _loadData();
  }

  Future<void> _copyWeek() async {
    final sourceStart = _weekStart
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);
    final count = await StudentBusyScheduleService.instance.copyWeekSchedules(
      widget.studentId,
      sourceStart,
      _weekStartStr,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã sao chép $count lịch bận từ tuần trước!')),
      );
      _loadData();
    }
  }

  Future<void> _applySuggestion(ScheduleSuggestion suggestion) async {
    String applyScope = 'TEMPORARY'; // TEMPORARY or REGULAR

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Xác nhận áp dụng xếp ca',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xác nhận gán ca học: ${suggestion.dayName} (${suggestion.startTime}–${suggestion.endTime}) cho ${widget.studentName}?',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Phạm vi áp dụng:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RadioListTile<String>(
                    title: const Text('Chỉ tuần này (Tạm thời)'),
                    subtitle: Text(
                      'Áp dụng từ $_weekStartStr đến $_weekEndStr',
                    ),
                    value: 'TEMPORARY',
                    groupValue: applyScope,
                    onChanged: (val) => setDialogState(() => applyScope = val!),
                  ),
                  RadioListTile<String>(
                    title: const Text('Lâu dài từ tuần này'),
                    subtitle: Text('Áp dụng từ $_weekStartStr về sau'),
                    value: 'REGULAR',
                    groupValue: applyScope,
                    onChanged: (val) => setDialogState(() => applyScope = val!),
                  ),
                ],
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
                  child: const Text('XÁC NHẬN ÁP DỤNG'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      try {
        final effectiveTo = applyScope == 'TEMPORARY'
            ? _weekEndStr
            : '9999-12-31';
        final source = applyScope == 'TEMPORARY'
            ? AssignmentSource.temporaryOverride
            : AssignmentSource.smartSuggestionAccepted;

        final success = await SmartSchedulingService.instance
            .confirmAndApplySuggestion(
              suggestion: suggestion,
              effectiveFrom: _weekStartStr,
              effectiveTo: effectiveTo,
              source: source,
              priority: applyScope == 'TEMPORARY' ? 2 : 1,
            );

        if (success > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✓ Đã áp dụng ca học ${suggestion.dayName} (${suggestion.startTime})!',
              ),
              backgroundColor: Colors.green[700],
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text(
                'Bảo vệ tài chính & Học phí',
                style: TextStyle(color: Colors.red),
              ),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lịch & Xếp ca: ${widget.studentName}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Week Selector Header
                  Card(
                    color: Colors.indigo[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios),
                            onPressed: () => _changeWeek(-7),
                          ),
                          Column(
                            children: [
                              Text(
                                _weekLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_busySchedules.length} lịch bận đã ghi nhận',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: () => _changeWeek(7),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Section 1: Student Busy Schedule
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'LỊCH BẬN HỌC SINH',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            tooltip: 'Sao chép tuần trước',
                            onPressed: _copyWeek,
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Thêm lịch bận'),
                            onPressed: () => _openAddBusyDialog(),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (_busySchedules.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Chưa có lịch bận nào được thêm cho tuần này.',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _busySchedules.length,
                      itemBuilder: (ctx, i) {
                        final b = _busySchedules[i];
                        final dayStr = [
                          'T2',
                          'T3',
                          'T4',
                          'T5',
                          'T6',
                          'T7',
                          'CN',
                        ][(b.dayOfWeek ?? 1) - 1];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[100],
                              child: Text(
                                dayStr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            title: Text(
                              '${b.title} (${b.startTime}–${b.endTime})',
                            ),
                            subtitle: Text(
                              '${b.type.displayName} • ${b.recurrenceType.displayName}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _openAddBusyDialog(b),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  // Section 2: Physics Session Suggestions
                  const Text(
                    'GỢI Ý XẾP CA VẬT LÝ',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Thuật toán chấm điểm theo lịch bận & quy tắc tối ưu (Chưa tự động đổi)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),

                  if (_suggestions.isEmpty)
                    const Center(
                      child: Text('Không tìm thấy ca Vật lý phù hợp'),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestions.length,
                      itemBuilder: (ctx, idx) {
                        final s = _suggestions[idx];
                        Color badgeColor = Colors.green;
                        if (s.fitLabel == 'Không phù hợp') {
                          badgeColor = Colors.red;
                        } else if (s.fitLabel == 'Cần cân nhắc') {
                          badgeColor = Colors.orange;
                        } else if (s.fitLabel == 'Phù hợp') {
                          badgeColor = Colors.blue;
                        }

                        return Card(
                          elevation: s.isCurrentAssignment ? 3 : 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: s.isCurrentAssignment
                                ? const BorderSide(
                                    color: Colors.indigo,
                                    width: 2,
                                  )
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo[100],
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            '#${idx + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${s.isCurrentAssignment ? '★ ' : ''}${s.dayName} • ${s.startTime}–${s.endTime}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${s.score.toInt()} điểm • ${s.fitLabel}',
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Lớp: ${s.className} • Sĩ số: ${s.currentCapacity}/${s.maxCapacity}',
                                ),
                                const SizedBox(height: 8),
                                ...s.reasons.map(
                                  (r) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      r,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: r.startsWith('✕')
                                            ? Colors.red[700]
                                            : r.startsWith('⚠')
                                            ? Colors.orange[800]
                                            : Colors.green[800],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: s.isCurrentAssignment
                                          ? Colors.grey
                                          : Colors.teal,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: s.isCurrentAssignment
                                        ? null
                                        : () => _applySuggestion(s),
                                    child: Text(
                                      s.isCurrentAssignment
                                          ? 'CA HIỆN TẠI'
                                          : 'ÁP DỤNG CA NÀY',
                                    ),
                                  ),
                                ),
                              ],
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
}
