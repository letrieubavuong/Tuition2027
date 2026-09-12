// File: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tuition2025/utils/theme.dart';
import 'l10n/app_localizations.dart';

// Import cac man hinh chinh
import 'screens/ds_lop.dart';
import 'screens/ds_hs.dart';
import 'screens/hocphi.dart';
import 'screens/home_page.dart'; // Import trang Home mới
import 'screens/splash_screen.dart'; // Import màn hình chờ
import 'services/notification_service.dart'; // Import dịch vụ thông báo
import 'services/widget_sync_service.dart';
import 'services/bank_notification_service.dart';
import 'services/tuition_event_service.dart';
import 'services/firebase_sync_service.dart';

// Tạo một GlobalKey để truy cập State của MainScreen từ bên ngoài
final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

// ----------------------------------------------------
// MainScreen: Quan ly Bottom Bar
// ----------------------------------------------------
class MainScreen extends StatefulWidget {
  const MainScreen({super.key}); // Constructor đã nhận key

  @override
  State<MainScreen> createState() => MainScreenState(); 
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // SỬA: Khôi phục lại danh sách các màn hình chính
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomePage(mainScreenKey: mainScreenKey, selectedIndex: 0),
      DSLop(mainScreenKey: mainScreenKey, selectedIndex: 1),
      DSHocSinh(mainScreenKey: mainScreenKey, selectedIndex: 2),
      HocPhiPage(mainScreenKey: mainScreenKey, selectedIndex: 3),
    ];
  }

  void onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
    if (index == 3 || index == 0) {
      TuitionEventService().notifyTuitionChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        // SỬA: Lấy label từ localization
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: AppLocalizations.of(context)!.homePageTitle,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.class_),
            label: AppLocalizations.of(context)!.classLabel,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person),
            label: AppLocalizations.of(context)!.studentLabel,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on),
            label: AppLocalizations.of(context)!.feeLabel,
          ),
        ],
        currentIndex: _selectedIndex,
        // SỬA: Đồng bộ màu sắc với theme mới
        type: BottomNavigationBarType.fixed, // Giữ nguyên để hiển thị label
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Theme.of(context).hintColor,
        onTap: onItemTapped,
      ),
    );
  }
}

// ----------------------------------------------------
// Ham main() khoi chay
// ----------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Khởi tạo dữ liệu ngôn ngữ cho package intl
  await initializeDateFormatting('vi_VN', null);

  runApp(const ProviderScope(child: MyApp()));

  // Khởi tạo dịch vụ thông báo & Firebase Realtime Database
  Future.microtask(() async {
    try {
      await FirebaseSyncService.instance.initialize();
      await NotificationService.instance.initialize();
      await NotificationService.instance.requestPermissions();
      await NotificationService.instance.syncAllClassReminders();
      await WidgetSyncService.syncTodaySchedule();
      await WidgetSyncService.syncBankQRWidget();

      BankNotificationService.instance;
      debugPrint('✅ Firebase & BankNotificationService initialized');
    } catch (e) {
      debugPrint('Error starting background services: $e');
    }
  });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider); // SỬA: Lắng nghe locale provider
    return MaterialApp(
      title: 'QLHS App',
      debugShowCheckedModeBanner: false, // SỬA: Ẩn banner debug
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeMode,
      // SỬA: Cập nhật cấu hình localization
      localizationsDelegates: const [
        AppLocalizations.delegate, // Delegate của ứng dụng
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('vi', 'VN'), // Tiếng Việt
      ],
      locale: locale, // SỬA: Sử dụng locale từ provider
      // SỬA: Gán GlobalKey cho MainScreen widget
      home: const SplashScreen(),
    );
  }
}
