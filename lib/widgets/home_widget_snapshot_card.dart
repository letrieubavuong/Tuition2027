// File: lib/widgets/home_widget_snapshot_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/home_widget_snapshot.dart';
import '../screens/diem_danh_page.dart';

enum HomeWidgetAction {
  attendance,
  sessionClose,
  attention,
  tuition,
  parents,
  students,
  dailyBrief,
  refresh,
}

class HomeWidgetActionPayload {
  final HomeWidgetAction action;
  final int? classId;
  final int? scheduleId;
  final DateTime? date;

  const HomeWidgetActionPayload({
    required this.action,
    this.classId,
    this.scheduleId,
    this.date,
  });
}

class HomeWidgetSnapshotCard extends StatelessWidget {
  final HomeWidgetSnapshot snapshot;
  final VoidCallback? onRefresh;
  final Function(String route)? onNavigate;
  final Function(HomeWidgetActionPayload payload)? onNavigatePayload;

  const HomeWidgetSnapshotCard({
    super.key,
    required this.snapshot,
    this.onRefresh,
    this.onNavigate,
    this.onNavigatePayload,
  });

  bool get _isValidDate {
    final clean = snapshot.date.trim();
    if (clean.isEmpty) return false;
    return DateTime.tryParse(clean) != null;
  }

  String _formatTimeDisplay(String? start, String? end) {
    final cleanStart = start?.trim();
    final cleanEnd = end?.trim();
    final hasStart = cleanStart != null && cleanStart.isNotEmpty;
    final hasEnd = cleanEnd != null && cleanEnd.isNotEmpty;

    if (hasStart && hasEnd) {
      return '$cleanStart–$cleanEnd';
    } else if (hasStart) {
      return 'Bắt đầu $cleanStart';
    } else if (hasEnd) {
      return 'Kết thúc $cleanEnd';
    } else {
      return 'Chưa có thời gian';
    }
  }

  void _dispatchAction(
    BuildContext context,
    HomeWidgetAction action, {
    int? classId,
    int? scheduleId,
    DateTime? date,
  }) {
    // REQUIREMENT 4: If date is invalid, do not deep-link
    if (action != HomeWidgetAction.refresh &&
        action != HomeWidgetAction.attention &&
        action != HomeWidgetAction.tuition &&
        action != HomeWidgetAction.parents &&
        action != HomeWidgetAction.students &&
        action != HomeWidgetAction.dailyBrief &&
        !_isValidDate) {
      return;
    }

    final payload = HomeWidgetActionPayload(
      action: action,
      classId: classId,
      scheduleId: scheduleId,
      date: date,
    );

    if (onNavigatePayload != null) {
      onNavigatePayload!(payload);
      return;
    }

    switch (action) {
      case HomeWidgetAction.attendance:
        if (classId != null && classId > 0 && date != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DiemDanhPage(
                selectedLopId: classId,
                selectedDate: date,
                selectedScheduleId: scheduleId,
              ),
            ),
          );
        } else {
          onNavigate?.call('diemdanh');
        }
        break;
      case HomeWidgetAction.sessionClose:
        // REQUIREMENT 1: Do NOT fallback to DiemDanhPage for sessionClose
        onNavigate?.call('session_close');
        break;
      case HomeWidgetAction.dailyBrief:
        // REQUIREMENT 2: Route dailyBrief to daily_brief, NOT attention
        onNavigate?.call('daily_brief');
        break;
      case HomeWidgetAction.refresh:
        onRefresh?.call();
        break;
      case HomeWidgetAction.attention:
        onNavigate?.call('attention');
        break;
      case HomeWidgetAction.tuition:
        onNavigate?.call('tuition');
        break;
      case HomeWidgetAction.parents:
        onNavigate?.call('parents');
        break;
      case HomeWidgetAction.students:
        onNavigate?.call('students');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final state = snapshot.operationalState;

