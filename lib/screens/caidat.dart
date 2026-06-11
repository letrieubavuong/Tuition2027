// File: lib/screens/caidat.dart (ĐÃ SỬA LỖI MÀU SẮC NÚT VÀ TỐI ƯU HÓA MÀU UI)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart'
    as p; // SỬA: Thêm tiền tố 'p' để tránh xung đột với BuildContext
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../services/caidat_service.dart';
import '../services/notification_service.dart'; // Import dịch vụ thông báo
import '../services/cloud_sync_service.dart';
import '../services/widget_sync_service.dart';
import '../utils/db.dart';
import '../utils/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/truong_service.dart';
import '../models/truong.dart';

// --- Riverpod Providers ---

// 1. Provider cho các services
final caiDatServiceProvider = Provider((ref) => CaiDatService());
final truongServiceProvider = Provider((ref) => TruongService());

// 2. State class để chứa dữ liệu của trang
class SettingsData {
  final String hocPhiBuoi;
  final String hocPhiThang;
  final String soBuoiChuanThang;
  final String tenQuanLy;
  final String emailQuanLy;
  final String? avatarPath;
  final String bankId;
  final String accountNo;
  final String accountName;
  final List<Truong> danhSachTruong;
  final String reminderMinutes; // Thêm cấu hình phút nhắc nhở

  SettingsData({
    required this.hocPhiBuoi,
    required this.hocPhiThang,
    required this.soBuoiChuanThang,
    required this.tenQuanLy,
    required this.emailQuanLy,
    this.avatarPath,
    required this.bankId,
    required this.accountNo,
    required this.accountName,
    required this.danhSachTruong,
    required this.reminderMinutes,
  });
}

// 3. Provider chính để tải dữ liệu
final settingsProvider = FutureProvider<SettingsData>((ref) async {
  final caiDatService = ref.watch(caiDatServiceProvider);
  final truongService = ref.watch(truongServiceProvider);

  // Tải song song các dữ liệu
  final results = await Future.wait([
    caiDatService.layCaiDat('hoc_phi_buoi'),
    caiDatService.layCaiDat('hoc_phi_thang'),
    caiDatService.layCaiDat('so_buoi_chuan_thang'),
    caiDatService.layCaiDat('nguoi_quan_ly'),
    caiDatService.layCaiDat('email'),
    caiDatService.layCaiDat('avatar_path'),
    caiDatService.layCaiDat('bank_id'),
    caiDatService.layCaiDat('account_no'),
    caiDatService.layCaiDat('account_name'),
    truongService.docTatCaTruong(),
    caiDatService.layCaiDat('reminder_minutes'),
  ]);

  return SettingsData(
    hocPhiBuoi: (results[0] as String?) ?? '',
    hocPhiThang: (results[1] as String?) ?? '',
    soBuoiChuanThang: (results[2] as String?) ?? '12',
    tenQuanLy: (results[3] as String?) ?? 'LÊ TRIỆU BÁ VƯƠNG',
    emailQuanLy: (results[4] as String?) ?? 'bavuong@moet.edu.vn',
    avatarPath: results[5] as String?,
    bankId: (results[6] as String?) ?? 'sacombank',
    accountNo: (results[7] as String?) ?? '0905073175',
    accountName: (results[8] as String?) ?? 'LE TRIEU BA VUONG',
    danhSachTruong: results[9] as List<Truong>,
    reminderMinutes: (results[10] as String?) ?? '10',
  );
});

class CaiDat extends ConsumerStatefulWidget {
  const CaiDat({super.key});

  @override
  ConsumerState<CaiDat> createState() => _CaiDatState();
}

class _CaiDatState extends ConsumerState<CaiDat> {
  final _hocPhiBuoiController = TextEditingController();
  final _hocPhiThangController = TextEditingController();
  final _soBuoiChuanController = TextEditingController();
  final _tenQuanLyController = TextEditingController();
  final _emailQuanLyController = TextEditingController();
  final _bankIdController = TextEditingController();
  final _accountNoController = TextEditingController();
  final _accountNameController = TextEditingController();
  String _reminderMinutes = '10';

