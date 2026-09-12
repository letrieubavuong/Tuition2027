// File: lib/screens/caidat.dart (ĐÃ SỬA LỖI MÀU SẮC NÚT VÀ TỐI ƯU HÓA MÀU UI)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart'
    as p; // SỬA: Thêm tiền tố 'p' để tránh xung đột với BuildContext
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../services/caidat_service.dart';
import '../services/notification_service.dart'; // Import dịch vụ thông báo
import '../services/google_sheets_service.dart';
import '../services/widget_sync_service.dart';
import '../services/report_service.dart';
import '../utils/db.dart';
import '../utils/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/truong_service.dart';
import '../models/truong.dart';
import 'pin_lock_screen.dart';
import '../services/bank_notification_service.dart';
import '../utils/toast_helper.dart';

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
  final String appPinEnabled; // Thêm cấu hình bật/tắt PIN
  final String appBiometricEnabled; // Thêm cấu hình vân tay
  final String autoApprovePayment; // Duyệt học phí tự động
  final String googleSheetsUrl; // Đường dẫn Google Sheets URL

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
    required this.appPinEnabled,
    required this.appBiometricEnabled,
    required this.autoApprovePayment,
    required this.googleSheetsUrl,
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
    caiDatService.layCaiDat('app_pin_enabled'),
    caiDatService.layCaiDat('auto_approve_payment'),
    caiDatService.layCaiDat('google_sheets_web_app_url'),
    caiDatService.layCaiDat('app_biometric_enabled'),
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
    appPinEnabled: (results[11] as String?) ?? 'false',
    autoApprovePayment: (results[12] as String?) ?? '0',
    googleSheetsUrl: (results[13] as String?) ?? '',
    appBiometricEnabled: (results[14] as String?) ?? 'false',
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
  final _googleSheetsUrlController = TextEditingController();
  String _reminderMinutes = '10';
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _autoApprovePayment = false;

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
            _googleSheetsUrlController.text = data.googleSheetsUrl;
            _reminderMinutes = data.reminderMinutes;
            _pinEnabled = data.appPinEnabled == 'true';
            _biometricEnabled = data.appBiometricEnabled == 'true';
            _autoApprovePayment = data.autoApprovePayment == '1';
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
    await caiDatService.capNhatCaiDat(
      'app_pin_enabled',
      _pinEnabled ? 'true' : 'false',
    );
    await caiDatService.capNhatCaiDat(
      'auto_approve_payment',
      _autoApprovePayment ? '1' : '0',
    );
    await caiDatService.capNhatCaiDat(
      'google_sheets_web_app_url',
      _googleSheetsUrlController.text.trim(),
    );

    // Đồng bộ lại toàn bộ thông báo với thời gian mới
    await NotificationService.instance.syncAllClassReminders();
    // Đồng bộ lại Widget mã QR ngân hàng
    await WidgetSyncService.syncBankQRWidget();

    if (mounted) {
      ToastHelper.showSuccess(
        context,
        AppLocalizations.of(context)!.saveSettingsSuccess,
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
    _googleSheetsUrlController.dispose();
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
    ToastHelper.showSuccess(
      context,
      AppLocalizations.of(context)!.deleteSchoolSuccess,
    );
  }

  Future<void> _backupDatabase() async {
    final loc = AppLocalizations.of(context)!;
    var status = await Permission.manageExternalStorage.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ToastHelper.showWarning(
        context,
        loc.locale.languageCode == 'vi'
            ? 'Không được cấp quyền truy cập bộ nhớ.'
            : 'Storage permission denied.',
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
        ToastHelper.showError(
          context,
          loc.locale.languageCode == 'vi'
              ? 'Lỗi: Không tìm thấy file database.'
              : 'Error: Database file not found.',
        );
        return;
      }

      final downloadsDir = '/storage/emulated/0/Download';
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'quan_ly_hs_backup_$timestamp.db';
      final backupPath = p.join(downloadsDir, backupFileName);

      await sourceFile.copy(backupPath);
      if (!mounted) return;

      ToastHelper.showSuccess(
        context,
        AppLocalizations.of(context)!.backupSuccess(backupPath),
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showError(
        context,
        AppLocalizations.of(context)!.backupError(e.toString()),
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
      ToastHelper.showWarning(
        context,
        loc.locale.languageCode == 'vi'
            ? 'Không được cấp quyền truy cập bộ nhớ.'
            : 'Storage permission denied.',
      );
      return;
    }

    FilePickerResult? result = await FilePicker.pickFiles(type: FileType.any);

    if (!mounted) return;
    if (result != null && result.files.single.path != null) {
      final selectedPath = result.files.single.path!;
      if (!selectedPath.toLowerCase().endsWith('.db')) {
        ToastHelper.showWarning(
          context,
          loc.locale.languageCode == 'vi'
              ? 'Vui lòng chọn file sao lưu có định dạng .db'
              : 'Please select a backup file with a .db extension',
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
        ToastHelper.showError(
          context,
          AppLocalizations.of(context)!.restoreError(e.toString()),
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
                  Icons.grid_on_outlined,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isVi
                      ? 'Sao lưu / Khôi phục Google Sheets'
                      : 'Google Sheets Backup / Restore',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isVi
                  ? 'Nhập đường dẫn Google Apps Script Web App URL của bạn:'
                  : 'Enter your Google Apps Script Web App URL:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _googleSheetsUrlController,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: _inputDecoration(
                context,
                isVi ? 'Đường dẫn Web App URL' : 'Web App URL',
                Icons.link,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _backupToGoogleSheets,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(isVi ? 'Lên Sheets' : 'Backup to Sheets'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _restoreFromGoogleSheets,
                    icon: const Icon(Icons.cloud_download),
                    label: Text(isVi ? 'Tải từ Sheets' : 'Restore from Sheets'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _showGoogleSheetsInstructions,
                icon: const Icon(Icons.help_outline),
                label: Text(
                  isVi
                      ? 'Hướng dẫn cài đặt Apps Script'
                      : 'Apps Script Setup Guide',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _backupToGoogleSheets() async {
    final isVi = AppLocalizations.of(context)!.locale.languageCode == 'vi';
    final url = _googleSheetsUrlController.text.trim();

    if (url.isEmpty) {
      ToastHelper.showWarning(
        context,
        isVi
            ? 'Vui lòng cấu hình và lưu Web App URL trước.'
            : 'Please configure and save Web App URL first.',
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final success = await GoogleSheetsService.instance.backupToGoogleSheets(
      url,
    );

    if (mounted) {
      Navigator.of(context).pop();
      if (success) {
        ToastHelper.showSuccess(
          context,
          isVi
              ? 'Sao lưu dữ liệu lên Google Sheets thành công!'
              : 'Google Sheets backup successful!',
        );
      } else {
        ToastHelper.showError(
          context,
          isVi
              ? 'Sao lưu thất bại. Vui lòng kiểm tra lại URL.'
              : 'Backup failed. Please check your URL.',
        );
      }
    }
  }

  Future<void> _restoreFromGoogleSheets() async {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    final url = _googleSheetsUrlController.text.trim();

    if (url.isEmpty) {
      ToastHelper.showWarning(
        context,
        isVi
            ? 'Vui lòng cấu hình Web App URL trước.'
            : 'Please configure Web App URL first.',
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).cardColor,
            title: Text(isVi ? 'Xác nhận khôi phục' : 'Confirm Restore'),
            content: Text(
              isVi
                  ? 'Dữ liệu hiện tại trên thiết bị sẽ bị ghi đè hoàn toàn bằng dữ liệu từ Google Sheets. Bạn có chắc chắn muốn tiếp tục?'
                  : 'Current local data will be completely overwritten by data from Google Sheets. Are you sure you want to continue?',
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
        ) ??
        false;

    if (!confirmed || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final success = await GoogleSheetsService.instance.restoreFromGoogleSheets(
      url,
    );

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
              TextButton(onPressed: () => exit(0), child: Text(loc.restart)),
            ],
          ),
        );
      } else {
        ToastHelper.showError(
          context,
          isVi
              ? 'Khôi phục thất bại. Vui lòng kiểm tra lại URL.'
              : 'Restore failed. Please check your URL.',
        );
      }
    }
  }

  Future<void> _tinhLaiSoBuoiDu() async {
    final isVi = AppLocalizations.of(context)!.locale.languageCode == 'vi';

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(ctx).cardColor,
            title: Text(
              isVi
                  ? 'Tính toán lại số buổi dư'
                  : 'Recalculate remaining sessions',
            ),
            content: Text(
              isVi
                  ? 'Ứng dụng sẽ tự động đặt lại và tính toán lại chính xác số buổi dư của tất cả học sinh theo dòng lịch sử điểm danh và thanh toán. Bạn có muốn tiếp tục?'
                  : 'The app will reset and recalculate all students\' remaining sessions chronologically from attendance and payment history. Do you want to proceed?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(ctx)!.get('cancel')!),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: Text(isVi ? 'Đồng ý' : 'Confirm'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final reportService = ReportService();
      await reportService.recalculateAllStudentsRemainingSessions();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ToastHelper.showSuccess(
          context,
          isVi
              ? 'Tính toán lại số buổi dư thành công!'
              : 'Recalculated remaining sessions successfully!',
        );
        ref.invalidate(settingsProvider);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ToastHelper.showError(
          context,
          isVi ? 'Có lỗi xảy ra: $e' : 'An error occurred: $e',
        );
      }
    }
  }

  void _showGoogleSheetsInstructions() {
    final isVi = AppLocalizations.of(context)!.locale.languageCode == 'vi';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        title: Text(
          isVi ? 'Hướng dẫn thiết lập Apps Script' : 'Apps Script Setup Guide',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVi
                    ? '1. Tạo một bảng tính Google Sheets mới trên Google Drive của bạn.\n'
                          '2. Vào Tiện ích mở rộng -> Apps Script.\n'
                          '3. Xóa hết code cũ và dán đoạn code dưới đây vào.\n'
                          '4. Nhấp vào nút Lưu và sau đó nhấp vào Triển khai -> Triển khai mới.\n'
                          '5. Chọn loại là "Ứng dụng web" (Web App).\n'
                          '6. Tại phần "Ai có quyền truy cập", chọn "Bất kỳ ai" (Anyone).\n'
                          '7. Nhấn Triển khai, cấp quyền nếu Google hỏi và sao chép đường dẫn Web App URL thu được dán vào ô bên dưới.'
                    : '1. Create a new Google Sheets on Google Drive.\n'
                          '2. Go to Extensions -> Apps Script.\n'
                          '3. Delete old code and paste the code snippet below.\n'
                          '4. Click Save, then click Deploy -> New deployment.\n'
                          '5. Select type as "Web App".\n'
                          '6. Under "Who has access", select "Anyone".\n'
                          '7. Click Deploy, authorize permissions, and copy the Web App URL into the App.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Apps Script Code:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.black12,
                child: const SelectableText(
                  'function doPost(e) {\n'
                  '  try {\n'
                  '    var payload = JSON.parse(e.postData.contents);\n'
                  '    if (payload.action === "backup") {\n'
                  '      var data = payload.data;\n'
                  '      var ss = SpreadsheetApp.getActiveSpreadsheet();\n'
                  '      for (var tableName in data) {\n'
                  '        var sheet = ss.getSheetByName(tableName) || ss.insertSheet(tableName);\n'
                  '        sheet.clear();\n'
                  '        var rows = data[tableName];\n'
                  '        if (rows && rows.length > 0) {\n'
                  '          var headers = Object.keys(rows[0]);\n'
                  '          sheet.appendRow(headers);\n'
                  '          var values = rows.map(function(row) {\n'
                  '            return headers.map(function(h) {\n'
                  '              var val = row[h];\n'
                  '              return (val === null || val === undefined) ? "" : val;\n'
                  '            });\n'
                  '          });\n'
                  '          sheet.getRange(2, 1, values.length, headers.length).setValues(values);\n'
                  '        }\n'
                  '      }\n'
                  '      return ContentService.createTextOutput(JSON.stringify({status: "success"}))\n'
                  '        .setMimeType(ContentService.MimeType.JSON);\n'
                  '    }\n'
                  '    return ContentService.createTextOutput(JSON.stringify({status: "error", message: "Invalid action"}))\n'
                  '      .setMimeType(ContentService.MimeType.JSON);\n'
                  '  } catch (err) {\n'
                  '    return ContentService.createTextOutput(JSON.stringify({status: "error", message: err.toString()}))\n'
                  '      .setMimeType(ContentService.MimeType.JSON);\n'
                  '  }\n'
                  '}\n\n'
                  'function doGet(e) {\n'
                  '  try {\n'
                  '    if (e.parameter.action === "restore") {\n'
                  '      var ss = SpreadsheetApp.getActiveSpreadsheet();\n'
                  '      var sheets = ss.getSheets();\n'
                  '      var data = {};\n'
                  '      for (var i = 0; i < sheets.length; i++) {\n'
                  '        var sheet = sheets[i];\n'
                  '        var tableName = sheet.getName();\n'
                  '        var values = sheet.getDataRange().getValues();\n'
                  '        if (values.length > 1) {\n'
                  '          var headers = values[0];\n'
                  '          var rows = [];\n'
                  '          for (var r = 1; r < values.length; r++) {\n'
                  '            var row = {};\n'
                  '            var hasData = false;\n'
                  '            for (var c = 0; c < headers.length; c++) {\n'
                  '              var val = values[r][c];\n'
                  '              if (val instanceof Date) {\n'
                  '                val = val.toISOString();\n'
                  '              }\n'
                  '              row[headers[c]] = val;\n'
                  '              if (val !== "") hasData = true;\n'
                  '            }\n'
                  '            if (hasData) {\n'
                  '              rows.push(row);\n'
                  '            }\n'
                  '          }\n'
                  '          data[tableName] = rows;\n'
                  '        } else {\n'
                  '          data[tableName] = [];\n'
                  '        }\n'
                  '      }\n'
                  '      return ContentService.createTextOutput(JSON.stringify({status: "success", data: data}))\n'
                  '        .setMimeType(ContentService.MimeType.JSON);\n'
                  '    }\n'
                  '    return ContentService.createTextOutput(JSON.stringify({status: "error", message: "Invalid action"}))\n'
                  '      .setMimeType(ContentService.MimeType.JSON);\n'
                  '  } catch (err) {\n'
                  '    return ContentService.createTextOutput(JSON.stringify({status: "error", message: err.toString()}))\n'
                  '      .setMimeType(ContentService.MimeType.JSON);\n'
                  '  }\n'
                  '}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.alarm_on,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc.locale.languageCode == 'vi'
                                      ? 'Thông báo nhắc ca học'
                                      : 'Class reminders',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DropdownButton<String>(
                            value: _reminderMinutes,
                            dropdownColor: Theme.of(context).cardColor,
                            onChanged: (String? newValue) async {
                              if (newValue != null) {
                                if (newValue != 'off') {
                                  final granted = await NotificationService.instance
                                      .requestPermissions();
                                  if (!context.mounted) return;
                                  if (!granted) {
                                    ToastHelper.showWarning(
                                      context,
                                      loc.locale.languageCode == 'vi'
                                          ? 'Vui lòng cấp quyền thông báo trong cài đặt máy'
                                          : 'Please enable notifications in device settings',
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
                                child: Text(
                                  loc.locale.languageCode == 'vi'
                                      ? 'Tắt thông báo'
                                      : 'Disable notifications',
                                ),
                              ),
                              DropdownMenuItem(
                                value: '5',
                                child: Text(
                                  loc.locale.languageCode == 'vi'
                                      ? 'Báo trước 5 phút'
                                      : '5 minutes before',
                                ),
                              ),
                              DropdownMenuItem(
                                value: '10',
                                child: Text(
                                  loc.locale.languageCode == 'vi'
                                      ? 'Báo trước 10 phút'
                                      : '10 minutes before',
                                ),
                              ),
                              DropdownMenuItem(
                                value: '15',
                                child: Text(
                                  loc.locale.languageCode == 'vi'
                                      ? 'Báo trước 15 phút'
                                      : '15 minutes before',
                                ),
                              ),
                              DropdownMenuItem(
                                value: '30',
                                child: Text(
                                  loc.locale.languageCode == 'vi'
                                      ? 'Báo trước 30 phút'
                                      : '30 minutes before',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_reminderMinutes != 'off') ...[
                        const Divider(height: 20),
                        Text(
                          loc.locale.languageCode == 'vi'
                              ? 'Tối ưu hóa cho máy thật (Android 12+):'
                              : 'Real Device Optimization (Android 12+):',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).hintColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                await NotificationService.instance.openExactAlarmSettings();
                              },
                              icon: const Icon(Icons.access_alarm, size: 16),
                              label: Text(
                                loc.locale.languageCode == 'vi'
                                    ? 'Cấp quyền báo thức chính xác'
                                    : 'Exact Alarm Permission',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final status = await Permission.ignoreBatteryOptimizations.request();
                                if (!context.mounted) return;
                                if (status.isGranted) {
                                  ToastHelper.showSuccess(
                                    context,
                                    loc.locale.languageCode == 'vi'
                                        ? 'Đã tắt tối ưu hóa pin cho ứng dụng'
                                        : 'Battery optimization disabled',
                                  );
                                } else {
                                  ToastHelper.showWarning(
                                    context,
                                    loc.locale.languageCode == 'vi'
                                        ? 'Chưa tắt tối ưu pin. Vui lòng chọn Không tối ưu hóa trong cài đặt'
                                        : 'Please set battery to unrestricted in device settings',
                                  );
                                }
                              },
                              icon: const Icon(Icons.battery_saver, size: 16),
                              label: Text(
                                loc.locale.languageCode == 'vi'
                                    ? 'Tắt tối ưu hóa pin'
                                    : 'Disable Battery Optimization',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await NotificationService.instance.scheduleTestNotification(10);
                                if (!context.mounted) return;
                                ToastHelper.showSuccess(
                                  context,
                                  loc.locale.languageCode == 'vi'
                                      ? 'Đã hẹn reo chuông sau 10 giây! Bạn có thể tắt/khóa màn hình để thử.'
                                      : 'Test alarm scheduled in 10s! You can turn off screen to test.',
                                );
                              },
                              icon: const Icon(Icons.play_circle_fill, size: 16),
                              label: Text(
                                loc.locale.languageCode == 'vi'
                                    ? 'Thử reo chuông (10 giây)'
                                    : 'Test Alarm (10s)',
                                style: const TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Cấu hình mã PIN bảo mật
              Card(
                color: Theme.of(context).cardColor,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        loc.locale.languageCode == 'vi'
                            ? 'Khóa ứng dụng bằng PIN'
                            : 'App PIN Lock',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      value: _pinEnabled,
                      onChanged: (bool value) async {
                        final caiDatService = ref.read(caiDatServiceProvider);
                        if (value) {
                          // Bật PIN: chuyển sang màn hình thiết lập PIN
                          final success = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PinLockScreen(isConfiguring: true),
                            ),
                          );
                          if (success == true) {
                            setState(() {
                              _pinEnabled = true;
                            });
                            ref.invalidate(settingsProvider);
                          }
                        } else {
                          // Tắt PIN và tắt vân tay luôn
                          await caiDatService.capNhatCaiDat(
                            'app_pin_enabled',
                            'false',
                          );
                          await caiDatService.capNhatCaiDat(
                            'app_biometric_enabled',
                            'false',
                          );
                          setState(() {
                            _pinEnabled = false;
                            _biometricEnabled = false;
                          });
                          ref.invalidate(settingsProvider);
                        }
                      },
                      secondary: Icon(
                        Icons.security_outlined,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      activeThumbColor: Theme.of(context).primaryColor,
                    ),
                    if (_pinEnabled) ...[
                      const Divider(height: 1),
                      SwitchListTile(
                        title: Text(
                          loc.locale.languageCode == 'vi'
                              ? 'Mở khóa bằng vân tay / khuôn mặt'
                              : 'Biometric Unlock',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        value: _biometricEnabled,
                        onChanged: (bool value) async {
                          final caiDatService = ref.read(caiDatServiceProvider);
                          if (value) {
                            final LocalAuthentication auth =
                                LocalAuthentication();
                            try {
                              final bool canAuthenticateWithBiometrics =
                                  await auth.canCheckBiometrics;
                              final bool canAuthenticate =
                                  canAuthenticateWithBiometrics ||
                                  await auth.isDeviceSupported();
                              if (!canAuthenticate) {
                                if (context.mounted) {
                                  ToastHelper.showError(
                                    context,
                                    loc.locale.languageCode == 'vi'
                                        ? 'Thiết bị không hỗ trợ sinh trắc học!'
                                        : 'Biometrics not supported on this device!',
                                  );
                                }
                                return;
                              }
                              final List<BiometricType> availableBiometrics =
                                  await auth.getAvailableBiometrics();
                              if (availableBiometrics.isEmpty) {
                                if (context.mounted) {
                                  ToastHelper.showError(
                                    context,
                                    loc.locale.languageCode == 'vi'
                                        ? 'Chưa đăng ký vân tay/khuôn mặt trên thiết bị!'
                                        : 'No biometrics registered on device!',
                                  );
                                }
                                return;
                              }

                              final bool
                              didAuthenticate = await auth.authenticate(
                                localizedReason: loc.locale.languageCode == 'vi'
                                    ? 'Xác thực vân tay/khuôn mặt để kích hoạt mở khóa'
                                    : 'Authenticate to enable biometric unlock',
                                options: const AuthenticationOptions(
                                  stickyAuth: true,
                                  biometricOnly: true,
                                ),
                              );

                              if (didAuthenticate) {
                                await caiDatService.capNhatCaiDat(
                                  'app_biometric_enabled',
                                  'true',
                                );
                                setState(() {
                                  _biometricEnabled = true;
                                });
                                ref.invalidate(settingsProvider);
                                if (context.mounted) {
                                  ToastHelper.showSuccess(
                                    context,
                                    loc.locale.languageCode == 'vi'
                                        ? 'Đã bật xác thực sinh trắc học thành công!'
                                        : 'Biometric unlock enabled successfully!',
                                  );
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ToastHelper.showError(
                                  context,
                                  'Lỗi xác thực: $e',
                                );
                              }
                            }
                          } else {
                            await caiDatService.capNhatCaiDat(
                              'app_biometric_enabled',
                              'false',
                            );
                            setState(() {
                              _biometricEnabled = false;
                            });
                            ref.invalidate(settingsProvider);
                          }
                        },
                        secondary: Icon(
                          Icons.fingerprint,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        activeThumbColor: Theme.of(context).primaryColor,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, right: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final success = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PinLockScreen(
                                      isConfiguring: true,
                                    ),
                                  ),
                                );
                                if (success == true) {
                                  ref.invalidate(settingsProvider);
                                }
                              },
                              icon: const Icon(Icons.lock_reset, size: 18),
                              label: Text(
                                loc.locale.languageCode == 'vi'
                                    ? 'Đổi mã PIN'
                                    : 'Change PIN',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Cài đặt đọc thông báo biến động số dư Sacombank
              Card(
                color: Theme.of(context).cardColor,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        loc.locale.languageCode == 'vi'
                            ? 'Duyệt học phí qua thông báo ngân hàng'
                            : 'Auto-approve via bank notification',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        loc.locale.languageCode == 'vi'
                            ? 'Tự động quét biến động số dư từ tất cả ngân hàng (Sacombank, VCB, MB, Vietinbank, BIDV, Agribank, VPBank, MoMo...) để gạch nợ & phát thông báo tức thì'
                            : 'Scan notifications from all banks (Sacombank, VCB, MB, Vietinbank, BIDV, MoMo...) to auto-update payment & push instant alerts',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                        ),
                      ),
                      value: _autoApprovePayment,
                      onChanged: (bool value) async {
                        if (value) {
                          // Check permission first
                          final permissionGranted = await BankNotificationService
                              .instance
                              .checkPermission();
                          if (!context.mounted) return;
                          if (!permissionGranted) {
                            // Ask user to grant permission
                            if (mounted) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: Theme.of(ctx).cardColor,
                                  title: Text(
                                    loc.locale.languageCode == 'vi'
                                        ? 'Cần cấp quyền truy cập'
                                        : 'Access Permission Required',
                                    style: Theme.of(ctx).textTheme.titleLarge,
                                  ),
                                  content: Text(
                                    loc.locale.languageCode == 'vi'
                                        ? 'Ứng dụng cần quyền "Truy cập thông báo" (Notification Access) để tự động đọc biến động số dư từ app ngân hàng (Sacombank, Vietcombank, MB, Techcombank, MoMo, v.v.).\n\n*Lưu ý (Android 13+): Nếu nút bật bị mờ (Cài đặt bị hạn chế), bạn hãy vào Cài đặt máy > Ứng dụng > Quản lý Học phí > Nhấn biểu tượng 3 chấm ở góc trên bên phải > Chọn "Cho phép cài đặt bị hạn chế" để mở khóa.'
                                        : 'The app needs "Notification Access" permission to automatically read balance changes from banking apps.\n\n*Note (Android 13+): If the toggle is greyed out (Restricted settings), go to Device Settings > Apps > Quản lý Học phí > Tap 3 dots in top right > Choose "Allow restricted settings".',
                                    style: Theme.of(ctx).textTheme.bodyLarge,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(loc.get('cancel')!),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await BankNotificationService.instance
                                            .openSettings();
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(
                                          context,
                                        ).primaryColor,
                                        foregroundColor: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                      child: Text(
                                        loc.locale.languageCode == 'vi'
                                            ? 'Mở cài đặt'
                                            : 'Open Settings',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return;
                          }
                        }
                        setState(() {
                          _autoApprovePayment = value;
                        });
                        // Save setting immediately
                        await ref
                            .read(caiDatServiceProvider)
                            .capNhatCaiDat(
                              'auto_approve_payment',
                              value ? '1' : '0',
                            );
                        ref.invalidate(settingsProvider);
                      },
                      secondary: Icon(
                        Icons.notifications_active_outlined,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      activeThumbColor: Theme.of(context).primaryColor,
                    ),

                    if (_autoApprovePayment) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Text(
                              loc.locale.languageCode == 'vi'
                                  ? 'Thử nghiệm thông báo:'
                                  : 'Test push alert:',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () async {
                                await BankNotificationService.instance
                                    .showTestNotification();
                                if (context.mounted) {
                                  ToastHelper.showSuccess(
                                    context,
                                    loc.locale.languageCode == 'vi'
                                        ? 'Đã gửi thông báo thử nghiệm! Kiểm tra thanh thông báo thiết bị.'
                                        : 'Test notification sent! Check device status bar.',
                                  );
                                }
                              },
                              icon: const Icon(
                                Icons.notification_add_rounded,
                                size: 18,
                              ),
                              label: Text(
                                loc.locale.languageCode == 'vi'
                                    ? 'Phát thông báo mẫu'
                                    : 'Send Test Alert',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
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
                  loc.locale.languageCode == 'vi'
                      ? 'Thông tin Ngân hàng (Để tạo mã QR)'
                      : 'Bank Information (For QR)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextField(
                controller: _bankIdController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: _inputDecoration(
                  context,
                  loc.locale.languageCode == 'vi'
                      ? 'Mã Ngân hàng (VD: sacombank, vcb, acb)'
                      : 'Bank Code (e.g. sacombank, vcb, acb)',
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
                  loc.locale.languageCode == 'vi'
                      ? 'Số tài khoản'
                      : 'Account number',
                  Icons.numbers,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accountNameController,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: _inputDecoration(
                  context,
                  loc.locale.languageCode == 'vi'
                      ? 'Tên chủ tài khoản (KHÔNG DẤU)'
                      : 'Account name (NO ACCENTS)',
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
                  labelText: loc.locale.languageCode == 'vi'
                      ? 'Số buổi học chuẩn/tháng'
                      : 'Standard sessions/month',
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
                  loc.locale.languageCode == 'vi'
                      ? 'Quản lý dữ liệu'
                      : 'Data Management',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _backupDatabase,
                      icon: const Icon(Icons.backup),
                      label: Text(
                        loc.locale.languageCode == 'vi' ? 'Sao lưu' : 'Backup',
                      ),
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
                      label: Text(
                        loc.locale.languageCode == 'vi'
                            ? 'Phục hồi'
                            : 'Restore',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _tinhLaiSoBuoiDu,
                icon: const Icon(Icons.calculate_outlined),
                label: Text(
                  loc.locale.languageCode == 'vi'
                      ? 'Tính toán lại số buổi dư học sinh'
                      : 'Recalculate Student Remaining Sessions',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
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
