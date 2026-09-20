// File: lib/widgets/xuat_bao_cao_pdf_dialog.dart

import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lop.dart';
import '../models/report_models.dart';
import '../services/lop_service.dart';
import '../services/pdf_export_service.dart';
import '../services/report_service.dart';

class XuatBaoCaoPdfDialog extends StatefulWidget {
  final Lop? initialLop;
  final Set<ReportSection>? initialSections;

  const XuatBaoCaoPdfDialog({super.key, this.initialLop, this.initialSections});

  @override
  State<XuatBaoCaoPdfDialog> createState() => _XuatBaoCaoPdfDialogState();
}

class _XuatBaoCaoPdfDialogState extends State<XuatBaoCaoPdfDialog> {
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  Color get accentColor => Theme.of(context).primaryColor;

  final LopService _lopService = LopService();
  final ReportService _reportService = ReportService();
  final PdfExportService _pdfService = PdfExportService();

  late Future<List<Lop>> _lopListFuture;

  // Options
  ReportPeriodType _periodType = ReportPeriodType.month;
  late int _selectedYear;
  late int _selectedMonth;
  late DateTime _startDate;
  late DateTime _endDate;

  ReportScope _scope = ReportScope.allClasses;
  Lop? _selectedLop;

  late Set<ReportSection> _selectedSections;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _lopListFuture = _lopService.docTatCaLop();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;

    if (widget.initialLop != null) {
      _scope = ReportScope.singleClass;
      _selectedLop = widget.initialLop;
    }

