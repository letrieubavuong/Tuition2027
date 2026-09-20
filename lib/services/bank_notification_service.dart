// File: lib/services/bank_notification_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'caidat_service.dart';
import 'bank_parsers/bank_notification_parser.dart';
import 'bank_parsers/bank_parser_factory.dart';
import 'payment_matching_engine.dart';
import 'payment_coordinator.dart';
import 'notification_router.dart';

class BankNotificationService {
  static final BankNotificationService instance =
      BankNotificationService._init();

  static const MethodChannel _channel = MethodChannel(
    'com.example.tuition2025/notification_listener',
  );
  final CaiDatService _caiDatService = CaiDatService();
  final PaymentMatchingEngine _matchingEngine = PaymentMatchingEngine();
  final PaymentCoordinator _paymentCoordinator = PaymentCoordinator();

  // Local notification setup to alert user of automated approvals
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  BankNotificationService._init() {
    _channel.setMethodCallHandler(_handleMethodCall);
    _initLocalNotifications();
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payloadStr = response.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          final payload = NotificationPayload.parse(payloadStr);
          await NotificationRouter.handleNotificationRouting(payload);
        }
      },
    );

    try {
      final launchDetails = await _localNotifications
          .getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payloadStr = launchDetails.notificationResponse?.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          NotificationRouter.pendingLaunchPayload = NotificationPayload.parse(
            payloadStr,
          );
          developer.log(
            '📦 App launched from notification with payload: $payloadStr',
            name: 'BankNotificationService',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Lỗi kiểm tra NotificationAppLaunchDetails: $e',
        name: 'BankNotificationService',
      );
    }
  }

  static bool isTrustedBankPackage(String packageName) {
    final parser = BankParserFactory.getParser(packageName);
    return parser != null;
  }

  static String notificationFingerprint(
    String packageName,
    String title,
    String text,
  ) {
    return BankNotificationParser.generateFingerprint(
      bankCode: packageName,
      accountHint: null,
      amount: 0,
      transferContent: '$title $text',
      rawText: '$title $text',
    );
  }

  // Handle incoming method calls from Native
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        final Map<dynamic, dynamic>? data =
            call.arguments as Map<dynamic, dynamic>?;
        if (data != null) {
          final String title = data['title'] ?? '';
          final String text = data['text'] ?? '';
          final String package = data['package'] ?? '';
          developer.log(
            '🔔 Nhận thông báo ngân hàng từ Native: $title | $text',
            name: 'BankNotificationService',
          );
          await processNotification(title, text, package);
        }
        break;
      default:
        developer.log(
          'Unhandled method: ${call.method}',
          name: 'BankNotificationService',
        );
    }
  }

  // Check if Notification Listener Permission is granted
  Future<bool> checkPermission() async {
    try {
      final bool isEnabled =
          await _channel.invokeMethod('isNotificationServiceEnabled') ?? false;
      return isEnabled;
    } catch (e) {
      developer.log(
        'Error checking notification listener permission: $e',
        name: 'BankNotificationService',
      );
      return false;
    }
  }

  // Redirect to Android Notification Access settings
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      developer.log(
        'Error opening notification listener settings: $e',
        name: 'BankNotificationService',
      );
    }
  }

  // Process transaction messages and attempt to match with tuition record
  Future<void> processNotification(
    String title,
    String text,
    String package,
  ) async {
    try {
      // 1. Route to bank parser factory
      final candidate = BankParserFactory.parseNotification(
        packageName: package,
        title: title,
        text: text,
      );

      if (candidate == null) {
        developer.log(
          'Package hoặc thông báo không được hỗ trợ parser: $package',
          name: 'BankNotificationService',
        );
        return;
      }

      if (!candidate.isCredit) {
        developer.log(
          'Bỏ qua thông báo không phải Money-In (Debit/OTP/Khuyến mãi)',
          name: 'BankNotificationService',
        );
        return;
      }

      // 2. Read auto_approve_payment setting
      final String enabledVal = await _caiDatService.docGiaTri(
        'auto_approve_payment',
      );
      final bool autoApprove = (enabledVal == '1');

      // 3. Run Payment Matching Engine
      final matchResult = await _matchingEngine.matchTransaction(
        candidate,
        autoApproveEnabled: autoApprove,
      );

      developer.log(
        'Kết quả Matching Engine: ${matchResult.status} | Điểm: ${matchResult.confidenceScore} | Lý do: ${matchResult.reason}',
        name: 'BankNotificationService',
      );

      // 4. Handle states
      if (matchResult.isDuplicate) {
        developer.log(
          'Bỏ qua thông báo lặp: ${matchResult.reason}',
          name: 'BankNotificationService',
        );
        return;
      }

      if (matchResult.isConfirmed) {
        // CONFIRMED: Execute Atomic SQLite Commit
        final int transactionId = await _paymentCoordinator
            .confirmPaymentAtomic(
              candidate: candidate,
              studentId: matchResult.matchedStudentId!,
              classId: matchResult.matchedClassId!,
              month: matchResult.matchedMonth!,
              matchMethod: matchResult.matchMethod!,
            );

        final formattedAmount = NumberFormat(
          '#,##0',
          'vi_VN',
        ).format(candidate.amount);
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

        final receiptMessage =
            '''
🧾 XÁC NHẬN THU HỌC PHÍ TỰ ĐỘNG
• Học sinh: ${matchResult.studentName}
• Lớp: ${matchResult.className}
• Tháng: ${matchResult.matchedMonth}
• Số tiền đã nhận: $formattedAmountđ
• Ngân hàng: ${candidate.bankCode.toUpperCase()}
• Thời gian nhận: $dateStr

Cảm ơn Phụ huynh đã thanh toán học phí!
'''
                .trim();

        try {
          await Clipboard.setData(ClipboardData(text: receiptMessage));
        } catch (_) {}

        final payloadJson = jsonEncode({
          'type': 'BANK_PAYMENT_CONFIRMED',
          'studentId': matchResult.matchedStudentId,
          'classId': matchResult.matchedClassId,
          'month': matchResult.matchedMonth,
          'transactionId': transactionId,
        });

        await _showLocalNotification(
          '🎉 GHI NHẬN HỌC PHÍ THÀNH CÔNG!',
          'Học sinh: ${matchResult.studentName} (${matchResult.className}) • +$formattedAmountđ (Tháng ${matchResult.matchedMonth}). Đã copy hóa đơn!',
          payload: payloadJson,
        );
      } else if (matchResult.isNeedReview || matchResult.isUnmatched) {
        // NEED_REVIEW / UNMATCHED: Record as pending for teacher review
        final int transactionId = await _paymentCoordinator
            .recordPendingOrUnmatchedTransaction(
              candidate: candidate,
              matchResult: matchResult,
            );

        final formattedAmount = NumberFormat(
          '#,##0',
          'vi_VN',
        ).format(candidate.amount);
        final titleStr = matchResult.isNeedReview
            ? '⏳ GIAO DỊCH CẦN DUYỆT (${matchResult.studentName ?? "Cần kiểm tra"})'
            : '❓ GIAO DỊCH CHƯA KHỚP HỌC SINH';

        final payloadType = matchResult.isNeedReview
            ? 'BANK_PAYMENT_REVIEW'
            : 'BANK_PAYMENT_UNMATCHED';

        final payloadJson = jsonEncode({
          'type': payloadType,
          'studentId': matchResult.matchedStudentId,
          'classId': matchResult.matchedClassId,
          'month': matchResult.matchedMonth,
          'transactionId': transactionId,
        });

        await _showLocalNotification(
          titleStr,
          '+$formattedAmountđ • ${matchResult.reason}. Vui lòng vào app kiểm tra & ghép học sinh!',
          payload: payloadJson,
        );
      }
    } catch (e, stack) {
      developer.log(
        '❌ Error processing bank notification: $e',
        stackTrace: stack,
        name: 'BankNotificationService',
      );
    }
  }

  Future<void> showTestNotification() async {
    await _showLocalNotification(
      '🎉 GHI NHẬN HỌC PHÍ TỰ ĐỘNG THÀNH CÔNG!',
      'Học sinh: Nguyễn Văn A (Lớp 10A1) • Đã nhận +600.000đ thành công qua mã VietQR!',
    );
  }

  Future<void> _showLocalNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    const AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      'tuition_payments_channel',
      'Tự Động Duyệt Học Phí',
      channelDescription:
          'Thông báo đẩy tức thì khi phụ huynh chuyển khoản QR học phí thành công',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const NotificationDetails generalNotificationDetails = NotificationDetails(
      android: androidDetails,
    );

    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      100000,
    );
    await _localNotifications.show(
      notificationId,
      title,
      body,
      generalNotificationDetails,
      payload: payload,
    );
  }
}
