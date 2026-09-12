import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import 'dart:developer' as developer;

class GoogleSheetsService {
  static final GoogleSheetsService instance = GoogleSheetsService._init();
  GoogleSheetsService._init();

  // Danh sách các bảng cần sao lưu
  static const List<String> _tables = [
    'truong',
    'cai_dat',
    'lop',
    'hoc_sinh',
    'lop_hoc_sinh',
    'lich_hoc',
    'diem_danh',
    'thanh_toan',
    'lich_hoc_chung',
    'lich_hoc_ca_nhan',
    'nhiem_vu',
    'nhiem_vu_hoc_sinh',
    'nhan_xet_thang',
    'danh_gia_buoi_hoc',
    'su_kien_hoc_tap',
    'quy_tac_diem',
  ];

  // Hàm trợ giúp gửi POST và tự theo dõi chuyển hướng (Google Apps Script Redirect 302/307)
  Future<http.Response> _postWithRedirect(
    String url,
    Map<String, String> headers,
    String body,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(url))
        ..headers.addAll(headers)
        ..body = body
        ..followRedirects =
            false; // Tắt tự động theo dõi chuyển hướng của client

      final streamedResponse = await client.send(request);
      var response = await http.Response.fromStream(streamedResponse);

      // Nếu gặp mã chuyển hướng 302, 303, 307 hoặc 308, ta gửi lại GET đến URL mới
      // vì Google Apps Script trả về URL chứa nội dung kết quả và chỉ nhận GET.
      int redirectCount = 0;
      while ((response.statusCode == 302 ||
              response.statusCode == 307 ||
              response.statusCode == 308 ||
              response.statusCode == 303) &&
          redirectCount < 5) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl == null) break;

        // Chuyển sang GET để nhận kết quả trả về từ Google Apps Script
        final nextRequest = http.Request('GET', Uri.parse(redirectUrl))
          ..followRedirects = false;

        final nextStreamedResponse = await client.send(nextRequest);
        response = await http.Response.fromStream(nextStreamedResponse);
        redirectCount++;
      }
      return response;
    } finally {
      client.close();
    }
  }

  // Sao lưu toàn bộ dữ liệu lên Google Sheets
  Future<bool> backupToGoogleSheets(String webAppUrl) async {
    if (webAppUrl.trim().isEmpty) {
      developer.log(
        'Google Sheets Sync: URL rỗng',
        name: 'GoogleSheetsService',
      );
      return false;
    }

    try {
      final db = await DBHelper.instance.database;
      final Map<String, List<Map<String, dynamic>>> dump = {};

      for (var tableName in _tables) {
        final List<Map<String, dynamic>> rows = await db.query(tableName);
        dump[tableName] = rows;
      }

      final payload = jsonEncode({'action': 'backup', 'data': dump});

      // Sử dụng hàm helper gửi POST giữ nguyên chuyển hướng
      final response = await _postWithRedirect(webAppUrl, {
        'Content-Type': 'application/json',
      }, payload).timeout(const Duration(seconds: 40));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['status'] == 'success') {
          developer.log(
            '✅ Google Sheets: Sao lưu thành công!',
            name: 'GoogleSheetsService',
          );
          return true;
        } else {
          developer.log(
            '❌ Google Sheets: Script báo lỗi: ${resData['message']}',
            name: 'GoogleSheetsService',
          );
        }
      } else {
        developer.log(
          '❌ Google Sheets: HTTP status ${response.statusCode}',
          name: 'GoogleSheetsService',
        );
      }
      return false;
    } catch (e) {
      developer.log(
        '❌ Google Sheets Sync Error: Lỗi sao lưu: $e',
        name: 'GoogleSheetsService',
      );
      return false;
    }
  }

  // Khôi phục toàn bộ dữ liệu từ Google Sheets
  Future<bool> restoreFromGoogleSheets(String webAppUrl) async {
    if (webAppUrl.trim().isEmpty) {
      developer.log(
        'Google Sheets Sync: URL rỗng',
        name: 'GoogleSheetsService',
      );
      return false;
    }

    try {
      final uri = Uri.parse(
        webAppUrl,
      ).replace(queryParameters: {'action': 'restore'});
      final response = await http.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final resData = jsonDecode(response.body);
        if (resData['status'] == 'success' && resData['data'] != null) {
          final Map<String, dynamic> data = resData['data'];
          final db = await DBHelper.instance.database;

          // Thực hiện nạp dữ liệu bằng Transaction
          await db.transaction((txn) async {
            final batch = txn.batch();

            for (var tableName in _tables) {
              if (data.containsKey(tableName)) {
                // Xóa bảng cũ trước khi khôi phục
                batch.delete(tableName);

                final List<dynamic> rows = data[tableName];
                for (var row in rows) {
                  if (row is Map<String, dynamic>) {
                    batch.insert(
                      tableName,
                      row,
                      conflictAlgorithm: ConflictAlgorithm.replace,
                    );
                  }
                }
              }
            }
            await batch.commit(noResult: true);
          });

          developer.log(
            '✅ Google Sheets: Khôi phục dữ liệu thành công!',
            name: 'GoogleSheetsService',
          );
          return true;
        } else {
          developer.log(
            '❌ Google Sheets: Script báo lỗi hoặc không có dữ liệu: ${resData['message']}',
            name: 'GoogleSheetsService',
          );
        }
      } else {
        developer.log(
          '❌ Google Sheets: HTTP status ${response.statusCode}',
          name: 'GoogleSheetsService',
        );
      }
      return false;
    } catch (e) {
      developer.log(
        '❌ Google Sheets Sync Error: Lỗi khôi phục: $e',
        name: 'GoogleSheetsService',
      );
      return false;
    }
  }
}
