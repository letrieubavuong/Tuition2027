// File: lib/screens/attention_queue_page.dart

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../models/attention_item.dart';
import '../services/attention_queue_service.dart';
import '../services/zalo_contact_service.dart';
import '../services/hoc_sinh_service.dart';
import 'hs_detail.dart';
import 'hocphi.dart';
import 'quan_ly_giao_dich_ngan_hang_page.dart';
import 'weekly_scheduling_page.dart';

class AttentionQueuePage extends StatefulWidget {
  const AttentionQueuePage({Key? key}) : super(key: key);

  @override
  State<AttentionQueuePage> createState() => _AttentionQueuePageState();
}

class _AttentionQueuePageState extends State<AttentionQueuePage> {
  final _attentionService = AttentionQueueService.instance;
  String _selectedCategory = 'all';
  List<AttentionItem> _items = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadItems();
    _attentionService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _attentionService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final items = await _attentionService.readAttentionQueue(
        categoryFilter: _selectedCategory,
        activeOnly: true,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
          _hasError = false;
          _errorMessage = '';
        });
      }
    } catch (e, st) {
      developer.log('Lỗi tải danh sách Việc Cần Xử Lý: $e', name: 'AttentionQueuePage', error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Không tải được Việc cần xử lý. Vui lòng thử lại.';
        });
      }
    }
  }

  Future<void> _handleRefresh() async {
    try {
      await _attentionService.refreshAttentionSources(force: true);
      await _loadItems();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi làm mới: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Việc Cần Xử Lý (Attention Queue)'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới nguồn',
            onPressed: () {
              setState(() => _isLoading = true);
              _handleRefresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? _buildErrorState()
                    : _items.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _handleRefresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                return _buildAttentionCard(_items[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'Tất cả'},
      {'key': 'student', 'label': 'Học sinh'},
      {'key': 'session', 'label': 'Buổi học'},
      {'key': 'payment', 'label': 'Học phí'},
      {'key': 'parent', 'label': 'Phụ huynh'},
      {'key': 'data', 'label': 'Dữ liệu'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedCategory == f['key'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = f['key']!;
                    _isLoading = true;
                  });
                  _loadItems();
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAttentionCard(AttentionItem item) {
    final theme = Theme.of(context);
    final isAcknowledged = item.status == AttentionStatus.acknowledged;

    Color badgeColor;
    String badgeIconStr;

    switch (item.severity) {
      case AttentionSeverity.critical:
        badgeColor = Colors.red;
        badgeIconStr = '🔴';
        break;
      case AttentionSeverity.warning:
        badgeColor = Colors.orange;
        badgeIconStr = '🟠';
        break;
      case AttentionSeverity.attention:
        badgeColor = Colors.amber;
        badgeIconStr = '🟡';
        break;
      case AttentionSeverity.info:
      default:
        badgeColor = Colors.blue;
        badgeIconStr = '🔵';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(badgeIconStr, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isAcknowledged) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '✓ Đã xem',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) => _handleMenuAction(item, val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'snooze_today',
                      child: Text('Nhắc lại chiều nay'),
                    ),
                    const PopupMenuItem(
                      value: 'snooze_tomorrow',
                      child: Text('Nhắc lại ngày mai'),
                    ),
                    const PopupMenuItem(
                      value: 'snooze_3days',
                      child: Text('Nhắc lại sau 3 ngày'),
                    ),
                    const PopupMenuDivider(),
                    if (!isAcknowledged)
                      const PopupMenuItem(
                        value: 'acknowledge',
                        child: Text('Đã xem'),
                      ),
                    const PopupMenuItem(
                      value: 'dismiss',
                      child: Text('Bỏ qua'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.summary,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isAcknowledged) ...[
                  OutlinedButton(
                    onPressed: () => _attentionService.acknowledge(item.id),
                    child: const Text('Đã xem'),
                  ),
                  const SizedBox(width: 8),
                ],
                ElevatedButton.icon(
                  onPressed: () => _handleItemPrimaryAction(item),
                  icon: const Icon(Icons.touch_app_rounded, size: 16),
                  label: Text(item.actionLabel.isNotEmpty ? item.actionLabel : 'Xử lý'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 64,
            color: Colors.green,
          ),
          SizedBox(height: 16),
          Text(
            'Không có việc cần xử lý',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Tất cả thông tin học tập & vận hành đều ổn định.',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadItems();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('THỬ LẠI'),
          ),
        ],
      ),
    );
  }

  void _handleItemPrimaryAction(AttentionItem item) async {
    // 1. PAYMENT_NEEDS_REVIEW -> Bank transaction management page
    if (item.type == AttentionType.PAYMENT_NEEDS_REVIEW || item.actionType == 'payment_review') {
      final txId = item.metadata['transactionId'] as int? ??
          int.tryParse(item.sourceId?.toString() ?? '');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuanLyGiaoDichNganHangPage(
              initialTransactionId: txId,
            ),
          ),
        );
      }
      return;
    }

    // 2. TUITION_REMINDER_DUE -> Tuition page
    if (item.type == AttentionType.TUITION_REMINDER_DUE || (item.actionType == 'payment' && item.type != AttentionType.PAYMENT_NEEDS_REVIEW)) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HocPhiPage()),
        );
      }
      return;
    }

    // 3. SCHEDULE_CONFLICT -> Weekly Scheduling Page
    if (item.type == AttentionType.SCHEDULE_CONFLICT || item.actionType == 'schedule') {
      if (item.classId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WeeklySchedulingPage(
              classId: item.classId!,
              className: item.className ?? 'Lớp #${item.classId}',
            ),
          ),
        );
      }
      return;
    }

    // 4. PARENT_CONTACT_PENDING or Zalo action -> Launch Zalo directly
    if (item.type == AttentionType.PARENT_CONTACT_PENDING || item.actionType == 'zalo') {
      if (item.studentId != null) {
        final hs = await HocSinhService().docHocSinhTheoId(item.studentId!);
        if (hs != null && mounted) {
          final preparedMsg = item.metadata['preparedMessage'] as String?;
          await ZaloContactService.instance.openParentZalo(
            context,
            hs,
            preparedMessage: preparedMsg,
          );
        }
      }
      _attentionService.acknowledge(item.id);
      return;
    }

    // 5. Default fallback -> Navigate to Student Detail Page
    if (item.studentId != null) {
      _navigateToStudent(item.studentId!);
    } else {
      _attentionService.acknowledge(item.id);
    }
  }

  void _navigateToStudent(int studentId) async {
    final hs = await HocSinhService().docHocSinhTheoId(studentId);
    if (hs != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HSDetail(hocSinh: hs)),
      );
    }
  }

  void _handleMenuAction(AttentionItem item, String action) {
    switch (action) {
      case 'snooze_today':
        _attentionService.snooze(item.id, duration: const Duration(hours: 6));
        break;
      case 'snooze_tomorrow':
        _attentionService.snooze(item.id, duration: const Duration(hours: 24));
        break;
      case 'snooze_3days':
        _attentionService.snooze(item.id, duration: const Duration(days: 3));
        break;
      case 'acknowledge':
        _attentionService.acknowledge(item.id);
        break;
      case 'dismiss':
        _attentionService.dismiss(item.id);
        break;
    }
  }
}
