import 'dart:async';
import 'package:flutter/material.dart';

enum ToastType { success, error, info, warning }

class ToastHelper {
  static OverlayEntry? _currentEntry;
  static VoidCallback? _currentRemoveCallback;

  /// Xóa ngay lập tức Toast hiện tại nếu đang hiển thị trên Overlay (không làm đọng stack)
  static void dismissCurrent() {
    if (_currentRemoveCallback != null) {
      final callback = _currentRemoveCallback;
      _currentRemoveCallback = null;
      _currentEntry = null;
      callback!();
    } else if (_currentEntry != null) {
      final entry = _currentEntry;
      _currentEntry = null;
      try {
        entry?.remove();
      } catch (_) {}
    }
  }

  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null || !overlayState.mounted) return;

    // 1 & 2 & 7: Loại bỏ Toast cũ ngay lập tức, không tạo stack overlay
    dismissCurrent();

    late OverlayEntry entry;
    bool isRemoved = false;

    // 5: OverlayEntry chỉ remove 1 lần duy nhất
    void removeEntry() {
      if (!isRemoved) {
        isRemoved = true;
        if (_currentEntry == entry) {
          _currentEntry = null;
          _currentRemoveCallback = null;
        }
        try {
          entry.remove();
        } catch (_) {}
      }
    }

    entry = OverlayEntry(
      builder: (context) => _ToastWidget(
        key: ValueKey('${DateTime.now().microsecondsSinceEpoch}_$message'),
        message: message,
        type: type,
        duration: duration,
        onDismiss: removeEntry,
      ),
    );

    _currentEntry = entry;
    _currentRemoveCallback = removeEntry;

    overlayState.insert(entry);
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message, type: ToastType.success, duration: duration);
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    show(context, message, type: ToastType.error, duration: duration);
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message, type: ToastType.info, duration: duration);
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(context, message, type: ToastType.warning, duration: duration);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    super.key,
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;
  Timer? _timer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    _timer = Timer(widget.duration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    // 3: Guard _isDismissing chống gọi lặp
    if (_isDismissing) return;
    _isDismissing = true;

    // 4: Cancel Timer khi dismiss thủ công hoặc hết hạn
    _timer?.cancel();
    _timer = null;

    if (mounted) {
      _controller
          .reverse()
          .then((_) {
            widget.onDismiss();
          })
          .catchError((_) {
            widget.onDismiss();
          });
    } else {
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _isDismissing = true;
    _timer?.cancel();
    _timer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color primaryColor;
    IconData icon;

    switch (widget.type) {
      case ToastType.success:
        primaryColor = Colors.teal;
        icon = Icons.check_circle_rounded;
        break;
      case ToastType.error:
        primaryColor = Colors.redAccent;
        icon = Icons.error_rounded;
        break;
      case ToastType.warning:
        primaryColor = Colors.orangeAccent;
        icon = Icons.warning_rounded;
        break;
      case ToastType.info:
        primaryColor = theme.primaryColor;
        icon = Icons.info_rounded;
        break;
    }

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0, left: 16.0, right: 16.0),
          child: SlideTransition(
            position: _offsetAnimation,
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2F) : Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.15),
                        blurRadius: 12.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: primaryColor, size: 24.0),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      GestureDetector(
                        key: const ValueKey('toast_close_button'),
                        onTap: _dismiss,
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white38 : Colors.black38,
                          size: 20.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
