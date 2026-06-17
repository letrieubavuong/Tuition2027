import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:tuition2025/utils/db.dart';
import 'package:tuition2025/models/lich_hoc.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:developer' as developer;

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  NotificationService._init();

  // Khởi tạo Notification
  Future<void> initialize() async {
    // 1. Khởi tạo timezone
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      developer.log('✅ Đã thiết lập múi giờ: $timeZoneName', name: 'NotificationService');
    } catch (e) {
      // Fallback về múi giờ Việt Nam nếu gặp lỗi
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      developer.log('⚠️ Không phát hiện được múi giờ tự động. Dùng mặc định: Asia/Ho_Chi_Minh ($e)', name: 'NotificationService');
    }

    // 2. Cấu hình thông báo cho Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Cấu hình thông báo cho iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        developer.log('🔔 Người dùng nhấn vào thông báo: ${response.payload}', name: 'NotificationService');
      },
    );

    // 4. Tạo kênh thông báo mặc định cho Android (Hỗ trợ phát chuông lặp liên tục như báo thức)
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'tuition_reminders_channel_alarm',
        'Nhắc Nhở Lịch Học (Chuông Báo Thức)',
        description: 'Kênh thông báo nhắc ca học và reo chuông lặp liên tục như báo thức',
        importance: Importance.max,
        playSound: true,
      );
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      developer.log('📢 Đã tạo kênh thông báo: tuition_reminders_channel_alarm', name: 'NotificationService');
    }

    developer.log('✅ Khởi tạo FlutterLocalNotifications thành công!', name: 'NotificationService');
  }

  // Yêu cầu quyền thông báo (đặc biệt cho Android 13+)
  Future<bool> requestPermissions() async {
    final bool? granted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    final bool? exactAlarmGranted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

    developer.log('🔑 Quyền thông báo được cấp: $granted, Quyền chuông chính xác: $exactAlarmGranted', name: 'NotificationService');
    return granted ?? false;
  }

  // Tính toán thời gian thông báo (Lớp học trừ đi số phút báo trước)
  tz.TZDateTime _calculateScheduledDateTime(int targetWeekday, String gioBatDau, int minutesBefore) {
    final parts = gioBatDau.split(':');
    final int hour = int.parse(parts[0]);
    final int minute = int.parse(parts[1]);

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    
    // targetWeekday: 1=CN, 2=T2, 3=T3, 4=T4, 5=T5, 6=T6, 7=T7
    // Múi giờ chuẩn DateTime: 1=Thứ Hai (Mon), ..., 7=Chủ Nhật (Sun)
    int standardWeekday = (targetWeekday == 1) ? DateTime.sunday : (targetWeekday - 1);

    tz.TZDateTime classDateTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Nếu giờ học hôm nay đã trôi qua, chuyển sang tuần tới
    if (classDateTime.isBefore(now)) {
      classDateTime = classDateTime.add(const Duration(days: 1));
    }

    // Tìm thứ chính xác tiếp theo
    while (classDateTime.weekday != standardWeekday) {
      classDateTime = classDateTime.add(const Duration(days: 1));
    }

    // Trừ đi số phút báo trước
    final reminderDateTime = classDateTime.subtract(Duration(minutes: minutesBefore));

    // Nếu thời điểm nhắc nhở lại rơi vào quá khứ so với hiện tại (ví dụ: lớp học lúc 15:00, báo trước 10 phút là 14:50, nhưng hiện tại đã là 14:55), ta cộng thêm 7 ngày (lên lịch cho tuần kế tiếp)
    if (reminderDateTime.isBefore(now)) {
      return reminderDateTime.add(const Duration(days: 7));
    }

    return reminderDateTime;
  }

  // Lên lịch thông báo nhắc nhở cho một ca học cụ thể
  Future<void> scheduleClassReminder(LichHoc lichHoc, {int? customMinutesBefore}) async {
    if (lichHoc.id == null) return;

    try {
      final db = await DBHelper.instance.database;
      
      // 1. Lấy thông tin cấu hình thời gian báo trước từ bảng cai_dat
      int minutesBefore = customMinutesBefore ?? 10;
      if (customMinutesBefore == null) {
        final settings = await db.query(
          DBHelper.tenBangCaiDat,
          where: 'khoa = ?',
          whereArgs: ['reminder_minutes'],
        );
        if (settings.isNotEmpty) {
          final val = settings.first['gia_tri'] as String;
          if (val == 'off') {
            // Đã tắt tính năng nhắc nhở
            await cancelClassReminder(lichHoc.id!);
            return;
          }
          minutesBefore = int.tryParse(val) ?? 10;
        }
      }

      // 2. Lấy tên lớp học
      final lopResult = await db.query(
        DBHelper.tenBangLop,
        where: 'id = ?',
        whereArgs: [lichHoc.idLop],
      );
      final String tenLop = lopResult.isNotEmpty 
          ? lopResult.first['ten'] as String 
          : 'Lớp học';

      // Hủy lịch thông báo cũ (nếu có) trước khi tạo mới
      await cancelClassReminder(lichHoc.id!);

      final scheduledDateTime = _calculateScheduledDateTime(
        lichHoc.thuTrongTuan, 
        lichHoc.gioBatDau, 
        minutesBefore
      );

      final androidDetails = AndroidNotificationDetails(
        'tuition_reminders_channel_alarm',
        'Nhắc Nhở Lịch Học (Chuông Báo Thức)',
        channelDescription: 'Kênh thông báo nhắc ca học và reo chuông lặp liên tục như báo thức',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        visibility: NotificationVisibility.public,
        additionalFlags: Int32List.fromList([4]), // Flag 4 là FLAG_INSISTENT reo lặp liên tục như báo thức
        audioAttributesUsage: AudioAttributesUsage.alarm,
        category: AndroidNotificationCategory.alarm,
      );

      final notificationDetails = NotificationDetails(android: androidDetails);

      bool canScheduleExact = true;
      if (Platform.isAndroid) {
        canScheduleExact = await _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.canScheduleExactNotifications() ?? false;
      }

      final scheduleMode = canScheduleExact 
          ? AndroidScheduleMode.exactAllowWhileIdle 
          : AndroidScheduleMode.inexactAllowWhileIdle;

      try {
        await _notificationsPlugin.zonedSchedule(
          lichHoc.id!, // Dùng ID lịch học làm ID thông báo luôn
          'Sắp đến giờ dạy - Tuition 2025',
          'Ca dạy lớp "$tenLop" sẽ bắt đầu lúc ${lichHoc.gioBatDau.substring(0, 5)} (còn $minutesBefore phút)',
          scheduledDateTime,
          notificationDetails,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'lop_id=${lichHoc.idLop}',
        );
        developer.log(
          '⏰ Đã lên lịch thông báo lớp "$tenLop" (ID: ${lichHoc.id}) lúc: $scheduledDateTime ($scheduleMode mode)',
          name: 'NotificationService'
        );
      } catch (scheduleError) {
        developer.log(
          '❌ Lỗi khi hẹn giờ thông báo lớp "$tenLop": $scheduleError',
          name: 'NotificationService'
        );
      }
    } catch (e) {
      developer.log('❌ Lỗi chung khi hẹn giờ thông báo: $e', name: 'NotificationService');
    }
  }

  // Hủy thông báo nhắc nhở cho một ca học
  Future<void> cancelClassReminder(int lichHocId) async {
    await _notificationsPlugin.cancel(lichHocId);
    developer.log('🚫 Đã hủy thông báo lịch nhắc cho ca học ID: $lichHocId', name: 'NotificationService');
  }

  // Hủy toàn bộ thông báo nhắc nhở
  Future<void> cancelAllReminders() async {
    await _notificationsPlugin.cancelAll();
    developer.log('🚫 Đã hủy toàn bộ thông báo lịch nhắc ca học', name: 'NotificationService');
  }

  // Đồng bộ lại tất cả lịch thông báo từ SQLite
  Future<void> syncAllClassReminders() async {
    try {
      final db = await DBHelper.instance.database;
      
      // Lấy cấu hình báo trước
      int minutesBefore = 10;
      final settings = await db.query(
        DBHelper.tenBangCaiDat,
        where: 'khoa = ?',
        whereArgs: ['reminder_minutes'],
      );
      
      if (settings.isNotEmpty) {
        final val = settings.first['gia_tri'] as String;
        if (val == 'off') {
          await cancelAllReminders();
          return;
        }
        minutesBefore = int.tryParse(val) ?? 10;
      } else {
        // Khởi tạo cấu hình mặc định là 10 phút nếu chưa có trong DB
        await db.insert(
          DBHelper.tenBangCaiDat, 
          {'khoa': 'reminder_minutes', 'gia_tri': '10'},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      // Hủy tất cả thông báo cũ trước khi tạo lại
      await cancelAllReminders();

      // Đọc danh sách tất cả các ca học
      final List<Map<String, dynamic>> maps = await db.query(DBHelper.tenBangLichHoc);
      final List<LichHoc> listLich = maps.map((map) => LichHoc.fromMap(map)).toList();

      for (var lh in listLich) {
        await scheduleClassReminder(lh, customMinutesBefore: minutesBefore);
      }
      
      developer.log('✅ Đã đồng bộ thành công ${listLich.length} thông báo ca dạy!', name: 'NotificationService');
    } catch (e) {
      developer.log('❌ Lỗi khi đồng bộ toàn bộ thông báo: $e', name: 'NotificationService');
    }
  }
}
