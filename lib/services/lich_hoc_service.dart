// File: lib/services/lich_hoc_service.dart (ĐÃ CẬP NHẬT VỚI TRY/CATCH VÀ LOGGING)

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../utils/schedule_helpers.dart'; // <-- IMPORT HELPER
import '../models/hs.dart';
import '../models/lich_hoc.dart';
import 'dart:developer' as developer;
import 'notification_service.dart';
import 'widget_sync_service.dart';

class LichHocService {
  final dbHelper = DBHelper.instance;
  final String tenBang = DBHelper.tenBangLichHoc;

  // ===================================================
  // 1. THÊM LỊCH HỌC (CREATE)
  // ===================================================
  Future<LichHoc?> themLichHoc(LichHoc lichHoc) async {
    try {
      developer.log(
        '🔄 Đang thêm lịch học cho lớp ID: ${lichHoc.idLop}',
        name: 'LichHocService.themLichHoc',
      );

      // Validate input
      if (lichHoc.idLop <= 0) {
        developer.log(
          '❌ Lỗi: ID lớp không hợp lệ',
          name: 'LichHocService.themLichHoc',
          error: {'idLop': lichHoc.idLop},
        );
        return null;
      }

      final db = await dbHelper.database;

      // kiểm tra trùng
      final exists = await db.query(
        tenBang,
        where:
            'id_lop = ? AND thuTrongTuan = ? AND gioBatDau = ? AND gioKetThuc = ?',
        whereArgs: [
          lichHoc.idLop,
          lichHoc.thuTrongTuan,
          lichHoc.gioBatDau,
          lichHoc.gioKetThuc,
        ],
      );
      if (exists.isNotEmpty) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học này đã tồn tại',
          name: 'LichHocService.themLichHoc',
          error: lichHoc.toMap(),
        );
        return null;
      }

