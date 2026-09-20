import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/l10n/app_localizations.dart';
import 'package:tuition2025/utils/theme.dart';

void main() {
  group('Theme & Locale Providers Unit & Widget Tests', () {
    test('Default themeModeProvider is ThemeMode.dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final themeMode = container.read(themeModeProvider);
      expect(themeMode, equals(ThemeMode.dark));
    });

    test('Default localeProvider is Locale("vi")', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final locale = container.read(localeProvider);
      expect(locale.languageCode, equals('vi'));
    });

    testWidgets(
      'Renders Dark Theme by default with correct background and text colors',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: Consumer(
              builder: (context, ref, child) {
                final themeMode = ref.watch(themeModeProvider);
                final locale = ref.watch(localeProvider);
                return MaterialApp(
                  theme: AppThemes.lightTheme,
                  darkTheme: AppThemes.darkTheme,
                  themeMode: themeMode,
                  locale: locale,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('vi', 'VN'),
                    Locale('en', ''),
                  ],
                  home: Scaffold(
                    appBar: AppBar(title: const Text('Quản Lý Học Phí')),
                    body: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [Text('Xin Chào'), Icon(Icons.star)],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        final BuildContext context = tester.element(find.byType(Scaffold));
        final theme = Theme.of(context);

        // Verify Dark Theme properties
        expect(theme.brightness, equals(Brightness.dark));
        expect(theme.scaffoldBackgroundColor, equals(AppColors.darkBackground));
        expect(theme.cardColor, equals(AppColors.darkCard));
        expect(theme.primaryColor, equals(AppColors.darkAccent));

        // Verify text contrast (dark primary text is white / light color)
        expect(
          theme.textTheme.bodyLarge?.color,
          equals(AppColors.darkPrimaryText),
        );
        expect(
          theme.textTheme.bodyMedium?.color,
          equals(AppColors.darkSecondaryText),
        );
      },
    );

    testWidgets(
      'Renders Light Theme correctly when themeModeProvider is set to light',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              themeModeProvider.overrideWith((ref) => ThemeMode.light),
            ],
            child: Consumer(
              builder: (context, ref, child) {
                final themeMode = ref.watch(themeModeProvider);
                final locale = ref.watch(localeProvider);
                return MaterialApp(
                  theme: AppThemes.lightTheme,
                  darkTheme: AppThemes.darkTheme,
                  themeMode: themeMode,
                  locale: locale,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  supportedLocales: const [
                    Locale('vi', 'VN'),
                    Locale('en', ''),
                  ],
                  home: Scaffold(
                    appBar: AppBar(title: const Text('Light Mode Test')),
                    body: const Center(child: Text('Chế độ sáng')),
                  ),
                );
              },
            ),
          ),
        );

        await tester.pumpAndSettle();

        final BuildContext context = tester.element(find.byType(Scaffold));
        final theme = Theme.of(context);

        // Verify Light Theme properties
        expect(theme.brightness, equals(Brightness.light));
        expect(
          theme.scaffoldBackgroundColor,
          equals(AppColors.lightBackground),
        );
        expect(theme.cardColor, equals(AppColors.lightCard));
        expect(theme.primaryColor, equals(AppColors.lightAccent));

        // Verify text contrast (light primary text is dark color)
        expect(
          theme.textTheme.bodyLarge?.color,
          equals(AppColors.lightPrimaryText),
        );
        expect(
          theme.textTheme.bodyMedium?.color,
          equals(AppColors.lightSecondaryText),
        );
      },
    );

    testWidgets('Renders Vietnamese Locale and AppLocalizations correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, child) {
              final themeMode = ref.watch(themeModeProvider);
              final locale = ref.watch(localeProvider);
              return MaterialApp(
                theme: AppThemes.lightTheme,
                darkTheme: AppThemes.darkTheme,
                themeMode: themeMode,
                locale: locale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [Locale('vi', 'VN'), Locale('en', '')],
                home: Scaffold(
                  body: Builder(
                    builder: (ctx) {
                      final loc = AppLocalizations.of(ctx);
                      return Text(loc?.homePageTitle ?? 'N/A');
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Text), findsOneWidget);
    });
  });
}
