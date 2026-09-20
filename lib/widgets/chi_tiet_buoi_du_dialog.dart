// File: lib/widgets/chi_tiet_buoi_du_dialog.dart

import 'package:flutter/material.dart';
import '../services/session_ledger_service.dart';

class ChiTietBuoiDuDialog extends StatefulWidget {
  final int studentId;
  final int classId;
  final String? monthYearFilter;

  const ChiTietBuoiDuDialog({
    Key? key,
    required this.studentId,
    required this.classId,
    this.monthYearFilter,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required int studentId,
    required int classId,
    String? monthYearFilter,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => ChiTietBuoiDuDialog(
        studentId: studentId,
        classId: classId,
        monthYearFilter: monthYearFilter,
      ),
    );
  }

  @override
  State<ChiTietBuoiDuDialog> createState() => _ChiTietBuoiDuDialogState();
}

class _ChiTietBuoiDuDialogState extends State<ChiTietBuoiDuDialog> {
  final SessionLedgerService _ledgerService = SessionLedgerService();
  bool _isLoading = true;
  StudentSessionBalanceResult? _result;
  String? _error;
  bool _showSessionDetails = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _ledgerService.rebuildStudentSessionBalance(
        widget.studentId,
        widget.classId,
        updateCacheInDb: false,
      );
      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải chi tiết buổi dư: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'CO_MAT':
        return Colors.green.shade700;
      case 'TRE':
        return Colors.orange.shade700;
      case 'VANG_CO_PHEP':
        return Colors.blue.shade700;
      case 'VANG_KHONG_PHEP':
        return Colors.red.shade700;
      case 'HOC_BU':
        return Colors.purple.shade700;
      case 'CANCELLED':
        return Colors.grey;
      case 'NO_RECORD':
      default:
        return Colors.blueGrey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'CO_MAT':
        return 'Có mặt';
      case 'TRE':
        return 'Đi trễ';
      case 'VANG_CO_PHEP':
        return 'Vắng có phép';
      case 'VANG_KHONG_PHEP':
        return 'Vắng không phép';
      case 'HOC_BU':
        return 'Học bù';
      case 'CANCELLED':
        return 'Hủy buổi';
      case 'NO_RECORD':
      default:
        return 'Chưa điểm danh';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.analytics_outlined, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _result != null
                  ? 'Chi tiết Buổi dư - ${_result!.studentName}'
                  : 'Chi tiết Buổi dư tích lũy',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 520,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            : _result == null || _result!.monthlyLedgers.isEmpty
            ? const Center(child: Text('Không có dữ liệu buổi dư'))
            : _buildContent(context),
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            setState(() {
              _showSessionDetails = !_showSessionDetails;
            });
          },
          icon: Icon(
            _showSessionDetails ? Icons.list_alt : Icons.calendar_view_day,
          ),
          label: Text(
            _showSessionDetails ? '[Ẩn từng buổi]' : '[Xem từng buổi]',
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final res = _result!;
    final ledgers = widget.monthYearFilter != null
        ? res.monthlyLedgers
              .where((m) => m.yearMonth == widget.monthYearFilter)
              .toList()
        : res.monthlyLedgers;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner tổng quan
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tham gia lớp từ: ${res.joinDate}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Lớp: ${res.className}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Số dư: ${res.currentBalance} buổi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Warnings tổng quát nếu có
          if (res.warnings.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'CẢNH BÁO DỮ LIỆU (DATA_WARNING):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  ...res.warnings.map(
                    (w) => Text('• $w', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Danh sách từng tháng
          ...ledgers.map((m) => _buildMonthCard(context, m)).toList(),
        ],
      ),
    );
  }

  Widget _buildMonthCard(BuildContext context, MonthSessionLedger month) {
    final yearMonthFormatted = 'THÁNG ${month.yearMonth}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  yearMonthFormatted,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.indigo,
                  ),
                ),
                Text(
                  'Dư cuối tháng: ${month.closingBalance}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: month.closingBalance > 0
                        ? Colors.green.shade700
                        : Colors.black87,
                  ),
                ),
              ],
            ),
            const Divider(),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildStatBadge(
                  'Lịch hợp lệ',
                  '${month.scheduledEligibleCount} buổi',
                ),
                _buildStatBadge('Có mặt', '${month.coMatCount}', Colors.green),
                _buildStatBadge('Đi trễ', '${month.treCount}', Colors.orange),
                _buildStatBadge(
                  'Vắng phép',
                  '${month.vangCoPhepCount}',
                  Colors.blue,
                ),
                _buildStatBadge(
                  'Vắng không phép',
                  '${month.vangKhongPhepCount}',
                  Colors.red,
                ),
                _buildStatBadge('Học bù', '${month.hocBuCount}', Colors.purple),
                _buildStatBadge(
                  'Phát sinh dư',
                  '+${month.earnedExtra}',
                  Colors.green.shade800,
                ),
              ],
            ),

            if (month.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...month.warnings.map(
                (w) => Text(
                  w,
                  style: const TextStyle(fontSize: 11, color: Colors.amber),
                ),
              ),
            ],

            if (_showSessionDetails) ...[
              const SizedBox(height: 12),
              const Text(
                'Lịch sử từng buổi học:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...month.sessions.map((s) => _buildSessionRow(s)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, [Color? color]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionRow(SessionLedgerItem session) {
    final statusColor = _getStatusColor(session.attendanceStatus);
    final statusLabel = _getStatusLabel(session.attendanceStatus);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: session.isEarnedExtra
            ? Colors.green.shade50
            : (session.isScheduledEligible
                  ? Colors.grey.shade50
                  : Colors.red.shade50),
        borderRadius: BorderRadius.circular(4),
        border: session.isEarnedExtra
            ? Border.all(color: Colors.green.shade300)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              session.date,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              session.dayOfWeek,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          const Spacer(),
          if (session.isEarnedExtra)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '+1 dư',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (!session.isScheduledEligible)
            const Text(
              '(K.thuộc lịch)',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}
