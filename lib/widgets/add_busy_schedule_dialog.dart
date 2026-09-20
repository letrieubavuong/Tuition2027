import 'package:flutter/material.dart';
import '../models/student_busy_schedule.dart';
import '../services/student_busy_schedule_service.dart';

class AddBusyScheduleDialog extends StatefulWidget {
  final int studentId;
  final StudentBusySchedule? initialSchedule;
  final String? initialWeekStart;

  const AddBusyScheduleDialog({
    super.key,
    required this.studentId,
    this.initialSchedule,
    this.initialWeekStart,
  });

  @override
  State<AddBusyScheduleDialog> createState() => _AddBusyScheduleDialogState();
}

class _AddBusyScheduleDialogState extends State<AddBusyScheduleDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late BusyType _type;
  late int _dayOfWeek;
  late String _startTime;
  late String _endTime;
  late RecurrenceType _recurrenceType;
  late String _effectiveFrom;
  late String _effectiveTo;
  String? _note;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final defaultStart =
        widget.initialWeekStart ?? now.toIso8601String().substring(0, 10);
    final defaultEnd = widget.initialWeekStart != null
        ? DateTime.parse(
            widget.initialWeekStart!,
          ).add(const Duration(days: 6)).toIso8601String().substring(0, 10)
        : '9999-12-31';

    if (widget.initialSchedule != null) {
      final s = widget.initialSchedule!;
      _title = s.title;
      _type = s.type;
      _dayOfWeek = s.dayOfWeek ?? 1;
      _startTime = s.startTime;
      _endTime = s.endTime;
      _recurrenceType = s.recurrenceType;
      _effectiveFrom = s.effectiveFrom;
      _effectiveTo = s.effectiveTo;
      _note = s.note;
    } else {
      _title = 'Lịch học trường';
      _type = BusyType.school;
      _dayOfWeek = 1;
      _startTime = '13:00';
      _endTime = '17:00';
      _recurrenceType = RecurrenceType.weekly;
      _effectiveFrom = defaultStart;
      _effectiveTo = defaultEnd;
    }
  }

  void _applySchoolPreset(String preset) {
    setState(() {
      if (preset == 'Sang') {
        _startTime = '07:00';
        _endTime = '11:30';
      } else if (preset == 'Chieu') {
        _startTime = '13:00';
        _endTime = '17:00';
      } else if (preset == 'CaNgay') {
        _startTime = '07:00';
        _endTime = '17:00';
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final schedule = StudentBusySchedule(
      id: widget.initialSchedule?.id,
      studentId: widget.studentId,
      type: _type,
      title: _title,
      dayOfWeek: _dayOfWeek,
      startTime: _startTime,
      endTime: _endTime,
      effectiveFrom: _effectiveFrom,
      effectiveTo: _effectiveTo,
      recurrenceType: _recurrenceType,
      note: _note,
    );

    if (widget.initialSchedule == null) {
      await StudentBusyScheduleService.instance.insertBusySchedule(schedule);
    } else {
      await StudentBusyScheduleService.instance.updateBusySchedule(schedule);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialSchedule == null ? 'Thêm lịch bận HS' : 'Sửa lịch bận HS',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<BusyType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Loại lịch bận'),
                items: BusyType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.displayName));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _type = val;
                      if (val == BusyType.school &&
                          _title == 'Lịch học trường') {
                        _title = 'Lịch học trường';
                      } else if (val == BusyType.extraMath) {
                        _title = 'Học thêm Toán';
                      } else if (val == BusyType.extraEnglish) {
                        _title = 'Học thêm Anh';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(
                  labelText: 'Tên/Mô tả (Ví dụ: Trường chính khóa)',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Nhập tên' : null,
                onSaved: (v) => _title = v!.trim(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _dayOfWeek,
                decoration: const InputDecoration(labelText: 'Thứ trong tuần'),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Thứ Hai (T2)')),
                  DropdownMenuItem(value: 2, child: Text('Thứ Ba (T3)')),
                  DropdownMenuItem(value: 3, child: Text('Thứ Tư (T4)')),
                  DropdownMenuItem(value: 4, child: Text('Thứ Năm (T5)')),
                  DropdownMenuItem(value: 5, child: Text('Thứ Sáu (T6)')),
                  DropdownMenuItem(value: 6, child: Text('Thứ Bảy (T7)')),
                  DropdownMenuItem(value: 7, child: Text('Chủ Nhật (CN)')),
                ],
                onChanged: (val) => setState(() => _dayOfWeek = val!),
              ),
              const SizedBox(height: 12),
              if (_type == BusyType.school) ...[
                const Text(
                  'Chọn nhanh giờ trường:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Sáng 7:00-11:30'),
                      onPressed: () => _applySchoolPreset('Sang'),
                    ),
                    ActionChip(
                      label: const Text('Chiều 13:00-17:00'),
                      onPressed: () => _applySchoolPreset('Chieu'),
                    ),
                    ActionChip(
                      label: const Text('Cả ngày 7:00-17:00'),
                      onPressed: () => _applySchoolPreset('CaNgay'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _startTime,
                      decoration: const InputDecoration(
                        labelText: 'Bắt đầu (HH:mm)',
                      ),
                      onSaved: (v) => _startTime = v ?? '07:00',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _endTime,
                      decoration: const InputDecoration(
                        labelText: 'Kết thúc (HH:mm)',
                      ),
                      onSaved: (v) => _endTime = v ?? '17:00',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceType>(
                value: _recurrenceType,
                decoration: const InputDecoration(labelText: 'Tần suất lặp'),
                items: RecurrenceType.values.map((r) {
                  return DropdownMenuItem(value: r, child: Text(r.displayName));
                }).toList(),
                onChanged: (val) => setState(() => _recurrenceType = val!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _effectiveFrom,
                decoration: const InputDecoration(
                  labelText: 'Hiệu lực từ (YYYY-MM-DD)',
                ),
                onSaved: (v) => _effectiveFrom = v ?? '',
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _effectiveTo,
                decoration: const InputDecoration(
                  labelText: 'Hiệu lực đến (YYYY-MM-DD)',
                ),
                onSaved: (v) => _effectiveTo = v ?? '9999-12-31',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Lưu')),
      ],
    );
  }
}