    final dateDisplay = snapshot.dateFormatted.isNotEmpty
        ? snapshot.dateFormatted
        : (snapshot.date.isNotEmpty ? snapshot.date : 'Chưa xác định ngày');

    final timeStr = DateFormat('HH:mm').format(snapshot.lastUpdatedAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── TIER A: CONTEXT HEADER ───
          _buildTierAHeader(context, dateDisplay),

          const Divider(height: 1, thickness: 1),

          // ─── TIER B: PRIMARY ACTION BOX ───
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildTierBPrimaryBox(context, state),
          ),

          const Divider(height: 1, thickness: 1),

          // ─── TIER C: EXCEPTIONS GRID ───
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _buildTierCExceptions(context),
          ),

          const Divider(height: 1, thickness: 1),

          // ─── FOOTER SUMMARY & FRESHNESS ───
          _buildFooter(context, timeStr),
        ],
      ),
    );
  }

  // ─── TIER A HEADER ───
  Widget _buildTierAHeader(BuildContext context, String dateDisplay) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final total = snapshot.todaySessionCount;
    final completed = snapshot.completedSessionCount;

    Color badgeBg = colorScheme.surfaceContainerHigh;
    Color badgeFg = colorScheme.onSurfaceVariant;
    BorderSide badgeBorder = BorderSide.none;

    if (total > 0) {
      if (completed == total) {
        badgeBg = Colors.green.withValues(alpha: 0.15);
        badgeFg = Colors.green;
        badgeBorder = BorderSide(color: Colors.green.shade400, width: 1);
      } else if (completed > 0) {
        badgeBg = colorScheme.primaryContainer;
        badgeFg = colorScheme.onPrimaryContainer;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateDisplay,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${snapshot.todaySessionCount} ca • ${snapshot.todayTotalStudents > 0 ? snapshot.todayTotalStudents : 0} HS dự kiến',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
                border: badgeBorder != BorderSide.none
                    ? Border.all(color: badgeBorder.color, width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    completed == total ? Icons.check_circle : Icons.schedule,
                    size: 14,
                    color: badgeFg,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '✓ $completed/$total xong',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: badgeFg,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── TIER B PRIMARY BOX ───
  Widget _buildTierBPrimaryBox(
    BuildContext context,
    HomeWidgetOperationalState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final parsedDate = DateTime.tryParse(snapshot.date.trim());
    final isDateValid = parsedDate != null;

    switch (state) {
      case HomeWidgetOperationalState.currentSession:
        final timeDisplay = _formatTimeDisplay(
          snapshot.currentStart,
          snapshot.currentEnd,
        );
        final className = snapshot.currentSessionName ?? 'Lớp học';

        String attendanceText;
        if (snapshot.currentResolvedCount == 0) {
          attendanceText =
              '○ Chưa điểm danh (${snapshot.currentTotalCount} HS)';
        } else if (snapshot.currentResolvedCount < snapshot.currentTotalCount) {
          attendanceText =
              '● Đang điểm danh ${snapshot.currentResolvedCount}/${snapshot.currentTotalCount} • Còn ${snapshot.currentUnresolvedCount} HS';
        } else {
          attendanceText =
              '✓ Điểm danh hoàn tất (${snapshot.currentTotalCount} HS)';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Đang dạy',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$timeDisplay • $className',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              attendanceText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (!isDateValid) ...[
              const SizedBox(height: 4),
              Text(
                'Dữ liệu ngày chưa hợp lệ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isDateValid
                    ? () => _dispatchAction(
                        context,
                        HomeWidgetAction.attendance,
                        classId: snapshot.effectiveCurrentClassId,
                        scheduleId: snapshot.currentScheduleId,
                        date: parsedDate,
                      )
                    : null,
                icon: const Icon(Icons.touch_app, size: 18),
                label: const Text('TIẾP TỤC ĐIỂM DANH'),
              ),
            ),
          ],
        );

      case HomeWidgetOperationalState.nextSession:
        final timeDisplay = _formatTimeDisplay(
          snapshot.nextStart,
          snapshot.nextEnd,
        );
        final className = snapshot.nextSessionName ?? 'Lớp học';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Ca tiếp theo',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$timeDisplay • $className',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sĩ số dự kiến: ${snapshot.nextTotalCount} HS',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (!isDateValid) ...[
              const SizedBox(height: 4),
              Text(
                'Dữ liệu ngày chưa hợp lệ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isDateValid
                    ? () => _dispatchAction(
                        context,
                        HomeWidgetAction.attendance,
                        classId: snapshot.effectiveNextClassId,
                        scheduleId: snapshot.nextScheduleId,
                        date: parsedDate,
                      )
                    : null,
                icon: const Icon(Icons.edit_calendar, size: 18),
                label: const Text('CHUẨN BỊ ĐIỂM DANH'),
              ),
            ),
          ],
        );

      case HomeWidgetOperationalState.sessionEnded:
        final className =
            snapshot.currentSessionName ??
            snapshot.nextSessionName ??
            'Lớp vừa kết thúc';
        final attText = snapshot.attendanceDone
            ? '✓ Điểm danh'
            : '○ Chưa điểm danh';
        final revText = snapshot.reviewDone ? '✓ Đánh giá' : '○ Chưa đánh giá';
        final hwText = snapshot.homeworkDone
            ? '✓ Giao BTVN'
            : '○ Chưa giao BTVN';
        final paText = snapshot.parentActionPending > 0
            ? '${snapshot.parentActionPending} PH cần xử lý'
            : '✓ PH ổn';
        final checklistText = '$attText • $revText • $hwText • $paText';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Ca vừa kết thúc',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              className,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              checklistText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (!isDateValid) ...[
              const SizedBox(height: 4),
              Text(
                'Dữ liệu ngày chưa hợp lệ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                ),
                onPressed: isDateValid
                    ? () => _dispatchAction(
                        context,
                        HomeWidgetAction.sessionClose,
                        classId: snapshot.effectiveCurrentClassId > 0
                            ? snapshot.effectiveCurrentClassId
                            : snapshot.effectiveNextClassId,
                        scheduleId:
                            snapshot.currentScheduleId ??
                            snapshot.nextScheduleId,
                        date: parsedDate,
                      )
                    : null,
                icon: const Icon(Icons.fact_check_outlined, size: 18),
                label: const Text('KẾT THÚC CA'),
              ),
            ),
          ],
        );

      case HomeWidgetOperationalState.morning:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hôm nay',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Có ${snapshot.todaySessionCount} ca dạy (${snapshot.todayTotalStudents} HS dự kiến)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              snapshot.dailyBriefSummary != null &&
                      snapshot.dailyBriefSummary!.isNotEmpty
                  ? snapshot.dailyBriefSummary!
                  : 'Chuẩn bị cho ngày làm việc',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    _dispatchAction(context, HomeWidgetAction.dailyBrief),
                icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                label: const Text('XEM DAILY BRIEF'),
              ),
            ),
          ],
        );

      case HomeWidgetOperationalState.eveningSummary:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng kết hôm nay',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '✓ Hoàn tất ${snapshot.completedSessionCount}/${snapshot.todaySessionCount} ca dạy',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              snapshot.dailyBriefSummary != null &&
                      snapshot.dailyBriefSummary!.isNotEmpty
                  ? snapshot.dailyBriefSummary!
                  : 'Tất cả ca hôm nay đã xong',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (snapshot.attentionCount > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      _dispatchAction(context, HomeWidgetAction.attention),
                  icon: const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 18,
                  ),
                  label: const Text('XEM VIỆC CẦN XỬ LÝ'),
                ),
              ),
            ],
          ],
        );

      case HomeWidgetOperationalState.stale:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  'Dữ liệu có thể đã cũ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Cập nhật lần cuối: ${DateFormat('HH:mm').format(snapshot.lastUpdatedAt)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    _dispatchAction(context, HomeWidgetAction.refresh),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('LÀM MỚI'),
              ),
            ),
          ],
        );

      case HomeWidgetOperationalState.noSession:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hôm nay không có ca',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hôm nay không có ca học',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              snapshot.attentionCount == 0
                  ? '✓ Không có việc cần xử lý'
                  : '⚠ Có ${snapshot.attentionCount} việc cần xử lý',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: snapshot.attentionCount > 0
                    ? Colors.orange.shade700
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
    }
  }

  // ─── TIER C EXCEPTIONS ───
  Widget _buildTierCExceptions(BuildContext context) {
    final totalExceptions =
        snapshot.attentionCount +
        snapshot.tuitionReminderCount +
        snapshot.parentContactPendingCount +
        snapshot.studentAttentionCount;

    if (totalExceptions == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
            SizedBox(width: 8),
            Text(
              '✓ Không có ngoại lệ cần xử lý',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                context,
                icon: Icons.priority_high_rounded,
                title: 'CẦN XỬ LÝ',
                value: '${snapshot.attentionCount} việc',
                isHighlighted: snapshot.attentionCount > 0,
                onTap: () =>
                    _dispatchAction(context, HomeWidgetAction.attention),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                context,
                icon: Icons.payments_outlined,
                title: 'HỌC PHÍ',
                value: '${snapshot.tuitionReminderCount} PH nhắc',
                isHighlighted: snapshot.tuitionReminderCount > 0,
                onTap: () => _dispatchAction(context, HomeWidgetAction.tuition),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                context,
                icon: Icons.forum_outlined,
                title: 'PHỤ HUYNH',
                value: '${snapshot.parentContactPendingCount} chưa LH',
                isHighlighted: snapshot.parentContactPendingCount > 0,
                onTap: () => _dispatchAction(context, HomeWidgetAction.parents),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                context,
                icon: Icons.school_outlined,
                title: 'HỌC SINH',
                value: '${snapshot.studentAttentionCount} chú ý',
                isHighlighted: snapshot.studentAttentionCount > 0,
                onTap: () =>
                    _dispatchAction(context, HomeWidgetAction.students),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required bool isHighlighted,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bg = isHighlighted
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;
    final border = isHighlighted
        ? colorScheme.primary.withValues(alpha: 0.3)
        : colorScheme.outlineVariant.withValues(alpha: 0.3);
    final iconColor = isHighlighted
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isHighlighted
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── FOOTER ───
  Widget _buildFooter(BuildContext context, String timeStr) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String footerSummaryText;
    if (snapshot.criticalCount > 0) {
      footerSummaryText =
          'Có ${snapshot.criticalCount} việc quan trọng cần xử lý';
    } else if (snapshot.attentionCount > 0) {
      footerSummaryText = 'Còn ${snapshot.attentionCount} việc cần xử lý';
    } else if (snapshot.dailyBriefSummary != null &&
        snapshot.dailyBriefSummary!.isNotEmpty) {
      footerSummaryText = snapshot.dailyBriefSummary!;
    } else {
      footerSummaryText = 'Mọi việc đang ổn';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
      ),
      child: Row(
        children: [
          Icon(
            snapshot.criticalCount > 0
                ? Icons.error_outline
                : Icons.verified_user_outlined,
            size: 16,
            color: snapshot.criticalCount > 0
                ? colorScheme.error
                : colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              footerSummaryText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            'Cập nhật $timeStr',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          if (onRefresh != null) ...[
            const SizedBox(width: 2),
            IconButton(
              onPressed: () =>
                  _dispatchAction(context, HomeWidgetAction.refresh),
              icon: Icon(Icons.refresh, size: 18, color: colorScheme.primary),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              tooltip: 'Làm mới',
            ),
          ],
        ],
      ),
    );
  }
}
