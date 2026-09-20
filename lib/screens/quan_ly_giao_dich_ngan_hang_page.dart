// File: lib/screens/quan_ly_giao_dich_ngan_hang_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/db.dart';
import '../services/bank_parsers/bank_notification_parser.dart';
import '../services/payment_coordinator.dart';

class QuanLyGiaoDichNganHangPage extends StatefulWidget {
  final int? initialTransactionId;

  const QuanLyGiaoDichNganHangPage({Key? key, this.initialTransactionId})
    : super(key: key);

  @override
  State<QuanLyGiaoDichNganHangPage> createState() =>
      _QuanLyGiaoDichNganHangPageState();
}

class _QuanLyGiaoDichNganHangPageState extends State<QuanLyGiaoDichNganHangPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DBHelper _dbHelper = DBHelper.instance;
  final PaymentCoordinator _paymentCoordinator = PaymentCoordinator();
  final NumberFormat _currencyFormat = NumberFormat('#,##0', 'vi_VN');

  bool _isLoading = true;
  List<Map<String, dynamic>> _confirmedList = [];
  List<Map<String, dynamic>> _needReviewList = [];
  List<Map<String, dynamic>> _unmatchedList = [];
  List<Map<String, dynamic>> _rejectedList = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTransactions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final db = await _dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT PT.*, HS.ten as ten_hoc_sinh, L.ten as ten_lop
        FROM payment_transactions PT
        LEFT JOIN ${DBHelper.tenBangHS} HS ON PT.hoc_sinh_id = HS.id
        LEFT JOIN ${DBHelper.tenBangLop} L ON PT.lop_id = L.id
        ORDER BY PT.created_at DESC
      ''');

      final confirmed = <Map<String, dynamic>>[];
      final needReview = <Map<String, dynamic>>[];
      final unmatched = <Map<String, dynamic>>[];
      final rejected = <Map<String, dynamic>>[];

      for (var r in rows) {
        final status = (r['status'] as String? ?? '').toUpperCase();
        if (status == 'CONFIRMED' || status == 'SUCCESS') {
          confirmed.add(r);
        } else if (status == 'NEED_REVIEW' || status == 'PENDING') {
          needReview.add(r);
        } else if (status == 'UNMATCHED') {
          unmatched.add(r);
        } else {
          rejected.add(r);
        }
      }

      if (mounted) {
        setState(() {
          _confirmedList = confirmed;
          _needReviewList = needReview;
          _unmatchedList = unmatched;
          _rejectedList = rejected;
          _isLoading = false;
        });

        if (widget.initialTransactionId != null) {
          final targetId = widget.initialTransactionId;
          int targetTab = -1;
          if (needReview.any((e) => e['id'] == targetId)) {
            targetTab = 1;
          } else if (unmatched.any((e) => e['id'] == targetId)) {
            targetTab = 2;
          } else if (confirmed.any((e) => e['id'] == targetId)) {
            targetTab = 0;
          } else if (rejected.any((e) => e['id'] == targetId)) {
            targetTab = 3;
          }

          if (targetTab != -1) {
            _tabController.animateTo(targetTab);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải nhật ký giao dịch: $e')),
        );
      }
    }
  }

  Future<void> _handleManualMatchDialog(Map<String, dynamic> txRow) async {
    final db = await _dbHelper.database;
    final hsRows = await db.query(DBHelper.tenBangHS, orderBy: 'ten ASC');
    final lopRows = await db.query(DBHelper.tenBangLop, orderBy: 'ten ASC');

    int? selectedHsId = txRow['hoc_sinh_id'] != 0 ? txRow['hoc_sinh_id'] : null;
    int? selectedLopId = txRow['lop_id'] != 0 ? txRow['lop_id'] : null;
    String monthStr = (txRow['month'] as String? ?? '').isNotEmpty
        ? txRow['month']
        : DateFormat('yyyy-MM').format(DateTime.now());

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.style_outlined, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Ghép Học Sinh & Xác Nhận'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nội dung CK: ${txRow['raw_content'] ?? txRow['transaction_id']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Số tiền: ${_currencyFormat.format(txRow['amount'])}đ',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedHsId,
                  decoration: const InputDecoration(
                    labelText: 'Chọn Học sinh',
                    border: OutlineInputBorder(),
                  ),
                  items: hsRows
                      .map(
                        (h) => DropdownMenuItem<int>(
                          value: h['id'] as int,
                          child: Text('${h['ten']} (#${h['id']})'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedHsId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: selectedLopId,
                  decoration: const InputDecoration(
                    labelText: 'Chọn Lớp học',
                    border: OutlineInputBorder(),
                  ),
                  items: lopRows
                      .map(
                        (l) => DropdownMenuItem<int>(
                          value: l['id'] as int,
                          child: Text(l['ten'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedLopId = val),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: monthStr,
                  decoration: const InputDecoration(
                    labelText: 'Tháng (YYYY-MM)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => monthStr = val.trim(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed:
                  (selectedHsId == null ||
                      selectedLopId == null ||
                      monthStr.isEmpty)
                  ? null
                  : () => Navigator.of(ctx).pop(true),
              child: const Text('Xác nhận Thu'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedHsId != null && selectedLopId != null) {
      final candidate = BankTransactionCandidate(
        bankCode: txRow['bank_code'] ?? 'manual',
        direction: 'CREDIT',
        amount: txRow['amount'] as int,
        transactionId: txRow['transaction_id'] as String?,
        transferContent: txRow['raw_content'] ?? '',
        rawFingerprint: txRow['raw_fingerprint'] ?? '',
        packageName: 'manual',
        rawTitle: 'Manual Match',
        rawText: txRow['raw_content'] ?? '',
      );

      try {
        await _paymentCoordinator.confirmPaymentAtomic(
          candidate: candidate,
          studentId: selectedHsId!,
          classId: selectedLopId!,
          month: monthStr,
          matchMethod: 'MANUAL',
          teacherNote: 'Giáo viên ghép thủ công',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Đã xác nhận thu học phí thành công!'),
            ),
          );
          _loadTransactions();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi xác nhận thu: $e')));
        }
      }
    }
  }

  Future<void> _ignoreTransaction(int recordId) async {
    final db = await _dbHelper.database;
    await db.update(
      'payment_transactions',
      {'status': 'REJECTED'},
      where: 'id = ?',
      whereArgs: [recordId],
    );
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao Dịch Ngân Hàng'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: '✓ Đã xác nhận (${_confirmedList.length})'),
            Tab(text: '? Cần duyệt (${_needReviewList.length})'),
            Tab(text: '○ Chưa khớp (${_unmatchedList.length})'),
            Tab(text: '! Bỏ qua / Lỗi (${_rejectedList.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(_confirmedList, isConfirmedTab: true),
                _buildTransactionList(_needReviewList, isReviewTab: true),
                _buildTransactionList(_unmatchedList, isUnmatchedTab: true),
                _buildTransactionList(_rejectedList),
              ],
            ),
    );
  }

  Widget _buildTransactionList(
    List<Map<String, dynamic>> items, {
    bool isConfirmedTab = false,
    bool isReviewTab = false,
    bool isUnmatchedTab = false,
  }) {
    if (items.isEmpty) {
      return const Center(child: Text('Không có giao dịch nào trong mục này'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (ctx, idx) {
        final item = items[idx];
        final id = item['id'] as int?;
        final isHighlight =
            (widget.initialTransactionId != null &&
            id == widget.initialTransactionId);
        final amount = item['amount'] as int? ?? 0;
        final hsName = item['ten_hoc_sinh'] as String? ?? 'Chưa xác định';
        final className = item['ten_lop'] as String? ?? '';
        final month = item['month'] as String? ?? '';
        final bankCode = (item['bank_code'] as String? ?? 'N/A').toUpperCase();
        final rawContent =
            item['raw_content'] as String? ?? item['transaction_id'] ?? '';
        final reason = item['failure_reason'] as String? ?? '';
        final matchMethod = item['match_method'] as String? ?? '';
        final createdAt = item['created_at'] as String? ?? '';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: isHighlight ? Colors.amber.shade50 : null,
          shape: isHighlight
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.amber.shade700, width: 2),
                )
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isConfirmedTab
                  ? Colors.green.shade100
                  : (isReviewTab
                        ? Colors.amber.shade100
                        : Colors.grey.shade200),
              child: Icon(
                isConfirmedTab
                    ? Icons.check_circle
                    : (isReviewTab ? Icons.help_outline : Icons.phonelink_ring),
                color: isConfirmedTab
                    ? Colors.green
                    : (isReviewTab
                          ? Colors.amber.shade900
                          : Colors.grey.shade700),
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '+${_currencyFormat.format(amount)}đ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    bankCode,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (hsName != 'Chưa xác định')
                  Text(
                    'Học sinh: $hsName ${className.isNotEmpty ? "($className)" : ""} • Tháng: $month',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                Text(
                  'Nội dung: $rawContent',
                  style: const TextStyle(fontSize: 11),
                ),
                if (reason.isNotEmpty)
                  Text(
                    'Ghi chú/Lý do: $reason',
                    style: const TextStyle(fontSize: 11, color: Colors.amber),
                  ),
                if (createdAt.isNotEmpty)
                  Text(
                    'Thời gian: $createdAt • Phương thức: $matchMethod',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
            trailing: (isReviewTab || isUnmatchedTab)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.link, color: Colors.indigo),
                        tooltip: 'Ghép học sinh',
                        onPressed: () => _handleManualMatchDialog(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Bỏ qua',
                        onPressed: () => _ignoreTransaction(item['id'] as int),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}
