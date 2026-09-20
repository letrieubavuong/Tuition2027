import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../controllers/lop_detail_controller.dart';
import '../../../models/hs.dart';
import '../../../models/hs_lop_view_model.dart';
import '../../../models/lop.dart';
import '../../../services/nhan_xet_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../widgets/danh_gia_dialog.dart';

class ClassEvaluationTab extends ConsumerStatefulWidget {
  final Lop lop;

  const ClassEvaluationTab({super.key, required this.lop});

  @override
  ConsumerState<ClassEvaluationTab> createState() => _ClassEvaluationTabState();
}

class _ClassEvaluationTabState extends ConsumerState<ClassEvaluationTab> {
  final _nhanXetService = NhanXetService();
  final _searchController = TextEditingController();

  late DateTime _selectedMonthDate;
  String _searchQuery = '';
  String _filterCategory =
      'all'; // 'all', 'attention', 'no_data', 'absent', 'homework'

  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  @override
  void initState() {
    super.initState();
    _selectedMonthDate = DateTime.now();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _thangString => DateFormat('yyyy-MM').format(_selectedMonthDate);

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonthDate = DateTime(
        _selectedMonthDate.year,
        _selectedMonthDate.month + offset,
        1,
      );
    });
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonthDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: 'CHỌN THÁNG ĐÁNH GIÁ',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonthDate = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  String _formatScoreStatus(double? score, String type) {
    if (score == null) return 'Chưa có dữ liệu';
    if (type == 'thaiDo') {
      if (score >= 4.0) return 'Xuất sắc';
      if (score >= 1.5) return 'Tốt';
      if (score >= 0.0) return 'Khá / Trung bình';
      return 'Cần nhắc nhở';
    } else if (type == 'hieuBai') {
      if (score >= 4.0) return 'Hiểu bài rất tốt';
      if (score >= 1.5) return 'Hiểu bài tốt';
      if (score >= 0.0) return 'Nắm cơ bản';
      return 'Tiếp thu chậm';
    } else if (type == 'baiTap') {
      if (score >= 4.0) return 'Xuất sắc';
      if (score >= 1.5) return 'Đầy đủ';
      if (score >= 0.0) return 'Chưa cẩn thận';
      return 'Thiếu BTVN';
    }
    return score.toStringAsFixed(1);
  }

  Color _getScoreColor(double? score) {
    if (score == null) return secondaryText;
    if (score >= 1.5) return Colors.greenAccent.shade400;
    if (score >= 0.0) return Colors.blueAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(lopDetailControllerProvider(widget.lop.id!));
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    return stateAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: accentColor)),
      error: (err, _) => Center(
        child: Text(
          isVi ? 'Lỗi tải dữ liệu: $err' : 'Error loading data: $err',
          style: TextStyle(color: deleteColor),
        ),
      ),
      data: (state) {
        final dsHocSinh = state.hocSinhs;
        if (dsHocSinh.isEmpty) {
          return Center(
            child: Text(
              isVi
                  ? 'Chưa có học sinh trong lớp.'
                  : 'No students in this class.',
              style: TextStyle(color: secondaryText),
            ),
          );
        }

        return FutureBuilder<List<StudentEvaluationSummaryViewModel>>(
          future: _nhanXetService.getClassEvaluationBatchSummary(
            classId: widget.lop.id!,
            month: _thangString,
            students: dsHocSinh,
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: accentColor),
              );
            }

            final summaries = snapshot.data ?? [];

            final totalCount = summaries.length;
            final hasDataCount = summaries.where((s) => s.hasEnoughData).length;
            final attentionCount = summaries
                .where((s) => s.needsAttention)
                .length;
            final noDataCount = totalCount - hasDataCount;

            // Filter logic
            final filtered = summaries.where((s) {
              if (_searchQuery.isNotEmpty &&
                  !s.studentName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  )) {
                return false;
              }
              if (_filterCategory == 'attention') return s.needsAttention;
              if (_filterCategory == 'no_data') return !s.hasEnoughData;
              if (_filterCategory == 'absent')
                return s.unexcusedAbsenceCount > 0 || s.excusedAbsenceCount > 0;
              if (_filterCategory == 'homework')
                return s.missingHomeworkCount > 0;
              return true;
            }).toList();

            return Column(
              children: [
                // Month Selector Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  color: cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 22),
                        color: lightText,
                        onPressed: () => _changeMonth(-1),
                      ),
                      InkWell(
                        onTap: _pickMonth,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_month,
                                color: accentColor,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isVi
                                    ? 'Tháng ${DateFormat('MM/yyyy').format(_selectedMonthDate)}'
                                    : DateFormat(
                                        'MMMM yyyy',
                                      ).format(_selectedMonthDate),
                                style: TextStyle(
                                  color: lightText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 22),
                        color: lightText,
                        onPressed: () => _changeMonth(1),
                      ),
                    ],
                  ),
                ),

                // Compact Summary Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: darkBackground,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          '$totalCount HS',
                          style: TextStyle(
                            color: lightText,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        Text(
                          '✓ $hasDataCount có dữ liệu',
                          style: TextStyle(
                            color: Colors.greenAccent.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        Text(
                          '⚠ $attentionCount cần chú ý',
                          style: TextStyle(
                            color: Colors.amber.shade400,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        if (noDataCount > 0) ...[
                          const Text(
                            ' • ',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Text(
                            '? $noDataCount chưa đủ dữ liệu',
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Search & Filter Chips
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        style: TextStyle(color: lightText, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '🔍 Tìm học sinh...',
                          hintStyle: TextStyle(
                            color: secondaryText,
                            fontSize: 13,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: Text('Tất cả ($totalCount)'),
                              selected: _filterCategory == 'all',
                              onSelected: (s) {
                                if (s) setState(() => _filterCategory = 'all');
                              },
                              selectedColor: accentColor.withValues(alpha: 0.3),
                              labelStyle: TextStyle(
                                color: _filterCategory == 'all'
                                    ? accentColor
                                    : lightText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ChoiceChip(
                              label: Text('⚠ Cần chú ý ($attentionCount)'),
                              selected: _filterCategory == 'attention',
                              onSelected: (s) {
                                if (s)
                                  setState(() => _filterCategory = 'attention');
                              },
                              selectedColor: Colors.amber.shade900.withValues(
                                alpha: 0.3,
                              ),
                              labelStyle: TextStyle(
                                color: _filterCategory == 'attention'
                                    ? Colors.amber.shade300
                                    : lightText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ChoiceChip(
                              label: Text('? Chưa đủ dữ liệu ($noDataCount)'),
                              selected: _filterCategory == 'no_data',
                              onSelected: (s) {
                                if (s)
                                  setState(() => _filterCategory = 'no_data');
                              },
                              selectedColor: Colors.blue.shade900.withValues(
                                alpha: 0.3,
                              ),
                              labelStyle: TextStyle(
                                color: _filterCategory == 'no_data'
                                    ? Colors.blue.shade300
                                    : lightText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ChoiceChip(
                              label: const Text('BTVN'),
                              selected: _filterCategory == 'homework',
                              onSelected: (s) {
                                if (s)
                                  setState(() => _filterCategory = 'homework');
                              },
                              selectedColor: Colors.purple.shade900.withValues(
                                alpha: 0.3,
                              ),
                              labelStyle: TextStyle(
                                color: _filterCategory == 'homework'
                                    ? Colors.purple.shade300
                                    : lightText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Student Evaluation List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'Không tìm thấy học sinh phù hợp.',
                            style: TextStyle(color: secondaryText),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, index) {
                            final item = filtered[index];
                            final hsVm = dsHocSinh.firstWhere(
                              (h) => h.id == item.studentId,
                              orElse: () => HSLopViewModel(
                                hocSinh: HS(
                                  id: item.studentId,
                                  ten: item.studentName,
                                  sdt: '',
                                ),
                                ngayThamGia: '',
                                trangThai: 'DangHoc',
                              ),
                            );
                            return _buildStudentEvaluationCard(item, hsVm);
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStudentEvaluationCard(
    StudentEvaluationSummaryViewModel item,
    HSLopViewModel hsVm,
  ) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _openStudentEvaluationDetailSheet(item, hsVm),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Name & Warning Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.studentName,
                      style: TextStyle(
                        color: lightText,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.warningBadge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.warningBadge!,
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Row 2: Attendance Rate & Recent 5 Session Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chuyên cần: ${item.attendanceRate.toInt()}% (${item.presentCount}/${item.totalSessions} buổi)',
                    style: TextStyle(
                      color: item.attendanceRate >= 80
                          ? Colors.greenAccent.shade400
                          : Colors.amber.shade400,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: item.recent5Sessions.map((st) {
                      final isPresent = st == 'Có mặt';
                      final isLate = st.contains('Trễ') || st.contains('muộn');
                      final color = isPresent
                          ? Colors.green
                          : isLate
                          ? Colors.orange
                          : Colors.red;
                      return Container(
                        margin: const EdgeInsets.only(left: 3),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Row 3: Attitude, Understanding, Homework status (No-data semantics)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      label: 'Thái độ',
                      value: _formatScoreStatus(
                        item.avgAttitudeScore,
                        'thaiDo',
                      ),
                      color: _getScoreColor(item.avgAttitudeScore),
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'Hiểu bài',
                      value: _formatScoreStatus(
                        item.avgUnderstandingScore,
                        'hieuBai',
                      ),
                      color: _getScoreColor(item.avgUnderstandingScore),
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'BTVN',
                      value: _formatScoreStatus(
                        item.avgHomeworkScore,
                        'baiTap',
                      ),
                      color: _getScoreColor(item.avgHomeworkScore),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: secondaryText, fontSize: 10)),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _openStudentEvaluationDetailSheet(
    StudentEvaluationSummaryViewModel item,
    HSLopViewModel hsVm,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.studentName,
                        style: TextStyle(
                          color: lightText,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        'Chi tiết đánh giá tháng ${DateFormat('MM/yyyy').format(_selectedMonthDate)}',
                        style: TextStyle(color: secondaryText, fontSize: 13),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: secondaryText),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'Chuyên cần',
                        '${item.attendanceRate.toInt()}% (${item.presentCount}/${item.totalSessions} buổi)',
                      ),
                      _buildDetailRow(
                        'Vắng không phép',
                        '${item.unexcusedAbsenceCount} buổi',
                      ),
                      _buildDetailRow('Đi muộn', '${item.lateCount} lần'),
                      _buildDetailRow(
                        'Thái độ học',
                        _formatScoreStatus(item.avgAttitudeScore, 'thaiDo'),
                      ),
                      _buildDetailRow(
                        'Hiểu bài & KT',
                        _formatScoreStatus(
                          item.avgUnderstandingScore,
                          'hieuBai',
                        ),
                      ),
                      _buildDetailRow(
                        'Bài tập về nhà',
                        _formatScoreStatus(item.avgHomeworkScore, 'baiTap'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'NHẬN XÉT CHUNG:',
                        style: TextStyle(
                          color: secondaryText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (item.nhanXetThang.nhanXetChung != null &&
                                item.nhanXetThang.nhanXetChung!.isNotEmpty)
                            ? item.nhanXetThang.nhanXetChung!
                            : 'Chưa có nhận xét riêng.',
                        style: TextStyle(
                          color: lightText,
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceEvenly,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: darkBackground,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final res = await showDialog<bool>(
                        context: context,
                        builder: (ctx2) => DanhGiaDialog(
                          idHocSinh: hsVm.id!,
                          tenHocSinh: hsVm.ten,
                          idLop: widget.lop.id!,
                          thang: _thangString,
                        ),
                      );
                      if (res == true) setState(() {});
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('SỬA THỦ CÔNG'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final pdf = PdfExportService();
                      await pdf.generateAndOpenBaoCaoHocTapPdf(
                        hsVm,
                        item.nhanXetThang,
                        widget.lop.ten,
                        _thangString,
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('XUẤT PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      final msg =
                          'Báo cáo học tập em ${hsVm.ten}: Chuyên cần ${item.attendanceRate.toInt()}%.';
                      SharePlus.instance.share(ShareParams(text: msg));
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('GỬI PHHS'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: secondaryText, fontSize: 13)),
          Text(
            val,
            style: TextStyle(
              color: lightText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
