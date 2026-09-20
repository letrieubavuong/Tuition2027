// File: lib/services/notification_router.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

import 'package:home_widget/home_widget.dart';
import '../screens/quan_ly_giao_dich_ngan_hang_page.dart';
import '../screens/diem_danh_page.dart';
import '../screens/hocphi.dart';
import '../screens/attention_queue_page.dart';
import '../screens/daily_brief_page.dart';
import '../screens/hs_detail.dart';
import 'hoc_sinh_service.dart';

class NotificationPayload {
  final String
  type; // 'BANK_PAYMENT_CONFIRMED', 'BANK_PAYMENT_REVIEW', 'BANK_PAYMENT_UNMATCHED', 'payment_confirmed', 'payment_need_review', 'tuition_reminder', 'attendance_alert', 'schedule_reminder', 'zalo'
  final int? studentId;
  final int? classId;
  final String? month;
  final int? paymentTransactionId;
  final String? phone;
  final String rawPayload;

  NotificationPayload({
    required this.type,
    this.studentId,
    this.classId,
    this.month,
    this.paymentTransactionId,
    this.phone,
    required this.rawPayload,
  });

  static NotificationPayload parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return NotificationPayload(type: 'unknown', rawPayload: raw ?? '');
    }

    final clean = raw.trim();

    // Check Zalo legacy payload
    if (clean.startsWith('zalo:')) {
      final phone = clean.substring(5).trim();
      return NotificationPayload(type: 'zalo', phone: phone, rawPayload: clean);
    }

    // Try parse JSON structured payload
    if (clean.startsWith('{') && clean.endsWith('}')) {
      try {
        final Map<String, dynamic> map = jsonDecode(clean);
        return NotificationPayload(
          type: map['type'] as String? ?? 'unknown',
          studentId: map['studentId'] as int?,
          classId: map['classId'] as int?,
          month: map['month'] as String?,
          paymentTransactionId:
              (map['transactionId'] ?? map['paymentTransactionId']) as int?,
          phone: map['phone'] as String?,
          rawPayload: clean,
        );
      } catch (e) {
        developer.log(
          'Lỗi parse notification payload JSON: $e',
          name: 'NotificationRouter',
        );
      }
    }

    // Legacy fallback parameters e.g. "lop_id=5"
    if (clean.startsWith('lop_id=')) {
      final id = int.tryParse(clean.substring(7));
      return NotificationPayload(
        type: 'schedule_reminder',
        classId: id,
        rawPayload: clean,
      );
    }

    return NotificationPayload(type: 'unknown', rawPayload: clean);
  }
}

class NotificationRouter {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static NotificationPayload? pendingLaunchPayload;
  static bool _isNavigating = false;

