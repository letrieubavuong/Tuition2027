// File: lib/utils/theme.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 1. Provider để quản lý trạng thái của theme (sáng/tối).
/// Mặc định là chế độ tối.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// SỬA: Thêm provider để quản lý ngôn ngữ
/// Mặc định là Tiếng Việt
final localeProvider = StateProvider<Locale>((ref) => const Locale('vi'));

/// 2. Lớp chứa tất cả các hằng số màu sắc cho cả hai theme.
/// Điều này giúp quản lý màu sắc tập trung và dễ dàng thay đổi.
class AppColors {
  // --- Dark Theme Colors ---
  static const Color darkBackground = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);
  static const Color darkPrimaryText = Colors.white;
  static const Color darkSecondaryText = Colors.white70;
  static const Color darkAccent = Color(0xFF00BFA5);
  static const Color darkError = Color(0xFFE94560);

  // --- Light Theme Colors ---
  static const Color lightBackground = Color(0xFFF0F2F5); // Màu xám nhạt
  static const Color lightCard = Colors.white;
  static const Color lightPrimaryText = Color(0xFF1C1E21); // Màu đen xám
  static const Color lightSecondaryText = Color(0xFF65676B); // Màu xám vừa
  static const Color lightAccent = Color(0xFF00897B); // Màu teal đậm hơn
  static const Color lightError = Color(0xFFD32F2F); // Màu đỏ chuẩn
}

/// 3. Lớp định nghĩa các đối tượng ThemeData cho mỗi chế độ.
class AppThemes {
  // --- ThemeData cho Chế độ Tối ---
  static final darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    primaryColor: AppColors.darkAccent,
    cardColor: AppColors.darkCard,
    dividerColor: AppColors.darkSecondaryText.withValues(alpha: 0.2),
    hintColor: AppColors.darkSecondaryText,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkCard,
      foregroundColor: AppColors.darkPrimaryText,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.darkPrimaryText,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.darkPrimaryText),
      bodyMedium: TextStyle(color: AppColors.darkSecondaryText),
      titleMedium: TextStyle(
        color: AppColors.darkPrimaryText,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: AppColors.darkPrimaryText,
        fontWeight: FontWeight.bold,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.darkAccent,
      secondary: AppColors.darkAccent,
      surface: AppColors.darkCard,
      onPrimary: AppColors.darkBackground,
      onSecondary: AppColors.darkBackground,
      onSurface: AppColors.darkPrimaryText,
      error: AppColors.darkError,
      onError: AppColors.darkPrimaryText,
    ),
  );

  // --- ThemeData cho Chế độ Sáng ---
  static final lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBackground,
    primaryColor: AppColors.lightAccent,
    cardColor: AppColors.lightCard,
    dividerColor: Colors.grey.shade300,
    hintColor: AppColors.lightSecondaryText,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightCard,
      foregroundColor: AppColors.lightPrimaryText,
      elevation: 1,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.lightPrimaryText,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.lightPrimaryText),
      bodyMedium: TextStyle(color: AppColors.lightSecondaryText),
      titleMedium: TextStyle(
        color: AppColors.lightPrimaryText,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: AppColors.lightPrimaryText,
        fontWeight: FontWeight.bold,
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: AppColors.lightAccent,
      secondary: AppColors.lightAccent,
      surface: AppColors.lightCard,
      error: AppColors.lightError,
    ),
  );
}
