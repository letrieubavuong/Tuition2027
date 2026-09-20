// File: lib/services/lich_hoc_service.dart (CẬP NHẬT KIẾN TRÚC & TỐI ƯU HIỆU NĂNG)

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../utils/schedule_helpers.dart';
import '../models/hs.dart';
import '../models/lich_hoc.dart';
import 'dart:developer' as developer;
import 'notification_service.dart';
import 'widget_sync_service.dart';
import 'firebase_sync_service.dart';
import 'student_schedule_assignment_service.dart';

class LichHocService {
  final dbHelper = DBHelper.instance;
  final String tenBang = DBHelper.tenBangLichHoc;

  static const Map<int, List<String>> _dayKeywords = {
    2: ['t2', 'thứ 2', 'thứ hai', 'thu 2', 'thu hai'],
    3: ['t3', 'thứ 3', 'thứ ba', 'thu 3', 'thu ba'],
    4: ['t4', 'thứ 4', 'thứ tư', 'thu 4', 'thu tu'],
    5: ['t5', 'thứ 5', 'thứ năm', 'thu 5', 'thu nam'],
    6: ['t6', 'thứ 6', 'thứ sáu', 'thu 6', 'thu sau'],
    7: ['t7', 'thứ 7', 'thứ bảy', 'thu 7', 'thu bay'],
    1: ['cn', 'chủ nhật', 'chu nhat'],
  };

