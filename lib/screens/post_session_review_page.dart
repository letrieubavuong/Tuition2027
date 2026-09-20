// File: lib/screens/post_session_review_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hs_lop_view_model.dart';
import '../models/lich_hoc.dart';
import '../models/lop.dart';
import '../models/post_session_review.dart';
import '../services/post_session_review_service.dart';
import '../utils/toast_helper.dart';

class PostSessionReviewPage extends StatefulWidget {
  final Lop lop;
  final LichHoc caHoc;
  final DateTime date;
  final List<HSLopViewModel> danhSachHS;
  final Map<String, String>
  currentAttendanceStatus; // key: 'hsId-caId' -> 'Có mặt'/'Vắng...'

  const PostSessionReviewPage({
    super.key,
    required this.lop,
    required this.caHoc,
    required this.date,
    required this.danhSachHS,
    required this.currentAttendanceStatus,
  });

  @override
  State<PostSessionReviewPage> createState() => _PostSessionReviewPageState();
}

class _PostSessionReviewPageState extends State<PostSessionReviewPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _postService = PostSessionReviewService();

  // Đánh giá mặc định cả ca
  String _defaultThaiDo = 'Tốt';
  String _defaultBaiCu = 'Đã chuẩn bị';
  String _defaultBaiTap = 'Đầy đủ';
  String _defaultTiepThu = 'Tốt';

  // Danh sách học sinh & state đánh giá riêng
  List<StudentReviewData> _studentReviews = [];

  // BTVN
  final TextEditingController _hwController = TextEditingController();
  String _hwDueDateChoice = 'BUOI_TIEP'; // 'BUOI_TIEP' hoặc 'CHON_NGAY'
  DateTime? _hwCustomDueDate;
  final Set<String> _selectedHwTags = {};

  // Hàng đợi gửi tin nhắn phụ huynh
  List<ParentCommunicationRecord> _commQueue = [];
  int _currentQueueIndex = 0;
  int _sentCount = 0;
  bool _isLoadingQueue = false;
  String? _customTemplate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initStudentReviews();
  }

  void _initStudentReviews() {
    _studentReviews = widget.danhSachHS.map((hs) {
      final attKey = '${hs.id}-${widget.caHoc.id}';
      final status = widget.currentAttendanceStatus[attKey] ?? 'Có mặt';
      return StudentReviewData(
        studentId: hs.id!,
        studentName: hs.ten,
        phone: hs.sdt,
        attendanceStatus: status,
        thaiDo: _defaultThaiDo,
        baiCu: _defaultBaiCu,
        baiTap: _defaultBaiTap,
        tiepThu: _defaultTiepThu,
      );
    }).toList();
  }

  void _applyDefaultToAllPresent() {
    setState(() {
      for (int i = 0; i < _studentReviews.length; i++) {
        if (!_studentReviews[i].isAbsent) {
          _studentReviews[i] = _studentReviews[i].copyWith(
            thaiDo: _defaultThaiDo,
            baiCu: _defaultBaiCu,
            baiTap: _defaultBaiTap,
            tiepThu: _defaultTiepThu,
          );
        }
      }
    });
    ToastHelper.show(
      context,
      'Đã áp dụng đánh giá chung cho tất cả học sinh có mặt!',
    );
  }

  Future<void> _prepareCommunicationQueue() async {
    setState(() => _isLoadingQueue = true);

    final timeSlot =
        '${widget.caHoc.gioBatDau.substring(0, 5)} - ${widget.caHoc.gioKetThuc.substring(0, 5)}';
    final hwDueDateStr = _hwDueDateChoice == 'BUOI_TIEP'
        ? 'Buổi học tiếp theo'
        : (_hwCustomDueDate != null
              ? DateFormat('dd/MM/yyyy').format(_hwCustomDueDate!)
              : 'Buổi học tiếp theo');

    final queue = await _postService.getPendingCommunicationQueue(
      classId: widget.lop.id!,
      className: widget.lop.ten,
      date: widget.date,
      timeSlot: timeSlot,
      reviews: _studentReviews,
      homeworkContent: _hwController.text.trim(),
      homeworkDueDate: hwDueDateStr,
      customTemplate: _customTemplate,
    );

    setState(() {
      _commQueue = queue;
      _currentQueueIndex = 0;
      _sentCount = 0;
      _isLoadingQueue = false;
    });
  }

  Future<void> _saveAllAndComplete() async {
    final timeSlot = widget.caHoc.gioBatDau.substring(0, 5);
    final hwDueDateStr = _hwDueDateChoice == 'BUOI_TIEP'
        ? 'Buổi học tiếp theo'
        : (_hwCustomDueDate != null
              ? DateFormat('dd/MM/yyyy').format(_hwCustomDueDate!)
              : 'Buổi học tiếp theo');

    await _postService.savePostSessionBatchReview(
      classId: widget.lop.id!,
      date: widget.date,
      timeSlot: timeSlot,
      reviews: _studentReviews,
      homeworkContent: _hwController.text.trim(),
      homeworkDueDate: hwDueDateStr,
      homeworkTags: _selectedHwTags.toList(),
    );

    if (mounted) {
      ToastHelper.show(context, 'Đã kết thúc ca và lưu toàn bộ đánh giá!');
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeSlot =
        '${widget.caHoc.gioBatDau.substring(0, 5)} - ${widget.caHoc.gioKetThuc.substring(0, 5)}';
    final dateStr = DateFormat('dd/MM/yyyy').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kết Thúc Ca & Đánh Giá',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Lớp ${widget.lop.ten} • Ca $timeSlot • $dateStr',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.rate_review_rounded), text: '1. Đánh Giá Ca'),
            Tab(
              icon: Icon(Icons.assignment_turned_in_rounded),
              text: '2. BTVN',
            ),
            Tab(icon: Icon(Icons.contact_phone_rounded), text: '3. Zalo PH'),
          ],
          onTap: (index) {
            if (index == 2) {
              _prepareCommunicationQueue();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
            ),
            tooltip: 'Hoàn tất ca học',
            onPressed: _saveAllAndComplete,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTab1ReviewList(theme),
          _buildTab2Homework(theme),
          _buildTab3ZaloAssist(theme),
        ],
      ),
    );
  }

  // =======================================================
  // TAB 1: ĐÁNH GIÁ CHUNG CẢ CA & TÙY CHỈNH HỌC SINH
  // =======================================================
  Widget _buildTab1ReviewList(ThemeData theme) {
    final attentionList = _studentReviews
        .where((s) => s.isAttentionNeeded)
        .toList();
    final normalList = _studentReviews
        .where((s) => !s.isAttentionNeeded)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ĐÁNH GIÁ MẶC ĐỊNH CẢ CA
          Card(
            color: theme.cardColor,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ĐÁNH GIÁ MẶC ĐỊNH CHO HS CÓ MẶT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildDropdownRow(
                    'Thái độ:',
                    _defaultThaiDo,
                    ['Tốt', 'Khá', 'Cần nhắc'],
                    (v) {
                      setState(() => _defaultThaiDo = v!);
                    },
                  ),
                  _buildDropdownRow(
                    'Bài cũ:',
                    _defaultBaiCu,
                    ['Đã chuẩn bị', 'Chưa tốt', 'Không chuẩn bị'],
                    (v) {
                      setState(() => _defaultBaiCu = v!);
                    },
                  ),
                  _buildDropdownRow(
                    'Bài tập:',
                    _defaultBaiTap,
                    ['Đầy đủ', 'Thiếu', 'Không làm'],
                    (v) {
                      setState(() => _defaultBaiTap = v!);
                    },
                  ),
                  _buildDropdownRow(
                    'Tiếp thu:',
                    _defaultTiepThu,
                    ['Tốt', 'Khá', 'Cần củng cố'],
                    (v) {
                      setState(() => _defaultTiepThu = v!);
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _applyDefaultToAllPresent,
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: const Text('ÁP DỤNG CHO TẤT CẢ HS CÓ MẶT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // NHÓM 1: CẦN CHÚ Ý (ƯU TIÊN LÊN ĐẦU)
          if (attentionList.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '⚠ CẦN CHÚ Ý (${attentionList.length} học sinh)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...attentionList.map(
              (s) => _buildStudentReviewCard(s, theme, isWarning: true),
            ),
            const SizedBox(height: 16),
          ],

          // NHÓM 2: BÌNH THƯỜNG
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: Colors.greenAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '✓ BÌNH THƯỜNG (${normalList.length} học sinh)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...normalList.map(
            (s) => _buildStudentReviewCard(s, theme, isWarning: false),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(
    String label,
    String currentValue,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          DropdownButton<String>(
            value: currentValue,
            isDense: true,
            underline: const SizedBox(),
            items: options.map((opt) {
              return DropdownMenuItem<String>(
                value: opt,
                child: Text(opt, style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStudentReviewCard(
    StudentReviewData student,
    ThemeData theme, {
    required bool isWarning,
  }) {
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isWarning
              ? Colors.orangeAccent.withValues(alpha: 0.5)
              : Colors.transparent,
          width: isWarning ? 1.5 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    student.studentName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: student.isAbsent
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    student.attendanceStatus,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: student.isAbsent
                          ? Colors.redAccent
                          : Colors.greenAccent,
                    ),
                  ),
                ),
              ],
            ),
            if (!student.isAbsent) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  // Chips BTVN
                  _buildChip('BT: Đầy đủ', student.baiTap == 'Đầy đủ', () {
                    setState(() => student.baiTap = 'Đầy đủ');
                  }),
                  _buildChip(
                    'BT: Thiếu',
                    student.baiTap == 'Thiếu',
                    () {
                      setState(() => student.baiTap = 'Thiếu');
                    },
                    color: Colors.orangeAccent,
                  ),
                  _buildChip(
                    'BT: Không làm',
                    student.baiTap == 'Không làm',
                    () {
                      setState(() => student.baiTap = 'Không làm');
                    },
                    color: Colors.redAccent,
                  ),

                  // Chips Bài Cũ
                  _buildChip(
                    'BC: Đã chuẩn bị',
                    student.baiCu == 'Đã chuẩn bị',
                    () {
                      setState(() => student.baiCu = 'Đã chuẩn bị');
                    },
                  ),
                  _buildChip(
                    'BC: Chưa thuộc',
                    student.baiCu == 'Chưa thuộc' ||
                        student.baiCu == 'Không chuẩn bị',
                    () {
                      setState(() => student.baiCu = 'Chưa thuộc');
                    },
                    color: Colors.orangeAccent,
                  ),

                  // Chips Thái Độ
                  _buildChip(
                    'TĐ: Mất tập trung',
                    student.thaiDo == 'Mất tập trung',
                    () {
                      setState(() => student.thaiDo = 'Mất tập trung');
                    },
                    color: Colors.orangeAccent,
                  ),
                  _buildChip(
                    'TĐ: Nói chuyện',
                    student.thaiDo == 'Nói chuyện',
                    () {
                      setState(() => student.thaiDo = 'Nói chuyện');
                    },
                    color: Colors.orangeAccent,
                  ),

                  // Chips Tiếp Thu
                  _buildChip(
                    'TT: Cần củng cố',
                    student.tiepThu == 'Cần củng cố',
                    () {
                      setState(() => student.tiepThu = 'Cần củng cố');
                    },
                    color: Colors.orangeAccent,
                  ),

                  // Chip Cần PH phối hợp
                  FilterChip(
                    label: const Text(
                      '⚠ Cần PH phối hợp',
                      style: TextStyle(fontSize: 11),
                    ),
                    selected: student.canPhPhoiHop,
                    selectedColor: Colors.deepOrange.withValues(alpha: 0.3),
                    checkmarkColor: Colors.deepOrange,
                    onSelected: (val) {
                      setState(() => student.canPhPhoiHop = val);
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    String label,
    bool isSelected,
    VoidCallback onTap, {
    Color? color,
  }) {
    final activeColor = color ?? Colors.greenAccent;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null),
      ),
      selected: isSelected,
      selectedColor: activeColor.withValues(alpha: 0.7),
      onSelected: (_) => onTap(),
    );
  }

  // =======================================================
  // TAB 2: GIAO BÀI TẬP VỀ NHÀ (BTVN MỘT LẦN CHO CẢ CA)
  // =======================================================
  Widget _buildTab2Homework(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BÀI TẬP VỀ NHÀ CHO CẢ CA',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hwController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  'Nhập nội dung BTVN (ví dụ: Làm bài 1 đến 5 trang 47 sách bài tập)...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: theme.cardColor,
            ),
          ),
          const SizedBox(height: 12),

          const Text(
            'THẺ GỢI Ý NHANH:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children:
                [
                  'Học bài cũ',
                  'Chuẩn bị bài mới',
                  'Mang tài liệu',
                  'Hoàn thành bài còn thiếu',
                ].map((tag) {
                  final isSelected = _selectedHwTags.contains(tag);
                  return FilterChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedHwTags.add(tag);
                        } else {
                          _selectedHwTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
          ),
          const SizedBox(height: 16),

          const Text(
            'HẠN NỘP BTVN:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Radio<String>(
                value: 'BUOI_TIEP',
                groupValue: _hwDueDateChoice,
                onChanged: (v) => setState(() => _hwDueDateChoice = v!),
              ),
              const Text('Buổi học tiếp theo'),
              const SizedBox(width: 16),
              Radio<String>(
                value: 'CHON_NGAY',
                groupValue: _hwDueDateChoice,
                onChanged: (v) => setState(() => _hwDueDateChoice = v!),
              ),
              const Text('Chọn ngày'),
            ],
          ),
          if (_hwDueDateChoice == 'CHON_NGAY') ...[
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 2)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (picked != null) {
                  setState(() => _hwCustomDueDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _hwCustomDueDate != null
                    ? DateFormat('dd/MM/yyyy').format(_hwCustomDueDate!)
                    : 'Chọn ngày nộp BTVN',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =======================================================
  // TAB 3: ZALO PERSONAL ASSISTANT — SMART FILTER & QUEUE
  // =======================================================
  Widget _buildTab3ZaloAssist(ThemeData theme) {
    if (_isLoadingQueue) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_commQueue.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.verified_user_rounded,
              color: Colors.greenAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Tất cả học sinh đều học tập tốt & đã gửi thông báo xong!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Hệ thống tự lọc thông minh: Không cần gửi tin nhắn phụ huynh nếu không có dấu hiệu cần lưu ý.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final currentItem = _commQueue[_currentQueueIndex];
    final hasPhone =
        currentItem.parentPhone != null &&
        currentItem.parentPhone!.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SUMMARY HEADER
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'HÀNG ĐỢI PH CẦN LIÊN HỆ (${_commQueue.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                    Text(
                      'Đã xử lý: $_sentCount / ${_commQueue.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Quy trình an toàn: App chuẩn bị tin nhắn -> Mở Zalo -> Giáo viên duyệt và bấm Gửi.',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // CANDIDATE CARD FOCUS
          Card(
            color: theme.cardColor,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.primaryColor, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.primaryColor.withValues(
                          alpha: 0.2,
                        ),
                        child: Text('${_currentQueueIndex + 1}'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentItem.studentName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Lý do: ${currentItem.reason}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orangeAccent,
                              ),
                            ),
                            if (!hasPhone)
                              const Text(
                                '⚠️ Chưa có SĐT phụ huynh',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  const Text(
                    'NỘI DUNG THÔNG BÁO:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: SelectableText(
                      currentItem.messageContent,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ACTIONS
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: currentItem.messageContent),
                          );
                          ToastHelper.show(
                            context,
                            'Đã copy nội dung tin nhắn!',
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openZaloForCurrent(currentItem),
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('MỞ ZALO GỬI'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openZaloForCurrent(ParentCommunicationRecord record) async {
    // 1. Copy message into clipboard
    await Clipboard.setData(ClipboardData(text: record.messageContent));
    if (mounted) ToastHelper.show(context, 'Đã copy nội dung vào Clipboard!');

    // 2. Open Zalo contact if phone exists
    if (record.parentPhone != null && record.parentPhone!.trim().isNotEmpty) {
      final phone = record.parentPhone!.trim();
      final Uri zaloUri = Uri.parse('https://zalo.me/$phone');
      try {
        await launchUrl(zaloUri, mode: LaunchMode.externalApplication);
      } catch (e) {
        if (mounted)
          ToastHelper.show(
            context,
            'Không thể mở Zalo trực tiếp. Đã copy nội dung!',
          );
      }
    }

    // 3. Confirm Manual Send Dialog
    if (mounted) {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Xác nhận thông báo cho PH ${record.studentName}'),
          content: const Text(
            'Bạn đã bấm Gửi thành công trong ứng dụng Zalo chưa?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'SKIP'),
              child: const Text('Bỏ qua'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'NOT_SENT'),
              child: const Text('Chưa gửi'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'SENT'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Đã gửi (Xác nhận)'),
            ),
          ],
        ),
      );

      if (result == 'SENT') {
        await _postService.markAsSentManuallyConfirmed(record);
        setState(() {
          _sentCount++;
          if (_currentQueueIndex < _commQueue.length - 1) {
            _currentQueueIndex++;
          } else {
            _commQueue.removeAt(_currentQueueIndex);
          }
        });
        if (mounted) ToastHelper.show(context, 'Đã lưu trạng thái ĐÃ GỬI!');
      } else if (result == 'SKIP') {
        await _postService.markAsSkipped(record);
        setState(() {
          if (_currentQueueIndex < _commQueue.length - 1) {
            _currentQueueIndex++;
          }
        });
      }
    }
  }
}
