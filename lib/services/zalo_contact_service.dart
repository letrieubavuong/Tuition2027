// File: lib/services/zalo_contact_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hs.dart';
import '../services/hoc_sinh_service.dart';
import '../services/student_event_service.dart';
import '../utils/toast_helper.dart';
import '../widgets/zalo_link_dialog.dart';

enum ZaloLinkStatus {
  unlinked,
  phoneAvailable,
  manualName,
  profileLinked,
  verified,
}

class ZaloContactService {
  static final ZaloContactService instance = ZaloContactService._internal();
  factory ZaloContactService() => instance;
  ZaloContactService._internal();

  final _hsService = HocSinhService();

  ZaloLinkStatus parseStatus(String? statusStr) {
    switch (statusStr) {
      case 'VERIFIED':
        return ZaloLinkStatus.verified;
      case 'PROFILE_LINKED':
        return ZaloLinkStatus.profileLinked;
      case 'MANUAL_NAME':
        return ZaloLinkStatus.manualName;
      case 'PHONE_AVAILABLE':
        return ZaloLinkStatus.phoneAvailable;
      default:
        return ZaloLinkStatus.unlinked;
    }
  }

  String statusToString(ZaloLinkStatus status) {
    switch (status) {
      case ZaloLinkStatus.verified:
        return 'VERIFIED';
      case ZaloLinkStatus.profileLinked:
        return 'PROFILE_LINKED';
      case ZaloLinkStatus.manualName:
        return 'MANUAL_NAME';
      case ZaloLinkStatus.phoneAvailable:
        return 'PHONE_AVAILABLE';
      case ZaloLinkStatus.unlinked:
        return 'UNLINKED';
    }
  }

  ZaloLinkStatus getEffectiveStatus(HS student) {
    final effectiveStr = student.effectiveZaloStatus;
    return parseStatus(effectiveStr);
  }

  ZaloLinkStatus getZaloLinkStatus(HS student) => getEffectiveStatus(student);

  String? getZaloDeepLink(HS student) {
    if (student.zaloProfileLink != null &&
        student.zaloProfileLink!.trim().isNotEmpty) {
      return student.zaloProfileLink!.trim();
    }
    final phone = student.effectiveParentPhone;
    if (phone != null && phone.isNotEmpty) {
      final clean = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (clean.isNotEmpty) {
        return 'https://zalo.me/$clean';
      }
    }
    return null;
  }

  String prepareParentMessage(HS student, String message) {
    final parentName =
        student.tenPhuHuynh ?? student.zaloDisplayName ?? 'Quý phụ huynh';
    return 'Kính gửi $parentName (PH em ${student.ten}):\n$message';
  }

