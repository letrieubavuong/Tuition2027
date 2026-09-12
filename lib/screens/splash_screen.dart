import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tuition2025/main.dart';
import 'package:tuition2025/l10n/app_localizations.dart';
import 'pin_lock_screen.dart';
import '../services/caidat_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _version = '1.0.3';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();

    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _version = info.version;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF1E1E38),
                    const Color(0xFF1A1A2E),
                    const Color(0xFF111124),
                  ]
                : [
                    const Color(0xFFE0F2F1),
                    const Color(0xFFF0F2F5),
                    const Color(0xFFFFFFFF),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Animated Logo & Icon
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      // Logo Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? theme.primaryColor.withValues(alpha: 0.15)
                              : theme.primaryColor.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: 96,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // App Name
                      Text(
                        'Tuition 2026',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: isDark ? Colors.white : Colors.teal.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Text(
                        loc.splashSubtitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Tagline
                      Text(
                        loc.splashTagline,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Enter Button
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    // Start fading/sliding in the button after the main content has partially appeared
                    final buttonOpacity = CurvedAnimation(
                      parent: _controller,
                      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
                    ).value;

                    final buttonSlide = Tween<double>(begin: 30.0, end: 0.0)
                        .animate(
                          CurvedAnimation(
                            parent: _controller,
                            curve: const Interval(
                              0.5,
                              1.0,
                              curve: Curves.easeOut,
                            ),
                          ),
                        )
                        .value;

                    return Opacity(
                      opacity: buttonOpacity,
                      child: Transform.translate(
                        offset: Offset(0, buttonSlide),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            final isPinEnabled =
                                await CaiDatService().layCaiDat(
                              'app_pin_enabled',
                            );
                            final savedPin = await CaiDatService().layCaiDat(
                              'app_pin_code',
                            );
                            if (context.mounted) {
                              if (isPinEnabled == 'true' &&
                                  savedPin != null &&
                                  savedPin.isNotEmpty) {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const PinLockScreen(isConfiguring: false),
                                  ),
                                );
                                return;
                              }
                            }
                          } catch (e) {
                            debugPrint('SplashScreen navigate error: $e');
                          }
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) =>
                                    MainScreen(key: mainScreenKey),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: isDark
                              ? const Color(0xFF1A1A2E)
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 48,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: theme.primaryColor.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              loc.getStarted,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 22),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '${loc.version} $_version',
                        style: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black26,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
