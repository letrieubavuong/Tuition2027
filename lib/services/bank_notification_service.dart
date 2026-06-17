import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/db.dart';
import 'thanh_toan_service.dart';
import 'caidat_service.dart';

class BankNotificationService {
  static final BankNotificationService instance = BankNotificationService._init();
  
  static const MethodChannel _channel = MethodChannel('com.example.tuition2025/notification_listener');
  final ThanhToanService _thanhToanService = ThanhToanService();
  final CaiDatService _caiDatService = CaiDatService();
  
  // Local notification setup to alert user of automated approvals
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  BankNotificationService._init() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // Handle incoming method calls from Kotlin
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onNotificationReceived':
        final Map<dynamic, dynamic>? data = call.arguments as Map<dynamic, dynamic>?;
        if (data != null) {
          final String title = data['title'] ?? '';
          final String text = data['text'] ?? '';
          final String package = data['package'] ?? '';
          developer.log('🔔 Nhận thông báo ngân hàng từ Native: $title | $text', name: 'BankNotificationService');
          await processNotification(title, text, package);
        }
        break;
      default:
        developer.log('Unhandled method: ${call.method}', name: 'BankNotificationService');
    }
  }

  // Check if Notification Listener Permission is granted
  Future<bool> checkPermission() async {
    try {
      final bool isEnabled = await _channel.invokeMethod('isNotificationServiceEnabled') ?? false;
      return isEnabled;
    } catch (e) {
      developer.log('Error checking notification listener permission: $e', name: 'BankNotificationService');
      return false;
    }
  }

  // Redirect to Android Notification Access settings
  Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openNotificationListenerSettings');
    } catch (e) {
      developer.log('Error opening notification listener settings: $e', name: 'BankNotificationService');
    }
  }

  // Process transaction messages and attempt to match with tuition record
  Future<void> processNotification(String title, String text, String package) async {
    try {
      // 1. Check if auto-payment processing is enabled in settings
      final String enabledVal = await _caiDatService.docGiaTri('auto_approve_payment');
      if (enabledVal != '1') {
        developer.log('Auto approve payment is disabled in settings. Ignoring notification.', name: 'BankNotificationService');
        return;
      }

      // 2. Parse credit amount
      // Match pattern like "+100,000" or "+ 100.000" or "+100000"
      final RegExp amountRegex = RegExp(r'\+\s*([0-9,.]+)\s*(?:VND|đ|d)?', caseSensitive: false);
      final Match? amountMatch = amountRegex.firstMatch(text);
      if (amountMatch == null) {
        developer.log('Could not parse credit amount from text: "$text"', name: 'BankNotificationService');
        return;
      }
      
      String cleanAmountStr = amountMatch.group(1)!.replaceAll(',', '').replaceAll('.', '').trim();
      int? amount = int.tryParse(cleanAmountStr);
      if (amount == null || amount <= 0) {
        developer.log('Parsed amount is invalid: $cleanAmountStr', name: 'BankNotificationService');
        return;
      }

      developer.log('💰 Detected credit transaction amount: $amount', name: 'BankNotificationService');

      // 3. Scan for student name and month in description text
      // Example transaction content: GD: +100,000 VND ND: Hoc phi Huynh Phan Ngoc Ha thang 2026-06
      final db = await DBHelper.instance.database;

      // Select all active classes & student pairs that are currently unpaid or partially paid
      // Let's get the list of unpaid/partially paid tuition records
      final List<Map<String, dynamic>> records = await db.rawQuery('''
        SELECT 
          TT.id_hoc_sinh, 
          TT.id_lop, 
          TT.thang, 
          TT.tong_thanh_toan, 
          TT.so_tien_da_dong,
          HS.ten as ten_hoc_sing,
          L.ten as ten_lop
        FROM ${DBHelper.tenBangThanhToan} TT
        JOIN ${DBHelper.tenBangHS} HS ON TT.id_hoc_sinh = HS.id
        JOIN ${DBHelper.tenBangLop} L ON TT.id_lop = L.id
        WHERE TT.so_tien_da_dong < TT.tong_thanh_toan
      ''');

      Map<String, dynamic>? bestMatch;
      double maxMatchScore = 0.0;

      // Accent marks removing mapping for normalization
      String removeDiacritics(String str) {
        const withDiacritics = 'áàảãạăắằẳẵặâấầẩẫậéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵđÁÀẢÃẠĂẮẰẲẴẶÂẤẦẨẪẬÉÈẺẼẸÊẾỀỂỄỆÍÌỈĨỊÓÒỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÚÙỦŨỤƯỨỪỬỮỰÝỲỶỸỴĐ';
        const withoutDiacritics = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyydAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
        
        String result = str;
        for (int i = 0; i < withDiacritics.length; i++) {
          result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
        }
        return result.toLowerCase();
      }

      String normalizedText = removeDiacritics(text);

      for (var record in records) {
        String studentName = record['ten_hoc_sing'] ?? '';
        String className = record['ten_lop'] ?? '';
        String month = record['thang'] ?? ''; // e.g., '2026-06'
        int totalToPay = record['tong_thanh_toan'] - record['so_tien_da_dong'];

        String normStudent = removeDiacritics(studentName);
        String normClass = removeDiacritics(className);
        
        // We match if:
        // 1. The transaction amount matches exactly the unpaid amount (or is close to it)
        // 2. The normalized text contains parts of the student name (first name/last name/full name)
        
        // If amount matches exactly, we get a huge bonus
        double score = 0.0;
        if (amount == totalToPay) {
          score += 5.0;
        } else if (amount == record['tong_thanh_toan']) {
          // Matches total monthly tuition
          score += 4.0;
        }

        // Check student name tokens matching
        List<String> studentTokens = normStudent.split(' ').where((t) => t.length > 1).toList();
        int matchedTokens = 0;
        for (var token in studentTokens) {
          if (normalizedText.contains(token)) {
            matchedTokens++;
          }
        }

        if (studentTokens.isNotEmpty) {
          double tokenMatchRatio = matchedTokens / studentTokens.length;
          score += tokenMatchRatio * 5.0; // max 5 points for name
        }

        // Check if month is present
        // Convert '2026-06' -> '06' or 'thang 6' or 'thang 06'
        List<String> monthParts = month.split('-');
        if (monthParts.length == 2) {
          String year = monthParts[0];
          String mm = monthParts[1];
          String mmShort = mm.startsWith('0') ? mm.substring(1) : mm;

          if (normalizedText.contains(month) || 
              (normalizedText.contains(mm) && normalizedText.contains(year)) ||
              (normalizedText.contains('thang $mm') || normalizedText.contains('thang $mmShort') || normalizedText.contains('th $mm') || normalizedText.contains('t$mm'))) {
            score += 2.0;
          }
        }

        // Check class name token
        List<String> classTokens = normClass.split(' ').where((t) => t.length > 1).toList();
        int matchedClassTokens = 0;
        for (var token in classTokens) {
          if (normalizedText.contains(token)) {
            matchedClassTokens++;
          }
        }
        if (classTokens.isNotEmpty && matchedClassTokens > 0) {
          score += (matchedClassTokens / classTokens.length) * 1.5;
        }

        // If amount matches and we matched at least some student tokens, we consider it a match
        if (matchedTokens >= 2 && score > maxMatchScore) {
          maxMatchScore = score;
          bestMatch = record;
        } else if (studentTokens.length < 2 && matchedTokens >= 1 && score > maxMatchScore) {
          // Student name is short (e.g. 1 token)
          maxMatchScore = score;
          bestMatch = record;
        }
      }

      if (bestMatch != null && maxMatchScore >= 6.5) {
        // High confidence match!
        int idHocSinh = bestMatch['id_hoc_sinh'];
        int idLop = bestMatch['id_lop'];
        String thang = bestMatch['thang'];
        String tenHS = bestMatch['ten_hoc_sing'];
        String tenLop = bestMatch['ten_lop'];
        int unpaid = bestMatch['tong_thanh_toan'] - bestMatch['so_tien_da_dong'];

        int completedPaymentAmount = unpaid;
        if (amount < unpaid) {
          // Partial payment
          completedPaymentAmount = bestMatch['so_tien_da_dong'] + amount;
        } else {
          // Fully paid or overpaid
          completedPaymentAmount = bestMatch['tong_thanh_toan'];
        }

        developer.log('🎯 Match found! Student: $tenHS, Class: $tenLop, Month: $thang. Updating DB...', name: 'BankNotificationService');
        
        await _thanhToanService.capNhatSoTienDaDong(
          idHocSinh,
          idLop,
          thang,
          completedPaymentAmount,
          'Duyệt tự động qua Sacombank App (+${amount.toString()})',
          ngayThanhToan: DateTime.now(),
        );

        // Show local push notification
        await _showLocalNotification(
          'Duyệt học phí tự động thành công!',
          'Học sinh: $tenHS ($tenLop) - Tháng: $thang đã đóng +${amount.toString()}đ',
        );
      } else {
        developer.log('⚠️ Could not match transaction to any student record (Max score: $maxMatchScore)', name: 'BankNotificationService');
      }
    } catch (e, stack) {
      developer.log('❌ Error processing bank notification: $e', stackTrace: stack, name: 'BankNotificationService');
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'tuition_reminders_channel',
      'Nhắc Nhở Lịch Học',
      channelDescription: 'Kênh thông báo nhắc ca học trước giờ lên lớp',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails generalNotificationDetails = NotificationDetails(android: androidDetails);
    
    // Using a random ID for payment notifications
    int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _localNotifications.show(
      notificationId,
      title,
      body,
      generalNotificationDetails,
    );
  }
}
