// File: lib/screens/caidat.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../services/caidat_service.dart';
import '../services/notification_service.dart';
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
import '../widgets/settings_tile.dart';

// --- Riverpod Providers ---

final caiDatServiceProvider = Provider((ref) => CaiDatService());
final truongServiceProvider = Provider((ref) => TruongService());

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
  final String reminderMinutes;
  final String appPinEnabled;
  final String appBiometricEnabled;
  final String autoApprovePayment;
  final String widgetRefreshInterval;

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
    required this.widgetRefreshInterval,
  });
}

final settingsProvider = FutureProvider<SettingsData>((ref) async {
  final caiDatService = ref.watch(caiDatServiceProvider);
  final truongService = ref.watch(truongServiceProvider);

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
    caiDatService.layCaiDat('app_biometric_enabled'),
    caiDatService.layCaiDat('widget_refresh_interval_minutes'),
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
    appBiometricEnabled: (results[13] as String?) ?? 'false',
    widgetRefreshInterval: (results[14] as String?) ?? '80',
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
  String _widgetRefreshInterval = '80';
  bool _pinEnabled = false;
  bool _biometricEnabled = false;
  bool _autoApprovePayment = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<SettingsData>>(settingsProvider, (_, next) {
      if (next is AsyncData<SettingsData>) {
        final data = next.value;
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
          _widgetRefreshInterval = data.widgetRefreshInterval;
          _pinEnabled = data.appPinEnabled == 'true';
          _biometricEnabled = data.appBiometricEnabled == 'true';
          _autoApprovePayment = data.autoApprovePayment == '1';
        });
      }
    }, fireImmediately: true);
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

  Future<void> _luuCaiDatChung() async {
    final caiDatService = ref.read(caiDatServiceProvider);
    final currentSettings = ref.read(settingsProvider).asData?.value;

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

    final settingsBatch = {
      'hoc_phi_buoi': hpBuoi,
      'hoc_phi_thang': hpThang,
      'so_buoi_chuan_thang': soBuoiChuan,
      'nguoi_quan_ly': tenQuanLy,
      'email': emailQuanLy,
      'bank_id': bankId,
      'account_no': accountNo,
      'account_name': accountName,
      'reminder_minutes': _reminderMinutes,
      'app_pin_enabled': _pinEnabled ? 'true' : 'false',
      'auto_approve_payment': _autoApprovePayment ? '1' : '0',
      'widget_refresh_interval_minutes': _widgetRefreshInterval,
    };

    final success = await caiDatService.capNhatCaiDatBatch(settingsBatch);

    if (success) {
      await HomeWidget.saveWidgetData<String>(
        'widget_refresh_interval_minutes',
        _widgetRefreshInterval,
      );
      try {
        await const MethodChannel(
          'com.example.tuition2025/notification_listener',
        ).invokeMethod('rescheduleWidgetWorker', {
          'interval': int.tryParse(_widgetRefreshInterval) ?? 80,
        });
      } catch (_) {}

      if (currentSettings == null ||
          currentSettings.reminderMinutes != _reminderMinutes) {
        await NotificationService.instance.syncAllClassReminders();
      }

      if (currentSettings == null ||
          currentSettings.bankId != bankId ||
          currentSettings.accountNo != accountNo ||
          currentSettings.accountName != accountName) {
        await WidgetSyncService.syncBankQRWidget();
      }

      if (mounted) {
        ToastHelper.showSuccess(
          context,
          AppLocalizations.of(context)!.saveSettingsSuccess,
        );
      }
      ref.invalidate(settingsProvider);
    } else {
      if (mounted) {
        ToastHelper.showError(
          context,
          AppLocalizations.of(context)!.locale.languageCode == 'vi'
              ? 'Lỗi lưu cài đặt. Vui lòng thử lại.'
              : 'Error saving settings. Please try again.',
        );
      }
    }
  }

  // --- HÀM THỰC THI CHỨC NĂNG DỮ LIỆU & HỆ THỐNG ---

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

      Database? tempDb;
      try {
        tempDb = await openDatabase(selectedPath, readOnly: true);
        final pragmaRes = await tempDb.rawQuery('PRAGMA integrity_check');
        final isOk =
            pragmaRes.isNotEmpty && pragmaRes.first.values.first == 'ok';
        if (!isOk) {
          throw Exception(
            'File sao lưu bị hỏng (PRAGMA integrity_check failed).',
          );
        }

        final tablesRes = await tempDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        final tableNames = tablesRes.map((r) => r['name'] as String).toSet();
        const requiredTables = [
          'hoc_sinh',
          'lop',
          'diem_danh',
          'thanh_toan',
          'cai_dat',
        ];
        for (var reqTable in requiredTables) {
          if (!tableNames.contains(reqTable)) {
            throw Exception(
              'File sao lưu không hợp lệ: Thiếu bảng bắt buộc $reqTable.',
            );
          }
        }
      } catch (e) {
        if (tempDb != null && tempDb.isOpen) {
          await tempDb.close();
        }
        if (!mounted) return;
        ToastHelper.showError(
          context,
          loc.locale.languageCode == 'vi'
              ? 'File sao lưu không hợp lệ: $e'
              : 'Invalid backup file: $e',
        );
        return;
      } finally {
        if (tempDb != null && tempDb.isOpen) {
          await tempDb.close();
        }
      }

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

      final dbPath = await getDatabasesPath();
      final originalDbPath = p.join(dbPath, 'quan_ly_hs.db');
      final tempSafetyBackupPath = p.join(dbPath, 'quan_ly_hs_safety.bak');

      try {
        await DBHelper.instance.close();

        final originalFile = File(originalDbPath);
        if (await originalFile.exists()) {
          await originalFile.copy(tempSafetyBackupPath);
        }

        await backupFile.copy(originalDbPath);

        final safetyBakFile = File(tempSafetyBackupPath);
        if (await safetyBakFile.exists()) {
          await safetyBakFile.delete();
        }

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
        final safetyBakFile = File(tempSafetyBackupPath);
        if (await safetyBakFile.exists()) {
          await safetyBakFile.copy(originalDbPath);
          await safetyBakFile.delete();
        }
        await DBHelper.instance.database;
        if (!mounted) return;
        ToastHelper.showError(
          context,
          AppLocalizations.of(context)!.restoreError(e.toString()),
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
        Navigator.pop(context);
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
        Navigator.pop(context);
        ToastHelper.showError(
          context,
          isVi ? 'Có lỗi xảy ra: $e' : 'An error occurred: $e',
        );
      }
    }
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
    if (!mounted) return;
    ToastHelper.showSuccess(
      context,
      AppLocalizations.of(context)!.deleteSchoolSuccess,
    );
  }

  // --- BOTTOM SHEETS CHỈNH SỬA CÀI ĐẶT ---

  void _showProfileEditSheet(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSheetHandle(),
              Text(
                loc.managerInfo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tenQuanLyController,
                decoration: _inputDecoration(
                  ctx,
                  loc.managerName,
                  Icons.person,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailQuanLyController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(ctx, loc.email, Icons.email),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _luuCaiDatChung();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  loc.get('save')!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showTuitionEditSheet(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSheetHandle(),
              Text(
                loc.feeSettings,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hocPhiBuoiController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  ctx,
                  loc.feePerSession,
                  Icons.monetization_on_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _soBuoiChuanController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  ctx,
                  isVi ? 'Số buổi học chuẩn/tháng' : 'Standard sessions/month',
                  Icons.calendar_today_outlined,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hocPhiThangController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  ctx,
                  loc.feePerMonth,
                  Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _luuCaiDatChung();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  loc.saveSettings,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showBankEditSheet(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSheetHandle(),
              Text(
                isVi
                    ? 'Thông tin Ngân hàng (Để tạo mã QR)'
                    : 'Bank Information (For QR)',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bankIdController,
                decoration: _inputDecoration(
                  ctx,
                  isVi
                      ? 'Mã Ngân hàng (VD: sacombank, vcb, acb)'
                      : 'Bank Code (e.g. sacombank, vcb, acb)',
                  Icons.account_balance,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountNoController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  ctx,
                  isVi ? 'Số tài khoản' : 'Account number',
                  Icons.numbers,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountNameController,
                decoration: _inputDecoration(
                  ctx,
                  isVi
                      ? 'Tên chủ tài khoản (KHÔNG DẤU)'
                      : 'Account name (NO ACCENTS)',
                  Icons.badge,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _luuCaiDatChung();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  loc.get('save')!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationEditSheet(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSheetHandle(),
                  Text(
                    isVi
                        ? 'Cấu hình Thông báo ca học'
                        : 'Class Notification Settings',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      isVi ? 'Thời gian nhắc nhở' : 'Reminder lead time',
                    ),
                    trailing: DropdownButton<String>(
                      value: _reminderMinutes,
                      onChanged: (String? newValue) async {
                        if (newValue != null) {
                          if (newValue != 'off') {
                            final granted = await NotificationService.instance
                                .requestPermissions();
                            if (!context.mounted) return;
                            if (!granted) {
                              ToastHelper.showWarning(
                                context,
                                isVi
                                    ? 'Vui lòng cấp quyền thông báo trong cài đặt máy'
                                    : 'Please enable notifications in device settings',
                              );
                            }
                          }
                          setState(() {
                            _reminderMinutes = newValue;
                          });
                          setSheetState(() {});
                          await _luuCaiDatChung();
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'off',
                          child: Text(isVi ? 'Tắt thông báo' : 'Disabled'),
                        ),
                        DropdownMenuItem(
                          value: '5',
                          child: Text(
                            isVi ? 'Báo trước 5 phút' : '5 mins before',
                          ),
                        ),
                        DropdownMenuItem(
                          value: '10',
                          child: Text(
                            isVi ? 'Báo trước 10 phút' : '10 mins before',
                          ),
                        ),
                        DropdownMenuItem(
                          value: '15',
                          child: Text(
                            isVi ? 'Báo trước 15 phút' : '15 mins before',
                          ),
                        ),
                        DropdownMenuItem(
                          value: '30',
                          child: Text(
                            isVi ? 'Báo trước 30 phút' : '30 mins before',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                  Text(
                    isVi
                        ? 'Tối ưu hóa hệ thống cho máy thật:'
                        : 'System Real Device Optimizations:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await NotificationService.instance
                          .openExactAlarmSettings();
                    },
                    icon: const Icon(Icons.access_alarm, size: 18),
                    label: Text(
                      isVi
                          ? 'Cấp quyền báo thức chính xác'
                          : 'Exact Alarm Permission',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final status = await Permission.ignoreBatteryOptimizations
                          .request();
                      if (!context.mounted) return;
                      if (status.isGranted) {
                        ToastHelper.showSuccess(
                          context,
                          isVi
                              ? 'Đã tắt tối ưu hóa pin cho ứng dụng'
                              : 'Battery optimization disabled',
                        );
                      } else {
                        ToastHelper.showWarning(
                          context,
                          isVi
                              ? 'Chưa tắt tối ưu pin. Vui lòng chọn Không tối ưu hóa trong cài đặt'
                              : 'Please set battery to unrestricted',
                        );
                      }
                    },
                    icon: const Icon(Icons.battery_saver, size: 18),
                    label: Text(
                      isVi
                          ? 'Tắt tối ưu hóa pin'
                          : 'Disable Battery Optimization',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await NotificationService.instance
                          .scheduleTestNotification(10);
                      if (!context.mounted) return;
                      ToastHelper.showSuccess(
                        context,
                        isVi
                            ? 'Đã hẹn reo chuông sau 10 giây! Tắt màn hình để thử.'
                            : 'Test alarm scheduled in 10s!',
                      );
                    },
                    icon: const Icon(Icons.play_circle_fill, size: 18),
                    label: Text(
                      isVi ? 'Thử reo chuông (10 giây)' : 'Test Alarm (10s)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showWidgetSettingsSheet(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSheetHandle(),
                  Text(
                    isVi
                        ? 'Cấu hình Home Screen Widget'
                        : 'Home Screen Widget Configuration',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      isVi
                          ? 'Tần suất làm mới nền Widget'
                          : 'Background Refresh Interval',
                    ),
                    subtitle: Text(
                      isVi
                          ? 'Khoảng thời gian Android cập nhật tự động ca học'
                          : 'Interval for Android background updates',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: DropdownButton<String>(
                      value: _widgetRefreshInterval,
                      onChanged: (String? newValue) async {
                        if (newValue != null) {
                          setState(() {
                            _widgetRefreshInterval = newValue;
                          });
                          setSheetState(() {});
                          await _luuCaiDatChung();
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: '15',
                          child: Text(isVi ? '15 phút' : '15 mins'),
                        ),
                        DropdownMenuItem(
                          value: '30',
                          child: Text(isVi ? '30 phút' : '30 mins'),
                        ),
                        DropdownMenuItem(
                          value: '60',
                          child: Text(isVi ? '60 phút' : '60 mins'),
                        ),
                        DropdownMenuItem(
                          value: '80',
                          child: Text(
                            isVi ? '80 phút (Khuyên dùng)' : '80 mins (Rec)',
                          ),
                        ),
                        DropdownMenuItem(
                          value: '90',
                          child: Text(isVi ? '90 phút' : '90 mins'),
                        ),
                        DropdownMenuItem(
                          value: '120',
                          child: Text(isVi ? '120 phút' : '120 mins'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSchoolManagementSheet(BuildContext context, List<Truong> schools) {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSheetHandle(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    loc.schoolList,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.add_circle,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _hienThiFormTruong();
                    },
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: schools.isEmpty
                    ? Center(
                        child: Text(
                          loc.locale.languageCode == 'vi'
                              ? 'Chưa có trường học nào'
                              : 'No schools added yet',
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      )
                    : ListView.separated(
                        itemCount: schools.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final truong = schools[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              truong.ten,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 20,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _hienThiFormTruong(truong: truong);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _xoaTruong(truong.id!);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // --- BUILD MÀN HÌNH CHÍNH (PREMIUM CLEAN MATERIAL 3) ---

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsAsync = ref.watch(settingsProvider);

    final formatCurrency = NumberFormat('#,##0', 'vi_VN');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.appSettings,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              isVi
                  ? 'Cá nhân hóa và quản lý ứng dụng'
                  : 'Preferences & app settings',
              style: TextStyle(
                fontSize: 12,
                color: theme.hintColor,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: settingsAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: theme.primaryColor)),
        error: (err, stack) => Center(
          child: Text(
            'Lỗi tải cài đặt: $err',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ),
        data: (settingsData) {
          // Format tuition fees preview
          final hpBuoiInt = int.tryParse(settingsData.hocPhiBuoi) ?? 0;
          final hpThangInt = int.tryParse(settingsData.hocPhiThang) ?? 0;
          final tuitionPreview = (hpBuoiInt > 0 || hpThangInt > 0)
              ? '${hpBuoiInt > 0 ? "${formatCurrency.format(hpBuoiInt)}đ/buổi" : ""}${hpBuoiInt > 0 && hpThangInt > 0 ? " • " : ""}${hpThangInt > 0 ? "${formatCurrency.format(hpThangInt)}đ/tháng" : ""}'
              : (isVi ? 'Chưa thiết lập' : 'Not configured');

          // Format bank preview
          final bankPreview = settingsData.accountNo.isNotEmpty
              ? '${settingsData.bankId.toUpperCase()} • ****${settingsData.accountNo.substring(settingsData.accountNo.length > 4 ? settingsData.accountNo.length - 4 : 0)}'
              : (isVi ? 'Chưa cài đặt' : 'Not configured');

          // Format reminder preview
          final reminderPreview = _reminderMinutes == 'off'
              ? (isVi ? 'Tắt thông báo' : 'Disabled')
              : (isVi
                    ? 'Báo trước $_reminderMinutes phút'
                    : '$_reminderMinutes mins before');

          // Initials for Avatar
          final initials = settingsData.tenQuanLy.trim().isNotEmpty
              ? settingsData.tenQuanLy
                    .trim()
                    .split(' ')
                    .where((s) => s.isNotEmpty)
                    .take(2)
                    .map((s) => s[0].toUpperCase())
                    .join('')
              : 'TV';

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            children: [
              // ─── 1. QUICK PROFILE BLOCK ───
              Container(
                margin: const EdgeInsets.only(bottom: 24.0),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerLow
                      : theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primaryColor.withOpacity(0.15),
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                  title: Text(
                    settingsData.tenQuanLy,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    '${settingsData.emailQuanLy} • ${isVi ? "Quản lý cơ sở" : "Facility Admin"}',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white38 : Colors.grey.shade400,
                  ),
                  onTap: () => _showProfileEditSheet(context),
                ),
              ),

              // ─── 2. SECTION: GIAO DIỆN & NGÔN NGỮ ───
              SettingsSection(
                title: isVi ? 'Giao diện & Ngôn ngữ' : 'Appearance & Language',
                children: [
                  SettingsSwitchTile(
                    leadingIcon: Icons.dark_mode_outlined,
                    title: loc.darkMode,
                    value: ref.watch(themeModeProvider) == ThemeMode.dark,
                    onChanged: (isDark) {
                      ref.read(themeModeProvider.notifier).state = isDark
                          ? ThemeMode.dark
                          : ThemeMode.light;
                    },
                  ),
                  SettingsTile(
                    leadingIcon: Icons.language_outlined,
                    title: loc.language,
                    valueText: ref.watch(localeProvider).languageCode == 'vi'
                        ? 'Tiếng Việt 🇻🇳'
                        : 'English 🇬🇧',
                    onTap: () {
                      final currentLocale = ref.read(localeProvider);
                      final nextLocale = currentLocale.languageCode == 'vi'
                          ? const Locale('en')
                          : const Locale('vi');
                      ref.read(localeProvider.notifier).state = nextLocale;
                    },
                  ),
                ],
              ),

              // ─── 3. SECTION: GIẢNG DẠY & HỌC PHÍ ───
              SettingsSection(
                title: isVi ? 'Giảng dạy & Học phí' : 'Tuition & Schools',
                children: [
                  SettingsTile(
                    leadingIcon: Icons.payments_outlined,
                    title: loc.feeSettings,
                    subtitle: tuitionPreview,
                    onTap: () => _showTuitionEditSheet(context),
                  ),
                  SettingsTile(
                    leadingIcon: Icons.school_outlined,
                    title: loc.schoolList,
                    subtitle: isVi
                        ? 'Quản lý các trường học liên kết'
                        : 'Manage student schools',
                    valueText:
                        '${settingsData.danhSachTruong.length} ${isVi ? "trường" : "schools"}',
                    onTap: () => _showSchoolManagementSheet(
                      context,
                      settingsData.danhSachTruong,
                    ),
                  ),
                ],
              ),

              // ─── 4. SECTION: THÔNG BÁO & LỊCH DẠY ───
              SettingsSection(
                title: isVi ? 'Thông báo & Widget' : 'Notifications & Widget',
                children: [
                  SettingsTile(
                    leadingIcon: Icons.alarm_outlined,
                    title: isVi ? 'Thông báo nhắc ca học' : 'Class reminders',
                    subtitle: isVi
                        ? 'Hẹn giờ phát thông báo trước ca dạy'
                        : 'Pre-class alert lead time',
                    valueText: reminderPreview,
                    onTap: () => _showNotificationEditSheet(context),
                  ),
                  SettingsTile(
                    leadingIcon: Icons.widgets_outlined,
                    title: isVi
                        ? 'Widget màn hình chính'
                        : 'Home Screen Widget',
                    subtitle: isVi
                        ? 'Tần suất làm mới dữ liệu nền'
                        : 'Background data refresh interval',
                    valueText:
                        '$_widgetRefreshInterval ${isVi ? "phút" : "mins"}',
                    onTap: () => _showWidgetSettingsSheet(context),
                  ),
                ],
              ),

              // ─── 5. SECTION: THANH TOÁN & NGÂN HÀNG ───
              SettingsSection(
                title: isVi ? 'Thanh toán & Ngân hàng' : 'Payment & Banking',
                children: [
                  SettingsTile(
                    leadingIcon: Icons.qr_code_2_outlined,
                    title: isVi
                        ? 'Tài khoản nhận tiền QR'
                        : 'QR Payment Account',
                    subtitle: settingsData.accountName.isNotEmpty
                        ? settingsData.accountName
                        : (isVi ? 'Cấu hình mã QR VietQR' : 'Configure VietQR'),
                    valueText: bankPreview,
                    onTap: () => _showBankEditSheet(context),
                  ),
                  SettingsSwitchTile(
                    leadingIcon: Icons.notifications_active_outlined,
                    title: isVi
                        ? 'Tự động duyệt học phí qua SMS'
                        : 'Auto-approve via notifications',
                    subtitle: isVi
                        ? 'Tự động quét biến động số dư ngân hàng'
                        : 'Auto scan bank balance alerts',
                    value: _autoApprovePayment,
                    onChanged: (bool value) async {
                      if (value) {
                        final permissionGranted = await BankNotificationService
                            .instance
                            .checkPermission();
                        if (!context.mounted) return;
                        if (!permissionGranted) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: Theme.of(ctx).cardColor,
                              title: Text(
                                isVi
                                    ? 'Cần cấp quyền truy cập'
                                    : 'Permission Required',
                              ),
                              content: Text(
                                isVi
                                    ? 'Ứng dụng cần quyền "Truy cập thông báo" để đọc biến động số dư từ app ngân hàng.\n\n*Lưu ý (Android 13+): Nếu nút bật bị mờ, hãy chọn "Cho phép cài đặt bị hạn chế" trong Cài đặt ứng dụng.'
                                    : 'Notification Access required to scan balance changes.',
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
                                    backgroundColor: theme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    isVi ? 'Mở cài đặt' : 'Open Settings',
                                  ),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                      }
                      setState(() {
                        _autoApprovePayment = value;
                      });
                      await ref
                          .read(caiDatServiceProvider)
                          .capNhatCaiDat(
                            'auto_approve_payment',
                            value ? '1' : '0',
                          );
                      ref.invalidate(settingsProvider);
                    },
                  ),
                ],
              ),

              // ─── 6. SECTION: BẢO MẬT & QUYỀN RIÊNG TƯ ───
              SettingsSection(
                title: isVi ? 'Bảo mật & Quyền riêng tư' : 'Security & Privacy',
                children: [
                  SettingsSwitchTile(
                    leadingIcon: Icons.security_outlined,
                    title: isVi ? 'Khóa ứng dụng bằng PIN' : 'App PIN Lock',
                    value: _pinEnabled,
                    onChanged: (bool value) async {
                      final caiDatService = ref.read(caiDatServiceProvider);
                      if (value) {
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
                  ),
                  if (_pinEnabled) ...[
                    SettingsSwitchTile(
                      leadingIcon: Icons.fingerprint,
                      title: isVi
                          ? 'Mở khóa vân tay / khuôn mặt'
                          : 'Biometric Unlock',
                      value: _biometricEnabled,
                      onChanged: (bool value) async {
                        final caiDatService = ref.read(caiDatServiceProvider);
                        if (value) {
                          final LocalAuthentication auth =
                              LocalAuthentication();
                          try {
                            final bool canAuth =
                                await auth.canCheckBiometrics ||
                                await auth.isDeviceSupported();
                            if (!canAuth) {
                              if (context.mounted) {
                                ToastHelper.showError(
                                  context,
                                  isVi
                                      ? 'Thiết bị không hỗ trợ sinh trắc học!'
                                      : 'Biometrics not supported!',
                                );
                              }
                              return;
                            }
                            final didAuth = await auth.authenticate(
                              localizedReason: isVi
                                  ? 'Xác thực vân tay/khuôn mặt'
                                  : 'Authenticate biometric',
                              options: const AuthenticationOptions(
                                stickyAuth: true,
                                biometricOnly: true,
                              ),
                            );

                            if (didAuth) {
                              await caiDatService.capNhatCaiDat(
                                'app_biometric_enabled',
                                'true',
                              );
                              setState(() {
                                _biometricEnabled = true;
                              });
                              ref.invalidate(settingsProvider);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ToastHelper.showError(context, 'Lỗi: $e');
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
                    ),
                    SettingsTile(
                      leadingIcon: Icons.lock_reset_outlined,
                      title: isVi ? 'Đổi mã PIN mở khóa' : 'Change PIN',
                      onTap: () async {
                        final success = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PinLockScreen(isConfiguring: true),
                          ),
                        );
                        if (success == true) {
                          ref.invalidate(settingsProvider);
                        }
                      },
                    ),
                  ],
                ],
              ),

              // ─── 7. SECTION: DỮ LIỆU & HỆ THỐNG ───
              SettingsSection(
                title: isVi ? 'Dữ liệu & Hệ thống' : 'Data & System',
                children: [
                  SettingsTile(
                    leadingIcon: Icons.backup_outlined,
                    title: isVi ? 'Sao lưu dữ liệu' : 'Backup Database',
                    subtitle: isVi
                        ? 'Xuất file dữ liệu .db ra thư mục Download'
                        : 'Export .db backup file',
                    onTap: _backupDatabase,
                  ),
                  SettingsTile(
                    leadingIcon: Icons.restore_outlined,
                    title: isVi ? 'Phục hồi dữ liệu' : 'Restore Database',
                    subtitle: isVi
                        ? 'Khôi phục từ file sao lưu .db'
                        : 'Restore from backup file',
                    isDanger: true,
                    onTap: _restoreDatabase,
                  ),
                  SettingsTile(
                    leadingIcon: Icons.calculate_outlined,
                    title: isVi
                        ? 'Tính toán lại số buổi dư học sinh'
                        : 'Recalculate Student Remaining Sessions',
                    subtitle: isVi
                        ? 'Khôi phục độ chính xác theo lịch sử'
                        : 'Audit history for accuracy',
                    onTap: _tinhLaiSoBuoiDu,
                  ),
                ],
              ),

              // ─── 8. ABOUT FOOTER ───
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  children: [
                    Text(
                      'Quản lý Học phí © 2026',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Phiên bản 2.5.0 Premium • Build 2026.09',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.hintColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white70 : Colors.black87,
        fontSize: 14,
      ),
      prefixIcon: Icon(icon, color: theme.primaryColor, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.primaryColor, width: 2),
      ),
      fillColor: isDark
          ? theme.colorScheme.surfaceContainerLow
          : Colors.grey.shade50,
      filled: true,
    );
  }
}
