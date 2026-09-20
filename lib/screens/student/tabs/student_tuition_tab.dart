import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/hoc_phi_tong_hop.dart';
import '../../../models/hs.dart';
import '../../../widgets/thu_tien_hoc_phi_dialog.dart';

class StudentTuitionTab extends StatelessWidget {
  final HS hocSinh;
  final Future<Map<String, dynamic>> hocPhiFuture;
  final VoidCallback onRefresh;

  const StudentTuitionTab({
    super.key,
    required this.hocSinh,
    required this.hocPhiFuture,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final currencyFmt = NumberFormat('#,##0', 'vi_VN');

    return FutureBuilder<Map<String, dynamic>>(
      future: hocPhiFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                isVi ? 'Lỗi tải dữ liệu học phí' : 'Error loading tuition data',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final conNoList = data['con_no'] as List<Map<String, dynamic>>? ?? [];
        final lichSuList = data['lich_su'] as List<Map<String, dynamic>>? ?? [];

        final tongNo = conNoList.fold<int>(
          0,
          (sum, item) => sum + (item['tien_no'] as int),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- DASHBOARD CARD ---
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            tongNo > 0
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            color: tongNo > 0
                                ? theme.colorScheme.error
                                : Colors.green.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isVi ? 'HỌC PHÍ TỔNG QUAN' : 'TUITION SUMMARY',
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
                      Text(
                        tongNo > 0
                            ? '${currencyFmt.format(tongNo)}đ'
                            : (isVi ? 'ĐÃ HOÀN THÀNH ✓' : 'PAID ✓'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: tongNo > 0
                              ? theme.colorScheme.error
                              : Colors.green.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tongNo > 0
                            ? (isVi
                                  ? 'Còn nợ (${conNoList.length} khoản)'
                                  : 'Outstanding debt')
                            : (isVi
                                  ? 'Học sinh không có nợ học phí'
                                  : 'No outstanding payments'),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (conNoList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              final item = conNoList.first;
                              final hsNo = HocSinhNoHocPhi(
                                idHocSinh: hocSinh.id!,
                                tenHocSinh: hocSinh.ten,
                                soTienCanNop:
                                    item['tong_thanh_toan'] as int? ?? 0,
                                soTienDaDong:
                                    item['so_tien_da_dong'] as int? ?? 0,
                                soTienConNo: item['tien_no'] as int? ?? 0,
                                mienGiam: hocSinh.mienGiam ?? 0,
                                soBuoiDu: hocSinh.soBuoiDu,
                                sdt: hocSinh.effectiveParentPhone,
                              );

                              final res = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => ThuTienHocPhiDialog(
                                  hocSinh: hsNo,
                                  thang: item['thang'] as String,
                                  soTienDaDongHienTai:
                                      item['so_tien_da_dong'] as int? ?? 0,
                                  idLop: item['id_lop'] as int,
                                ),
                              );

                              if (res == true) {
                                onRefresh();
                              }
                            },
                            icon: const Icon(Icons.payment, size: 18),
                            label: Text(
                              isVi ? 'THU HỌC PHÍ' : 'COLLECT TUITION',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // --- CHI TIẾT KHOẢN NỢ ---
              if (conNoList.isNotEmpty) ...[
                Text(
                  isVi ? 'CHI TIẾT THÁNG CÒN NỢ' : 'DEBT DETAILS BY MONTH',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: conNoList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final item = conNoList[i];
                    final tienNo = item['tien_no'] as int;
                    return Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.error.withOpacity(0.3),
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        title: Text(
                          '${item['ten_lop']} (${item['thang']})',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          'Đã đóng: ${currencyFmt.format(item['so_tien_da_dong'])}đ / ${currencyFmt.format(item['tong_thanh_toan'])}đ',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: Text(
                          '-${currencyFmt.format(tienNo)}đ',
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],

              // --- LỊCH SỬ GIAO DỊCH (VERTICAL TIMELINE) ---
              Text(
                isVi ? 'LỊCH SỬ GIAO DỊCH' : 'TRANSACTION HISTORY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              if (lichSuList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isVi
                            ? 'Chưa có giao dịch đóng học phí nào.'
                            : 'No payment transactions recorded yet.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lichSuList.length,
                  itemBuilder: (context, i) {
                    final tx = lichSuList[i];
                    return TransactionTimelineItem(
                      tx: tx,
                      isLast: i == lichSuList.length - 1,
                      currencyFmt: currencyFmt,
                      isVi: isVi,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class TransactionTimelineItem extends StatelessWidget {
  final Map<String, dynamic> tx;
  final bool isLast;
  final NumberFormat currencyFmt;
  final bool isVi;

  const TransactionTimelineItem({
    super.key,
    required this.tx,
    required this.isLast,
    required this.currencyFmt,
    required this.isVi,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = tx['so_tien_da_dong'] as int? ?? 0;
    final status = (tx['status'] as String?)?.toLowerCase();
    final lop = tx['ten_lop'] as String? ?? '';
    final thang = tx['thang'] as String? ?? '';
    final dateStr = tx['ngay_thanh_toan'] as String?;

    DateTime? dateObj;
    if (dateStr != null && dateStr.isNotEmpty) {
      dateObj = DateTime.tryParse(dateStr);
    }

    Color dotColor = Colors.green.shade600;
    String? statusBadgeText;
    Color statusBadgeColor = Colors.green.shade600;

    if (status == 'pending') {
      dotColor = Colors.amber.shade700;
      statusBadgeText = isVi ? 'Chờ duyệt' : 'Pending';
      statusBadgeColor = Colors.amber.shade700;
    } else if (status == 'failed' || status == 'rejected') {
      dotColor = theme.colorScheme.error;
      statusBadgeText = isVi ? 'Thất bại' : 'Failed';
      statusBadgeColor = theme.colorScheme.error;
    } else if (status == 'completed' || status == 'success') {
      dotColor = Colors.green.shade600;
      statusBadgeText = isVi ? 'Thành công' : 'Success';
      statusBadgeColor = Colors.green.shade600;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Rail
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 6),
                // Dot (8px)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: dotColor.withOpacity(0.35),
                        blurRadius: 3,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                // Vertical Connector Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Content Box
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '+${currencyFmt.format(amount)}đ',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: dotColor,
                          ),
                        ),
                        if (statusBadgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusBadgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: statusBadgeColor.withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              statusBadgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusBadgeColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (lop.isNotEmpty || thang.isNotEmpty)
                      Text(
                        lop.isNotEmpty && thang.isNotEmpty
                            ? '$lop • Tháng $thang'
                            : (lop.isNotEmpty ? lop : 'Tháng $thang'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (dateObj != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd/MM/yyyy • HH:mm').format(dateObj),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
