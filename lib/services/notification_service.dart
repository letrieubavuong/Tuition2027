import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tuition2025/utils/db.dart';
import 'package:tuition2025/models/lich_hoc.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:developer' as developer;
import 'notification_router.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  NotificationService._init();

  // Helper tạo cấu hình thông báo Android chuông báo thức lặp
  AndroidNotificationDetails _buildAlarmNotificationDetails() {
    return AndroidNotificationDetails(
      'tuition_reminders_channel_alarm_v2',
      'Nhắc Nhở Lịch Học (Chuông Báo Thức)',
      channelDescription:
          'Kênh thông báo nhắc ca học và reo chuông lặp liên tục như báo thức',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      visibility: NotificationVisibility.public,
      additionalFlags: Int32List.fromList([
        4,
      ]), // Flag 4 là FLAG_INSISTENT reo lặp liên tục như báo thức
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
    );
  }

  // Khởi tạo Notification (chống gọi trùng lặp nhiều lần)
  Future<void> initialize() async {
    if (_initialized) return;

    // 1. Khởi tạo timezone
    tz.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timeZone.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      developer.log(
        '✅ Đã thiết lập múi giờ: $timeZoneName',
        name: 'NotificationService',
      );
    } catch (e) {
      // Fallback về múi giờ Việt Nam nếu gặp lỗi
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      developer.log(
        '⚠️ Không phát hiện được múi giờ tự động. Dùng mặc định: Asia/Ho_Chi_Minh ($e)',
        name: 'NotificationService',
      );
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

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        developer.log(
          '🔔 Người dùng nhấn vào thông báo: ${response.payload}',
          name: 'NotificationService',
        );
        final payload = NotificationPayload.parse(response.payload);
        await NotificationRouter.handleNotificationRouting(payload);
      },
    );

    // Check cold start notification launch details
    try {
      final NotificationAppLaunchDetails? launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payloadStr = launchDetails.notificationResponse?.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          NotificationRouter.pendingLaunchPayload = NotificationPayload.parse(
            payloadStr,
          );
          developer.log(
            '🚀 Cold Start notification launch detected: $payloadStr',
            name: 'NotificationService',
          );
        }
      }
    } catch (e) {
      developer.log(
        'Lỗi kiềm tra cold start notification: $e',
        name: 'NotificationService',
      );
    }

    // 4. Tạo kênh thông báo mặc định cho Android (Hỗ trợ phát chuông lặp liên tục như báo thức)
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'tuition_reminders_channel_alarm_v2',
        'Nhắc Nhở Lịch Học (Chuông Báo Thức)',
        description:
            'Kênh thông báo nhắc ca học và reo chuông lặp liên tục như báo thức',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      developer.log(
        '📢 Đã tạo kênh thông báo: tuition_reminders_channel_alarm_v2',
        name: 'NotificationService',
      );
    }

    _initialized = true;
    developer.log(
      '✅ Khởi tạo FlutterLocalNotifications thành công!',
      name: 'NotificationService',
    );
  }

  // Yêu cầu quyền thông báo (đặc biệt cho Android 13+)
  Future<bool> requestPermissions() async {
    final bool? granted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    final bool? exactAlarmGranted = await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();

    developer.log(
      '🔑 Quyền thông báo được cấp: $granted, Quyền chuông chính xác: $exactAlarmGranted',
      name: 'NotificationService',
    );
    return granted ?? false;
  }

  // Kiểm tra xem thiết bị đã cho phép đặt chuông báo thức chính xác (Exact Alarm) chưa
  Future<bool> checkExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    return await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
  }

  // Mở màn hình cài đặt "Báo thức & Giờ nhắc" của Android 12+
  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();
  }

  // Thử nghiệm gửi thông báo nhắc ca dạy sau X giây (dùng để kiểm tra trên máy thật)
  Future<void> scheduleTestNotification(int secondsFromNow) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime scheduledDateTime = now.add(
      Duration(seconds: secondsFromNow),
    );

    final notificationDetails = NotificationDetails(
      android: _buildAlarmNotificationDetails(),
    );

    bool canScheduleExact = await checkExactAlarmPermission();
    final scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _notificationsPlugin.zonedSchedule(
      999999, // ID thử nghiệm
      '🔔 Thử nghiệm thông báo ca dạy - Tuition 2025',
      'Đây là thông báo thử nghiệm nhắc ca dạy reo chuông báo thức!',
      scheduledDateTime,
      notificationDetails,
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'test_notification',
    );
    developer.log(
      '🧪 Đã lên lịch thông báo thử nghiệm sau $secondsFromNow giây (Lúc: $scheduledDateTime, ExactMode: $canScheduleExact)',
      name: 'NotificationService',
    );
  }

  // Parse chuỗi giờ bắt đầu ca học an toàn (hỗ trợ HH:mm, HH:mm:ss, HHhMM, v.v.)
  (int, int)? _parseTimeString(String timeStr) {
    final cleaned = timeStr.trim();
    if (cleaned.isEmpty) return null;

    final regex = RegExp(r'^(\d{1,2})[:hH](\d{1,2})(?::\d{1,2})?$');
    final match = regex.firstMatch(cleaned);

    if (match != null) {
      final hour = int.tryParse(match.group(1)!);
      final minute = int.tryParse(match.group(2)!);
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        return (hour, minute);
      }
    }

    final parts = cleaned.split(RegExp(r'[:hH]'));
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0].trim());
      final minute = int.tryParse(parts[1].trim());
      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        return (hour, minute);
      }
    }

    return null;
  }

  // Tính toán thời gian thông báo (Lớp học trừ đi số phút báo trước)
  tz.TZDateTime? _calculateScheduledDateTime(
    int targetWeekday,
    String gioBatDau,
    int minutesBefore,
  ) {
    final parsedTime = _parseTimeString(gioBatDau);
    if (parsedTime == null) {
      developer.log(
        '⚠️ Không thể parse giờ bắt đầu ca học hợp lệ: "$gioBatDau"',
        name: 'NotificationService',
      );
      return null;
    }

    final int hour = parsedTime.$1;
    final int minute = parsedTime.$2;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // targetWeekday: 1=CN, 2=T2, 3=T3, 4=T4, 5=T5, 6=T6, 7=T7
    // Múi giờ chuẩn DateTime: 1=Thứ Hai (Mon), ..., 7=Chủ Nhật (Sun)
    int standardWeekday = (targetWeekday == 1)
        ? DateTime.sunday
        : (targetWeekday - 1);

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
    final reminderDateTime = classDateTime.subtract(
      Duration(minutes: minutesBefore),
    );

    // Nếu thời điểm nhắc nhở lại rơi vào quá khứ so với hiện tại, cộng 7 ngày
    if (reminderDateTime.isBefore(now)) {
      return reminderDateTime.add(const Duration(days: 7));
    }

    return reminderDateTime;
  }

  // Lên lịch thông báo nhắc nhở cho một ca học cụ thể
  Future<void> scheduleClassReminder(
    LichHoc lichHoc, {
    int? customMinutesBefore,
    String? tenLop,
    bool? canScheduleExact,
    AndroidScheduleMode? scheduleMode,
    bool cancelExisting = true,
  }) async {
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
            await cancelClassReminder(lichHoc.id!);
            return;
          }
          minutesBefore = int.tryParse(val) ?? 10;
        }
      }

      // 2. Lấy tên lớp học (dùng tenLop truyền vào hoặc query nếu chưa có)
      String className = tenLop ?? '';
      if (className.isEmpty) {
        final lopResult = await db.query(
          DBHelper.tenBangLop,
          columns: ['ten'],
          where: 'id = ?',
          whereArgs: [lichHoc.idLop],
        );
        className = lopResult.isNotEmpty
            ? (lopResult.first['ten'] as String? ?? 'Lớp học')
            : 'Lớp học';
      }

      // 3. Xác định AndroidScheduleMode (nếu truyền sẵn scheduleMode thì dùng luôn, không cần check platform)
      AndroidScheduleMode finalScheduleMode;
      if (scheduleMode != null) {
        finalScheduleMode = scheduleMode;
      } else {
        bool isExact = canScheduleExact ?? true;
        if (canScheduleExact == null && Platform.isAndroid) {
          isExact = await checkExactAlarmPermission();
        }
        finalScheduleMode = isExact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle;
      }

      // Hủy lịch thông báo cũ (nếu có và cancelExisting = true) trước khi tạo mới
      if (cancelExisting) {
        await cancelClassReminder(lichHoc.id!);
      }

      final scheduledDateTime = _calculateScheduledDateTime(
        lichHoc.thuTrongTuan,
        lichHoc.gioBatDau,
        minutesBefore,
      );

      if (scheduledDateTime == null) {
        developer.log(
          '⚠️ Bỏ qua hẹn giờ cho ca học ID: ${lichHoc.id} do giờ bắt đầu không hợp lệ: "${lichHoc.gioBatDau}"',
          name: 'NotificationService',
        );
        return;
      }

      final timeDisplay = _parseTimeString(lichHoc.gioBatDau);
      final formattedTime = timeDisplay != null
          ? '${timeDisplay.$1.toString().padLeft(2, '0')}:${timeDisplay.$2.toString().padLeft(2, '0')}'
          : lichHoc.gioBatDau;

      final notificationDetails = NotificationDetails(
        android: _buildAlarmNotificationDetails(),
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          lichHoc.id!, // Dùng ID lịch học làm ID thông báo luôn
          'Sắp đến giờ dạy - Tuition 2025',
          'Ca dạy lớp "$className" sẽ bắt đầu lúc $formattedTime (còn $minutesBefore phút)',
          scheduledDateTime,
          notificationDetails,
          androidScheduleMode: finalScheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: 'lop_id=${lichHoc.idLop}',
        );
        developer.log(
          '⏰ Đã lên lịch thông báo lớp "$className" (ID: ${lichHoc.id}) lúc: $scheduledDateTime ($finalScheduleMode mode)',
          name: 'NotificationService',
        );
      } catch (scheduleError) {
        developer.log(
          '❌ Lỗi khi hẹn giờ thông báo lớp "$className": $scheduleError',
          name: 'NotificationService',
        );
      }
    } catch (e) {
      developer.log(
        '❌ Lỗi chung khi hẹn giờ thông báo: $e',
        name: 'NotificationService',
      );
    }
  }

  // Hủy thông báo nhắc nhở cho một ca học
  Future<void> cancelClassReminder(int lichHocId) async {
    await _notificationsPlugin.cancel(lichHocId);
    developer.log(
      '🚫 Đã hủy thông báo lịch nhắc cho ca học ID: $lichHocId',
      name: 'NotificationService',
    );
  }

  // Hủy toàn bộ thông báo nhắc nhở
  Future<void> cancelAllReminders() async {
    await _notificationsPlugin.cancelAll();
    developer.log(
      '🚫 Đã hủy toàn bộ thông báo lịch nhắc ca học',
      name: 'NotificationService',
    );
  }

  // Đồng bộ lại tất cả lịch thông báo từ SQLite (JOIN 1 lần duy nhất loại bỏ N+1 Query)
  Future<void> syncAllClassReminders() async {
    try {
      final db = await DBHelper.instance.database;

      // 1. Đọc setting nhắc trước 1 lần duy nhất
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
        await db.insert(DBHelper.tenBangCaiDat, {
          'khoa': 'reminder_minutes',
          'gia_tri': '10',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // 2. Đọc tất cả lịch + tên lớp 1 lần duy nhất bằng SQL JOIN
      final List<Map<String, dynamic>> rawSchedules = await db.rawQuery('''
        SELECT lh.*, l.ten as ten_lop
        FROM ${DBHelper.tenBangLichHoc} lh
        LEFT JOIN ${DBHelper.tenBangLop} l ON lh.id_lop = l.id
      ''');

      // 3. Kiểm tra Exact Alarm 1 lần duy nhất và khởi tạo AndroidScheduleMode
      final bool canScheduleExact = await checkExactAlarmPermission();
      final AndroidScheduleMode scheduleMode = canScheduleExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;

      // 4. Hủy tất cả thông báo cũ 1 lần duy nhất
      await cancelAllReminders();

      // 5. Lên lịch từng ca học theo thứ tự tuần tự (Sequential - không dùng Future.wait để an toàn trên thiết bị thật)
      for (var r in rawSchedules) {
        final lh = LichHoc.fromMap(r);
        final tenLop = r['ten_lop'] as String? ?? 'Lớp học';
        await scheduleClassReminder(
          lh,
          customMinutesBefore: minutesBefore,
          tenLop: tenLop,
          scheduleMode: scheduleMode,
          cancelExisting: false,
        );
      }

      developer.log(
        '✅ Đã đồng bộ thành công ${rawSchedules.length} thông báo ca dạy!',
        name: 'NotificationService',
      );
    } catch (e) {
      developer.log(
        '❌ Lỗi khi đồng bộ toàn bộ thông báo: $e',
        name: 'NotificationService',
      );
    }
  }
}
