// File: lib/services/calendar_sync_service.dart

import 'dart:io';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'lich_hoc_service.dart';

class CalendarSyncService {
  /// Chuyển đổi thứ trong tuần từ App (1=CN, 2=T2...7=T7) sang DateTime.weekday (1=T2...7=CN)
  static int _mapAppThuToDateTimeWeekday(int appThu) {
    if (appThu == 1) return DateTime.sunday; // 7
    return appThu - 1; // 2 -> 1 (Monday), 3 -> 2 (Tuesday)... 7 -> 6 (Saturday)
  }

  /// Tính thời điểm tiếp theo ứng với thứ trong tuần và giờ quy định
  static DateTime _nextDateTimeForDayAndTime(int appThu, String timeStr) {
    final targetWeekday = _mapAppThuToDateTimeWeekday(appThu);
    final now = DateTime.now();
    final parts = timeStr.split(':');
    final hour = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 17) : 17;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 30) : 30;

    int daysAhead = targetWeekday - now.weekday;
    if (daysAhead < 0) {
      daysAhead += 7;
    } else if (daysAhead == 0) {
      // Nếu cùng thứ hôm nay nhưng giờ đã qua thì chuyển sang tuần tới
      final targetTimeToday = DateTime(now.year, now.month, now.day, hour, minute);
      if (now.isAfter(targetTimeToday)) {
        daysAhead = 7;
      }
    }

    final targetDate = now.add(Duration(days: daysAhead));
    return DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
  }

  /// Thêm 1 ca dạy cụ thể vào Google Calendar / Lịch hệ điều hành
  static Future<bool> themCaHocVaoCalendar(LichHocCoTenLop schedule) async {
    try {
      final startDt = _nextDateTimeForDayAndTime(
        schedule.lichHoc.thuTrongTuan,
        schedule.lichHoc.gioBatDau,
      );

      final endDt = _nextDateTimeForDayAndTime(
        schedule.lichHoc.thuTrongTuan,
        schedule.lichHoc.gioKetThuc,
      );

      // Nếu endDt <= startDt (do lỗi giờ qua ngày), cộng thêm duration mặc định
      final actualEndDt = endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)
          ? startDt.add(const Duration(hours: 1, minutes: 30))
          : endDt;

      final Event event = Event(
        title: 'Lớp ${schedule.tenLop} - Dạy Học',
        description:
            'Ca dạy lớp ${schedule.tenLop}\nThời gian: ${schedule.lichHoc.gioBatDau} - ${schedule.lichHoc.gioKetThuc}\nĐược đồng bộ từ ứng dụng QL Học Phí Tuition2025.',
        location: 'Lớp học ${schedule.tenLop}',
        startDate: startDt,
        endDate: actualEndDt,
        iosParams: const IOSParams(
          reminder: Duration(minutes: 30),
        ),
        androidParams: const AndroidParams(
          emailInvites: [],
        ),
        recurrence: Recurrence(
          frequency: Frequency.weekly,
        ),
      );

      return await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      debugPrint('Lỗi thêm sự kiện lịch: $e');
      return false;
    }
  }

  /// Xuất toàn bộ danh sách lịch dạy ra file .ics (iCalendar) để nhập vào Google Calendar/Outlook
  static Future<String?> xuatDanhSachLichDaySangICS(
    List<LichHocCoTenLop> schedules,
  ) async {
    if (schedules.isEmpty) return null;

    final StringBuffer sb = StringBuffer();
    sb.writeln('BEGIN:VCALENDAR');
    sb.writeln('VERSION:2.0');
    sb.writeln('PRODID:-//Tuition2025//LichDayApp//VI');
    sb.writeln('CALSCALE:GREGORIAN');
    sb.writeln('METHOD:PUBLISH');
    sb.writeln('X-WR-CALNAME:Lịch Dạy Học - Tuition2025');
    sb.writeln('X-WR-TIMEZONE:Asia/Ho_Chi_Minh');

    final icsDateFormat = DateFormat("yyyyMMdd'T'HHmmss");

    for (var i = 0; i < schedules.length; i++) {
      final s = schedules[i];
      final startDt = _nextDateTimeForDayAndTime(
        s.lichHoc.thuTrongTuan,
        s.lichHoc.gioBatDau,
      );
      final endDt = _nextDateTimeForDayAndTime(
        s.lichHoc.thuTrongTuan,
        s.lichHoc.gioKetThuc,
      );
      final actualEndDt = endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)
          ? startDt.add(const Duration(hours: 1, minutes: 30))
          : endDt;

      sb.writeln('BEGIN:VEVENT');
      sb.writeln('UID:tuition2025_${s.lichHoc.id ?? i}_${DateTime.now().millisecondsSinceEpoch}@tuition.app');
      sb.writeln('DTSTAMP:${icsDateFormat.format(DateTime.now())}');
      sb.writeln('DTSTART:${icsDateFormat.format(startDt)}');
      sb.writeln('DTEND:${icsDateFormat.format(actualEndDt)}');
      sb.writeln('SUMMARY:Lớp ${s.tenLop} - Dạy Học');
      sb.writeln('DESCRIPTION:Ca dạy lớp ${s.tenLop} (${s.lichHoc.gioBatDau} - ${s.lichHoc.gioKetThuc})');
      sb.writeln('LOCATION:Lớp ${s.tenLop}');
      sb.writeln('RRULE:FREQ=WEEKLY');
      sb.writeln('BEGIN:VALARM');
      sb.writeln('ACTION:DISPLAY');
      sb.writeln('DESCRIPTION:Nhắc nhở ca dạy lớp ${s.tenLop}');
      sb.writeln('TRIGGER:-PT30M'); // Báo trước 30 phút
      sb.writeln('END:VALARM');
      sb.writeln('END:VEVENT');
    }

    sb.writeln('END:VCALENDAR');

    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/lich_day_tuition2025.ics';
      final file = File(filePath);
      await file.writeAsString(sb.toString());

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'File Lịch Dạy Học (.ics) dùng để nhập vào Google Calendar',
        subject: 'Lịch Dạy Học Tuition2025',
      );

      return filePath;
    } catch (e) {
      debugPrint('Lỗi tạo file .ics: $e');
      return null;
    }
  }
}
