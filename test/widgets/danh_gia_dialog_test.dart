import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tuition2025/widgets/danh_gia_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  group('DanhGiaDialog Widget Tests', () {
    testWidgets('Renders dialog title and form fields correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const DanhGiaDialog(
            idHocSinh: 1,
            tenHocSinh: 'Nguyễn Văn An',
            idLop: 10,
            thang: '2026-09',
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pump();

      expect(find.byType(DanhGiaDialog), findsOneWidget);
      expect(find.textContaining('Nguyễn Văn An'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
