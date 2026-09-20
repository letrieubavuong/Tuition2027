// File: lib/widgets/attention_queue_summary_card.dart

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../services/attention_queue_service.dart';
import '../screens/attention_queue_page.dart';

class AttentionQueueSummaryCard extends StatefulWidget {
  const AttentionQueueSummaryCard({Key? key}) : super(key: key);

  @override
  State<AttentionQueueSummaryCard> createState() =>
      _AttentionQueueSummaryCardState();
}

class _AttentionQueueSummaryCardState extends State<AttentionQueueSummaryCard> {
  final _attentionService = AttentionQueueService.instance;
  Map<String, int> _counts = {'urgent': 0, 'high': 0, 'normal': 0, 'total': 0};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
    _attentionService.addListener(_loadCounts);
  }

  @override
  void dispose() {
    _attentionService.removeListener(_loadCounts);
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      final counts = await _attentionService.getSummaryCounts();
      if (mounted) {
        setState(() {
          _counts = counts;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      developer.log('Lỗi tải đếm summary AttentionQueue: $e', name: 'AttentionQueueSummaryCard', error: e, stackTrace: st);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _counts['total'] ?? 0;
    final urgent = _counts['urgent'] ?? 0;
    final high = _counts['high'] ?? 0;
    final normal = _counts['normal'] ?? 0;

    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AttentionQueuePage()),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: total > 0
                              ? Colors.redAccent.withValues(alpha: 0.15)
                              : Colors.green.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          total > 0
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline_rounded,
                          color: total > 0 ? Colors.redAccent : Colors.green,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VIỆC CẦN THẦY XỬ LÝ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            total > 0
                                ? '$total việc đang chờ phản hồi'
                                : 'Tất cả việc đã hoàn tất',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AttentionQueuePage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    label: const Text('Xem tất cả'),
                  ),
                ],
              ),
              if (total > 0) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (urgent > 0)
                      _buildTag(
                        '🔴 $urgent Khẩn cấp',
                        Colors.red.shade100,
                        Colors.red.shade900,
                      ),
                    if (high > 0)
                      _buildTag(
                        '🟠 $high Cần chú ý',
                        Colors.orange.shade100,
                        Colors.orange.shade900,
                      ),
                    if (normal > 0)
                      _buildTag(
                        '🟡 $normal Nhắc việc',
                        Colors.amber.shade100,
                        Colors.amber.shade900,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
