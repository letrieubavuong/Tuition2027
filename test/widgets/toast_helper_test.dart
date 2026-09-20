import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tuition2025/utils/toast_helper.dart';

Widget _buildTestApp({
  required Widget child,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() {
    ToastHelper.dismissCurrent();
  });

  tearDown(() {
    ToastHelper.dismissCurrent();
  });

  testWidgets('1. Auto dismiss toast after duration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              ToastHelper.showSuccess(
                context,
                'Thông báo tự đóng',
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text('Show'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Thông báo tự đóng'), findsOneWidget);

    // Hết thời gian duration (2s) -> Tự động đóng
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Thông báo tự đóng'), findsNothing);
  });

  testWidgets('2. Manual dismiss toast via close button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              ToastHelper.showInfo(
                context,
                'Thông báo đóng bằng tay',
                duration: const Duration(seconds: 5),
              );
            },
            child: const Text('Show'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Thông báo đóng bằng tay'), findsOneWidget);

    // Chạm nút đóng X (ValueKey toast_close_button)
    final closeBtn = find.byKey(const ValueKey('toast_close_button'));
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();

    expect(find.text('Thông báo đóng bằng tay'), findsNothing);
  });

  testWidgets('3. Manual dismiss right at timer expiration (race condition)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              ToastHelper.showWarning(
                context,
                'Race condition test',
                duration: const Duration(seconds: 2),
              );
            },
            child: const Text('Show'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Nhảy thời gian đến đúng lúc timer kích hoạt (2 giây)
    await tester.pump(const Duration(seconds: 2));

    // Bấm nút đóng đúng thời điểm đó
    final closeBtn = find.byKey(const ValueKey('toast_close_button'));
    if (closeBtn.evaluate().isNotEmpty) {
      await tester.tap(closeBtn);
    }

    await tester.pumpAndSettle();

    expect(find.text('Race condition test'), findsNothing);
  });

  testWidgets(
    '4. Calling 10 toasts rapidly shows only the latest toast without stacking',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                for (int i = 0; i < 10; i++) {
                  ToastHelper.showSuccess(
                    context,
                    'Toast $i',
                    duration: const Duration(seconds: 3),
                  );
                }
              },
              child: const Text('Show 10'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show 10'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Chỉ duy nhất Toast cuối cùng (Toast 9) xuất hiện trên Overlay
      expect(find.text('Toast 9'), findsOneWidget);
      expect(find.text('Toast 0'), findsNothing);
      expect(find.text('Toast 5'), findsNothing);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Toast 9'), findsNothing);
    },
  );

  testWidgets('5. Widget/context disposed while toast is active', (
    WidgetTester tester,
  ) async {
    final navKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ToastHelper.showError(
                  context,
                  'Screen dispose test',
                  duration: const Duration(seconds: 3),
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(body: Text('New Screen')),
                  ),
                );
              },
              child: const Text('Show and Navigate'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show and Navigate'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('New Screen'), findsOneWidget);

    // Chờ timer hết hạn khi screen cũ đã unmount
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('6. Renders properly in Light and Dark mode', (
    WidgetTester tester,
  ) async {
    // Light Mode
    await tester.pumpWidget(
      _buildTestApp(
        brightness: Brightness.light,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ToastHelper.showSuccess(context, 'Light Toast'),
            child: const Text('Light'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Light'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Light Toast'), findsOneWidget);

    ToastHelper.dismissCurrent();
    await tester.pumpAndSettle();

    // Dark Mode
    await tester.pumpWidget(
      _buildTestApp(
        brightness: Brightness.dark,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ToastHelper.showError(context, 'Dark Toast'),
            child: const Text('Dark'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Dark'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Dark Toast'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Dark Toast'), findsNothing);
  });
}