  /// Trả về Widget Icon thể hiện trạng thái Zalo của học sinh:
  /// ✓ Đã xác minh (VERIFIED)
  /// ! Chưa xác minh (PHONE_AVAILABLE / MANUAL_NAME / PROFILE_LINKED)
  /// ○ Chưa liên kết (UNLINKED)
  Widget buildZaloStatusIcon(
    HS student, {
    double size = 18,
    VoidCallback? onTap,
    BuildContext? context,
  }) {
    final status = getEffectiveStatus(student);
    Widget iconWidget;
    String tooltipMsg;

    switch (status) {
      case ZaloLinkStatus.verified:
        iconWidget = Container(
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(2),
          child: Icon(Icons.check, size: size - 4, color: Colors.white),
        );
        tooltipMsg = '✓ Đã xác minh Zalo PH';
        break;
      case ZaloLinkStatus.profileLinked:
        iconWidget = Container(
          decoration: const BoxDecoration(
            color: Colors.blueAccent,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(2),
          child: Icon(Icons.link, size: size - 4, color: Colors.white),
        );
        tooltipMsg = '! Đã lưu link Profile Zalo PH (chưa xác minh)';
        break;
      case ZaloLinkStatus.manualName:
        iconWidget = Container(
          decoration: const BoxDecoration(
            color: Colors.orangeAccent,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(2),
          child: Icon(Icons.priority_high, size: size - 4, color: Colors.white),
        );
        tooltipMsg = '! Đã lưu tên/ghi chú Zalo PH (chưa xác minh)';
        break;
      case ZaloLinkStatus.phoneAvailable:
        iconWidget = Container(
          decoration: const BoxDecoration(
            color: Colors.amber,
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(2),
          child: Icon(
            Icons.priority_high,
            size: size - 4,
            color: Colors.black.withValues(alpha: 0.8),
          ),
        );
        tooltipMsg = '! Có SĐT PH (chưa xác minh Zalo)';
        break;
      case ZaloLinkStatus.unlinked:
        iconWidget = Icon(
          Icons.radio_button_unchecked,
          size: size,
          color: Colors.grey,
        );
        tooltipMsg = '○ Chưa liên kết Zalo PH';
        break;
    }

    final button = InkWell(
      onTap: () {
        if (onTap != null) {
          onTap();
        } else if (context != null) {
          openParentZalo(context, student);
        }
      },
      borderRadius: BorderRadius.circular(size),
      child: Tooltip(message: tooltipMsg, child: iconWidget),
    );

    return button;
  }

  /// Widget Nút Nhanh Zalo (Zalo Quick Action Button)
  Widget buildZaloQuickButton(
    BuildContext context,
    HS student, {
    String? preparedMessage,
    bool compact = true,
  }) {
    final status = getEffectiveStatus(student);

    Color buttonBgColor;
    Color buttonTextColor;
    IconData leadingIcon;

    switch (status) {
      case ZaloLinkStatus.verified:
        buttonBgColor = const Color(0xFF0068FF);
        buttonTextColor = Colors.white;
        leadingIcon = Icons.verified_user_rounded;
        break;
      case ZaloLinkStatus.profileLinked:
      case ZaloLinkStatus.manualName:
      case ZaloLinkStatus.phoneAvailable:
        buttonBgColor = Colors.orangeAccent.shade700;
        buttonTextColor = Colors.white;
        leadingIcon = Icons.contact_phone_rounded;
        break;
      case ZaloLinkStatus.unlinked:
        buttonBgColor = Colors.grey.shade800;
        buttonTextColor = Colors.white70;
        leadingIcon = Icons.link_off_rounded;
        break;
    }

    if (compact) {
      return InkWell(
        onTap: () =>
            openParentZalo(context, student, preparedMessage: preparedMessage),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: buttonBgColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(leadingIcon, size: 14, color: buttonTextColor),
              const SizedBox(width: 4),
              Text(
                'Zalo',
                style: TextStyle(
                  color: buttonTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              buildZaloStatusIcon(student, size: 14),
            ],
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: () =>
          openParentZalo(context, student, preparedMessage: preparedMessage),
      icon: Icon(leadingIcon, color: buttonTextColor),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Liên hệ Zalo PH',
            style: TextStyle(
              color: buttonTextColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 6),
          buildZaloStatusIcon(student, size: 16),
        ],
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: buttonBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Mở Zalo Phụ Huynh / Tìm kiếm / Link Profile fallback
  Future<bool> openParentZalo(
    BuildContext context,
    HS student, {
    String? preparedMessage,
  }) async {
    // 1. Trường hợp có Link Profile
    if (student.zaloProfileLink != null &&
        student.zaloProfileLink!.trim().isNotEmpty) {
      final link = student.zaloProfileLink!.trim();
      final Uri? uri = Uri.tryParse(
        link.startsWith('http') ? link : 'https://$link',
      );
      if (uri != null) {
        if (preparedMessage != null && preparedMessage.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: preparedMessage));
          if (context.mounted) {
            ToastHelper.showInfo(
              context,
              'Đã sao chép nội dung tin nhắn. Mở Zalo...',
            );
          }
        }
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    }

    // 2. Trường hợp có SĐT (sdtPhuHuynh / zaloPhone / sdt)
    final phone = student.effectiveParentPhone;
    if (phone != null && phone.isNotEmpty) {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      if (cleanPhone.isNotEmpty) {
        final deepLinkUri = Uri.parse('https://zalo.me/$cleanPhone');
        if (preparedMessage != null && preparedMessage.isNotEmpty) {
          await Clipboard.setData(ClipboardData(text: preparedMessage));
          if (context.mounted) {
            ToastHelper.showInfo(
              context,
              'Đã sao chép nội dung. Mở Zalo để gửi cho PH ${student.tenPhuHuynh ?? student.ten}...',
            );
          }
        }
        final launched = await launchUrl(
          deepLinkUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      }
    }

    // 3. Trường hợp không SĐT nhưng có Tên Zalo / Ghi chú Zalo
    final zaloName =
        student.zaloDisplayName ?? student.tenPhuHuynh ?? student.zaloNote;
    if (zaloName != null && zaloName.trim().isNotEmpty) {
      final textToCopy = preparedMessage != null && preparedMessage.isNotEmpty
          ? 'Tên Zalo: ${zaloName.trim()}\nNội dung:\n$preparedMessage'
          : zaloName.trim();

      await Clipboard.setData(ClipboardData(text: textToCopy));
      if (context.mounted) {
        ToastHelper.showWarning(
          context,
          'Đã sao chép tên Zalo "$zaloName" & nội dung. Vui lòng mở Zalo và dán để tìm.',
        );
      }

      final zaloAppUri = Uri.parse('zalo://');
      bool launched = false;
      try {
        launched = await launchUrl(
          zaloAppUri,
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}

      if (!launched) {
        final zaloWebUri = Uri.parse('https://zalo.me');
        await launchUrl(zaloWebUri, mode: LaunchMode.externalApplication);
      }
      return true;
    }

    // 4. Chưa có bất kỳ thông tin liên hệ Zalo nào -> Mở Dialog Liên Kết
    if (context.mounted) {
      showZaloLinkDialog(context, student);
    }
    return false;
  }

  /// Hiển thị Dialog Quản lý & Liên kết Zalo PH
  Future<void> showZaloLinkDialog(BuildContext context, HS student) async {
    await showDialog(
      context: context,
      builder: (ctx) => ZaloLinkDialog(student: student),
    );
  }

  /// Đánh dấu đã xác minh Zalo (VERIFIED)
  Future<void> markVerified(BuildContext context, HS student) async {
    final updated = student.copyWith(zaloLinkStatus: 'VERIFIED');
    final res = await _hsService.capNhatHocSinh(updated);
    if (res > 0) {
      StudentEventService().notifyStudentUpdated(updated);
      if (context.mounted) {
        ToastHelper.showSuccess(context, '✓ Đã xác minh liên kết Zalo PH!');
      }
    }
  }
}
