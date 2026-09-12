import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Simple widget smoke test', (WidgetTester tester) async {
    // Build a simple widget to ensure the test environment works.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Tuition 2025'))),
      ),
    );

    expect(find.text('Tuition 2025'), findsOneWidget);
  });
}
