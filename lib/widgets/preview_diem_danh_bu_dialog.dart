// File: lib/widgets/preview_diem_danh_bu_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionPreviewItem {
  final String dateStr;
  final String dayOfWeek;
  final String timeSlot;
  final String action; // 'KEEP', 'SKIP', 'INSERT'
  final String reason;
  final int hsCount;

  SessionPreviewItem({
    required this.dateStr,
    required this.dayOfWeek,
    required this.timeSlot,
    required this.action,
    required this.reason,
    required this.hsCount,
  });
}

class PreviewDiemDanhBuDialog extends StatefulWidget {
  final String tenLop;
  final String thangStr; // 'MM/YYYY'
  final int totalScheduled;
  final int holidayCount;
  final int existingCount;
  final int outsideParticipationCount;
  final int insertCount;
  final List<SessionPreviewItem> sessions;

  const PreviewDiemDanhBuDialog({
    super.key,
    required this.tenLop,
    required this.thangStr,
    required this.totalScheduled,
    required this.holidayCount,
    required this.existingCount,
    this.outsideParticipationCount = 0,
    required this.insertCount,
    required this.sessions,
  });

  @override
  State<PreviewDiemDanhBuDialog> createState() =>
      _PreviewDiemDanhBuDialogState();
}

class _PreviewDiemDanhBuDialogState extends State<PreviewDiemDanhBuDialog> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.fact_check_rounded,
              color: theme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Xem Trước Điểm Danh Bù',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Lớp: ${widget.tenLop} • Tháng ${widget.thangStr}',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thống kê tổng quan
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    _buildStatRow(
                      'Theo lịch học:',
                      '${widget.totalScheduled} ca',
                      Colors.blue,
                    ),
                    const Divider(height: 12),
                    _buildStatRow(
                      'Nghỉ lễ / Nghỉ chung (SKIP):',
                      '${widget.holidayCount} ca',
                      Colors.orange,
                    ),
                    _buildStatRow(
                      'Đã có dữ liệu (KEEP):',
                      '${widget.existingCount} ca/hs',
                      Colors.green,
                    ),
                    if (widget.outsideParticipationCount > 0)
                      _buildStatRow(
                        'Không thuộc thời gian học (SKIP):',
                        '${widget.outsideParticipationCount} ca/hs',
                        Colors.grey,
                      ),
                    const Divider(height: 12),
                    _buildStatRow(
                      'Sẽ bổ sung Có mặt (INSERT):',
                      '${widget.insertCount} bản ghi',
                      theme.primaryColor,
                      isBold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Nút bật/tắt xem từng buổi
              InkWell(
                onTap: () => setState(() => _showDetails = !_showDetails),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _showDetails
                            ? 'Ẩn chi tiết từng buổi'
                            : 'Xem chi tiết từng buổi (${widget.sessions.length})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      Icon(
                        _showDetails
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: theme.primaryColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

              if (_showDetails) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, idx) {
                      final s = widget.sessions[idx];
                      Color badgeColor;
                      String badgeText;

                      if (s.action == 'INSERT') {
                        badgeColor = Colors.green;
                        badgeText = 'INSERT';
                      } else if (s.action == 'SKIP') {
                        badgeColor = Colors.orange;
                        badgeText = 'SKIP';
                      } else {
                        badgeColor = Colors.grey;
                        badgeText = 'KEEP';
                      }

                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        title: Row(
                          children: [
                            Text(
                              '${s.dateStr} (${s.dayOfWeek})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: badgeColor.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          '${s.timeSlot} • ${s.reason}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.hintColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        ElevatedButton.icon(
          onPressed: widget.insertCount > 0
              ? () => Navigator.pop(context, true)
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.check_circle_rounded, size: 16),
          label: Text('Xác Nhận Chèn (${widget.insertCount})'),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
