import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/hs.dart';
import '../../../models/lop.dart';
import '../../../models/student_signal.dart';
import '../../../services/student_signal_service.dart';
import '../../../services/zalo_contact_service.dart';
import '../../../utils/db.dart';
import '../student_detail_page.dart';

class StudentOverviewTab extends StatefulWidget {
  final HS hocSinh;
  final Future<StudentClassInfo> classInfoFuture;
  final Future<Map<String, int>> attendanceStatsFuture;
  final Future<Map<String, dynamic>> hocPhiFuture;
  final VoidCallback onRefresh;

  const StudentOverviewTab({
    super.key,
    required this.hocSinh,
    required this.classInfoFuture,
    required this.attendanceStatsFuture,
    required this.hocPhiFuture,
    required this.onRefresh,
  });

  @override
  State<StudentOverviewTab> createState() => _StudentOverviewTabState();
}

class _StudentOverviewTabState extends State<StudentOverviewTab> {
  List<StudentSignal> _activeSignals = [];
  Map<String, dynamic>? _latestSession;
  bool _loadingOverview = true;

  @override
  void initState() {
    super.initState();
    _loadOverviewData();
  }

  @override
  void didUpdateWidget(covariant StudentOverviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.hocSinh.id != widget.hocSinh.id) {
      _loadOverviewData();
    }
  }

  Future<void> _loadOverviewData() async {
    try {
      final signals = await StudentSignalService.instance.getSignalsForStudent(
        widget.hocSinh.id!,
        activeOnly: true,
      );

      final db = await DBHelper.instance.database;
      final attRows = await db.rawQuery(
        '''
        SELECT d.gio_diem_danh, d.trang_thai, l.ten as ten_lop,
               r.diem_thai_do, r.diem_hieu_bai, r.diem_bai_tap, r.nhan_xet
        FROM ${DBHelper.tenBangDiemDanh} d
        LEFT JOIN ${DBHelper.tenBangLop} l ON l.id = d.id_lop
        LEFT JOIN ${DBHelper.tenBangDanhGiaBuoiHoc} r ON r.id_diem_danh = d.id
        WHERE d.id_hoc_sinh = ?
        ORDER BY d.gio_diem_danh DESC
        LIMIT 1
        ''',
        [widget.hocSinh.id!],
      );

      if (mounted) {
        setState(() {
          _activeSignals = signals;
          _latestSession = attRows.isNotEmpty ? attRows.first : null;
          _loadingOverview = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOverview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final currencyFmt = NumberFormat('#,##0', 'vi_VN');

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TẦNG 1: METRICS & WARNING BANNER ---
            FutureBuilder<List<dynamic>>(
              future: Future.wait([
                widget.attendanceStatsFuture,
                widget.hocPhiFuture,
                widget.classInfoFuture,
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final attData = snapshot.data![0] as Map<String, int>;
                final hpData = snapshot.data![1] as Map<String, dynamic>;
                final classInfo = snapshot.data![2] as StudentClassInfo;

                final coMat = attData['coMat'] ?? 0;
                final nghiCoPhep = attData['nghiCoPhep'] ?? 0;
                final nghiKhongPhep = attData['nghiKhongPhep'] ?? 0;
                final tongBuoi = coMat + nghiCoPhep + nghiKhongPhep;
                final attRate = tongBuoi > 0
                    ? ((coMat + nghiCoPhep) / tongBuoi * 100).round()
                    : 100;

                final conNoList =
                    hpData['con_no'] as List<Map<String, dynamic>>? ?? [];
                final tongNo = conNoList.fold<int>(
                  0,
                  (sum, item) => sum + (item['tien_no'] as int),
                );

                return Column(
                  children: [
                    // Metric Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: isVi ? 'Chuyên cần' : 'Attendance',
                            value: '$attRate%',
                            subtitle: isVi
                                ? '$coMat/$tongBuoi buổi'
                                : '$coMat/$tongBuoi sessions',
                            icon: Icons.pie_chart_outline,
                            accentColor: attRate >= 80
                                ? Colors.green.shade600
                                : attRate >= 60
                                ? Colors.amber.shade700
                                : theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            context,
                            title: isVi ? 'Học phí' : 'Tuition',
                            value: tongNo > 0
                                ? '${currencyFmt.format(tongNo)}đ'
                                : (isVi ? 'Đã hoàn thành' : 'Paid'),
                            subtitle: tongNo > 0
                                ? (isVi ? 'Còn nợ' : 'Outstanding')
                                : (isVi ? 'Không nợ' : 'Clean balance'),
                            icon: tongNo > 0
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            accentColor: tongNo > 0
                                ? theme.colorScheme.error
                                : Colors.green.shade600,
                          ),
                        ),
                      ],
                    ),

                    // Active Signal Banner (If real warning exists)
                    if (!_loadingOverview && _activeSignals.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer.withOpacity(
                            0.4,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.error.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: theme.colorScheme.error,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isVi
                                        ? 'CẦN CHÚ Ý (${_activeSignals.length} vấn đề)'
                                        : 'ATTENTION NEEDED (${_activeSignals.length} issues)',
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _activeSignals
                                        .map((s) => s.description)
                                        .join(' • '),
                                    style: TextStyle(
                                      color: theme.colorScheme.onErrorContainer,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // --- TẦNG 2: BUỔI HỌC GẦN NHẤT ---
                    _buildLatestSessionCard(context, isVi),

                    const SizedBox(height: 14),

                    // --- TẦNG 3: LỚP ĐANG THEO HỌC ---
                    _buildEnrolledClassesSection(
                      context,
                      classInfo.dsLop,
                      isVi,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 14),

            // --- TẦNG 4: THÔNG TIN HỒ SƠ & LIÊN HỆ ---
            _buildProfileDetailsSection(context, isVi),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestSessionCard(BuildContext context, bool isVi) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_toggle_off_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isVi ? 'BUỔI GẦN NHẤT' : 'LATEST SESSION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_latestSession == null)
              Text(
                isVi ? 'Chưa có buổi học nào.' : 'No recent session found.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _latestSession!['ten_lop'] ??
                        (isVi ? 'Buổi học' : 'Session'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (_latestSession!['gio_diem_danh'] != null)
                    Text(
                      DateFormat('dd/MM/yyyy • HH:mm').format(
                        DateTime.parse(_latestSession!['gio_diem_danh']),
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildChip(
                    context,
                    _latestSession!['trang_thai'] ??
                        (isVi ? 'Có mặt' : 'Present'),
                    Icons.check_circle_outline,
                    Colors.green.shade600,
                  ),
                  if (_latestSession!['diem_bai_tap'] != null)
                    _buildChip(
                      context,
                      'BTVN: ${_latestSession!['diem_bai_tap']}',
                      Icons.assignment_outlined,
                      Colors.blue.shade600,
                    ),
                  if (_latestSession!['diem_thai_do'] != null)
                    _buildChip(
                      context,
                      'Thái độ: ${_latestSession!['diem_thai_do']}',
                      Icons.sentiment_satisfied_outlined,
                      Colors.amber.shade700,
                    ),
                ],
              ),
              if (_latestSession!['nhan_xet'] != null &&
                  (_latestSession!['nhan_xet'] as String).isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '"${_latestSession!['nhan_xet']}"',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledClassesSection(
    BuildContext context,
    List<Lop> dsLop,
    bool isVi,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVi ? 'LỚP ĐANG THEO HỌC' : 'ENROLLED CLASSES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (dsLop.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  isVi ? 'Chưa tham gia lớp nào' : 'Not enrolled in any class',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dsLop.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final lop = dsLop[i];
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.class_outlined,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    lop.ten,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Khối ${lop.khoi}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildProfileDetailsSection(BuildContext context, bool isVi) {
    final theme = Theme.of(context);
    final hs = widget.hocSinh;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(
            Icons.contact_mail_outlined,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            isVi ? 'THÔNG TIN HỒ SƠ CHI TIẾT' : 'PROFILE DETAILS',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          children: [
            const Divider(height: 1),
            _buildProfileRow(
              context,
              Icons.school_outlined,
              isVi ? 'Trường' : 'School',
              hs.truongDangHoc,
            ),
            _buildProfileRow(
              context,
              Icons.phone_outlined,
              isVi ? 'SĐT Học sinh' : 'Student Phone',
              hs.sdtHocSinh,
            ),
            _buildProfileRow(
              context,
              Icons.family_restroom_outlined,
              isVi ? 'Phụ huynh' : 'Parent Name',
              hs.tenPhuHuynh,
            ),
            ListTile(
              dense: true,
              leading: Icon(
                Icons.phone_android_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                isVi ? 'SĐT Phụ huynh & Zalo' : 'Parent Phone',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              subtitle: Text(
                hs.effectiveParentPhone ?? (isVi ? 'Chưa cập nhật' : 'N/A'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              trailing: ZaloContactService.instance.buildZaloQuickButton(
                context,
                hs,
              ),
            ),
            _buildProfileRow(
              context,
              Icons.location_on_outlined,
              isVi ? 'Địa chỉ' : 'Address',
              hs.diaChi,
            ),
            _buildProfileRow(context, Icons.facebook, 'Facebook', hs.facebook),
            _buildProfileRow(
              context,
              Icons.card_membership_outlined,
              isVi ? 'Miễn giảm' : 'Discount',
              hs.mienGiam != null ? '${hs.mienGiam}%' : null,
            ),
            _buildProfileRow(
              context,
              Icons.event_available_outlined,
              isVi ? 'Số buổi dư' : 'Bonus sessions',
              '${hs.soBuoiDu} buổi',
            ),
            if (hs.ghiChu != null && hs.ghiChu!.isNotEmpty)
              _buildProfileRow(
                context,
                Icons.note_alt_outlined,
                isVi ? 'Ghi chú' : 'Notes',
                hs.ghiChu,
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(
    BuildContext context,
    IconData icon,
    String label,
    String? value,
  ) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