  @override
  void initState() {
    super.initState();
    // SỬA: Di chuyển ref.listen vào initState để đảm bảo nó được thiết lập một lần
    // và cập nhật các controller ngay khi dữ liệu được tải về lần đầu.
    ref.listenManual<AsyncValue<SettingsData>>(
      settingsProvider,
      (_, next) {
        // Dùng listenManual để có thể truy cập ref trong initState
        if (next is AsyncData<SettingsData>) {
          final data = next.value;
          // Cập nhật giá trị cho các controller
          setState(() {
            _tenQuanLyController.text = data.tenQuanLy;
            _emailQuanLyController.text = data.emailQuanLy;
            _hocPhiBuoiController.text = data.hocPhiBuoi;
            _hocPhiThangController.text = data.hocPhiThang;
            _soBuoiChuanController.text = data.soBuoiChuanThang;
            _bankIdController.text = data.bankId;
            _accountNoController.text = data.accountNo;
            _accountNameController.text = data.accountName;
            _reminderMinutes = data.reminderMinutes;
          });
        }
      },
      fireImmediately:
          true, // SỬA: Yêu cầu cập nhật ô nhập liệu ngay khi vừa mở trang
    );
  }

  // SỬA: Đổi tên hàm để phản ánh đúng chức năng
  Future<void> _luuCaiDatChung() async {
    final caiDatService = ref.read(caiDatServiceProvider);
    final String hpBuoi = _hocPhiBuoiController.text.replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    final String hpThang = _hocPhiThangController.text.replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
    final String soBuoiChuan = _soBuoiChuanController.text.trim();
    final String tenQuanLy = _tenQuanLyController.text.trim();
    final String emailQuanLy = _emailQuanLyController.text.trim();
    final String bankId = _bankIdController.text.trim();
    final String accountNo = _accountNoController.text.trim();
    final String accountName = _accountNameController.text.trim();

    await caiDatService.capNhatCaiDat('hoc_phi_buoi', hpBuoi);
    await caiDatService.capNhatCaiDat('hoc_phi_thang', hpThang);
    await caiDatService.capNhatCaiDat('so_buoi_chuan_thang', soBuoiChuan);
    await caiDatService.capNhatCaiDat('nguoi_quan_ly', tenQuanLy);
    await caiDatService.capNhatCaiDat('email', emailQuanLy);
    await caiDatService.capNhatCaiDat('bank_id', bankId);
    await caiDatService.capNhatCaiDat('account_no', accountNo);
    await caiDatService.capNhatCaiDat('account_name', accountName);
    await caiDatService.capNhatCaiDat('reminder_minutes', _reminderMinutes);
    
    // Đồng bộ lại toàn bộ thông báo với thời gian mới
    await NotificationService.instance.syncAllClassReminders();
    // Đồng bộ lại Widget mã QR ngân hàng
    await WidgetSyncService.syncBankQRWidget();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.saveSettingsSuccess),
        ),
      );
    }
    // Vô hiệu hóa provider để tải lại dữ liệu mới
    ref.invalidate(settingsProvider);
  }

  @override
  void dispose() {
    _hocPhiBuoiController.dispose();
    _hocPhiThangController.dispose();
    _soBuoiChuanController.dispose();
    _tenQuanLyController.dispose();
    _emailQuanLyController.dispose();
    _bankIdController.dispose();
    _accountNoController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _hienThiFormTruong({Truong? truong}) async {
    TextEditingController controller = TextEditingController(
      text: truong?.ten ?? '',
    );
    final bool ketQua =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).cardColor,
            title: Text(
              truong == null
                  ? AppLocalizations.of(ctx)!.addSchool
                  : AppLocalizations.of(ctx)!.editSchool,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            content: TextField(
              controller: controller,
              style: Theme.of(ctx).textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(ctx)!.schoolName,
                labelStyle: Theme.of(ctx).textTheme.bodyMedium,
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.darkSecondaryText),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(ctx).primaryColor,
                    width: 2,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  AppLocalizations.of(ctx)!.get('cancel')!,
                  style: TextStyle(color: Theme.of(ctx).primaryColor),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (controller.text.isNotEmpty) {
                    final truongService = ref.read(truongServiceProvider);
                    if (truong == null) {
                      await truongService.taoTruong(
                        Truong(ten: controller.text),
                      );
                    } else {
                      truong.ten = controller.text;
                      await truongService.capNhatTruong(truong);
                    }
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, true);
                  }
                },
                child: Text(
                  AppLocalizations.of(ctx)!.get('save')!,
                  style: TextStyle(color: Theme.of(ctx).primaryColor),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (ketQua) {
      ref.invalidate(settingsProvider);
    }
  }

  Future<void> _xoaTruong(int id) async {
    await ref.read(truongServiceProvider).xoaTruong(id);
    ref.invalidate(settingsProvider);
    if (!mounted) return; // SỬA: Thêm kiểm tra mounted
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.deleteSchoolSuccess),
      ),
    );
  }

  Future<void> _backupDatabase() async {
    final loc = AppLocalizations.of(context)!;
    var status = await Permission.manageExternalStorage.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.locale.languageCode == 'vi' ? 'Không được cấp quyền truy cập bộ nhớ.' : 'Storage permission denied.')),
      );
      return;
    }

    try {
      await DBHelper.instance.close(); 
      final dbPath = await getDatabasesPath();
      final sourcePath = p.join(dbPath, 'quan_ly_hs.db'); 
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.locale.languageCode == 'vi' ? 'Lỗi: Không tìm thấy file database.' : 'Error: Database file not found.')),
        );
        return;
      }

      final downloadsDir = '/storage/emulated/0/Download';
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'quan_ly_hs_backup_$timestamp.db';
      final backupPath = p.join(downloadsDir, backupFileName); 

      await sourceFile.copy(backupPath);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.backupSuccess(backupPath),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.backupError(e.toString()),
          ),
        ),
      );
    } finally {
      await DBHelper.instance.database;
    }
  }

  Future<void> _restoreDatabase() async {
    final loc = AppLocalizations.of(context)!;
    var status = await Permission.manageExternalStorage.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.locale.languageCode == 'vi' ? 'Không được cấp quyền truy cập bộ nhớ.' : 'Storage permission denied.')),
      );
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (!mounted) return;
    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;
      if (!selectedPath.toLowerCase().endsWith('.db')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              loc.locale.languageCode == 'vi'
                  ? 'Vui lòng chọn file sao lưu có định dạng .db'
                  : 'Please select a backup file with a .db extension',
            ),
          ),
        );
        return;
      }
      final backupFile = File(selectedPath);

      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(ctx).cardColor,
              title: Text(AppLocalizations.of(ctx)!.restoreConfirmTitle),
              content: Text(AppLocalizations.of(ctx)!.restoreConfirmContent),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(AppLocalizations.of(ctx)!.get('cancel')!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: Text(AppLocalizations.of(ctx)!.get('restoreData')!),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted || !confirmed) return;

      try {
        await DBHelper.instance.close();
        final dbPath = await getDatabasesPath();
        final originalDbPath = p.join(dbPath, 'quan_ly_hs.db'); 

        if (!mounted) return;
        await backupFile.copy(originalDbPath);

        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).cardColor,
            title: Text(AppLocalizations.of(ctx)!.restoreSuccessTitle),
            content: Text(AppLocalizations.of(ctx)!.restoreSuccessContent),
            actions: [
              TextButton(
                onPressed: () => exit(0),
                child: Text(AppLocalizations.of(ctx)!.restart),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.restoreError(e.toString()),
            ),
          ),
        );
        await DBHelper.instance.database; 
      }
    }
  }

  Widget _buildCloudSyncSection() {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';

    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_sync,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isVi ? 'Đồng bộ đám mây (Firebase)' : 'Cloud Sync (Firebase)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!CloudSyncService.instance.isInitialized) ...[
              Text(
                isVi
                    ? 'Tính năng đồng bộ đám mây chưa được cấu hình. Vui lòng thêm file google-services.json vào thư mục android/app/ và build lại ứng dụng.'
                    : 'Cloud sync is not configured. Please add the google-services.json file to android/app/ and rebuild the app.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ] else ...[
              StreamBuilder(
                stream: CloudSyncService.instance.authStateChanges,
                builder: (context, snapshot) {
                  final user = CloudSyncService.instance.currentUser;
                  if (user == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi
                              ? 'Đăng nhập tài khoản để sao lưu dữ liệu lên đám mây và đồng bộ giữa các thiết bị.'
                              : 'Log in to backup data to the cloud and sync between devices.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showAuthDialog,
                            icon: const Icon(Icons.login),
                            label: Text(isVi ? 'Đăng nhập / Đăng ký' : 'Login / Register'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              isVi
                                  ? 'Tài khoản: ${user.email}'
                                  : 'Account: ${user.email}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await CloudSyncService.instance.dangXuat();
                              setState(() {});
                            },
                            icon: const Icon(Icons.logout, size: 16, color: Colors.redAccent),
                            label: Text(
                              isVi ? 'Đăng xuất' : 'Logout',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _backupToCloud,
                              icon: const Icon(Icons.cloud_upload),
                              label: Text(isVi ? 'Lên đám mây' : 'Backup to Cloud'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _restoreFromCloud,
                              icon: const Icon(Icons.cloud_download),
                              label: Text(isVi ? 'Tải về máy' : 'Restore from Cloud'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigo,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAuthDialog() async {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLogin = true;
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                isLogin
                    ? (isVi ? 'Đăng nhập tài khoản' : 'Login Account')
                    : (isVi ? 'Đăng ký tài khoản' : 'Register Account'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: isVi ? 'Email' : 'Email',
                      prefixIcon: const Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: isVi ? 'Mật khẩu' : 'Password',
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isLoading)
                    const CircularProgressIndicator()
                  else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setStateDialog(() {
                              isLogin = !isLogin;
                            });
                          },
                          child: Text(
                            isLogin
                                ? (isVi ? 'Tạo tài khoản mới?' : 'Create account?')
                                : (isVi ? 'Đã có tài khoản?' : 'Have an account?'),
                            style: TextStyle(color: Theme.of(context).primaryColor),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final email = emailController.text.trim();
                            final password = passwordController.text;
                            if (email.isEmpty || password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isVi
                                        ? 'Vui lòng điền đầy đủ thông tin'
                                        : 'Please fill in all fields',
                                  ),
                                ),
                              );
                              return;
                            }
                            setStateDialog(() {
                              isLoading = true;
                            });
                            try {
                              if (isLogin) {
                                await CloudSyncService.instance.dangNhap(email, password);
                              } else {
                                await CloudSyncService.instance.dangKy(email, password);
                              }
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('Lỗi: ${e.toString()}'),
                                  ),
                                );
                              }
                            } finally {
                              setStateDialog(() {
                                isLoading = false;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                          child: Text(
                            isLogin
                                ? (isVi ? 'Đăng nhập' : 'Login')
                                : (isVi ? 'Đăng ký' : 'Register'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
    setState(() {});
  }

  Future<void> _backupToCloud() async {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final success = await CloudSyncService.instance.saoLuuLenDamMay();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (isVi ? 'Sao lưu lên đám mây thành công!' : 'Cloud backup successful!')
                : (isVi ? 'Sao lưu thất bại. Vui lòng thử lại.' : 'Backup failed. Please try again.'),
          ),
        ),
      );
    }
  }

  Future<void> _restoreFromCloud() async {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: Text(isVi ? 'Xác nhận khôi phục' : 'Confirm Restore'),
        content: Text(
          isVi
              ? 'Dữ liệu hiện tại trên thiết bị sẽ bị ghi đè hoàn toàn bằng dữ liệu từ đám mây. Bạn có chắc chắn muốn tiếp tục?'
              : 'Current local data will be completely overwritten by cloud data. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(loc.get('cancel')!),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(loc.get('restoreData')!),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final success = await CloudSyncService.instance.khoiPhucTuDamMay();

    if (mounted) {
      Navigator.pop(context);
      if (success) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).cardColor,
            title: Text(loc.restoreSuccessTitle),
            content: Text(loc.restoreSuccessContent),
            actions: [
              TextButton(
                onPressed: () => exit(0),
                child: Text(loc.restart),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isVi
                  ? 'Khôi phục thất bại hoặc chưa có bản sao lưu trên đám mây.'
                  : 'Restore failed or no cloud backup exists yet.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe provider để lấy dữ liệu và cập nhật UI
    final loc = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(settingsProvider); // SỬA: Lấy settingsAsync

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        title: Text(loc.appSettings),
        // Các thuộc tính khác đã được định nghĩa trong theme
      ),
      // Sử dụng when để xử lý các trạng thái của provider
      body: settingsAsync.when(
        loading: () => Center(
          // SỬA: Lấy màu từ theme
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
        error: (err, stack) => Center(
          child: Text(
            'Lỗi tải cài đặt: $err',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        data: (settingsData) {
          // Khi có dữ liệu, hiển thị ListView
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              // Mục chuyển đổi theme
              Card(
                color: Theme.of(context).cardColor,
                child: SwitchListTile(
                  // SỬA: Lấy màu từ theme
                  title: Text(
                    loc.darkMode,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  value: ref.watch(themeModeProvider) == ThemeMode.dark,
                  onChanged: (isDark) {
                    ref.read(themeModeProvider.notifier).state = isDark
                        ? ThemeMode.dark
                        : ThemeMode.light;
                  },
                  secondary: Icon(
                    Icons.dark_mode_outlined,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  activeThumbColor: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              // SỬA: Thêm mục chọn ngôn ngữ
              Card(
                color: Theme.of(context).cardColor, // SỬA: Lấy màu từ theme
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.language,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      DropdownButton<Locale>(
                        value: ref.watch(
                          localeProvider,
                        ), // SỬA: Lấy locale từ provider
                        dropdownColor: Theme.of(context).cardColor,
                        onChanged: (Locale? newLocale) {
                          if (newLocale != null) {
                            ref.read(localeProvider.notifier).state = newLocale;
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: Locale('vi'),
                            child: Text('Tiếng Việt 🇻🇳'),
                          ),
                          DropdownMenuItem(
                            value: Locale('en'),
                            child: Text('English 🇬🇧'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Thêm mục cấu hình nhắc nhở ca học
              Card(
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          loc.locale.languageCode == 'vi' ? 'Thông báo nhắc ca học' : 'Class reminders',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _reminderMinutes,
                        dropdownColor: Theme.of(context).cardColor,
                        onChanged: (String? newValue) async {
                          if (newValue != null) {
                            if (newValue != 'off') {
                              final granted = await NotificationService.instance.requestPermissions();
                              if (!granted && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      loc.locale.languageCode == 'vi'
                                          ? 'Vui lòng cấp quyền thông báo trong cài đặt máy'
                                          : 'Please enable notifications in device settings',
                                    ),
                                  ),
                                );
                              }
                            }
                            setState(() {
                              _reminderMinutes = newValue;
                            });
                          }
                        },
                        items: [
                          DropdownMenuItem(
                            value: 'off',
                            child: Text(loc.locale.languageCode == 'vi' ? 'Tắt thông báo' : 'Disable notifications'),
                          ),
                          DropdownMenuItem(
                            value: '5',
                            child: Text(loc.locale.languageCode == 'vi' ? 'Báo trước 5 phút' : '5 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: '10',
                            child: Text(loc.locale.languageCode == 'vi' ? 'Báo trước 10 phút' : '10 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: '15',
                            child: Text(loc.locale.languageCode == 'vi' ? 'Báo trước 15 phút' : '15 minutes before'),
                          ),
                          DropdownMenuItem(
                            value: '30',
                            child: Text(loc.locale.languageCode == 'vi' ? 'Báo trước 30 phút' : '30 minutes before'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),

              // ===================================
              // Phần I: Thông tin quản lý
              // ===================================
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  // SỬA: Dùng localization
                  loc.managerInfo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextField(
                controller: _tenQuanLyController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: _inputDecoration(
                  context, // SỬA: Truyền context
                  loc.managerName,
                  Icons.person,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailQuanLyController,
                keyboardType: TextInputType.emailAddress,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge, // SỬA: Lấy style từ theme
                decoration: _inputDecoration(
                  context,
                  loc.email,
                  Icons.email,
                ), // SỬA: Truyền context
              ),
              Divider(height: 40, color: Theme.of(context).dividerColor),

              // ===================================
              // Phần IB: Thông tin Ngân hàng (QR)
              // ===================================
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  loc.locale.languageCode == 'vi' ? 'Thông tin Ngân hàng (Để tạo mã QR)' : 'Bank Information (For QR)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextField(
                controller: _bankIdController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: _inputDecoration(
                  context,
                  loc.locale.languageCode == 'vi' ? 'Mã Ngân hàng (VD: sacombank, vcb, acb)' : 'Bank Code (e.g. sacombank, vcb, acb)',
                  Icons.account_balance,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accountNoController,
                keyboardType: TextInputType.number,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: _inputDecoration(
                  context,
                  loc.locale.languageCode == 'vi' ? 'Số tài khoản' : 'Account number',
                  Icons.numbers,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accountNameController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: _inputDecoration(
                  context,
                  loc.locale.languageCode == 'vi' ? 'Tên chủ tài khoản (KHÔNG DẤU)' : 'Account name (NO ACCENTS)',
                  Icons.badge,
                ),
              ),
              Divider(height: 40, color: Theme.of(context).dividerColor),

              // ===================================
              // Phần I: Cài đặt Học phí cố định
              // ===================================
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  // SỬA: Dùng localization
                  loc.feeSettings,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),

              // TextField cho Học phí theo buổi
              TextField(
                controller: _hocPhiBuoiController,
                keyboardType: TextInputType.number,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge, // SỬA: Lấy style từ theme
                decoration: InputDecoration(
                  labelText: loc.feePerSession,
                  labelStyle: Theme.of(context).textTheme.bodyMedium,
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.darkSecondaryText),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _soBuoiChuanController,
                keyboardType: TextInputType.number,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge, // SỬA: Lấy style từ theme
                decoration: InputDecoration(
                  labelText: loc.locale.languageCode == 'vi' ? 'Số buổi học chuẩn/tháng' : 'Standard sessions/month',
                  labelStyle: Theme.of(context).textTheme.bodyMedium,
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.darkSecondaryText),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              // TextField cho Mức thu theo tháng
              TextField(
                controller: _hocPhiThangController,
                keyboardType: TextInputType.number,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge, // SỬA: Lấy style từ theme
                decoration: InputDecoration(
                  labelText: loc.feePerMonth,
                  labelStyle: Theme.of(context).textTheme.bodyMedium,
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.darkSecondaryText),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  fillColor: Theme.of(context).cardColor,
                  filled: true,
                ),
              ),
              const SizedBox(height: 24),
              // Nút LƯU CÀI ĐẶT CHUNG
              // Nút LƯU CÀI ĐẶT HỌC PHÍ (FIX MÀU NÚT)
              ElevatedButton(
                onPressed: _luuCaiDatChung, // SỬA: Gọi hàm đã đổi tên
                style: ElevatedButton.styleFrom(
                  // Sửa: Đổi màu nền nút sang màu accentColor hoặc primaryButtonColor để nổi bật
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onPrimary, // Chữ màu tối trên nền sáng
                ),
                // Sửa: Đảm bảo chữ màu trắng (lightText)
                child: Text(
                  loc.saveSettings,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),

              Divider(height: 40, color: Theme.of(context).dividerColor),

              // ===================================
              // Phần II: Danh sách Trường học
              // ===================================
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.schoolList,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: Theme.of(context).primaryColor,
                      ),
                      onPressed: () => _hienThiFormTruong(),
                    ),
                  ],
                ),
              ),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: settingsData.danhSachTruong.length,
                itemBuilder: (context, index) {
                  final truong = settingsData.danhSachTruong[index];
                  return Card(
                    color: Theme.of(context).cardColor,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(
                        truong.ten,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              size: 20,
                              color: AppColors.darkAccent,
                            ),
                            onPressed: () => _hienThiFormTruong(truong: truong),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _xoaTruong(truong.id!),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              Divider(height: 40, color: Theme.of(context).dividerColor),

              // ===================================
              // Phần III: Quản lý dữ liệu
              // ===================================
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: Text(
                  loc.locale.languageCode == 'vi' ? 'Quản lý dữ liệu' : 'Data Management',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _backupDatabase,
                      icon: const Icon(Icons.backup),
                      label: Text(loc.locale.languageCode == 'vi' ? 'Sao lưu' : 'Backup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _restoreDatabase,
                      icon: const Icon(Icons.restore),
                      label: Text(loc.locale.languageCode == 'vi' ? 'Phục hồi' : 'Restore'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildCloudSyncSection(),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

// SỬA: Tách hàm tạo InputDecoration để tái sử dụng
InputDecoration _inputDecoration(
  BuildContext context,
  String label,
  IconData icon,
) {
  return InputDecoration(
    labelText: label,
    labelStyle: Theme.of(context).textTheme.bodyMedium,
    prefixIcon: Icon(
      icon,
      color: Theme.of(context).textTheme.bodyMedium?.color,
    ),
    border: const OutlineInputBorder(),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(
        color: AppColors.darkSecondaryText,
      ), // Giữ nguyên cho dark mode
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
    ),
    fillColor: Theme.of(context).cardColor,
    filled: true,
  );
}
