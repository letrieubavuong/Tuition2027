// File: lib/widgets/main_drawer.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tuition2025/widgets/xuat_bao_cao_pdf_dialog.dart';
import '../main.dart';

// Import các screens mà Drawer cần điều hướng đến
import '../screens/caidat.dart';
import '../screens/thong_ke_page.dart';
import '../screens/huong_dan_su_dung_page.dart';
import '../screens/quy_tac_diem_settings_page.dart';
import '../screens/bang_xep_hang_khoi_page.dart';
import '../utils/theme.dart';
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

  Future<void> _chonAnhDaiDien(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    final currentContext = context;
    final caiDatService = ref.read(caiDatServiceProvider);
    await caiDatService.capNhatCaiDat('avatar_path', image.path);
    ref.invalidate(settingsProvider);

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
                            theme.cardColor.withOpacity(0.8),
                          ]
                        : [
                            theme.primaryColor.withOpacity(0.08),
                            theme.primaryColor.withOpacity(0.02),
                          ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
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
                                color: theme.primaryColor.withOpacity(0.15),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: GestureDetector(
                            onTap: () => _chonAnhDaiDien(context, ref),
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: theme.primaryColor.withOpacity(0.1),
                              backgroundImage: hasAvatar ? FileImage(File(avatarPath)) : null,
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
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: isDark ? const Color(0xFF1E1E38) : Colors.white,
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
              child: Text(loc.locale.languageCode == 'vi' ? 'Lỗi tải thông tin' : 'Error loading profile'),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                    onTap: () => _navigateToOtherScreen(context, const ThongKePage()),
                    context: context,
                  ),
                  _buildDrawerItem(
                    icon: Icons.emoji_events_rounded,
                    text: loc.locale.languageCode == 'vi' ? 'Đấu Trường Hạng Khối' : 'Grade Leaderboards',
                    onTap: () => _navigateToOtherScreen(context, const BangXepHangKhoiPage()),
                    context: context,
                  ),
                ],
              ),
            ),
          ),
          
          // Footer thiết kế dưới đáy
          Material(
            color: isDark ? theme.cardColor.withOpacity(0.4) : theme.cardColor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
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
                  onTap: () => _navigateToOtherScreen(context, const CaiDat()),
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.rule_rounded,
                  text: loc.scoreRules,
                  onTap: () => _navigateToOtherScreen(context, const QuyTacDiemSettingsPage()),
                  context: context,
                ),
                _buildDrawerItem(
                  icon: Icons.help_outline_rounded,
                  text: loc.userGuide,
                  onTap: () => _navigateToOtherScreen(context, const HuongDanSuDungPage()),
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
            ? theme.primaryColor.withOpacity(0.12)
            : theme.primaryColor.withOpacity(0.08),
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
            color: isSelected ? theme.primaryColor : theme.textTheme.bodyLarge?.color?.withOpacity(0.85),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
