import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/caidat_service.dart';
import '../main.dart';
import '../utils/toast_helper.dart';

class PinLockScreen extends StatefulWidget {
  final bool
  isConfiguring; // true if configuring PIN in Settings, false if unlocking app at startup
  const PinLockScreen({super.key, required this.isConfiguring});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final CaiDatService _caiDatService = CaiDatService();
  final List<int> _enteredPin = [];
  String _savedPin = '';
  String _firstEnterPin = ''; // Used during configuration to confirm the PIN
  bool _isConfirming = false;
  String _message = '';
  bool _isLoading = true;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadSavedPin();
  }

  Future<void> _loadSavedPin() async {
    if (widget.isConfiguring) {
      setState(() {
        _message = 'Nhập mã PIN mới gồm 6 số';
        _isLoading = false;
      });
    } else {
      final pin = await _caiDatService.layCaiDat('app_pin_code');
      final biometricEnabled =
          await _caiDatService.layCaiDat('app_biometric_enabled') == 'true';

      bool bioAvailable = false;
      if (biometricEnabled) {
        final LocalAuthentication auth = LocalAuthentication();
        final bool canAuthenticateWithBiometrics =
            await auth.canCheckBiometrics;
        bioAvailable =
            canAuthenticateWithBiometrics || await auth.isDeviceSupported();
      }

      setState(() {
        _savedPin = pin ?? '';
        _biometricAvailable = bioAvailable;
        _message = 'Nhập mã PIN để mở khóa';
        _isLoading = false;
      });

      if (_savedPin.isEmpty) {
        // Safe check: if PIN is enabled but empty, bypass
        _unlockAndGoToMain();
      } else if (_biometricAvailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _authenticateWithBiometrics();
        });
      }
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Xác thực vân tay/khuôn mặt để mở khóa ứng dụng',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (didAuthenticate) {
        _unlockAndGoToMain();
      }
    } catch (e) {
      debugPrint('Lỗi xác thực vân tay: $e');
    }
  }

  void _onKeyPress(int value) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin.add(value);
      });

      if (_enteredPin.length == 6) {
        // Delay slightly for visual effect
        Future.delayed(const Duration(milliseconds: 200), _processPin);
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin.removeLast();
      });
    }
  }

  Future<void> _processPin() async {
    final enteredString = _enteredPin.join();
    _enteredPin.clear();

    if (widget.isConfiguring) {
      if (!_isConfirming) {
        // First time entering new PIN
        setState(() {
          _firstEnterPin = enteredString;
          _isConfirming = true;
          _message = 'Nhập lại mã PIN để xác nhận';
        });
      } else {
        // Confirming PIN
        if (enteredString == _firstEnterPin) {
          // Success: Save PIN to settings
          await _caiDatService.capNhatCaiDat('app_pin_enabled', 'true');
          await _caiDatService.capNhatCaiDat('app_pin_code', enteredString);
          if (mounted) {
            ToastHelper.showSuccess(
              context,
              'Đã thiết lập mã PIN bảo mật thành công!',
            );
            Navigator.of(context).pop(true);
          }
        } else {
          // Failure
          setState(() {
            _isConfirming = false;
            _firstEnterPin = '';
            _message = 'Mã PIN không khớp. Vui lòng nhập lại mã PIN mới';
          });
        }
      }
    } else {
      // Unlocking
      if (enteredString == _savedPin) {
        _unlockAndGoToMain();
      } else {
        setState(() {
          _message = 'Mã PIN không đúng. Vui lòng thử lại';
        });
      }
    }
  }

  void _unlockAndGoToMain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => MainScreen(key: mainScreenKey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A1A2E)
          : const Color(0xFFF0F2F5),
      appBar: widget.isConfiguring
          ? AppBar(
              title: const Text('Thiết lập mã PIN'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: isDark ? Colors.white : Colors.black,
            )
          : null,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // Logo / Icon
            Icon(
              Icons.lock_outline_rounded,
              size: 64,
              color: theme.primaryColor,
            ),
            const SizedBox(height: 24),
            // Header message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Code indicator (dots)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final isFilled = index < _enteredPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? theme.primaryColor
                        : (isDark ? Colors.white24 : Colors.black26),
                  ),
                );
              }),
            ),
            const Spacer(),
            // Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Column(
                children: [
                  _buildKeypadRow([1, 2, 3]),
                  const SizedBox(height: 16),
                  _buildKeypadRow([4, 5, 6]),
                  const SizedBox(height: 16),
                  _buildKeypadRow([7, 8, 9]),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back/Cancel button during configuration or Biometric button during lock
                      !widget.isConfiguring && _biometricAvailable
                          ? SizedBox(
                              width: 68,
                              height: 68,
                              child: IconButton(
                                icon: const Icon(Icons.fingerprint, size: 28),
                                color: theme.primaryColor,
                                onPressed: _authenticateWithBiometrics,
                              ),
                            )
                          : widget.isConfiguring
                          ? SizedBox(
                              width: 68,
                              height: 68,
                              child: IconButton(
                                icon: const Icon(Icons.close),
                                color: isDark ? Colors.white54 : Colors.black54,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            )
                          : const SizedBox(width: 68),
                      _buildKeypadButton(0),
                      SizedBox(
                        width: 68,
                        height: 68,
                        child: IconButton(
                          icon: const Icon(Icons.backspace_outlined),
                          color: isDark ? Colors.white70 : Colors.black54,
                          onPressed: _onDelete,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<int> values) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: values.map((val) => _buildKeypadButton(val)).toList(),
    );
  }

  Widget _buildKeypadButton(int value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _onKeyPress(value),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF16213E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
