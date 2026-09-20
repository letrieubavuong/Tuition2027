import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/db.dart';
import '../utils/vietqr_util.dart';
import 'widget_snapshot_service.dart';

class WidgetSyncService {
  static Future<void> syncTodaySchedule() async {
    await WidgetSnapshotService.instance.refresh();
  }

  static Future<void> syncBankQRWidget() async {
    try {
      final db = await DBHelper.instance.database;
      final List<Map<String, dynamic>> settings = await db.query(
        DBHelper.tenBangCaiDat,
      );

      String bankId = 'sacombank';
      String accountNo = '';
      String accountName = '';

      for (var row in settings) {
        final key = row['khoa'] as String;
        final val = row['gia_tri'] as String;
        if (key == 'bank_id') bankId = val;
        if (key == 'account_no') accountNo = val;
        if (key == 'account_name') accountName = val;
      }

      if (accountNo.trim().isEmpty) {
        await HomeWidget.saveWidgetData<String>(
          'qr_bank_info',
          'Chưa cấu hình tài khoản',
        );
        await HomeWidget.saveWidgetData<String>('qr_image_path', '');
        await HomeWidget.updateWidget(
          name: 'BankQRWidgetProvider',
          androidName: 'BankQRWidgetProvider',
          qualifiedAndroidName: 'com.example.tuition2025.BankQRWidgetProvider',
        );
        return;
      }

      final String bankInfoText =
          'NH: ${bankId.toUpperCase()} - $accountNo\n$accountName';
      await HomeWidget.saveWidgetData<String>('qr_bank_info', bankInfoText);

      // Generate payload (with amount 0 for generic payment)
      final String qrPayload = VietQRUtil.generateVietQRPayload(
        bankId: bankId,
        accountNo: accountNo,
        amount: 0,
        description: 'Thanh toan hoc phi',
      );

      // Render to image
      final qrPainter = QrPainter(
        data: qrPayload,
        version: QrVersions.auto,
        gapless: true,
        errorCorrectionLevel: QrErrorCorrectLevel.Q,
      );

      final ui.Image image = await qrPainter.toImage(300);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final directory = await getTemporaryDirectory();
        final qrFile = File('${directory.path}/bank_qr_widget.png');
        await qrFile.writeAsBytes(pngBytes);

        await HomeWidget.saveWidgetData<String>('qr_image_path', qrFile.path);
      }

      await HomeWidget.updateWidget(
        name: 'BankQRWidgetProvider',
        androidName: 'BankQRWidgetProvider',
        qualifiedAndroidName: 'com.example.tuition2025.BankQRWidgetProvider',
      );
    } catch (e) {
      // Fail silently
    }
  }
}