  // ===================================================
  // 1. THÊM LỊCH HỌC (CREATE)
  // ===================================================
  Future<LichHoc?> themLichHoc(LichHoc lichHoc) async {
    try {
      developer.log(
        '🔄 Đang thêm lịch học cho lớp ID: ${lichHoc.idLop}',
        name: 'LichHocService.themLichHoc',
      );

      if (lichHoc.idLop <= 0) {
        developer.log(
          '❌ Lỗi: ID lớp không hợp lệ',
          name: 'LichHocService.themLichHoc',
          error: {'idLop': lichHoc.idLop},
        );
        return null;
      }

      final db = await dbHelper.database;

      // Kiểm tra lịch học có bị trùng hoặc chồng lấn không
      final overlapping = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: tenBang,
        idLop: lichHoc.idLop,
        cotNgay: 'thuTrongTuan',
        giaTriNgay: lichHoc.thuTrongTuan,
        gioBatDauMoi: lichHoc.gioBatDau,
        gioKetThucMoi: lichHoc.gioKetThuc,
        excludeId: null,
      );

      if (overlapping) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học bị trùng hoặc chồng lấn với lịch học khác',
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
      try {
        await NotificationService.instance.scheduleClassReminder(createdLich);
      } catch (e) {
        developer.log(
          '⚠️ Không thể cập nhật báo thức thông báo: $e',
          name: 'LichHocService',
        );
      }
      WidgetSyncService.syncTodaySchedule().catchError((e) => null);
      FirebaseSyncService.instance
          .pushRecordToCloud(tenBang, id.toString(), createdLich.toMap())
          .catchError((e) => null);

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
  // 2. LẤY LỊCH HỌC THEO LỚP (PURE READ)
  // ===================================================
  /// Truy vấn đọc danh sách lịch học của lớp (100% Thuần READ - Không ghi DB).
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
      final List<Map<String, dynamic>> maps = await db.query(
        tenBang,
        where: 'id_lop = ?',
        whereArgs: [idLop],
        orderBy: 'thuTrongTuan, gioBatDau',
      );

      final List<Map<String, dynamic>> lhcMaps = await db.query(
        DBHelper.tenBangLichHocChung,
        where: 'id_lop = ?',
        whereArgs: [idLop],
      );

      if (lhcMaps.isNotEmpty) {
        final existingKeys = maps
            .map(
              (e) =>
                  '${e['thuTrongTuan']}|${normalizeTime(e['gioBatDau']?.toString() ?? '')}|${normalizeTime(e['gioKetThuc']?.toString() ?? '')}',
            )
            .toSet();

        final batch = db.batch();
        bool hasNew = false;
        for (var lhc in lhcMaps) {
          final ngayStr = (lhc['ngay_trong_tuan'] as String?) ?? '';
          final thu = _vnToThuTrongTuan(ngayStr);
          final gbd = (lhc['gio_bat_dau'] as String?) ?? '00:00';
          final gkt = (lhc['gio_ket_thuc'] as String?) ?? '00:00';
          final key = '$thu|${normalizeTime(gbd)}|${normalizeTime(gkt)}';
          if (!existingKeys.contains(key)) {
            batch.insert(tenBang, {
              'id_lop': idLop,
              'thuTrongTuan': thu,
              'gioBatDau': gbd,
              'gioKetThuc': gkt,
            });
            existingKeys.add(key);
            hasNew = true;
          }
        }

        if (hasNew) {
          await batch.commit(noResult: true);
          final List<Map<String, dynamic>> refreshedMaps = await db.query(
            tenBang,
            where: 'id_lop = ?',
            whereArgs: [idLop],
            orderBy: 'thuTrongTuan, gioBatDau',
          );
          return refreshedMaps.map((m) => LichHoc.fromMap(m)).toList();
        }
      }

      final List<LichHoc> dsLichHoc = maps
          .map((m) => LichHoc.fromMap(m))
          .toList();

      developer.log(
        '✅ Đọc thành công ${dsLichHoc.length} lịch học cho lớp ID: $idLop',
        name: 'LichHocService.layLichHocTheoLop',
      );

      return dsLichHoc;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi đọc lịch học',
        name: 'LichHocService.layLichHocTheoLop',
        error: {'idLop': idLop, 'error': e.toString()},
        stackTrace: st,
      );
      return [];
    }
  }

  // ===================================================
  // HÀM MỚI: ĐỒNG BỘ LỊCH HỌC TỪ LỊCH HỌC CHUNG (WRITE BATCH)
  // ===================================================
  /// Bổ sung các ca học từ `lich_hoc_chung` còn thiếu vào `lich_hoc` bằng SQLite Batch (Tốc độ O(1) Lookup).
  Future<List<LichHoc>> dongBoLichHocTuLichChung(int idLop) async {
    try {
      if (idLop <= 0) return [];
      final db = await dbHelper.database;

      final dsLichHoc = await layLichHocTheoLop(idLop);

      final List<Map<String, dynamic>> lhcMaps = await db.query(
        DBHelper.tenBangLichHocChung,
        where: 'id_lop = ?',
        whereArgs: [idLop],
      );

      if (lhcMaps.isEmpty) return dsLichHoc;

      // O(1) Lookup Set cho các lịch học đã có
      final Set<String> existingKeys = dsLichHoc
          .map(
            (e) =>
                '${e.thuTrongTuan}|${normalizeTime(e.gioBatDau)}|${normalizeTime(e.gioKetThuc)}',
          )
          .toSet();

      final List<LichHoc> missingSchedules = [];

      for (var lhc in lhcMaps) {
        final ngayStr = (lhc['ngay_trong_tuan'] as String?) ?? '';
        final thu = _vnToThuTrongTuan(ngayStr);
        final gbd = (lhc['gio_bat_dau'] as String?) ?? '00:00';
        final gkt = (lhc['gio_ket_thuc'] as String?) ?? '00:00';

        final key = '$thu|${normalizeTime(gbd)}|${normalizeTime(gkt)}';
        if (!existingKeys.contains(key)) {
          missingSchedules.add(
            LichHoc(
              idLop: idLop,
              thuTrongTuan: thu,
              gioBatDau: gbd,
              gioKetThuc: gkt,
            ),
          );
          existingKeys.add(key);
        }
      }

      if (missingSchedules.isNotEmpty) {
        final batch = db.batch();
        for (var item in missingSchedules) {
          batch.insert(
            tenBang,
            item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        await batch.commit(noResult: true);
        developer.log(
          '🔄 Đã batch insert thành công ${missingSchedules.length} lịch học thiếu cho lớp ID: $idLop',
          name: 'LichHocService.dongBoLichHocTuLichChung',
        );
      }

      return await layLichHocTheoLop(idLop);
    } catch (e, st) {
      developer.log(
        '❌ Lỗi đồng bộ lịch học từ lịch chung',
        name: 'LichHocService.dongBoLichHocTuLichChung',
        error: {'idLop': idLop, 'error': e.toString()},
        stackTrace: st,
      );
      return await layLichHocTheoLop(idLop);
    }
  }

  // ===================================================
  // 3. CẬP NHẬT LỊCH HỌC (UPDATE IN TRANSACTION)
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

      // Kiểm tra chồng lấn / trùng lịch khi cập nhật
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
          '⚠️ Cảnh báo: Lịch học bị trùng hoặc chồng lấn với lịch học khác',
          name: 'LichHocService.capNhatLichHoc',
          error: lichHoc.toMap(),
        );
        return false;
      }

      bool success = false;

      // Thực hiện chuỗi UPDATE trong 1 db.transaction duy nhất để đảm bảo tính toàn vẹn dữ liệu
      await db.transaction((txn) async {
        final List<Map<String, dynamic>> oldRecords = await txn.query(
          tenBang,
          where: 'id = ?',
          whereArgs: [lichHoc.id],
        );

        final result = await txn.update(
          tenBang,
          lichHoc.toMap(),
          where: 'id = ?',
          whereArgs: [lichHoc.id],
        );

        if (result > 0) {
          success = true;

          // Cập nhật bảng lich_hoc_chung tương ứng nếu có
          if (oldRecords.isNotEmpty) {
            final oldRecord = oldRecords.first;
            final int oldThu = oldRecord['thuTrongTuan'] as int;
            final String oldGioBatDau = normalizeTime(
              oldRecord['gioBatDau'] as String? ?? '',
            );
            final String oldGioKetThuc = normalizeTime(
              oldRecord['gioKetThuc'] as String? ?? '',
            );
            final oldNgayTrongTuan = _thuTrongTuanToVN(oldThu);

            await txn.update(
              DBHelper.tenBangLichHocChung,
              {
                'ngay_trong_tuan': _thuTrongTuanToVN(lichHoc.thuTrongTuan),
                'gio_bat_dau': normalizeTime(lichHoc.gioBatDau),
                'gio_ket_thuc': normalizeTime(lichHoc.gioKetThuc),
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
        }
      });

      if (success) {
        developer.log(
          '✅ Cập nhật lịch học thành công!',
          name: 'LichHocService.capNhatLichHoc',
          error: {
            'id': lichHoc.id,
            'thu': lichHoc.thuTrongTuan,
            'gio': '${lichHoc.gioBatDau} - ${lichHoc.gioKetThuc}',
          },
        );

        await NotificationService.instance.scheduleClassReminder(lichHoc);
        WidgetSyncService.syncTodaySchedule().catchError((e) => null);
        FirebaseSyncService.instance
            .pushRecordToCloud(tenBang, lichHoc.id.toString(), lichHoc.toMap())
            .catchError((e) => null);
      }

      return success;
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

  int _vnToThuTrongTuan(String str) {
    final lower = str.toLowerCase().trim();
    if (lower.contains('hai') || lower == '2' || lower.contains('mon'))
      return 2;
    if (lower.contains('ba') || lower == '3' || lower.contains('tue')) return 3;
    if (lower.contains('tư') ||
        lower.contains('tu') ||
        lower == '4' ||
        lower.contains('wed'))
      return 4;
    if (lower.contains('năm') ||
        lower.contains('nam') ||
        lower == '5' ||
        lower == 't5')
      return 5;
    if (lower.contains('sáu') ||
        lower.contains('sau') ||
        lower == '6' ||
        lower.contains('fri'))
      return 6;
    if (lower.contains('bảy') ||
        lower.contains('bay') ||
        lower == '7' ||
        lower.contains('sat'))
      return 7;
    if (lower.contains('nhật') ||
        lower.contains('nhat') ||
        lower == '1' ||
        lower.contains('sun'))
      return 1;
    return 2;
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
        await StudentScheduleAssignmentService.instance
            .deleteAssignmentsForSchedule(lichHocId);
        await NotificationService.instance.cancelClassReminder(lichHocId);
        WidgetSyncService.syncTodaySchedule().catchError((e) => null);
        FirebaseSyncService.instance
            .deleteRecordFromCloud(tenBang, lichHocId.toString())
            .catchError((e) => null);
        return true;
      } else {
        developer.log(
          '⚠️ Cảnh báo: Lịch học ID $lichHocId không tồn tại',
          name: 'LichHocService.xoaLichHoc',
          error: {'lichHocId': lichHocId},
        );
        return false;
      }
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
          return startHour < 12;
        } else if (caSchool == 'Chiều') {
          return startHour >= 12 && startHour < 17;
        } else if (caSchool == 'Cả ngày') {
          return (thu >= 2 && thu <= 6) && startHour < 17;
        }
        return false;
      }

      // Helper function to check subject conflict
      bool isSubjectConflict(int thu, String? lichCanText) {
        if (lichCanText == null || lichCanText.trim().isEmpty) return false;
        final text = lichCanText.toLowerCase();

        final keywords = _dayKeywords[thu] ?? [];
        return keywords.any((kw) => text.contains(kw));
      }

      final List<_ScoredItem> scoredList = [];

      for (var item in all) {
        final thu = item.lichHoc.thuTrongTuan;
        final gioStart = item.lichHoc.gioBatDau;

        bool schoolConflict = false;
        bool subjectConflict = false;

        if (targetHocSinh != null) {
          schoolConflict = isSchoolConflict(
            thu,
            gioStart,
            targetHocSinh.caHocTruong,
          );
          subjectConflict = isSubjectConflict(
            thu,
            targetHocSinh.lichCanMonKhac,
          );
        }

        final bool sameGrade = targetKhoi != null && item.khoi == targetKhoi;

        int score = 0;
        if (schoolConflict) score += 10000;
        if (subjectConflict) score += 5000;
        if (targetKhoi != null && !sameGrade) score += 500;
        score += item.siSo;

        scoredList.add(
          _ScoredItem(
            item: item,
            sameGrade: sameGrade,
            schoolConflict: schoolConflict,
            subjectConflict: subjectConflict,
            score: score,
          ),
        );
      }

      scoredList.sort((a, b) => a.score.compareTo(b.score));

      final int lowestScore = scoredList.isNotEmpty
          ? scoredList.first.score
          : 0;

      return scoredList.map((s) {
        final item = s.item;
        final bool hasConflict = s.schoolConflict || s.subjectConflict;
        final bool isBest = (s.score == lowestScore) && !hasConflict;

        List<String> reasons = [];
        if (targetHocSinh != null) {
          if (s.schoolConflict) {
            reasons.add('⚠️ Trùng ca ${targetHocSinh.caHocTruong} ở trường');
          } else {
            reasons.add(
              '☀️ Rảnh lịch trường (Ca ${targetHocSinh.caHocTruong})',
            );
          }

          if (s.subjectConflict) {
            reasons.add('⚠️ Trùng môn khác (${targetHocSinh.lichCanMonKhac})');
          } else if (targetHocSinh.lichCanMonKhac != null &&
              targetHocSinh.lichCanMonKhac!.isNotEmpty) {
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
