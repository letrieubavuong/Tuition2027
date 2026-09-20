import 'package:flutter/material.dart';

import '../../../models/hs.dart';
import '../../../services/zalo_contact_service.dart';
import '../student_detail_page.dart';

class StudentProfileHeader extends StatelessWidget {
  final HS hocSinh;
  final Future<StudentClassInfo> classInfoFuture;
  final Future<Map<String, dynamic>> hocPhiFuture;
  final VoidCallback onEditInfo;
  final VoidCallback onSchedule;
  final VoidCallback onRefresh;
  final VoidCallback onDelete;

  const StudentProfileHeader({
    super.key,
    required this.hocSinh,
    required this.classInfoFuture,
    required this.hocPhiFuture,
    required this.onEditInfo,
    required this.onSchedule,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Large Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  hocSinh.ten.isNotEmpty ? hocSinh.ten[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. School & Status (Student name is in AppBar)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hocSinh.truongDangHoc != null &&
                        hocSinh.truongDangHoc!.trim().isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hocSinh.truongDangHoc!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Real Status Badges & Zalo Button
                    FutureBuilder<List<dynamic>>(
                      future: Future.wait([classInfoFuture, hocPhiFuture]),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();

                        final classInfo = snapshot.data![0] as StudentClassInfo;
                        final hpData =
                            snapshot.data![1] as Map<String, dynamic>;

                        final conNoList =
                            hpData['con_no'] as List<Map<String, dynamic>>? ??
                            [];
                        final hasDebt = conNoList.isNotEmpty;

                        return Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (classInfo.dsLop.isNotEmpty)
                              _buildBadge(
                                context,
                                isVi
                                    ? '${classInfo.dsLop.length} lớp đang học'
                                    : 'Enrolled in ${classInfo.dsLop.length} classes',
                                Colors.green.shade600,
                              ),
                            if (hasDebt)
                              _buildBadge(
                                context,
                                isVi ? 'Nợ học phí' : 'Tuition debt',
                                theme.colorScheme.error,
                              ),
                            ZaloContactService.instance.buildZaloQuickButton(
                              context,
                              hocSinh,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 3. Quick Actions Row: [ Lịch học ] [ ⋮ Menu ]
          Row(
            children: [
              // Schedule Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onSchedule,
                icon: Icon(
                  Icons.calendar_month_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                label: Text(
                  isVi ? 'Lịch học' : 'Schedule',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),

              const Spacer(),

              // Overflow Popup Menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEditInfo();
                  } else if (value == 'refresh') {
                    onRefresh();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(isVi ? 'Sửa thông tin' : 'Edit info'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(isVi ? 'Làm mới' : 'Refresh'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVi ? 'Xóa học sinh' : 'Delete student',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
