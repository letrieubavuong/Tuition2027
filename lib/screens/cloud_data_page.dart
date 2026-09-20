// File: lib/screens/cloud_data_page.dart

import 'package:flutter/material.dart';
import '../services/firebase_sync_service.dart';
import '../utils/toast_helper.dart';

class CloudDataPage extends StatefulWidget {
  const CloudDataPage({super.key});

  @override
  State<CloudDataPage> createState() => _CloudDataPageState();
}

class _CloudDataPageState extends State<CloudDataPage> {
  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _pushDataToCloud() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang đẩy dữ liệu lên Firebase Cloud...';
    });

    try {
      final count = await FirebaseSyncService.instance
          .pushAllLocalDataToCloud();
      if (!mounted) return;
      ToastHelper.showSuccess(
        context,
        'Đã đồng bộ $count bản ghi lên Firebase Cloud!',
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showError(context, 'Lỗi đồng bộ Cloud: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  Future<void> _pullDataFromCloud() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text(
              'Xác nhận khôi phục',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Hành động này sẽ GHI ĐÈ toàn bộ dữ liệu SQLite trên máy bằng dữ liệu mới nhất từ Firebase Cloud.\n\nBạn có chắc chắn muốn tiếp tục?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tải & Ghi đè'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang tải và ghi đè dữ liệu từ Firebase Cloud...';
    });

    try {
      final tableCount = await FirebaseSyncService.instance
          .pullAllCloudDataToLocal(isFullMirror: true);
      if (!mounted) return;
      ToastHelper.showSuccess(
        context,
        'Đã khôi phục thành công $tableCount bảng dữ liệu từ Firebase Cloud!',
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showError(context, 'Lỗi tải dữ liệu từ Cloud: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  Future<void> _showAuditDialog({bool deepAudit = false}) async {
    setState(() {
      _isLoading = true;
      _statusMessage = deepAudit
          ? 'Đang thực hiện đối soát sâu SHA-256...'
          : 'Đang kiểm tra đối soát dữ liệu...';
    });

    try {
      final audit = await FirebaseSyncService.instance.doiSoatDuLieuCloud(
        deepAudit: deepAudit,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      int totalLocal = 0;
      int totalCloud = 0;
      bool allMatched = true;

      audit.forEach((tbl, info) {
        final l = info['local'] as int? ?? 0;
        final c = info['cloud'] as int? ?? 0;
        final match = info['isMatch'] as bool? ?? (l == c);
        totalLocal += l;
        if (c >= 0) totalCloud += c;
        if (!match) allMatched = false;
      });

      showDialog(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  allMatched
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: allMatched ? Colors.green : Colors.orange,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deepAudit
                        ? 'Đối soát sâu SHA-256'
                        : 'Đối soát dữ liệu Cloud',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: allMatched
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            allMatched ? Icons.check_circle : Icons.info,
                            color: allMatched ? Colors.green : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              allMatched
                                  ? 'Dữ liệu Điện thoại ($totalLocal bản ghi) và Cloud ($totalCloud bản ghi) ${deepAudit ? "khớp SHA-256 100%!" : "khớp số lượng 100%!"}'
                                  : 'Máy: $totalLocal bản ghi | Cloud: $totalCloud bản ghi. Một số bảng chưa khớp.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: allMatched
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Chi tiết ${audit.length} bảng CSDL:',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!deepAudit)
                          InkWell(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              _showAuditDialog(deepAudit: true);
                            },
                            child: Text(
                              'Đối soát sâu SHA-256',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...audit.entries.map((entry) {
                      final tbl = entry.key;
                      final l = entry.value['local'] as int? ?? 0;
                      final c = entry.value['cloud'] as int? ?? 0;
                      final match = entry.value['isMatch'] as bool? ?? (l == c);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tbl,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Máy: $l | Cloud: ${c < 0 ? 'Lỗi' : c}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: match
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.error,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  match
                                      ? Icons.check_circle_outline
                                      : Icons.cancel_outlined,
                                  size: 15,
                                  color: match
                                      ? Colors.green
                                      : colorScheme.error,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              if (!allMatched)
                TextButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _pushDataToCloud();
                  },
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: const Text('Đẩy ngay'),
                ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
      ToastHelper.showError(context, 'Lỗi đối soát dữ liệu: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Dữ liệu & Cloud'), centerTitle: false),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_done_rounded,
                          color: colorScheme.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Đồng bộ Firebase Cloud',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sao lưu và sao chép dữ liệu giữa thiết bị cục bộ và Realtime Database.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Thao tác chính',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        Icons.cloud_upload_rounded,
                        color: colorScheme.primary,
                      ),
                      title: const Text('Đồng bộ lên Cloud'),
                      subtitle: const Text(
                        'Đẩy toàn bộ dữ liệu SQLite hiện tại lên Firebase Cloud',
                      ),
                      onTap: _isLoading ? null : _pushDataToCloud,
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    ListTile(
                      leading: Icon(
                        Icons.cloud_download_rounded,
                        color: colorScheme.error,
                      ),
                      title: const Text('Khôi phục từ Cloud'),
                      subtitle: const Text(
                        'Tải dữ liệu mới nhất từ Cloud và ghi đè dữ liệu máy',
                      ),
                      onTap: _isLoading ? null : _pullDataFromCloud,
                    ),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    ListTile(
                      leading: Icon(
                        Icons.fact_check_rounded,
                        color: colorScheme.secondary,
                      ),
                      title: const Text('Đối soát dữ liệu'),
                      subtitle: const Text(
                        'Kiểm tra và so sánh số lượng bản ghi giữa Máy và Cloud',
                      ),
                      onTap: _isLoading
                          ? null
                          : () => _showAuditDialog(deepAudit: false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Nâng cao',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  leading: Icon(
                    Icons.security_rounded,
                    color: colorScheme.tertiary,
                  ),
                  title: const Text('Đối soát sâu SHA-256'),
                  subtitle: const Text(
                    'So sánh mã băm SHA-256 từng dòng dữ liệu để đảm bảo toàn vẹn tuyệt đối',
                  ),
                  onTap: _isLoading
                      ? null
                      : () => _showAuditDialog(deepAudit: true),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
