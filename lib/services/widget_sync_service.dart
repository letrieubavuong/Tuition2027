import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../utils/db.dart';
import '../utils/vietqr_util.dart';

class WidgetSyncService {
  static Future<void> syncTodaySchedule() async {
    try {
      final db = await DBHelper.instance.database;
      final now = DateTime.now();
      final int thuHienTai = now.weekday; // 1=Mon, ..., 7=Sun
      final int thuTrongTuanDB = (thuHienTai == 7) ? 1 : thuHienTai + 1;

      final List<Map<String, dynamic>> caHocHomNay = await db.rawQuery(
        '''
        SELECT L.ten as tenLop, LH.gioBatDau, LH.gioKetThuc
        FROM ${DBHelper.tenBangLichHoc} LH
        JOIN ${DBHelper.tenBangLop} L ON LH.id_lop = L.id
        WHERE LH.thuTrongTuan = ?
        ORDER BY LH.gioBatDau ASC
        ''',
        [thuTrongTuanDB],
      );

      final dateFormatted = DateFormat('dd/MM/yyyy').format(now);
      final dayNames = {
        1: 'Chủ Nhật',
        2: 'Thứ Hai',
        3: 'Thứ Ba',
        4: 'Thứ Tư',
        5: 'Thứ Năm',
        6: 'Thứ Sáu',
        7: 'Thứ Bảy',
      };
      final dayName = dayNames[thuTrongTuanDB] ?? 'Hôm nay';

      await HomeWidget.saveWidgetData<String>(
        'widget_date',
        '$dayName ($dateFormatted)',
      );

      if (caHocHomNay.isEmpty) {
        await HomeWidget.saveWidgetData<bool>('widget_empty', true);
      } else {
        await HomeWidget.saveWidgetData<bool>('widget_empty', false);

        // Populate up to 8 slots
        for (int i = 0; i < 8; i++) {
          final slotIndex = i + 1;
          if (i < caHocHomNay.length) {
            final classItem = caHocHomNay[i];
            var rawTime = classItem['gioBatDau'] as String;
            if (rawTime.length >= 5) {
              rawTime = rawTime.substring(0, 5);
            }
            final timeStr = rawTime;
            final nameStr = classItem['tenLop'] as String;

            await HomeWidget.saveWidgetData<String>('time_$slotIndex', timeStr);
            await HomeWidget.saveWidgetData<String>('name_$slotIndex', nameStr);
          } else {
            await HomeWidget.saveWidgetData<String>('time_$slotIndex', '');
            await HomeWidget.saveWidgetData<String>('name_$slotIndex', '');
          }
        }
      }

      await HomeWidget.updateWidget(
        name: 'TuitionWidgetProvider',
        androidName: 'TuitionWidgetProvider',
      );
    } catch (e) {
      // Fail silently
    }
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
      );
    } catch (e) {
      // Fail silently
    }
  }
}
