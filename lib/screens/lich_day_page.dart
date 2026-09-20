// File: lib/screens/lich_day_page.dart

import 'package:flutter/material.dart';
import '../models/hs.dart';
import '../models/lich_hoc.dart';
import '../models/lop.dart';
import '../services/hoc_sinh_service.dart';
import '../services/lich_hoc_service.dart';
import '../services/lop_service.dart';
import '../widgets/main_drawer.dart';
import '../main.dart';
import '../screens/diem_danh_page.dart';
import '../services/calendar_sync_service.dart';
import '../utils/toast_helper.dart';

class LichDayPage extends StatefulWidget {
  final GlobalKey<MainScreenState>? mainScreenKey;
  final int? selectedIndex;

  const LichDayPage({super.key, this.mainScreenKey, this.selectedIndex});

  @override
  State<LichDayPage> createState() => _LichDayPageState();
}

class _LichDayPageState extends State<LichDayPage> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  final LichHocService _lichHocService = LichHocService();
  final LopService _lopService = LopService();
  final HocSinhService _hsService = HocSinhService();

  bool _isLoading = true;
  List<LichHocCoTenLop> _allSchedules = [];
  List<Lop> _allClasses = [];

  // 0 = Tất cả các thứ, 2 = Thứ 2, 3 = Thứ 3, ..., 7 = Thứ 7, 1 = Chủ nhật
  int _selectedDay = 0;

  final List<Map<String, dynamic>> _dayOptions = [
    {'val': 0, 'label': 'Tất cả'},
    {'val': 2, 'label': 'Thứ 2'},
    {'val': 3, 'label': 'Thứ 3'},
    {'val': 4, 'label': 'Thứ 4'},
    {'val': 5, 'label': 'Thứ 5'},
    {'val': 6, 'label': 'Thứ 6'},
    {'val': 7, 'label': 'Thứ 7'},
    {'val': 1, 'label': 'Chủ Nhật'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final schedules = await _lichHocService.layTatCaLichHocCoTenLop();
      final classes = await _lopService.docTatCaLop();
      if (mounted) {
        setState(() {
          _allSchedules = schedules;
          _allClasses = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'Lỗi tải lịch dạy: $e');
      }
    }
  }

  String _getThuLabel(int thu) {
    switch (thu) {
      case 2:
        return 'Thứ Hai';
      case 3:
        return 'Thứ Ba';
      case 4:
        return 'Thứ Tư';
      case 5:
        return 'Thứ Năm';
      case 6:
        return 'Thứ Sáu';
      case 7:
        return 'Thứ Bảy';
      case 1:
        return 'Chủ Nhật';
      default:
        return 'Không rõ';
    }
  }

  int _countSchedulesForDay(int dayVal) {
    if (dayVal == 0) return _allSchedules.length;
    return _allSchedules.where((s) => s.lichHoc.thuTrongTuan == dayVal).length;
  }

  String _getBusiestDayText() {
    if (_allSchedules.isEmpty) return 'Chưa có ca dạy';
    final Map<int, int> counts = {};
    for (var item in _allSchedules) {
      final thu = item.lichHoc.thuTrongTuan;
      counts[thu] = (counts[thu] ?? 0) + 1;
    }
    int busiestThu = 2;
    int maxCount = 0;
    counts.forEach((thu, count) {
      if (count > maxCount) {
        maxCount = count;
        busiestThu = thu;
      }
    });
    return '${_getThuLabel(busiestThu)} ($maxCount ca)';
  }

  void _openAddOrEditDialog([LichHocCoTenLop? editTarget]) async {
    if (_allClasses.isEmpty) {
      ToastHelper.showError(
        context,
        'Bạn chưa có lớp học nào! Vui lòng tạo lớp trước.',
      );
      return;
    }

    int selectedLopId = editTarget != null
        ? editTarget.lichHoc.idLop
        : _allClasses.first.id!;
    int selectedThu = editTarget != null ? editTarget.lichHoc.thuTrongTuan : 2;

    TimeOfDay startTime = const TimeOfDay(hour: 17, minute: 30);
    TimeOfDay endTime = const TimeOfDay(hour: 19, minute: 0);

    if (editTarget != null) {
      selectedThu = editTarget.lichHoc.thuTrongTuan;
      final startParts = editTarget.lichHoc.gioBatDau.split(':');
      final endParts = editTarget.lichHoc.gioKetThuc.split(':');
      if (startParts.length >= 2) {
        startTime = TimeOfDay(
          hour: int.tryParse(startParts[0]) ?? 17,
          minute: int.tryParse(startParts[1]) ?? 30,
        );
      }
      if (endParts.length >= 2) {
        endTime = TimeOfDay(
          hour: int.tryParse(endParts[0]) ?? 19,
          minute: int.tryParse(endParts[1]) ?? 0,
        );
      }
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctxStateful, setDialogState) {
          final isVi = Localizations.localeOf(context).languageCode == 'vi';

          Future<void> pickTime(bool isStart) async {
            final picked = await showTimePicker(
              context: ctxStateful,
              initialTime: isStart ? startTime : endTime,
            );
            if (picked != null) {
              setDialogState(() {
                if (isStart) {
                  startTime = picked;
                  final startMins = startTime.hour * 60 + startTime.minute;
                  final endMins = endTime.hour * 60 + endTime.minute;
                  if (endMins <= startMins) {
                    endTime = TimeOfDay(
                      hour: (startTime.hour + 1) % 24,
                      minute: startTime.minute,
                    );
                  }
                } else {
                  endTime = picked;
                }
              });
            }
          }

          String formatTimeOfDay(TimeOfDay tod) {
            final h = tod.hour.toString().padLeft(2, '0');
            final m = tod.minute.toString().padLeft(2, '0');
            return '$h:$m';
          }

          return AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              editTarget == null
                  ? (isVi ? 'Thêm Ca Dạy Mới' : 'Add New Class Schedule')
                  : (isVi ? 'Điều Chỉnh Ca Dạy' : 'Edit Class Schedule'),
              style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVi ? 'Lớp học:' : 'Class:',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: selectedLopId,
                    dropdownColor: cardColor,
                    style: TextStyle(color: lightText, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: darkBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: _allClasses.map((lop) {
                      return DropdownMenuItem<int>(
                        value: lop.id,
                        child: Text('${lop.ten} (Khối ${lop.khoi})'),
                      );
                    }).toList(),
                    onChanged: editTarget != null
                        ? null
                        : (val) {
                            if (val != null) {
                              setDialogState(() => selectedLopId = val);
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isVi ? 'Thứ trong tuần:' : 'Day of week:',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    initialValue: selectedThu,
                    dropdownColor: cardColor,
                    style: TextStyle(color: lightText, fontSize: 14),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: darkBackground,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [2, 3, 4, 5, 6, 7, 1].map((thu) {
                      return DropdownMenuItem<int>(
                        value: thu,
                        child: Text(_getThuLabel(thu)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedThu = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVi ? 'Giờ bắt đầu:' : 'Start time:',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => pickTime(true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: darkBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatTimeOfDay(startTime),
                                      style: TextStyle(
                                        color: lightText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: accentColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVi ? 'Giờ kết thúc:' : 'End time:',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => pickTime(false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: darkBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatTimeOfDay(endTime),
                                      style: TextStyle(
                                        color: lightText,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: accentColor,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctxStateful),
                child: Text(
                  isVi ? 'Hủy' : 'Cancel',
                  style: TextStyle(color: secondaryText),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final String startStr = '${formatTimeOfDay(startTime)}:00';
                  final String endStr = '${formatTimeOfDay(endTime)}:00';

                  final newLich = LichHoc(
                    id: editTarget?.lichHoc.id,
                    idLop: selectedLopId,
                    thuTrongTuan: selectedThu,
                    gioBatDau: startStr,
                    gioKetThuc: endStr,
                  );

                  bool success = false;
                  if (editTarget == null) {
                    final res = await _lichHocService.themLichHoc(newLich);
                    success = res != null;
                  } else {
                    success = await _lichHocService.capNhatLichHoc(newLich);
                  }

                  if (context.mounted) {
                    if (success) {
                      Navigator.pop(ctxStateful);
                      ToastHelper.showSuccess(
                        context,
                        editTarget == null
                            ? 'Đã thêm ca dạy thành công!'
                            : 'Đã cập nhật ca dạy thành công!',
                      );
                      _loadData();
                    } else {
                      ToastHelper.showError(
                        context,
                        'Không thể lưu! Ca dạy bị trùng hoặc chồng lấn thời gian với lớp học khác.',
                      );
                    }
                  }
                },
                child: Text(isVi ? 'LƯU' : 'SAVE'),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Trợ Lý Gợi Ý Xếp Lịch Học Thông Minh khi học sinh bị cấn lịch
  void _openSmartRecommendationSheet() async {
    int? selectedKhoi; // null = Tất cả các khối
    HS? selectedHocSinh;
    List<HS> allStudents = [];
    try {
      allStudents = await _hsService.docTatCaHocSinh();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return FutureBuilder<List<GoiYCaHoc>>(
              future: _lichHocService.layGoiYCaHocPhuHop(
                targetKhoi: selectedKhoi,
                targetHocSinh: selectedHocSinh,
              ),
              builder: (context, snapshot) {
                final isVi =
                    Localizations.localeOf(context).languageCode == 'vi';

                return Container(
                  height: MediaQuery.of(context).size.height * 0.8,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle Bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lightbulb_rounded,
                              color: Colors.amber,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isVi
                                      ? 'Trợ Lý Gợi Ý Xếp Lịch'
                                      : 'Smart Schedule Recommender',
                                  style: TextStyle(
                                    color: lightText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  isVi
                                      ? 'Tự động né lịch trường & môn khác của HS'
                                      : 'Auto-avoids school & other subject conflicts',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: lightText),
                            onPressed: () => Navigator.pop(sheetCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Dropdown Chọn Học Sinh Cần Xếp Lịch
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedHocSinh != null
                                ? accentColor
                                : Colors.white12,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<HS?>(
                            value: selectedHocSinh,
                            isExpanded: true,
                            dropdownColor: cardColor,
                            hint: Row(
                              children: [
                                const Icon(
                                  Icons.person_search_rounded,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isVi
                                      ? 'Chọn học sinh cấn lịch (để né trùng)...'
                                      : 'Select student to match...',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            onChanged: (HS? hs) {
                              setSheetState(() {
                                selectedHocSinh = hs;
                              });
                            },
                            items: [
                              DropdownMenuItem<HS?>(
                                value: null,
                                child: Text(
                                  isVi
                                      ? '(Tất cả ca dạy / Chưa chọn HS)'
                                      : '(All slots / No student)',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              ...allStudents.map((hs) {
                                return DropdownMenuItem<HS?>(
                                  value: hs,
                                  child: Row(
                                    children: [
                                      Text(
                                        hs.ten,
                                        style: TextStyle(
                                          color: lightText,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Học ${hs.caHocTruong}',
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (hs.lichCanMonKhac != null &&
                                          hs.lichCanMonKhac!.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '(${hs.lichCanMonKhac})',
                                            style: TextStyle(
                                              color: secondaryText,
                                              fontSize: 10,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Lọc theo Khối
                      Row(
                        children: [
                          Text(
                            isVi ? 'Lọc Khối:' : 'Filter Grade:',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 34,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ChoiceChip(
                                    label: Text(
                                      'Tất cả',
                                      style: TextStyle(
                                        color: selectedKhoi == null
                                            ? Colors.white
                                            : lightText,
                                        fontWeight: selectedKhoi == null
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                    selected: selectedKhoi == null,
                                    selectedColor: accentColor,
                                    backgroundColor: isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.grey.shade200,
                                    side: BorderSide(
                                      color: selectedKhoi == null
                                          ? accentColor
                                          : (isDark
                                                ? Colors.white24
                                                : Colors.black12),
                                    ),
                                    checkmarkColor: Colors.white,
                                    onSelected: (val) {
                                      if (val) {
                                        setSheetState(
                                          () => selectedKhoi = null,
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  ...List.generate(7, (i) {
                                    final k = i + 6; // Khối 6 đến 12
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        label: Text(
                                          'Khối $k',
                                          style: TextStyle(
                                            color: selectedKhoi == k
                                                ? Colors.white
                                                : lightText,
                                            fontWeight: selectedKhoi == k
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                        selected: selectedKhoi == k,
                                        selectedColor: accentColor,
                                        backgroundColor: isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.grey.shade200,
                                        side: BorderSide(
                                          color: selectedKhoi == k
                                              ? accentColor
                                              : (isDark
                                                    ? Colors.white24
                                                    : Colors.black12),
                                        ),
                                        checkmarkColor: Colors.white,
                                        onSelected: (val) {
                                          setSheetState(() {
                                            selectedKhoi = val ? k : null;
                                          });
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // List các ca dạy được xếp hạng gợi ý
                      Expanded(
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: accentColor,
                                ),
                              )
                            : snapshot.hasError ||
                                  (snapshot.data?.isEmpty ?? true)
                            ? Center(
                                child: Text(
                                  isVi
                                      ? 'Không có ca dạy gợi ý nào.'
                                      : 'No recommended slots.',
                                  style: TextStyle(color: secondaryText),
                                ),
                              )
                            : ListView.builder(
                                itemCount: snapshot.data!.length,
                                itemBuilder: (ctxList, idx) {
                                  final goiY = snapshot.data![idx];
                                  final item = goiY.item;

                                  final startClean =
                                      item.lichHoc.gioBatDau.length >= 5
                                      ? item.lichHoc.gioBatDau.substring(0, 5)
                                      : item.lichHoc.gioBatDau;
                                  final endClean =
                                      item.lichHoc.gioKetThuc.length >= 5
                                      ? item.lichHoc.gioKetThuc.substring(0, 5)
                                      : item.lichHoc.gioKetThuc;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: goiY.hasConflict
                                          ? Colors.red.withValues(alpha: 0.08)
                                          : (goiY.isBestChoice
                                                ? Colors.green.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : cardColor),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: goiY.hasConflict
                                            ? Colors.redAccent.withValues(
                                                alpha: 0.4,
                                              )
                                            : (goiY.isBestChoice
                                                  ? Colors.green.withValues(
                                                      alpha: 0.5,
                                                    )
                                                  : Colors.white12),
                                        width:
                                            (goiY.isBestChoice ||
                                                goiY.hasConflict)
                                            ? 1.5
                                            : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Badge Gợi Ý Hàng Đầu hoặc Cảnh Báo
                                        if (goiY.isBestChoice)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.star_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          )
                                        else if (goiY.hasConflict)
                                          Container(
                                            margin: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            padding: const EdgeInsets.all(8),
                                            decoration: const BoxDecoration(
                                              color: Colors.redAccent,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.warning_amber_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    item.tenLop,
                                                    style: TextStyle(
                                                      color: lightText,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'Khối ${item.khoi}',
                                                      style: const TextStyle(
                                                        color: Colors.blue,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${_getThuLabel(item.lichHoc.thuTrongTuan)}: $startClean - $endClean',
                                                style: TextStyle(
                                                  color: accentColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                goiY.reason,
                                                style: TextStyle(
                                                  color: goiY.hasConflict
                                                      ? Colors.orangeAccent
                                                      : (goiY.isBestChoice
                                                            ? Colors.greenAccent
                                                            : secondaryText),
                                                  fontSize: 11,
                                                  fontWeight:
                                                      (goiY.isBestChoice ||
                                                          goiY.hasConflict)
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: goiY.hasConflict
                                                ? Colors.orange.shade800
                                                : (goiY.isBestChoice
                                                      ? Colors.green
                                                      : accentColor),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            elevation: goiY.isBestChoice
                                                ? 2
                                                : 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(sheetCtx);
                                            final String hsText =
                                                selectedHocSinh != null
                                                ? ' cho học sinh ${selectedHocSinh!.ten}'
                                                : '';
                                            ToastHelper.showSuccess(
                                              context,
                                              'Đã chọn ca ${_getThuLabel(item.lichHoc.thuTrongTuan)} ($startClean - $endClean) của ${item.tenLop}$hsText!',
                                            );
                                          },
                                          child: Text(
                                            isVi ? 'Chọn ca này' : 'Select',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmDelete(LichHocCoTenLop item) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isVi ? 'Xóa Ca Dạy?' : 'Delete Class Schedule?',
          style: TextStyle(color: deleteColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isVi
              ? 'Bạn có chắc chắn muốn xóa ca dạy ${_getThuLabel(item.lichHoc.thuTrongTuan)} (${item.lichHoc.gioBatDau.substring(0, 5)} - ${item.lichHoc.gioKetThuc.substring(0, 5)}) của lớp ${item.tenLop}?'
              : 'Are you sure you want to delete this schedule?',
          style: TextStyle(color: lightText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isVi ? 'Hủy' : 'Cancel',
              style: TextStyle(color: secondaryText),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: deleteColor),
            onPressed: () async {
              Navigator.pop(ctx);
              if (item.lichHoc.id != null) {
                final ok = await _lichHocService.xoaLichHoc(item.lichHoc.id!);
                if (mounted) {
                  if (ok) {
                    ToastHelper.showSuccess(context, 'Đã xóa ca dạy!');
                    _loadData();
                  } else {
                    ToastHelper.showError(context, 'Lỗi xóa ca dạy!');
                  }
                }
              }
            },
            child: Text(
              isVi ? 'XÓA' : 'DELETE',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final int totalClassesWithSchedule = _allSchedules
        .map((s) => s.lichHoc.idLop)
        .toSet()
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: Colors.blueAccent,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tổng ca dạy',
                      style: TextStyle(color: secondaryText, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_allSchedules.length}',
                      style: TextStyle(
                        color: lightText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 28, width: 1, color: Colors.white10),
              Expanded(
                child: Column(
                  children: [
                    const Icon(
                      Icons.class_rounded,
                      color: Colors.greenAccent,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lớp đang dạy',
                      style: TextStyle(color: secondaryText, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$totalClassesWithSchedule lớp',
                      style: TextStyle(
                        color: lightText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 28, width: 1, color: Colors.white10),
              Expanded(
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.orangeAccent,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ngày bận nhất',
                      style: TextStyle(color: secondaryText, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getBusiestDayText(),
                      style: TextStyle(
                        color: lightText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Nút Trợ Lý Gợi Ý Xếp Lịch Cho Học Sinh Cấn Lịch
          const SizedBox(height: 12),
          InkWell(
            onTap: _openSmartRecommendationSheet,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFB45309)],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lightbulb_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'GỢI Ý XẾP LỊCH CHO HỌC SINH CẤN LỊCH',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayFilterChips() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: _dayOptions.length,
        itemBuilder: (context, index) {
          final opt = _dayOptions[index];
          final int dayVal = opt['val'] as int;
          final String label = opt['label'] as String;
          final int count = _countSchedulesForDay(dayVal);
          final bool isSelected = _selectedDay == dayVal;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              selected: isSelected,
              label: Text('$label ($count)'),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : secondaryText,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              selectedColor: accentColor,
              backgroundColor: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (val) {
                setState(() {
                  _selectedDay = dayVal;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard(LichHocCoTenLop item) {
    final startClean = item.lichHoc.gioBatDau.length >= 5
        ? item.lichHoc.gioBatDau.substring(0, 5)
        : item.lichHoc.gioBatDau;
    final endClean = item.lichHoc.gioKetThuc.length >= 5
        ? item.lichHoc.gioKetThuc.substring(0, 5)
        : item.lichHoc.gioKetThuc;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Thẻ Giờ Học
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time_filled, color: accentColor, size: 16),
                  const SizedBox(height: 4),
                  Text(
                    startClean,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    endClean,
                    style: TextStyle(color: secondaryText, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Thông tin Lớp Học
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.tenLop,
                          style: TextStyle(
                            color: lightText,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Khối ${item.khoi}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_outlined,
                        size: 13,
                        color: secondaryText,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Sĩ số: ${item.siSo} học sinh',
                        style: TextStyle(color: secondaryText, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getThuLabel(item.lichHoc.thuTrongTuan),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Thao tác (Sửa, Xóa, Điểm danh)
            Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.event_available_rounded, size: 18),
                      color: Colors.blueAccent,
                      tooltip: 'Thêm vào Google Calendar / Lịch máy',
                      onPressed: () async {
                        final ok =
                            await CalendarSyncService.themCaHocVaoCalendar(
                              item,
                            );
                        if (context.mounted) {
                          if (ok) {
                            ToastHelper.showSuccess(
                              context,
                              'Đang mở ứng dụng Lịch để tạo sự kiện...',
                            );
                          } else {
                            ToastHelper.showError(
                              context,
                              'Không thể mở ứng dụng Lịch!',
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      color: Colors.amber,
                      tooltip: 'Điều chỉnh ca dạy',
                      onPressed: () => _openAddOrEditDialog(item),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: deleteColor,
                      tooltip: 'Xóa ca dạy',
                      onPressed: () => _confirmDelete(item),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => DiemDanhPage(
                          selectedLopId: item.lichHoc.idLop,
                          selectedDate: DateTime.now(),
                          selectedScheduleId: item.lichHoc.id,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green, width: 0.5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fact_check_outlined,
                          size: 12,
                          color: Colors.green,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Điểm danh',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    final filteredSchedules = _selectedDay == 0
        ? _allSchedules
        : _allSchedules
              .where((s) => s.lichHoc.thuTrongTuan == _selectedDay)
              .toList();

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          isVi ? 'LỊCH DẠY THEO TUẦN' : 'WEEKLY TEACHING SCHEDULE',
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: cardColor,
        foregroundColor: lightText,
        elevation: 0,
        leading: widget.mainScreenKey != null
            ? Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : null,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.edit_calendar_rounded,
              color: Colors.blueAccent,
            ),
            tooltip: 'Đồng bộ Google Calendar',
            onSelected: (val) async {
              if (val == 'sync_all') {
                if (_allSchedules.isEmpty) {
                  ToastHelper.showWarning(
                    context,
                    'Chưa có ca dạy nào để đồng bộ!',
                  );
                  return;
                }
                int count = 0;
                for (var sched in _allSchedules) {
                  final ok = await CalendarSyncService.themCaHocVaoCalendar(
                    sched,
                  );
                  if (ok) count++;
                }
                if (context.mounted) {
                  ToastHelper.showSuccess(
                    context,
                    'Đã chuyển $count ca dạy sang ứng dụng Lịch!',
                  );
                }
              } else if (val == 'export_ics') {
                if (_allSchedules.isEmpty) {
                  ToastHelper.showWarning(
                    context,
                    'Chưa có ca dạy nào để xuất!',
                  );
                  return;
                }
                final path =
                    await CalendarSyncService.xuatDanhSachLichDaySangICS(
                      _allSchedules,
                    );
                if (context.mounted && path != null) {
                  ToastHelper.showSuccess(
                    context,
                    'Đã khởi tạo file .ics thành công!',
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem<String>(
                value: 'sync_all',
                child: Row(
                  children: [
                    Icon(
                      Icons.edit_calendar_rounded,
                      color: Colors.blue,
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Đồng bộ vào Lịch điện thoại',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export_ics',
                child: Row(
                  children: [
                    Icon(Icons.ios_share_rounded, color: Colors.teal, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Xuất file Lịch (.ics)',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: widget.mainScreenKey != null && widget.selectedIndex != null
          ? MainDrawer(
              mainScreenKey: widget.mainScreenKey!,
              selectedIndex: widget.selectedIndex!,
            )
          : null,
      // Nút Thêm Ca Dạy Mới Thiết Kế Gradient Pill Đẹp Mắt
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: GestureDetector(
        onTap: () => _openAddOrEditDialog(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F3460), Color(0xFF0072FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0072FF).withValues(alpha: 0.4),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isVi ? 'THÊM CA DẠY MỚI' : 'ADD NEW SCHEDULE',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  _buildSummaryCard(),
                  _buildDayFilterChips(),
                  const SizedBox(height: 6),
                  Expanded(
                    child: filteredSchedules.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 48,
                                  color: secondaryText,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  isVi
                                      ? 'Chưa có ca dạy nào trong ${_selectedDay == 0 ? "tuần" : _getThuLabel(_selectedDay)}'
                                      : 'No schedule found',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredSchedules.length,
                            padding: const EdgeInsets.only(bottom: 90),
                            itemBuilder: (context, index) {
                              return _buildScheduleCard(
                                filteredSchedules[index],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