  /// Điều hướng payload thông báo tới màn hình phù hợp
  static Future<void> handleNotificationRouting(
    NotificationPayload payload, {
    BuildContext? context,
  }) async {
    final navContext = context ?? navigatorKey.currentContext;

    if (navContext == null) {
      developer.log(
        '⏳ Navigator context is null. Storing pending launch payload: ${payload.type}',
        name: 'NotificationRouter',
      );
      pendingLaunchPayload = payload;
      return;
    }

    if (_isNavigating) {
      developer.log(
        '⚠️ Skip duplicate navigation attempt (re-entrancy guard)',
        name: 'NotificationRouter',
      );
      return;
    }

    _isNavigating = true;

    try {
      developer.log(
        '🚀 NotificationNavigation: type=${payload.type}, studentId=${payload.studentId}, classId=${payload.classId}, month=${payload.month}, transactionId=${payload.paymentTransactionId}',
        name: 'NotificationRouter',
      );

      switch (payload.type) {
        case 'zalo':
          if (payload.phone != null && payload.phone!.isNotEmpty) {
            final Uri zaloUri = Uri.parse('https://zalo.me/${payload.phone}');
            try {
              if (await canLaunchUrl(zaloUri)) {
                await launchUrl(zaloUri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              developer.log('Lỗi mở Zalo: $e', name: 'NotificationRouter');
            }
          }
          break;

        case 'BANK_PAYMENT_CONFIRMED':
        case 'payment_confirmed':
          if (payload.studentId != null && payload.studentId! > 0) {
            final hs = await HocSinhService().docHocSinhTheoId(
              payload.studentId!,
            );
            if (hs != null && navContext.mounted) {
              developer.log(
                'NotificationNavigation: BANK_PAYMENT_CONFIRMED studentId=${payload.studentId} transactionId=${payload.paymentTransactionId} destination=HSDetail/tuition',
                name: 'NotificationRouter',
              );
              await Navigator.of(navContext).push(
                MaterialPageRoute(
                  builder: (ctx) => HSDetail(hocSinh: hs, initialTabIndex: 3),
                ),
              );
              break;
            }
          }

          // Fallback if student is deleted or missing
          developer.log(
            'NotificationNavigation: BANK_PAYMENT_CONFIRMED student not found (id=${payload.studentId}), falling back to QuanLyGiaoDichNganHangPage',
            name: 'NotificationRouter',
          );
          if (navContext.mounted) {
            await Navigator.of(navContext).push(
              MaterialPageRoute(
                builder: (ctx) => QuanLyGiaoDichNganHangPage(
                  initialTransactionId: payload.paymentTransactionId,
                ),
              ),
            );
          }
          break;

        case 'BANK_PAYMENT_REVIEW':
        case 'payment_need_review':
        case 'BANK_PAYMENT_UNMATCHED':
        case 'payment_unmatched':
          developer.log(
            'NotificationNavigation: ${payload.type} transactionId=${payload.paymentTransactionId} destination=QuanLyGiaoDichNganHangPage',
            name: 'NotificationRouter',
          );
          await Navigator.of(navContext).push(
            MaterialPageRoute(
              builder: (ctx) => QuanLyGiaoDichNganHangPage(
                initialTransactionId: payload.paymentTransactionId,
              ),
            ),
          );
          break;

        case 'tuition_reminder':
          await Navigator.of(navContext).push(
            MaterialPageRoute(
              builder: (ctx) => HocPhiPage(
                selectedLopId: payload.classId,
                selectedMonth: payload.month,
              ),
            ),
          );
          break;

        case 'attendance_alert':
        case 'schedule_reminder':
          await Navigator.of(navContext).push(
            MaterialPageRoute(
              builder: (ctx) => DiemDanhPage(selectedLopId: payload.classId),
            ),
          );
          break;

        case 'attention':
          await Navigator.of(navContext).push(
            MaterialPageRoute(builder: (ctx) => const AttentionQueuePage()),
          );
          break;

        case 'dailybrief':
          await Navigator.of(
            navContext,
          ).push(MaterialPageRoute(builder: (ctx) => const DailyBriefPage()));
          break;

        case 'unknown':
        default:
          developer.log(
            '⚠️ Unrecognized or malformed payload. Fallback gracefully without crash.',
            name: 'NotificationRouter',
          );
          break;
      }
    } finally {
      _isNavigating = false;
    }
  }

  /// Tự động lắng nghe và điều hướng deep link từ AppWidget tap
  static void setupWidgetDeepLinks() {
    // 1. Cold start từ widget tap
    HomeWidget.initiallyLaunchedFromHomeWidget().then((Uri? uri) {
      if (uri != null) _handleWidgetUri(uri);
    });

    // 2. Warm start từ widget tap
    HomeWidget.widgetClicked.listen((Uri? uri) {
      if (uri != null) _handleWidgetUri(uri);
    });
  }

  static void _handleWidgetUri(Uri uri) {
    final host = uri.host.isNotEmpty ? uri.host : uri.path.replaceAll('/', '');
    NotificationPayload payload;
    if (host == 'diemdanh') {
      payload = NotificationPayload(
        type: 'attendance_alert',
        rawPayload: uri.toString(),
      );
    } else if (host == 'attention') {
      payload = NotificationPayload(
        type: 'attention',
        rawPayload: uri.toString(),
      );
    } else if (host == 'dailybrief') {
      payload = NotificationPayload(
        type: 'dailybrief',
        rawPayload: uri.toString(),
      );
    } else if (host == 'payment') {
      payload = NotificationPayload(
        type: 'tuition_reminder',
        rawPayload: uri.toString(),
      );
    } else {
      payload = NotificationPayload(
        type: 'unknown',
        rawPayload: uri.toString(),
      );
    }
    handleNotificationRouting(payload);
  }

  /// Xử lý cold start nếu có payload tồn đọng khi app vừa khởi chạy
  static void processPendingLaunchPayload() {
    if (pendingLaunchPayload != null) {
      final payload = pendingLaunchPayload!;
      pendingLaunchPayload = null;
      if (navigatorKey.currentContext != null) {
        handleNotificationRouting(payload);
      }
    }
  }
}