      // Kiểm tra lịch học có chồng lấn không
      final overlapping = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: tenBang,
        idLop: lichHoc.idLop,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: lichHoc.thuTrongTuan,
        gioBatDauMoi: lichHoc.gioBatDau,
        gioKetThucMoi: lichHoc.gioKetThuc,
        excludeId: null, // không có id khi thêm mới
      );

      if (overlapping) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học bị chồng lấn với lịch học khác',
          name: 'LichHocService.themLichHoc',
          error: lichHoc.toMap(),
        );
        return null;
      }

      final id = await db.insert(
        tenBang,
        lichHoc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      developer.log(
        '✅ Thêm lịch học thành công!',
        name: 'LichHocService.themLichHoc',
        error: {
          'id': id,
          'idLop': lichHoc.idLop,
          'thu': lichHoc.thuTrongTuan,
          'gio': '${lichHoc.gioBatDau} - ${lichHoc.gioKetThuc}',
        },
      );

      final createdLich = lichHoc.copyWith(id: id);
      await NotificationService.instance.scheduleClassReminder(createdLich);
      WidgetSyncService.syncTodaySchedule().catchError((e) => null);

      return createdLich;
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi thêm lịch học',
        name: 'LichHocService.themLichHoc',
        error: {'error': e.toString(), 'lichHoc': lichHoc.toMap()},
        stackTrace: st,
      );
      return null;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi thêm lịch học',
        name: 'LichHocService.themLichHoc',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ===================================================
  // 2. LẤY LỊCH HỌC THEO LỚP (READ)
  // ===================================================
  Future<List<LichHoc>> layLichHocTheoLop(int idLop) async {
    try {
      if (idLop <= 0) {
        developer.log(
          '❌ Lỗi: ID lớp không hợp lệ',
          name: 'LichHocService.layLichHocTheoLop',
          error: {'idLop': idLop},
        );
        return [];
      }

      final db = await dbHelper.database;
      // <-- SỬA: dùng id_lop (khớp schema)
      final List<Map<String, dynamic>> maps = await db.query(
        tenBang,
        where: 'id_lop = ?',
        whereArgs: [idLop],
        orderBy: 'thuTrongTuan, gioBatDau',
      );

      developer.log(
        '✅ Đọc thành công ${maps.length} lịch học từ lớp ID: $idLop',
        name: 'LichHocService.layLichHocTheoLop',
      );

      return List.generate(maps.length, (i) {
        return LichHoc.fromMap(maps[i]);
      });
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi đọc lịch học',
        name: 'LichHocService.layLichHocTheoLop',
        error: {'idLop': idLop, 'error': e.toString()},
        stackTrace: st,
      );
      return [];
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi đọc lịch học',
        name: 'LichHocService.layLichHocTheoLop',
        error: {'idLop': idLop, 'error': e.toString()},
        stackTrace: st,
      );
      return [];
    }
  }

  // ===================================================
  // 3. CẬP NHẬT LỊCH HỌC (UPDATE)
  // ===================================================
  Future<bool> capNhatLichHoc(LichHoc lichHoc) async {
    try {
      developer.log(
        '🔄 Đang cập nhật lịch học ID: ${lichHoc.id}',
        name: 'LichHocService.capNhatLichHoc',
      );

      if (lichHoc.id == null || lichHoc.id! <= 0) {
        developer.log(
          '❌ Lỗi: ID lịch học không hợp lệ',
          name: 'LichHocService.capNhatLichHoc',
          error: {'id': lichHoc.id},
        );
        return false;
      }

      final db = await dbHelper.database;

      // kiểm tra trùng với bản ghi khác
      final exists = await db.query(
        tenBang,
        where:
            'id_lop = ? AND thuTrongTuan = ? AND gioBatDau = ? AND gioKetThuc = ? AND id != ?',
        whereArgs: [
          lichHoc.idLop,
          lichHoc.thuTrongTuan,
          lichHoc.gioBatDau,
          lichHoc.gioKetThuc,
          lichHoc.id,
        ],
      );
      if (exists.isNotEmpty) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học bị trùng với lịch học khác',
          name: 'LichHocService.capNhatLichHoc',
          error: lichHoc.toMap(),
        );
        return false;
      }

      // Kiểm tra chồng lấn khi cập nhật
      final overlapping = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: tenBang,
        idLop: lichHoc.idLop,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: lichHoc.thuTrongTuan,
        gioBatDauMoi: lichHoc.gioBatDau,
        gioKetThucMoi: lichHoc.gioKetThuc,
        excludeId: lichHoc.id,
      );
      if (overlapping) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học bị chồng lấn với lịch học khác',
          name: 'LichHocService.capNhatLichHoc',
          error: lichHoc.toMap(),
        );
        return false;
      }
      // Lấy thông tin lịch cũ để tìm lịch học chung tương ứng trước khi cập nhật
      final List<Map<String, dynamic>> oldRecords = await db.query(
        tenBang,
        where: 'id = ?',
        whereArgs: [lichHoc.id],
      );

      final result = await db.update(
        tenBang,
        lichHoc.toMap(),
        where: 'id = ?',
        whereArgs: [lichHoc.id],
      );

      if (result > 0) {
        developer.log(
          '✅ Cập nhật lịch học thành công!',
          name: 'LichHocService.capNhatLichHoc',
          error: {
            'id': lichHoc.id,
            'thu': lichHoc.thuTrongTuan,
            'gio': '${lichHoc.gioBatDau} - ${lichHoc.gioKetThuc}',
          },
        );

        // ĐỒNG BỘ: Cập nhật thông tin trong bảng lich_hoc_chung tương ứng nếu có
        if (oldRecords.isNotEmpty) {
          final oldRecord = oldRecords.first;
          final int oldThu = oldRecord['thuTrongTuan'] as int;
          final String oldGioBatDau = (oldRecord['gioBatDau'] as String)
              .substring(0, 5);
          final String oldGioKetThuc = (oldRecord['gioKetThuc'] as String)
              .substring(0, 5);

          // Chuyển đổi thứ của lịch cũ sang tiếng Việt
          final oldNgayTrongTuan = _thuTrongTuanToVN(oldThu);

          // Cập nhật lich_hoc_chung tương ứng
          await db.update(
            DBHelper.tenBangLichHocChung,
            {
              'ngay_trong_tuan': _thuTrongTuanToVN(lichHoc.thuTrongTuan),
              'gio_bat_dau': lichHoc.gioBatDau.substring(0, 5),
              'gio_ket_thuc': lichHoc.gioKetThuc.substring(0, 5),
            },
            where:
                'id_lop = ? AND ngay_trong_tuan = ? AND gio_bat_dau = ? AND gio_ket_thuc = ?',
            whereArgs: [
              lichHoc.idLop,
              oldNgayTrongTuan,
              oldGioBatDau,
              oldGioKetThuc,
            ],
          );
        }

        await NotificationService.instance.scheduleClassReminder(lichHoc);
        WidgetSyncService.syncTodaySchedule().catchError((e) => null);
      }

      return result > 0;
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi cập nhật lịch học',
        name: 'LichHocService.capNhatLichHoc',
        error: {'error': e.toString(), 'lichHoc': lichHoc.toMap()},
        stackTrace: st,
      );
      return false;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi cập nhật lịch học',
        name: 'LichHocService.capNhatLichHoc',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  // Helper method to translate weekday to Vietnamese
  String _thuTrongTuanToVN(int thu) {
    switch (thu) {
      case 2:
        return 'Thứ Hai';
      case 3:
        return 'Thứ Ba';
      case 4:
        return 'Thứ Tư';
      case 5:
        return 'Thứ Năm';
      case 6:
        return 'Thứ Sáu';
      case 7:
        return 'Thứ Bảy';
      case 1:
        return 'Chủ Nhật';
      default:
        return 'Không rõ';
    }
  }

  // ===================================================
  // 4. XÓA LỊCH HỌC (DELETE)
  // ===================================================
  Future<bool> xoaLichHoc(int lichHocId) async {
    try {
      developer.log(
        '🔄 Đang xóa lịch học ID: $lichHocId',
        name: 'LichHocService.xoaLichHoc',
      );

      if (lichHocId <= 0) {
        developer.log(
          '❌ Lỗi: ID lịch học không hợp lệ',
          name: 'LichHocService.xoaLichHoc',
          error: {'lichHocId': lichHocId},
        );
        return false;
      }

      final db = await dbHelper.database;

      // Kiểm tra lịch học có tồn tại không
      final existing = await db.query(
        tenBang,
        where: 'id = ?',
        whereArgs: [lichHocId],
      );

      if (existing.isEmpty) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học ID $lichHocId không tồn tại',
          name: 'LichHocService.xoaLichHoc',
          error: {'lichHocId': lichHocId},
        );
        return false;
      }

      final result = await db.delete(
        tenBang,
        where: 'id = ?',
        whereArgs: [lichHocId],
      );

      if (result > 0) {
        developer.log(
          '✅ Xóa lịch học thành công! ID: $lichHocId',
          name: 'LichHocService.xoaLichHoc',
        );
        await NotificationService.instance.cancelClassReminder(lichHocId);
        WidgetSyncService.syncTodaySchedule().catchError((e) => null);
      }

      return result > 0;
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi xóa lịch học',
        name: 'LichHocService.xoaLichHoc',
        error: {'lichHocId': lichHocId, 'error': e.toString()},
        stackTrace: st,
      );
      return false;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi xóa lịch học',
        name: 'LichHocService.xoaLichHoc',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  // ===================================================
  // 5. LẤY TẤT CẢ LỊCH HỌC KÈM TÊN LỚP (READ ALL FOR SCHEDULE VIEW)
  // ===================================================
  Future<List<LichHocCoTenLop>> layTatCaLichHocCoTenLop() async {
    try {
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT 
          lh.*, 
          l.ten as ten_lop, 
          l.khoi as khoi_lop,
          COUNT(lhs.id_hoc_sinh) as si_so
        FROM ${DBHelper.tenBangLichHoc} lh
        JOIN ${DBHelper.tenBangLop} l ON lh.id_lop = l.id
        LEFT JOIN ${DBHelper.tenBangLopHS} lhs ON l.id = lhs.id_lop 
          AND (lhs.ngay_nghi_hoc IS NULL OR lhs.ngay_nghi_hoc > date('now', 'localtime') OR lhs.ngay_hoc_lai_sau_nghi <= date('now', 'localtime'))
        GROUP BY lh.id
        ORDER BY lh.thuTrongTuan ASC, lh.gioBatDau ASC
      ''');

      return maps.map((map) {
        final lich = LichHoc.fromMap(map);
        return LichHocCoTenLop(
          lichHoc: lich,
          tenLop: map['ten_lop'] as String? ?? 'Lớp ${lich.idLop}',
          khoi: map['khoi_lop'] as int? ?? 0,
          siSo: map['si_so'] as int? ?? 0,
        );
      }).toList();
    } catch (e, st) {
      developer.log('Lỗi layTatCaLichHocCoTenLop', error: e, stackTrace: st);
      return [];
    }
  }

  // ===================================================
  // 6. THUẬT TOÁN GỢI Ý CA HỌC TỐI ƯU CHO HỌC SINH CẤN LỊCH
  // ===================================================
  // ===================================================
  // 6. THUẬT TOÁN GỢI Ý CA HỌC TỐI ƯU CHO HỌC SINH CẤN LỊCH
  // ===================================================
  Future<List<GoiYCaHoc>> layGoiYCaHocPhuHop({
    int? targetKhoi,
    HS? targetHocSinh,
  }) async {
    try {
      final all = await layTatCaLichHocCoTenLop();
      if (all.isEmpty) return [];

      // Helper function to check school conflict
      bool isSchoolConflict(int thu, String gioStart, String caSchool) {
        final startHour = int.tryParse(gioStart.split(':').first) ?? 17;
        if (caSchool == 'Sáng') {
          // Trường học sáng (07:00 - 12:00) -> Ca dạy < 12:00 bị trùng
          return startHour < 12;
        } else if (caSchool == 'Chiều') {
          // Trường học chiều (12:00 - 17:15) -> Ca dạy từ 12:00 đến 17:15 bị trùng
          return startHour >= 12 && startHour < 17;
        } else if (caSchool == 'Cả ngày') {
          // Học cả ngày từ T2 đến T6 trước 17:15 bị trùng
          return (thu >= 2 && thu <= 6) && startHour < 17;
        }
        return false;
      }

      // Helper function to check subject conflict
      bool isSubjectConflict(int thu, String? lichCanText) {
        if (lichCanText == null || lichCanText.trim().isEmpty) return false;
        final text = lichCanText.toLowerCase();

        final Map<int, List<String>> dayKeywords = {
          2: ['t2', 'thứ 2', 'thứ hai', 'thu 2', 'thu hai'],
          3: ['t3', 'thứ 3', 'thứ ba', 'thu 3', 'thu ba'],
          4: ['t4', 'thứ 4', 'thứ tư', 'thu 4', 'thu tu'],
          5: ['t5', 'thứ 5', 'thứ năm', 'thu 5', 'thu nam'],
          6: ['t6', 'thứ 6', 'thứ sáu', 'thu 6', 'thu sau'],
          7: ['t7', 'thứ 7', 'thứ bảy', 'thu 7', 'thu bay'],
          1: ['cn', 'chủ nhật', 'chu nhat'],
        };

        final keywords = dayKeywords[thu] ?? [];
        return keywords.any((kw) => text.contains(kw));
      }

      // Build recommendation items with scoring
      final List<_ScoredItem> scoredList = [];

      for (var item in all) {
        final thu = item.lichHoc.thuTrongTuan;
        final gioStart = item.lichHoc.gioBatDau;

        bool schoolConflict = false;
        bool subjectConflict = false;

        if (targetHocSinh != null) {
          schoolConflict = isSchoolConflict(thu, gioStart, targetHocSinh.caHocTruong);
          subjectConflict = isSubjectConflict(thu, targetHocSinh.lichCanMonKhac);
        }

        final bool sameGrade = targetKhoi != null && item.khoi == targetKhoi;

        int score = 0;
        if (schoolConflict) score += 10000;
        if (subjectConflict) score += 5000;
        if (targetKhoi != null && !sameGrade) score += 500;
        score += item.siSo;

        scoredList.add(_ScoredItem(
          item: item,
          sameGrade: sameGrade,
          schoolConflict: schoolConflict,
          subjectConflict: subjectConflict,
          score: score,
        ));
      }

      scoredList.sort((a, b) => a.score.compareTo(b.score));

      final int lowestScore = scoredList.isNotEmpty ? scoredList.first.score : 0;

      return scoredList.map((s) {
        final item = s.item;
        final bool hasConflict = s.schoolConflict || s.subjectConflict;
        final bool isBest = (s.score == lowestScore) && !hasConflict;

        List<String> reasons = [];
        if (targetHocSinh != null) {
          if (s.schoolConflict) {
            reasons.add('⚠️ Trùng ca ${targetHocSinh.caHocTruong} ở trường');
          } else {
            reasons.add('☀️ Rảnh lịch trường (Ca ${targetHocSinh.caHocTruong})');
          }

          if (s.subjectConflict) {
            reasons.add('⚠️ Trùng môn khác (${targetHocSinh.lichCanMonKhac})');
          } else if (targetHocSinh.lichCanMonKhac != null && targetHocSinh.lichCanMonKhac!.isNotEmpty) {
            reasons.add('✅ Không vướng môn khác');
          }
        }

        reasons.add('Sĩ số: ${item.siSo} học sinh');
        if (s.sameGrade) {
          reasons.add('Đúng Khối ${item.khoi}');
        }
        if (isBest) {
          reasons.add('🌟 GỢI Ý TỐT NHẤT');
        }

        return GoiYCaHoc(
          item: item,
          isSameGrade: s.sameGrade,
          isBestChoice: isBest,
          hasConflict: hasConflict,
          reason: reasons.join(' • '),
        );
      }).toList();
    } catch (e, st) {
      developer.log('Lỗi layGoiYCaHocPhuHop', error: e, stackTrace: st);
      return [];
    }
  }
}

class _ScoredItem {
  final LichHocCoTenLop item;
  final bool sameGrade;
  final bool schoolConflict;
  final bool subjectConflict;
  final int score;

  _ScoredItem({
    required this.item,
    required this.sameGrade,
    required this.schoolConflict,
    required this.subjectConflict,
    required this.score,
  });
}

class LichHocCoTenLop {
  final LichHoc lichHoc;
  final String tenLop;
  final int khoi;
  final int siSo;

  LichHocCoTenLop({
    required this.lichHoc,
    required this.tenLop,
    required this.khoi,
    required this.siSo,
  });
}

class GoiYCaHoc {
  final LichHocCoTenLop item;
  final bool isSameGrade;
  final bool isBestChoice;
  final bool hasConflict;
  final String reason;

  GoiYCaHoc({
    required this.item,
    required this.isSameGrade,
    required this.isBestChoice,
    this.hasConflict = false,
    required this.reason,
  });
}
