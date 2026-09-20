// File: test/widgets/main_drawer_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tuition2025/widgets/main_drawer.dart';
import 'package:tuition2025/screens/caidat.dart';
import 'package:tuition2025/screens/cloud_data_page.dart';
import 'package:tuition2025/main.dart';
import 'package:tuition2025/l10n/app_localizations.dart';

void main() {
  Widget buildTestableWidget({
    required Widget child,
    required SettingsData settings,
  }) {
    return ProviderScope(
      overrides: [settingsProvider.overrideWith((ref) async => settings)],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('vi'), Locale('en')],
        locale: const Locale('vi'),
        home: child,
      ),
    );
  }

  testWidgets('MainDrawer renders header, 4 sections, items, and version', (
    tester,
  ) async {
    final mockSettings = SettingsData(
      hocPhiBuoi: '100000',
      hocPhiThang: '1200000',
      soBuoiChuanThang: '8',
      tenQuanLy: 'Trần Văn Thiện Ngọc',
      emailQuanLy: 'teacher@test.com',
      avatarPath: null,
      bankId: 'MB',
      accountNo: '123456789',
      accountName: 'TRAN VAN THIEN NGOC',
      danhSachTruong: [],
      reminderMinutes: '30',
      appPinEnabled: 'false',
      appBiometricEnabled: 'false',
      autoApprovePayment: 'true',
      widgetRefreshInterval: '15',
    );

    final key = GlobalKey<MainScreenState>();

    await tester.pumpWidget(
      buildTestableWidget(
        settings: mockSettings,
        child: Scaffold(body: MainDrawer(mainScreenKey: key, selectedIndex: 0)),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Header Profile Info
    expect(find.text('Trần Văn Thiện Ngọc'), findsOneWidget);
    expect(find.text('teacher@test.com'), findsOneWidget);

    // Verify 4 Sections
    expect(find.text('CHỨC NĂNG CHÍNH'), findsOneWidget);
    expect(find.text('Vận hành'), findsOneWidget);
    expect(find.text('TIỆN ÍCH'), findsOneWidget);
    expect(find.text('Hệ thống'), findsOneWidget);

    // Verify Navigation Items
    expect(find.text('Lớp học'), findsOneWidget);
    expect(find.text('Học sinh'), findsOneWidget);
    expect(find.text('Học phí'), findsOneWidget);
    expect(find.text('Lịch dạy'), findsOneWidget);
    expect(find.text('Thống Kê'), findsOneWidget);
    expect(find.text('Bảng xếp hạng khối'), findsOneWidget);
    expect(find.text('Xuất Báo Cáo PDF'), findsOneWidget);
    expect(find.text('Dữ liệu & Cloud'), findsOneWidget);
    expect(find.text('Cài Đặt'), findsOneWidget);
    expect(find.text('Quy Tắc Điểm'), findsOneWidget);
    expect(find.text('Hướng dẫn sử dụng'), findsOneWidget);

    // Verify Version in Footer
    expect(find.textContaining('Phiên bản'), findsOneWidget);
  });

  testWidgets('MainDrawer Cloud item opens CloudDataPage', (tester) async {
    final mockSettings = SettingsData(
      hocPhiBuoi: '100000',
      hocPhiThang: '1200000',
      soBuoiChuanThang: '8',
      tenQuanLy: 'Nguyễn Văn A',
      emailQuanLy: 'nguyenvana@test.com',
      avatarPath: null,
      bankId: 'MB',
      accountNo: '123456789',
      accountName: 'NGUYEN VAN A',
      danhSachTruong: [],
      reminderMinutes: '30',
      appPinEnabled: 'false',
      appBiometricEnabled: 'false',
      autoApprovePayment: 'true',
      widgetRefreshInterval: '15',
    );

    final key = GlobalKey<MainScreenState>();

    await tester.pumpWidget(
      buildTestableWidget(
        settings: mockSettings,
        child: Scaffold(body: MainDrawer(mainScreenKey: key, selectedIndex: 0)),
      ),
    );

    await tester.pumpAndSettle();

    // Scroll to and tap Dữ liệu & Cloud
    final cloudItem = find.text('Dữ liệu & Cloud');
    await tester.ensureVisible(cloudItem);
    await tester.tap(cloudItem);
    await tester.pumpAndSettle();

    // Verify CloudDataPage is shown
    expect(find.byType(CloudDataPage), findsOneWidget);
    expect(find.text('Đồng bộ lên Cloud'), findsOneWidget);
    expect(find.text('Khôi phục từ Cloud'), findsOneWidget);
    expect(find.text('Đối soát dữ liệu'), findsOneWidget);
  });
}
