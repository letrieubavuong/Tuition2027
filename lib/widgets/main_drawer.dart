// File: lib/widgets/main_drawer.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tuition2025/widgets/xuat_bao_cao_pdf_dialog.dart';
import '../services/firebase_sync_service.dart';
import '../main.dart';
import '../utils/toast_helper.dart';

// Import các screens mà Drawer cần điều hướng đến
import '../screens/caidat.dart';
import '../screens/thong_ke_page.dart';
import '../screens/huong_dan_su_dung_page.dart';
import '../screens/quy_tac_diem_settings_page.dart';
import '../screens/bang_xep_hang_khoi_page.dart';
import '../screens/lich_day_page.dart';
import '../l10n/app_localizations.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title.toUpperCase(),
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: Center(
        child: Text(
          'Nội dung trang: $title',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// MainDrawer: Thanh điều hướng bên trái thiết kế hiện đại
// ----------------------------------------------------
class MainDrawer extends ConsumerStatefulWidget {
  final GlobalKey<MainScreenState> mainScreenKey;
  final int selectedIndex;
  const MainDrawer({
    super.key,
    required this.mainScreenKey,
    required this.selectedIndex,
  });

  @override
  ConsumerState<MainDrawer> createState() => _MainDrawerState();
}

class _MainDrawerState extends ConsumerState<MainDrawer> {
  String _version = '1.0.3';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _version = info.version;
        });
      }
    });
  }

  // Hàm điều hướng chung cho Drawer
  void _navigateTo(BuildContext context, int index) {
    Navigator.of(context).pop();
    widget.mainScreenKey.currentState?.onItemTapped(index);
  }

  // Hàm điều hướng cho các trang không nằm trong BottomBar
  void _navigateToOtherScreen(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => screen));
  }

  Future<void> _hienThiDialogDoiSoat(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final audit = await FirebaseSyncService.instance.doiSoatDuLieuCloud();

    if (!context.mounted) return;
    Navigator.of(context).pop(); // Đóng loading

    int totalLocal = 0;
    int totalCloud = 0;
    bool allMatched = true;

    audit.forEach((tbl, info) {
      final l = info['local'] as int? ?? 0;
      final c = info['cloud'] as int? ?? 0;
      totalLocal += l;
      if (c >= 0) totalCloud += c;
      if (l != c) allMatched = false;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              allMatched ? Icons.verified_rounded : Icons.warning_amber_rounded,
              color: allMatched ? Colors.green : Colors.orange,
              size: 26,
            ),
            const SizedBox(width: 8),
            const Text(
              'Đối Soát Dữ Liệu Cloud',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 340,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
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
                              ? 'Dữ liệu giữa Điện thoại ($totalLocal bản ghi) và Cloud ($totalCloud bản ghi) khớp nhau 100%!'
                              : 'Tổng Máy: $totalLocal bản ghi | Cloud: $totalCloud bản ghi. Có một số bảng chưa khớp.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: allMatched ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chi tiết 20 bảng CSDL:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                ...audit.entries.map((entry) {
                  final tbl = entry.key;
                  final l = entry.value['local'] as int? ?? 0;
                  final c = entry.value['cloud'] as int? ?? 0;
                  final match = l == c;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tbl,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Row(
                          children: [
                            Text(
                              'Máy: $l | Cloud: ${c < 0 ? 'Lỗi' : c}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: match ? Colors.grey : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              match ? Icons.check_circle_outline : Icons.cancel_outlined,
                              size: 14,
                              color: match ? Colors.green : Colors.red,
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
                final count = await FirebaseSyncService.instance.pushAllLocalDataToCloud();
                if (context.mounted) {
                  ToastHelper.showSuccess(context, 'Đã đẩy thành công $count bản ghi lên Firebase!');
                }
              },
              icon: const Icon(Icons.cloud_upload_rounded, size: 16),
              label: const Text('Đẩy ngay'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _chonAnhDaiDien(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final currentContext = context;
    final caiDatService = ref.read(caiDatServiceProvider);
    await caiDatService.capNhatCaiDat('avatar_path', image.path);
    ref.invalidate(settingsProvider);

    if (!context.mounted) return;
    final loc = AppLocalizations.of(currentContext)!;
    showDialog(
      context: currentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(currentContext).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.success,
          style: TextStyle(
            color: Theme.of(currentContext).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          loc.avatarUpdateSuccess,
          style: Theme.of(currentContext).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              loc.close,
              style: TextStyle(color: Theme.of(currentContext).primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // Header Drawer Thiết kế Premium
          settingsAsync.when(
            data: (settingsData) {
              final avatarPath = settingsData.avatarPath;
              final hasAvatar = avatarPath != null && avatarPath.isNotEmpty;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            theme.cardColor,
                            theme.cardColor.withValues(alpha: 0.8),
                          ]
                        : [
                            theme.primaryColor.withValues(alpha: 0.08),
                            theme.primaryColor.withValues(alpha: 0.02),
                          ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.primaryColor,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primaryColor.withValues(
                                  alpha: 0.15,
                                ),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: GestureDetector(
                            onTap: () => _chonAnhDaiDien(context, ref),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: theme.primaryColor.withValues(
                                alpha: 0.1,
                              ),
                              backgroundImage: hasAvatar
                                  ? FileImage(File(avatarPath))
                                  : null,
                              child: !hasAvatar
                                  ? Icon(
                                      Icons.person_rounded,
                                      color: theme.primaryColor,
                                      size: 44,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        // Nút chỉnh sửa ảnh nhỏ xinh, sang trọng
                        GestureDetector(
                          onTap: () => _chonAnhDaiDien(context, ref),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? theme.cardColor : Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: isDark
                                  ? const Color(0xFF1E1E38)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      settingsData.tenQuanLy,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settingsData.emailQuanLy,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
            loading: () => Container(
              height: 200,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
            error: (err, stack) => Container(
              height: 200,
              alignment: Alignment.center,
              child: Text(
                loc.locale.languageCode == 'vi'
                    ? 'Lỗi tải thông tin'
                    : 'Error loading profile',
              ),
            ),
          ),

          // Danh sách menu điều hướng
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, loc.mainFunctions),
                  _buildDrawerItem(
                    icon: Icons.grid_view_rounded,
                    text: loc.homePageTitle,
                    isSelected: widget.selectedIndex == 0,
                    onTap: () => _navigateTo(context, 0),
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.class_rounded,
                    text: loc.classLabel,
                    isSelected: widget.selectedIndex == 1,
                    onTap: () => _navigateTo(context, 1),
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.people_alt_rounded,
                    text: loc.studentLabel,
                    isSelected: widget.selectedIndex == 2,
                    onTap: () => _navigateTo(context, 2),
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet_rounded,
                    text: loc.feeLabel,
                    isSelected: widget.selectedIndex == 3,
                    onTap: () => _navigateTo(context, 3),
                    context: context,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Divider(color: theme.dividerColor),
                  ),
                  _buildSectionHeader(context, loc.utilities),
                  _buildDrawerItem(
                    icon: Icons.picture_as_pdf_rounded,
                    text: loc.exportPdfReport,
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (ctx) => const XuatBaoCaoPdfDialog(),
                      );
                    },
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.analytics_rounded,
                    text: loc.statistics,
                    onTap: () =>
                        _navigateToOtherScreen(context, const ThongKePage()),
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.calendar_view_week_rounded,
                    text: loc.locale.languageCode == 'vi'
                        ? 'Lịch Dạy Theo Tuần'
                        : 'Weekly Teaching Schedule',
                    onTap: () => _navigateToOtherScreen(
                      context,
                      LichDayPage(
                        mainScreenKey: widget.mainScreenKey,
                        selectedIndex: widget.selectedIndex,
                      ),
                    ),
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.emoji_events_rounded,
                    text: loc.locale.languageCode == 'vi'
                        ? 'Đấu Trường Hạng Khối'
                        : 'Grade Leaderboards',
                    onTap: () => _navigateToOtherScreen(
                      context,
                      const BangXepHangKhoiPage(),
                    ),
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.cloud_sync_rounded,
                    text: loc.locale.languageCode == 'vi'
                        ? 'Đồng bộ Cloud (Firebase)'
                        : 'Sync Firebase Cloud',
                    onTap: () async {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚡ Đang đẩy dữ liệu từ máy lên Firebase Cloud...'),
                          duration: Duration(seconds: 2),
                        ),
                      );

                      final count = await FirebaseSyncService.instance.pushAllLocalDataToCloud();

                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                                SizedBox(width: 8),
                                Text(
                                  'Đồng Bộ Thành Công',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Đã tải lên và đồng bộ thành công $count bản ghi thuộc toàn bộ 20 bảng dữ liệu SQLite từ điện thoại lên Firebase Cloud!',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '🌐 Dữ liệu hiện tại đã được cập nhật thời gian thực tới phiên bản Web (tuition2027.vercel.app).',
                                  style: TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Đóng'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.cloud_download_rounded,
                    text: loc.locale.languageCode == 'vi'
                        ? 'Tải dữ liệu từ Cloud về máy'
                        : 'Pull Data from Firebase Cloud',
                    onTap: () async {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚡ Đang tải dữ liệu từ Firebase Cloud về SQLite...'),
                          duration: Duration(seconds: 2),
                        ),
                      );

                      final count = await FirebaseSyncService.instance.pullAllCloudDataToLocal();

                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: Colors.blue, size: 28),
                                SizedBox(width: 8),
                                Text(
                                  'Tải Dữ Liệu Thành Công',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            content: Text(
                              'Đã tải và khôi phục thành công $count bảng dữ liệu từ Firebase Cloud vào ứng dụng!',
                              style: const TextStyle(fontSize: 15),
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () => Navigator.of(ctx).pop(),
                                child: const Text('Đóng'),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.fact_check_rounded,
                    text: loc.locale.languageCode == 'vi'
                        ? 'Đối soát dữ liệu Cloud (Firebase)'
                        : 'Audit Firebase Cloud Data',
                    onTap: () {
                      Navigator.of(context).pop();
                      _hienThiDialogDoiSoat(context);
                    },
                    context: context,
                  ),
                ],
              ),
            ),
          ),

          // Footer thiết kế dưới đáy
          Material(
            color: isDark
                ? theme.cardColor.withValues(alpha: 0.4)
                : theme.cardColor,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    text: loc.settings,
                    onTap: () =>
                        _navigateToOtherScreen(context, const CaiDat()),
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.rule_rounded,
                    text: loc.scoreRules,
                    onTap: () => _navigateToOtherScreen(
                      context,
                      const QuyTacDiemSettingsPage(),
                    ),
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline_rounded,
                    text: loc.userGuide,
                    onTap: () => _navigateToOtherScreen(
                      context,
                      const HuongDanSuDungPage(),
                    ),
                    context: context,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${loc.version} $_version',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).hintColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
    bool isSelected = false,
    required BuildContext context,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: isDark
            ? theme.primaryColor.withValues(alpha: 0.12)
            : theme.primaryColor.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          icon,
          color: isSelected ? theme.primaryColor : theme.hintColor,
          size: 22,
        ),
        title: Text(
          text,
          style: TextStyle(
            color: isSelected
                ? theme.primaryColor
                : theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
