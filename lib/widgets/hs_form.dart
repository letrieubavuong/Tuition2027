// File: lib/widgets/hs_form.dart

import 'package:flutter/material.dart';
import '../models/hs.dart';
import '../models/student_busy_schedule.dart';
import '../models/truong.dart';
import '../services/hoc_sinh_service.dart';
import '../services/student_busy_schedule_service.dart';
import '../services/truong_service.dart';
import '../utils/toast_helper.dart';

class HocSinhFormDialog extends StatefulWidget {
  final HS? hocSinh;
  final List<Truong> danhSachTruong;
  final HocSinhService hsService;

  const HocSinhFormDialog({
    super.key,
    this.hocSinh,
    required this.danhSachTruong,
    required this.hsService,
  });

  @override
  State<HocSinhFormDialog> createState() => _HocSinhFormDialogState();
}

class _HocSinhFormDialogState extends State<HocSinhFormDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tenController;
  late final TextEditingController _sdtPhuHuynhController;
  late final TextEditingController _sdtHocSinhController;
  late final TextEditingController _tenPhuHuynhController;
  late final TextEditingController _diaChiController;
  late final TextEditingController _ghiChuController;
  late final TextEditingController _facebookController;
  late final TextEditingController _customMienGiamController;

  String? _selectedTruong;
  int _mienGiam = 0;
  bool _isCustomMienGiam = false;
  List<StudentBusySchedule> _busySchedules = [];
  bool _isSubmitting = false;

  final TruongService _truongService = TruongService();
  late Future<List<Truong>> _truongFuture;
  bool _extraInfoExpanded = false;

  @override
  void initState() {
    super.initState();
    final hs = widget.hocSinh;
    _tenController = TextEditingController(text: hs?.ten);
    _sdtPhuHuynhController = TextEditingController(
      text: hs?.sdtPhuHuynh ?? hs?.sdt,
    );
    _sdtHocSinhController = TextEditingController(text: hs?.sdtHocSinh);
    _tenPhuHuynhController = TextEditingController(text: hs?.tenPhuHuynh);
    _diaChiController = TextEditingController(text: hs?.diaChi);
    _ghiChuController = TextEditingController(text: hs?.ghiChu);
    _facebookController = TextEditingController(text: hs?.facebook);
    
    _mienGiam = hs?.mienGiam ?? 0;
    final standardPercentages = [0, 10, 20, 25, 30, 50, 100];
    if (!standardPercentages.contains(_mienGiam)) {
      _isCustomMienGiam = true;
      _customMienGiamController = TextEditingController(text: _mienGiam.toString());
    } else {
      _customMienGiamController = TextEditingController();
    }

    _selectedTruong = hs?.truongDangHoc;
    _truongFuture = _truongService.docTatCaTruong();

    // Auto-expand extra info if editing a student with existing extra fields
    if (hs != null) {
      if ((hs.tenPhuHuynh != null && hs.tenPhuHuynh!.isNotEmpty) ||
          (hs.sdtHocSinh != null && hs.sdtHocSinh!.isNotEmpty) ||
          (hs.diaChi != null && hs.diaChi!.isNotEmpty) ||
          (hs.facebook != null && hs.facebook!.isNotEmpty) ||
          (hs.ghiChu != null && hs.ghiChu!.isNotEmpty)) {
        _extraInfoExpanded = true;
      }
      _loadExistingBusySchedules(hs.id!);
    }
  }

  Future<void> _loadExistingBusySchedules(int studentId) async {
    try {
      final list = await StudentBusyScheduleService.instance
          .getBusySchedulesForStudent(studentId);
      if (mounted) {
        setState(() {
          _busySchedules = list;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tenController.dispose();
    _sdtPhuHuynhController.dispose();
    _sdtHocSinhController.dispose();
    _tenPhuHuynhController.dispose();
    _diaChiController.dispose();
    _ghiChuController.dispose();
    _facebookController.dispose();
    _customMienGiamController.dispose();
    super.dispose();
  }

  void _handleSave() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final ten = _tenController.text.trim();
    final sdtPhuHuynh = _sdtPhuHuynhController.text.trim();
    final sdtHocSinh = _sdtHocSinhController.text.trim();
    final tenPhuHuynh = _tenPhuHuynhController.text.trim();
    final diaChi = _diaChiController.text.trim();
    final ghiChu = _ghiChuController.text.trim();
    final facebook = _facebookController.text.trim();

    int finalMienGiam = _mienGiam;
    if (_isCustomMienGiam) {
      final val = int.tryParse(_customMienGiamController.text.trim());
      if (val != null && val >= 0 && val <= 100) {
        finalMienGiam = val;
      }
    }

    try {
      HS savedHs;
      if (widget.hocSinh != null) {
        final updatedHs = widget.hocSinh!.copyWith();
        updatedHs.id = widget.hocSinh!.id;
        updatedHs.ten = ten;
        updatedHs.sdtPhuHuynh = sdtPhuHuynh.isEmpty ? null : sdtPhuHuynh;
        updatedHs.sdt = sdtPhuHuynh.isEmpty ? null : sdtPhuHuynh;
        updatedHs.sdtHocSinh = sdtHocSinh.isEmpty ? null : sdtHocSinh;
        updatedHs.tenPhuHuynh = tenPhuHuynh.isEmpty ? null : tenPhuHuynh;
        updatedHs.truongDangHoc = _selectedTruong;
        updatedHs.diaChi = diaChi.isEmpty ? null : diaChi;
        updatedHs.ghiChu = ghiChu.isEmpty ? null : ghiChu;
        updatedHs.facebook = facebook.isEmpty ? null : facebook;
        updatedHs.mienGiam = finalMienGiam;

        await widget.hsService.capNhatHocSinh(updatedHs);
        savedHs = updatedHs;
      } else {
        final hsMoi = HS(
          ten: ten,
          sdtPhuHuynh: sdtPhuHuynh.isEmpty ? null : sdtPhuHuynh,
          sdt: sdtPhuHuynh.isEmpty ? null : sdtPhuHuynh,
          sdtHocSinh: sdtHocSinh.isEmpty ? null : sdtHocSinh,
          tenPhuHuynh: tenPhuHuynh.isEmpty ? null : tenPhuHuynh,
          truongDangHoc: _selectedTruong,
          diaChi: diaChi.isEmpty ? null : diaChi,
          ghiChu: ghiChu.isEmpty ? null : ghiChu,
          facebook: facebook.isEmpty ? null : facebook,
          mienGiam: finalMienGiam,
        );
        savedHs = await widget.hsService.taoHocSinh(hsMoi);
      }

      // Persist structured busy schedules for savedHs.id
      if (savedHs.id != null) {
        final service = StudentBusyScheduleService.instance;
        final existing = await service.getBusySchedulesForStudent(savedHs.id!);
        for (var oldItem in existing) {
          if (oldItem.id != null) {
            await service.deleteBusySchedule(oldItem.id!);
          }
        }
        for (var busy in _busySchedules) {
          final newBusy = busy.copyWith(studentId: savedHs.id!);
          await service.insertBusySchedule(newBusy);
        }
      }

      if (mounted) {
        ToastHelper.showSuccess(
          context,
          widget.hocSinh != null
              ? '✓ Đã cập nhật học sinh'
              : '✓ Đã thêm học sinh',
        );
        Navigator.of(context).pop(savedHs);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi lưu học sinh: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatDayLabel(int day) {
    switch (day) {
      case 1:
        return 'T2';
      case 2:
        return 'T3';
      case 3:
        return 'T4';
      case 4:
        return 'T5';
      case 5:
        return 'T6';
      case 6:
        return 'T7';
      case 7:
        return 'CN';
      default:
        return 'T$day';
    }
  }

  void _openWeeklyBusyPickerSheet() async {
    final updatedBusy = await showModalBottomSheet<List<StudentBusySchedule>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _WeeklyBusyPickerModal(
        studentId: widget.hocSinh?.id ?? 0,
        initialBusySchedules: _busySchedules,
      ),
    );

    if (updatedBusy != null && mounted) {
      setState(() {
        _busySchedules = updatedBusy;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.hocSinh != null;

    return Dialog(
      backgroundColor: cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'SỬA HỌC SINH' : 'THÊM HỌC SINH MỚI',
                      style: TextStyle(
                        color: lightText,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: secondaryText, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // --- 1. THÔNG TIN CHÍNH ---
                Text(
                  'THÔNG TIN CHÍNH',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                // Họ và tên (Bắt buộc)
                TextFormField(
                  controller: _tenController,
                  autofocus: !isEditing,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: lightText),
                  decoration: InputDecoration(
                    labelText: 'Họ và tên *',
                    labelStyle: TextStyle(color: secondaryText),
                    prefixIcon: Icon(Icons.person, color: accentColor, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Vui lòng nhập họ và tên học sinh';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // SĐT phụ huynh (Không bắt buộc)
                TextFormField(
                  controller: _sdtPhuHuynhController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(color: lightText),
                  decoration: InputDecoration(
                    labelText: 'SĐT Phụ huynh',
                    hintText: 'Có thể bổ sung sau',
                    hintStyle: TextStyle(color: secondaryText.withValues(alpha: 0.5), fontSize: 13),
                    labelStyle: TextStyle(color: secondaryText),
                    prefixIcon: Icon(Icons.phone, color: secondaryText, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),

                // Trường đang học
                _buildTruongDropdown(),
                const SizedBox(height: 12),

                // % Miễn giảm học phí
                Text(
                  'Miễn giảm học phí (%)',
                  style: TextStyle(color: secondaryText, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...[0, 10, 20, 25, 30, 50, 100].map((pct) {
                        final isSelected = !_isCustomMienGiam && _mienGiam == pct;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('$pct%'),
                            selected: isSelected,
                            selectedColor: accentColor,
                            labelStyle: TextStyle(
                              color: isSelected ? darkBackground : lightText,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _isCustomMienGiam = false;
                                _mienGiam = pct;
                              });
                            },
                          ),
                        );
                      }),
                      ChoiceChip(
                        label: Text(_isCustomMienGiam ? 'Khác ($_mienGiam%)' : 'Khác...'),
                        selected: _isCustomMienGiam,
                        selectedColor: accentColor,
                        labelStyle: TextStyle(
                          color: _isCustomMienGiam ? darkBackground : lightText,
                          fontWeight: _isCustomMienGiam ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _isCustomMienGiam = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                if (_isCustomMienGiam) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _customMienGiamController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: lightText),
                    decoration: InputDecoration(
                      labelText: 'Nhập % miễn giảm khác (0 - 100)',
                      labelStyle: TextStyle(color: secondaryText),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 0 && parsed <= 100) {
                        setState(() => _mienGiam = parsed);
                      }
                    },
                    validator: (v) {
                      if (_isCustomMienGiam) {
                        final parsed = int.tryParse(v ?? '');
                        if (parsed == null || parsed < 0 || parsed > 100) {
                          return 'Vui lòng nhập số từ 0 đến 100';
                        }
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),

                // --- 2. LỊCH CẤN / THỜI GIAN BẬN ---
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade900.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event_busy_rounded, color: Colors.amber.shade400, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'LỊCH CẤN / THỜI GIAN BẬN',
                                style: TextStyle(
                                  color: Colors.amber.shade300,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade800.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_busySchedules.length} khoảng bận',
                              style: TextStyle(color: Colors.amber.shade200, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_busySchedules.isEmpty)
                        Text(
                          'Chưa thiết lập lịch bận.',
                          style: TextStyle(color: secondaryText, fontSize: 13, fontStyle: FontStyle.italic),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _busySchedules.take(4).map((b) {
                            final dayLabel = _formatDayLabel(b.dayOfWeek ?? 1);
                            return Chip(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              backgroundColor: cardColor,
                              side: BorderSide(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                              label: Text(
                                '$dayLabel • ${b.startTime}–${b.endTime}',
                                style: TextStyle(color: lightText, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList()
                            ..addAll(_busySchedules.length > 4
                                ? [
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      backgroundColor: cardColor,
                                      label: Text(
                                        '+${_busySchedules.length - 4} khác',
                                        style: TextStyle(color: Colors.amber.shade300, fontSize: 11),
                                      ),
                                    )
                                  ]
                                : []),
                        ),
                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.amber.shade500),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _openWeeklyBusyPickerSheet,
                          icon: Icon(Icons.edit_calendar_rounded, size: 16, color: Colors.amber.shade400),
                          label: Text(
                            'THIẾT LẬP LỊCH TUẦN',
                            style: TextStyle(color: Colors.amber.shade300, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // --- 3. THÔNG TIN THÊM (COLLAPSIBLE) ---
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: _extraInfoExpanded,
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      '▸ Thông tin thêm (SĐT HS, địa chỉ, ghi chú)',
                      style: TextStyle(color: secondaryText, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    children: [
                      const SizedBox(height: 4),

                      // Tên phụ huynh
                      TextFormField(
                        controller: _tenPhuHuynhController,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: lightText),
                        decoration: InputDecoration(
                          labelText: 'Tên phụ huynh (Bố/Mẹ)',
                          labelStyle: TextStyle(color: secondaryText),
                          prefixIcon: Icon(Icons.person_outline, color: secondaryText, size: 20),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // SĐT Học sinh
                      TextFormField(
                        controller: _sdtHocSinhController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: lightText),
                        decoration: InputDecoration(
                          labelText: 'SĐT Học sinh (nếu có)',
                          labelStyle: TextStyle(color: secondaryText),
                          prefixIcon: Icon(Icons.phone_android, color: secondaryText, size: 20),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Địa chỉ
                      TextFormField(
                        controller: _diaChiController,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: lightText),
                        decoration: InputDecoration(
                          labelText: 'Địa chỉ nhà',
                          labelStyle: TextStyle(color: secondaryText),
                          prefixIcon: Icon(Icons.home_outlined, color: secondaryText, size: 20),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Facebook
                      TextFormField(
                        controller: _facebookController,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: lightText),
                        decoration: InputDecoration(
                          labelText: 'Facebook học sinh / PH',
                          labelStyle: TextStyle(color: secondaryText),
                          prefixIcon: Icon(Icons.facebook, color: secondaryText, size: 20),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Ghi chú
                      TextFormField(
                        controller: _ghiChuController,
                        maxLines: 2,
                        style: TextStyle(color: lightText),
                        decoration: InputDecoration(
                          labelText: 'Ghi chú thêm',
                          labelStyle: TextStyle(color: secondaryText),
                          prefixIcon: Icon(Icons.note_alt_outlined, color: secondaryText, size: 20),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- SAVE BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: darkBackground,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : _handleSave,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isEditing ? 'LƯU CẬP NHẬT' : 'LƯU HỌC SINH',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTruongDropdown() {
    return FutureBuilder<List<Truong>>(
      future: _truongFuture,
      builder: (context, snapshot) {
        final danhSach = snapshot.hasData ? snapshot.data! : widget.danhSachTruong;

        bool valueExists = _selectedTruong == null || danhSach.any((t) => t.ten == _selectedTruong);
        String? safeValue = valueExists ? _selectedTruong : null;

        return DropdownButtonFormField<String>(
          value: safeValue,
          style: TextStyle(color: lightText, fontSize: 14),
          dropdownColor: cardColor,
          decoration: InputDecoration(
            labelText: 'Trường đang học',
            labelStyle: TextStyle(color: secondaryText),
            prefixIcon: Icon(Icons.school, color: secondaryText, size: 20),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('Chưa chọn trường', style: TextStyle(color: secondaryText)),
            ),
            ...danhSach.map((t) {
              return DropdownMenuItem<String>(
                value: t.ten,
                child: Text(t.ten, style: TextStyle(color: lightText)),
              );
            }),
          ],
          onChanged: (val) {
            setState(() => _selectedTruong = val);
          },
        );
      },
    );
  }
}

// =======================================================
// 2. MODAL PICKER THỜI GIAN BẬN THEO TUẦN (WEEKLY BUSY PICKER)
// =======================================================
class _WeeklyBusyPickerModal extends StatefulWidget {
  final int studentId;
  final List<StudentBusySchedule> initialBusySchedules;

  const _WeeklyBusyPickerModal({
    required this.studentId,
    required this.initialBusySchedules,
  });

  @override
  State<_WeeklyBusyPickerModal> createState() => _WeeklyBusyPickerModalState();
}

class _WeeklyBusyPickerModalState extends State<_WeeklyBusyPickerModal> {
  int _selectedDay = 1; // 1 = T2, ..., 7 = CN
  late List<StudentBusySchedule> _schedules;

  static const List<Map<String, String>> _presetSlots = [
    {'start': '07:30', 'end': '09:00'},
    {'start': '09:00', 'end': '10:30'},
    {'start': '14:00', 'end': '15:30'},
    {'start': '15:30', 'end': '17:00'},
    {'start': '17:30', 'end': '19:00'},
    {'start': '19:30', 'end': '21:00'},
  ];

  @override
  void initState() {
    super.initState();
    _schedules = List.from(widget.initialBusySchedules);
  }

  bool _isSlotBusy(int day, String start, String end) {
    return _schedules.any((s) =>
        (s.dayOfWeek == day || s.dayOfWeek == null) &&
        s.startTime.substring(0, 5) == start &&
        s.endTime.substring(0, 5) == end);
  }

  void _togglePresetSlot(int day, String start, String end) {
    setState(() {
      if (_isSlotBusy(day, start, end)) {
        _schedules.removeWhere((s) =>
            (s.dayOfWeek == day || s.dayOfWeek == null) &&
            s.startTime.substring(0, 5) == start &&
            s.endTime.substring(0, 5) == end);
      } else {
        _schedules.add(
          StudentBusySchedule(
            studentId: widget.studentId,
            type: BusyType.personal,
            title: 'Bận $start–$end',
            dayOfWeek: day,
            startTime: '$start:00',
            endTime: '$end:00',
            effectiveFrom: '2000-01-01',
            effectiveTo: '9999-12-31',
          ),
        );
      }
    });
  }

  void _addCustomBusySlot() async {
    TimeOfDay start = const TimeOfDay(hour: 17, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 18, minute: 30);
    String label = 'Lịch bận môn khác';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Thêm khoảng bận tùy chỉnh', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(labelText: 'Tên/Môn cấn (VD: Tiếng Anh)'),
                    onChanged: (v) => label = v,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(context: context, initialTime: start);
                            if (picked != null) setStateDialog(() => start = picked);
                          },
                          child: Text('Bắt đầu: ${start.format(context)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final picked = await showTimePicker(context: context, initialTime: end);
                            if (picked != null) setStateDialog(() => end = picked);
                          },
                          child: Text('Kết thúc: ${end.format(context)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    final startMin = start.hour * 60 + start.minute;
                    final endMin = end.hour * 60 + end.minute;
                    if (endMin <= startMin) {
                      ToastHelper.showError(context, 'Giờ kết thúc phải sau giờ bắt đầu');
                      return;
                    }
                    final startStr = '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:00';
                    final endStr = '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}:00';

                    setState(() {
                      _schedules.add(
                        StudentBusySchedule(
                          studentId: widget.studentId,
                          type: BusyType.other,
                          title: label.isEmpty ? 'Bận $startStr' : label,
                          dayOfWeek: _selectedDay,
                          startTime: startStr,
                          endTime: endStr,
                          effectiveFrom: '2000-01-01',
                          effectiveTo: '9999-12-31',
                        ),
                      );
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _clearDay(int day) {
    setState(() {
      _schedules.removeWhere((s) => s.dayOfWeek == day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('THIẾT LẬP LỊCH BẬN THEO TUẦN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 28), onPressed: () => Navigator.pop(context, _schedules)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Day selector tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (idx) {
              final dayNum = idx + 1;
              final isSelected = _selectedDay == dayNum;
              final busyCount = _schedules.where((s) => s.dayOfWeek == dayNum).length;

              return InkWell(
                onTap: () => setState(() => _selectedDay = dayNum),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? Theme.of(context).primaryColor : Colors.white24),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayNames[idx],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                      if (busyCount > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Khung giờ ngày ${dayNames[_selectedDay - 1]}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton.icon(
                onPressed: () => _clearDay(_selectedDay),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                label: const Text('Xóa ngày này', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ],
          ),

          Expanded(
            child: ListView(
              children: [
                ..._presetSlots.map((slot) {
                  final start = slot['start']!;
                  final end = slot['end']!;
                  final isBusy = _isSlotBusy(_selectedDay, start, end);

                  return Card(
                    color: isBusy ? Colors.red.shade900.withValues(alpha: 0.3) : Colors.green.shade900.withValues(alpha: 0.15),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: isBusy,
                      activeColor: Colors.redAccent,
                      title: Text('$start – $end', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isBusy ? '🔴 BẬN (Không xếp ca)' : '🟢 RẢNH', style: TextStyle(color: isBusy ? Colors.redAccent : Colors.greenAccent, fontSize: 12)),
                      onChanged: (_) => _togglePresetSlot(_selectedDay, start, end),
                    ),
                  );
                }),

                // Custom slots list for this day
                ..._schedules.where((s) => s.dayOfWeek == _selectedDay && !_presetSlots.any((p) => p['start'] == s.startTime.substring(0, 5) && p['end'] == s.endTime.substring(0, 5))).map((s) {
                  return Card(
                    color: Colors.amber.shade900.withValues(alpha: 0.3),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('${s.title}: ${s.startTime.substring(0, 5)} – ${s.endTime.substring(0, 5)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            _schedules.remove(s);
                          });
                        },
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _addCustomBusySlot,
                  icon: const Icon(Icons.add),
                  label: const Text('+ THÊM KHOẢNG BẬN KHÁC (TÙY CHỈNH)'),
                ),
              ],
            ),
          ),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(context, _schedules),
              child: const Text('XÁC NHẬN LỊCH TUẦN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// 3. HÀM HELPER CANONICAL: Dùng để gọi Dialog từ bất kỳ đâu
// =======================================================
Future<HS?> showHocSinhFormDialog({
  required BuildContext context,
  required List<Truong> danhSachTruong,
  required HocSinhService hsService,
  HS? hocSinh,
}) {
  return showDialog<HS?>(
    context: context,
    builder: (context) => HocSinhFormDialog(
      hocSinh: hocSinh,
      danhSachTruong: danhSachTruong,
      hsService: hsService,
    ),
  );
}