    _selectedSections =
        widget.initialSections ??
        {
          ReportSection.classSummary,
          ReportSection.attendance,
          ReportSection.tuition,
          ReportSection.evaluation,
        };
  }

  void _applyPresetThisMonth() {
    final now = DateTime.now();
    setState(() {
      _periodType = ReportPeriodType.month;
      _selectedYear = now.year;
      _selectedMonth = now.month;
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
    });
  }

  void _applyPresetLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    setState(() {
      _periodType = ReportPeriodType.month;
      _selectedYear = lastMonth.year;
      _selectedMonth = lastMonth.month;
      _startDate = lastMonth;
      _endDate = lastMonthEnd;
    });
  }

  void _applyPreset7Days() {
    final now = DateTime.now();
    setState(() {
      _periodType = ReportPeriodType.customRange;
      _endDate = now;
      _startDate = now.subtract(const Duration(days: 6));
    });
  }

  void _applyPreset30Days() {
    final now = DateTime.now();
    setState(() {
      _periodType = ReportPeriodType.customRange;
      _endDate = now;
      _startDate = now.subtract(const Duration(days: 29));
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _handleGenerateReport(PdfAction action) async {
    if (_selectedSections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 mục báo cáo.')),
      );
      return;
    }

    if (_scope == ReportScope.singleClass && _selectedLop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn một lớp cụ thể.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final monthStr =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      final request = ReportRequest(
        periodType: _periodType,
        monthStr: monthStr,
        startDate: _startDate,
        endDate: _endDate,
        scope: _scope,
        classId: _scope == ReportScope.singleClass ? _selectedLop?.id : null,
        sections: _selectedSections,
      );

      final reportData = await _reportService.generateFacilityReport(request);
      await _pdfService.generateAndExportUnifiedPdf(reportData, action: action);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e, stackTrace) {
      dev.log(
        'Lỗi khi tạo/xuất báo cáo PDF: $e',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: cardColor,
            title: const Text(
              'Lỗi',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Không thể tạo báo cáo PDF. Vui lòng thử lại hoặc kiểm tra dữ liệu.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: accentColor),
          const SizedBox(width: 8),
          const Text(
            'XUẤT BÁO CÁO PDF',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Presets
            const Text(
              'Chọn nhanh khoảng thời gian:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text(
                    'Tháng này',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected:
                      _periodType == ReportPeriodType.month &&
                      _selectedMonth == DateTime.now().month &&
                      _selectedYear == DateTime.now().year,
                  onSelected: (_) => _applyPresetThisMonth(),
                ),
                ChoiceChip(
                  label: const Text(
                    'Tháng trước',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: false,
                  onSelected: (_) => _applyPresetLastMonth(),
                ),
                ChoiceChip(
                  label: const Text(
                    '7 ngày vừa qua',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: false,
                  onSelected: (_) => _applyPreset7Days(),
                ),
                ChoiceChip(
                  label: const Text(
                    '30 ngày vừa qua',
                    style: TextStyle(fontSize: 11),
                  ),
                  selected: false,
                  onSelected: (_) => _applyPreset30Days(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Period Selection Type
            Row(
              children: [
                Expanded(
                  child: RadioListTile<ReportPeriodType>(
                    title: const Text(
                      'Theo tháng',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: ReportPeriodType.month,
                    groupValue: _periodType,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) setState(() => _periodType = val);
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<ReportPeriodType>(
                    title: const Text(
                      'Từ ngày -> đến ngày',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: ReportPeriodType.customRange,
                    groupValue: _periodType,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) setState(() => _periodType = val);
                    },
                  ),
                ),
              ],
            ),

            if (_periodType == ReportPeriodType.month) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedMonth,
                      items: List.generate(12, (index) => index + 1).map((m) {
                        return DropdownMenuItem<int>(
                          value: m,
                          child: Text('Tháng $m'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedMonth = val);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tháng',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedYear,
                      items:
                          List.generate(
                            11,
                            (index) => DateTime.now().year - 5 + index,
                          ).map((y) {
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text('$y'),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedYear = val);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Năm',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Từ ngày',
                          isDense: true,
                        ),
                        child: Text(dateFormat.format(_startDate)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickDate(isStart: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Đến ngày',
                          isDense: true,
                        ),
                        child: Text(dateFormat.format(_endDate)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),

            // Scope selection
            const Text(
              'Phạm vi báo cáo:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<ReportScope>(
                    title: const Text(
                      'Tất cả các lớp',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: ReportScope.allClasses,
                    groupValue: _scope,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) setState(() => _scope = val);
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<ReportScope>(
                    title: const Text(
                      'Một lớp cụ thể',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: ReportScope.singleClass,
                    groupValue: _scope,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      if (val != null) setState(() => _scope = val);
                    },
                  ),
                ),
              ],
            ),

            if (_scope == ReportScope.singleClass) ...[
              FutureBuilder<List<Lop>>(
                future: _lopListFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final lops = snapshot.data!;
                  if (_selectedLop == null && lops.isNotEmpty) {
                    _selectedLop = lops.first;
                  }
                  return DropdownButtonFormField<Lop>(
                    initialValue: _selectedLop,
                    items: lops.map((l) {
                      return DropdownMenuItem<Lop>(
                        value: l,
                        child: Text('Lớp ${l.ten} (Khối ${l.khoi})'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedLop = val),
                    decoration: const InputDecoration(
                      labelText: 'Chọn lớp',
                      isDense: true,
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),

            // Sections Selection
            const Text(
              'Nội dung báo cáo:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            CheckboxListTile(
              title: const Text(
                'Tổng quan trung tâm / lớp',
                style: TextStyle(fontSize: 12),
              ),
              value: _selectedSections.contains(ReportSection.classSummary),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSections.add(ReportSection.classSummary);
                  } else {
                    _selectedSections.remove(ReportSection.classSummary);
                  }
                });
              },
            ),
            CheckboxListTile(
              title: const Text(
                'Báo cáo điểm danh',
                style: TextStyle(fontSize: 12),
              ),
              value: _selectedSections.contains(ReportSection.attendance),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSections.add(ReportSection.attendance);
                  } else {
                    _selectedSections.remove(ReportSection.attendance);
                  }
                });
              },
            ),
            CheckboxListTile(
              title: const Text(
                'Báo cáo học phí',
                style: TextStyle(fontSize: 12),
              ),
              value: _selectedSections.contains(ReportSection.tuition),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSections.add(ReportSection.tuition);
                  } else {
                    _selectedSections.remove(ReportSection.tuition);
                  }
                });
              },
            ),
            CheckboxListTile(
              title: const Text(
                'Báo cáo đánh giá học tập',
                style: TextStyle(fontSize: 12),
              ),
              value: _selectedSections.contains(ReportSection.evaluation),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedSections.add(ReportSection.evaluation);
                  } else {
                    _selectedSections.remove(ReportSection.evaluation);
                  }
                });
              },
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      actions: [
        if (_isExporting)
          const Center(child: CircularProgressIndicator())
        else ...[
          OutlinedButton.icon(
            onPressed: () => _handleGenerateReport(PdfAction.preview),
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('XEM TRƯỚC', style: TextStyle(fontSize: 11)),
          ),
          ElevatedButton.icon(
            onPressed: () => _handleGenerateReport(PdfAction.print),
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('XUẤT PDF', style: TextStyle(fontSize: 11)),
          ),
          IconButton(
            tooltip: 'Chia sẻ',
            icon: Icon(Icons.share, color: accentColor),
            onPressed: () => _handleGenerateReport(PdfAction.share),
          ),
        ],
      ],
    );
  }
}
