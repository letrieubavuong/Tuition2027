// File: lib/widgets/main_drawer.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../widgets/xuat_bao_cao_pdf_dialog.dart';
import '../main.dart';
import '../utils/toast_helper.dart';

// Screens
import '../screens/caidat.dart';
import '../screens/thong_ke_page.dart';
import '../screens/huong_dan_su_dung_page.dart';
import '../screens/quy_tac_diem_settings_page.dart';
import '../screens/bang_xep_hang_khoi_page.dart';
import '../screens/lich_day_page.dart';
import '../screens/cloud_data_page.dart';
import '../l10n/app_localizations.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title, style: Theme.of(context).appBarTheme.titleTextStyle),
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
  String _version = '—';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(() {
              _version = info.version;
            });
          }
        })
        .catchError((_) {
          if (mounted) {
            setState(() {
              _version = '—';
            });
          }
        });
  }

  void _navigateTo(BuildContext context, int index) {
    Navigator.of(context).pop();
    widget.mainScreenKey.currentState?.onItemTapped(index);
  }

  void _navigateToOtherScreen(BuildContext context, Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => screen));
  }

  Future<void> _chonAnhDaiDien(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      final caiDatService = ref.read(caiDatServiceProvider);
      await caiDatService.capNhatCaiDat('avatar_path', image.path);
      ref.invalidate(settingsProvider);

      if (!context.mounted) return;
      ToastHelper.showSuccess(context, 'Đã cập nhật ảnh đại diện');
    } catch (e) {
      if (!context.mounted) return;
      ToastHelper.showError(context, 'Lỗi chọn ảnh đại diện: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: Column(
        children: [
          // Header compact & modern Material 3
          settingsAsync.when(
            data: (settingsData) {
              final avatarPath = settingsData.avatarPath;
              final hasAvatar = avatarPath != null && avatarPath.isNotEmpty;
              return Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.of(context).padding.top + 16,
                  16,
                  16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _navigateToOtherScreen(context, const CaiDat()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            GestureDetector(
                              onTap: () => _chonAnhDaiDien(context, ref),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: colorScheme.primaryContainer,
                                backgroundImage: hasAvatar
                                    ? FileImage(File(avatarPath))
                                    : null,
                                child: !hasAvatar
                                    ? Icon(
                                        Icons.person_rounded,
                                        color: colorScheme.onPrimaryContainer,
                                        size: 28,
                                      )
                                    : null,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _chonAnhDaiDien(context, ref),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 11,
                                  color: colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settingsData.tenQuanLy.isNotEmpty
                                    ? settingsData.tenQuanLy
                                    : 'Quản lý',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settingsData.emailQuanLy.isNotEmpty
                                    ? settingsData.emailQuanLy
                                    : 'Thống kê & Quản lý học phí',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () => Container(
              height: 100,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
            error: (err, stack) => Container(
              height: 100,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              child: Text(
                loc.locale.languageCode == 'vi'
                    ? 'Lỗi tải thông tin'
                    : 'Error loading profile',
                style: TextStyle(color: colorScheme.error, fontSize: 13),
              ),
            ),
          ),

          // Menu navigation
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION 1: CHÍNH
                  _buildSectionHeader(context, loc.mainFunctions),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.grid_view_rounded,
                    text: loc.homePageTitle,
                    isSelected: widget.selectedIndex == 0,
                    onTap: () => _navigateTo(context, 0),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.class_rounded,
                    text: loc.classLabel,
                    isSelected: widget.selectedIndex == 1,
                    onTap: () => _navigateTo(context, 1),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.people_alt_rounded,
                    text: loc.studentLabel,
                    isSelected: widget.selectedIndex == 2,
                    onTap: () => _navigateTo(context, 2),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.account_balance_wallet_rounded,
                    text: loc.feeLabel,
                    isSelected: widget.selectedIndex == 3,
                    onTap: () => _navigateTo(context, 3),
                  ),

                  const SizedBox(height: 8),
                  // SECTION 2: VẬN HÀNH
                  _buildSectionHeader(
                    context,
                    loc.locale.languageCode == 'vi' ? 'Vận hành' : 'Operations',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.calendar_view_week_rounded,
                    text: loc.locale.languageCode == 'vi'
                        ? 'Lịch dạy'
                        : 'Schedule',
                    onTap: () => _navigateToOtherScreen(
                      context,
                      LichDayPage(
                        mainScreenKey: widget.mainScreenKey,
                        selectedIndex: widget.selectedIndex,
                      ),
                    ),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.analytics_rounded,
                    text: loc.statistics,
                    onTap: () =>
                        _navigateToOtherScreen(context, const ThongKePage()),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.emoji_events_rounded,
                    text: loc.locale.languageCode == 'vi'
                        ? 'Bảng xếp hạng khối'
                        : 'Grade Leaderboards',
                    onTap: () => _navigateToOtherScreen(
                      context,
                      const BangXepHangKhoiPage(),
                    ),
                  ),

                  const SizedBox(height: 8),
                  // SECTION 3: CÔNG CỤ
                  _buildSectionHeader(context, loc.utilities),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.picture_as_pdf_rounded,
                    text: loc.exportPdfReport,
                    onTap: () {
                      Navigator.of(context).pop();
                      showDialog(
                        context: context,
                        builder: (ctx) => const XuatBaoCaoPdfDialog(),
                      );
                    },
                  ),

                  const SizedBox(height: 8),
                  // SECTION 4: HỆ THỐNG
                  _buildSectionHeader(
                    context,
                    loc.locale.languageCode == 'vi' ? 'Hệ thống' : 'System',
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.cloud_sync_rounded,
                    text: loc.locale.languageCode == 'vi'
                        ? 'Dữ liệu & Cloud'
                        : 'Data & Cloud',
                    onTap: () =>
                        _navigateToOtherScreen(context, const CloudDataPage()),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_rounded,
                    text: loc.settings,
                    onTap: () =>
                        _navigateToOtherScreen(context, const CaiDat()),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.rule_rounded,
                    text: loc.scoreRules,
                    onTap: () => _navigateToOtherScreen(
                      context,
                      const QuyTacDiemSettingsPage(),
                    ),
                  ),
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.help_outline_rounded,
                    text: loc.userGuide,
                    onTap: () => _navigateToOtherScreen(
                      context,
                      const HuongDanSuDungPage(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant, width: 1),
                ),
              ),
              child: Text(
                '${loc.version} $_version',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String text,
    required GestureTapCallback onTap,
    bool isSelected = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          selected: isSelected,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(
            icon,
            color: isSelected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 21,
          ),
          title: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14.5,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
