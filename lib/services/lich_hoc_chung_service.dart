// File: lib/services/lich_hoc_chung_service.dart

import 'package:sqflite/sqflite.dart';
import '../utils/db.dart';
import '../utils/schedule_helpers.dart';
import '../models/lich_hoc_chung.dart';
import 'dart:developer' as developer;
import '../models/lich_hoc_ca_nhan.dart';
import 'firebase_sync_service.dart';

class LichHocChungService {
  final String tenBangLHC = DBHelper.tenBangLichHocChung;
  final String tenBangLHCN = DBHelper.tenBangLichHocCaNhan;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  // ===================================================
  // 1. THÊM LỊCH HỌC CHUNG (CREATE)
  // ===================================================
  Future<LichHocChung?> themLichHocChung(LichHocChung lichHoc) async {
    try {
      developer.log(
        '🔄 Đang thêm lịch học chung cho lớp ID: ${lichHoc.idLop}',
        name: 'LichHocChungService.themLichHocChung',
      );

      if (lichHoc.idLop <= 0) {
        developer.log(
          '❌ Lỗi: ID lớp không hợp lệ',
          name: 'LichHocChungService.themLichHocChung',
          error: {'idLop': lichHoc.idLop},
        );
        return null;
      }

      final db = await _database;

      // Kiểm tra trùng lịch
      final existing = await db.query(
        tenBangLHC,
        where:
            'id_lop = ? AND ngay_trong_tuan = ? AND gio_bat_dau = ? AND gio_ket_thuc = ?',
        whereArgs: [
          lichHoc.idLop,
          lichHoc.ngayTrongTuan,
          lichHoc.gioBatDau,
          lichHoc.gioKetThuc,
        ],
      );

      if (existing.isNotEmpty) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học chung này đã tồn tại',
          name: 'LichHocChungService.themLichHocChung',
          error: lichHoc.toMap(),
        );
        return null;
      }

      // Kiểm tra chồng lấn
      final overlapping = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: tenBangLHC,
        idLop: lichHoc.idLop,
        cotNgay: 'ngay_trong_tuan',
        giaTriNgay: lichHoc.ngayTrongTuan,
        gioBatDauMoi: lichHoc.gioBatDau,
        gioKetThucMoi: lichHoc.gioKetThuc,
        excludeId: null,
      );

      if (overlapping) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học bị chồng lấn với lịch học khác',
          name: 'LichHocChungService.themLichHocChung',
          error: lichHoc.toMap(),
        );
        return null;
      }

      final id = await db.insert(
        tenBangLHC,
        lichHoc.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      developer.log(
        '✅ Thêm lịch học chung thành công!',
        name: 'LichHocChungService.themLichHocChung',
        error: {
          'id': id,
          'idLop': lichHoc.idLop,
          'ngay': lichHoc.ngayTrongTuan,
          'gio': '${lichHoc.gioBatDau} - ${lichHoc.gioKetThuc}',
        },
      );

      final createdLich = lichHoc.copyWith(id: id);
      FirebaseSyncService.instance
          .pushRecordToCloud(tenBangLHC, id.toString(), createdLich.toMap())
          .catchError((e) => null);

      return createdLich;
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi thêm lịch học chung',
        name: 'LichHocChungService.themLichHocChung',
        error: e,
        stackTrace: st,
      );
      return null;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi thêm lịch học chung',
        name: 'LichHocChungService.themLichHocChung',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // ===================================================
  // 2. LẤY LỊCH HỌC CHUNG THEO LỚP (READ)
  // ===================================================
  Future<List<LichHocChung>> layLichHocChungTheoLop(int idLop) async {
    try {
      if (idLop <= 0) {
        developer.log(
          '❌ Lỗi: ID lớp không hợp lệ',
          name: 'LichHocChungService.layLichHocChungTheoLop',
          error: {'idLop': idLop},
        );
        return [];
      }

      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        tenBangLHC,
        where: 'id_lop = ?',
        whereArgs: [idLop],
        orderBy: 'ngay_trong_tuan ASC, gio_bat_dau ASC',
      );

      developer.log(
        '✅ Đọc thành công ${maps.length} lịch học chung từ lớp ID: $idLop',
        name: 'LichHocChungService.layLichHocChungTheoLop',
      );

      return List.generate(maps.length, (i) {
        return LichHocChung.fromMap(maps[i]);
      });
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi đọc lịch học chung',
        name: 'LichHocChungService.layLichHocChungTheoLop',
        error: {'idLop': idLop, 'error': e},
        stackTrace: st,
      );
      return [];
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi đọc lịch học chung',
        name: 'LichHocChungService.layLichHocChungTheoLop',
        error: {'idLop': idLop, 'error': e},
        stackTrace: st,
      );
      return [];
    }
  }

  // ===================================================
  // 3. CẬP NHẬT LỊCH HỌC CHUNG (UPDATE)
  // ===================================================
  Future<bool> capNhatLichHocChung(LichHocChung lichHoc) async {
    try {
      developer.log(
        '🔄 Đang cập nhật lịch học chung ID: ${lichHoc.id}',
        name: 'LichHocChungService.capNhatLichHocChung',
      );

      if (lichHoc.id == null || lichHoc.id! <= 0) {
        developer.log(
          '❌ Lỗi: ID lịch học không hợp lệ',
          name: 'LichHocChungService.capNhatLichHocChung',
          error: {'id': lichHoc.id},
        );
        return false;
      }

      final db = await _database;

      // Kiểm tra tồn tại
      final existing = await db.query(
        tenBangLHC,
        where: 'id = ?',
        whereArgs: [lichHoc.id],
      );

      if (existing.isEmpty) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học chung ID ${lichHoc.id} không tồn tại',
          name: 'LichHocChungService.capNhatLichHocChung',
          error: {'id': lichHoc.id},
        );
        return false;
      }

      // Kiểm tra chồng lấn
      final overlapping = await kiemTraChongLanLichHoc(
        db: db,
        tenBang: tenBangLHC,
        idLop: lichHoc.idLop,
        cotNgay: 'ngay_trong_tuan',
        giaTriNgay: lichHoc.ngayTrongTuan,
        gioBatDauMoi: lichHoc.gioBatDau,
        gioKetThucMoi: lichHoc.gioKetThuc,
        excludeId: lichHoc.id,
      );

      if (overlapping) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học bị chồng lấn với lịch học khác',
          name: 'LichHocChungService.capNhatLichHocChung',
          error: lichHoc.toMap(),
        );
        return false;
      }

      final result = await db.update(
        tenBangLHC,
        lichHoc.toMap(),
        where: 'id = ?',
        whereArgs: [lichHoc.id],
      );

      if (result > 0) {
        developer.log(
          '✅ Cập nhật lịch học chung thành công! ID: ${lichHoc.id}',
          name: 'LichHocChungService.capNhatLichHocChung',
        );
        FirebaseSyncService.instance
            .pushRecordToCloud(tenBangLHC, lichHoc.id.toString(), lichHoc.toMap())
            .catchError((e) => null);
      }

      return result > 0;
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi cập nhật lịch học chung',
        name: 'LichHocChungService.capNhatLichHocChung',
        error: {'error': e, 'lichHoc': lichHoc.toMap()},
        stackTrace: st,
      );
      return false;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi cập nhật lịch học chung',
        name: 'LichHocChungService.capNhatLichHocChung',
        error: {'error': e, 'lichHoc': lichHoc.toMap()},
        stackTrace: st,
      );
      return false;
    }
  }

  // ===================================================
  // 4. XÓA LỊCH HỌC CHUNG (DELETE)
  // ===================================================
  Future<bool> xoaLichHocChung(int lichHocId) async {
    try {
      developer.log(
        '🔄 Đang xóa lịch học chung ID: $lichHocId',
        name: 'LichHocChungService.xoaLichHocChung',
      );

      if (lichHocId <= 0) {
        developer.log(
          '❌ Lỗi: ID lịch học không hợp lệ',
          name: 'LichHocChungService.xoaLichHocChung',
          error: {'lichHocId': lichHocId},
        );
        return false;
      }

      final db = await _database;

      // Kiểm tra tồn tại
      final existing = await db.query(
        tenBangLHC,
        where: 'id = ?',
        whereArgs: [lichHocId],
      );

      if (existing.isEmpty) {
        developer.log(
          '⚠️ Cảnh báo: Lịch học chung ID $lichHocId không tồn tại',
          name: 'LichHocChungService.xoaLichHocChung',
          error: {'lichHocId': lichHocId},
        );
        return false;
      }

      // Xóa tất cả lịch học cá nhân liên quan
      await db.delete(
        tenBangLHCN,
        where: 'id_lich_hoc_chung = ?',
        whereArgs: [lichHocId],
      );

      // Xóa lịch học chung
      final result = await db.delete(
        tenBangLHC,
        where: 'id = ?',
        whereArgs: [lichHocId],
      );

      if (result > 0) {
        developer.log(
          '✅ Xóa lịch học chung thành công! ID: $lichHocId',
          name: 'LichHocChungService.xoaLichHocChung',
        );
        FirebaseSyncService.instance
            .deleteRecordFromCloud(tenBangLHC, lichHocId.toString())
            .catchError((e) => null);
      }

      return result > 0;
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi xóa lịch học chung',
        name: 'LichHocChungService.xoaLichHocChung',
        error: {'lichHocId': lichHocId, 'error': e},
        stackTrace: st,
      );
      return false;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi xóa lịch học chung',
        name: 'LichHocChungService.xoaLichHocChung',
        error: {'lichHocId': lichHocId, 'error': e},
        stackTrace: st,
      );
      return false;
    }
  }

  // ===================================================
  // 5. GÁN LỊCH HỌC CHO HỌC SINH (CREATE LICH_HOC_CA_NHAN)
  // ===================================================
  Future<bool> ganLichHocChoHocSinh(int idHocSinh, int idLichHocChung) async {
    try {
      developer.log(
        '🔄 Đang gán lịch học chung ID: $idLichHocChung cho học sinh ID: $idHocSinh',
        name: 'LichHocChungService.ganLichHocChoHocSinh',
      );

      if (idHocSinh <= 0 || idLichHocChung <= 0) {
        developer.log(
          '❌ Lỗi: ID không hợp lệ',
          name: 'LichHocChungService.ganLichHocChoHocSinh',
          error: {'idHocSinh': idHocSinh, 'idLichHocChung': idLichHocChung},
        );
        return false;
      }

      final db = await _database;

      // Kiểm tra đã gán chưa
      final existing = await db.query(
        tenBangLHCN,
        where: 'id_hoc_sinh = ? AND id_lich_hoc_chung = ?',
        whereArgs: [idHocSinh, idLichHocChung],
      );

      if (existing.isNotEmpty) {
        developer.log(
          '⚠️ Cảnh báo: Học sinh đã được gán lịch học này rồi',
          name: 'LichHocChungService.ganLichHocChoHocSinh',
        );
        return false;
      }

      final lichHocCaNhan = LichHocCaNhan(
        idHocSinh: idHocSinh,
        idLichHocChung: idLichHocChung,
      );

      await db.insert(
        tenBangLHCN,
        lichHocCaNhan.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      developer.log(
        '✅ Gán lịch học cho học sinh thành công!',
        name: 'LichHocChungService.ganLichHocChoHocSinh',
      );
      FirebaseSyncService.instance
          .pushRecordToCloud(
              tenBangLHCN, '${idHocSinh}_$idLichHocChung', lichHocCaNhan.toMap())
          .catchError((e) => null);
      return true;
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi gán lịch học',
        name: 'LichHocChungService.ganLichHocChoHocSinh',
        error: e,
        stackTrace: st,
      );
      return false;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi gán lịch học',
        name: 'LichHocChungService.ganLichHocChoHocSinh',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  // ===================================================
  // 6. HỦY GÁN LỊCH HỌC CHO HỌC SINH (DELETE LICH_HOC_CA_NHAN)
  // ===================================================
  Future<bool> huyGanLichHocChoHocSinh(
    int idHocSinh,
    int idLichHocChung,
  ) async {
    try {
      developer.log(
        '🔄 Đang hủy gán lịch học chung ID: $idLichHocChung cho học sinh ID: $idHocSinh',
        name: 'LichHocChungService.huyGanLichHocChoHocSinh',
      );

      final db = await _database;

      final result = await db.delete(
        tenBangLHCN,
        where: 'id_hoc_sinh = ? AND id_lich_hoc_chung = ?',
        whereArgs: [idHocSinh, idLichHocChung],
      );

      if (result > 0) {
        developer.log(
          '✅ Hủy gán lịch học thành công!',
          name: 'LichHocChungService.huyGanLichHocChoHocSinh',
        );
        FirebaseSyncService.instance
            .deleteRecordFromCloud(tenBangLHCN, '${idHocSinh}_$idLichHocChung')
            .catchError((e) => null);
      }

      return result > 0;
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi hủy gán lịch học',
        name: 'LichHocChungService.huyGanLichHocChoHocSinh',
        error: e,
        stackTrace: st,
      );
      return false;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi hủy gán lịch học',
        name: 'LichHocChungService.huyGanLichHocChoHocSinh',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  // ===================================================
  // 7. LẤY LỊCH HỌC CÁ NHÂN CỦA HỌC SINH
  // ===================================================
  Future<List<LichHocChung>> layLichHocCaNhanCuaHocSinh(
    int idHocSinh, {
    int? idLop,
  }) async {
    try {
      if (idHocSinh <= 0) {
        developer.log(
          '❌ Lỗi: ID học sinh không hợp lệ',
          name: 'LichHocChungService.layLichHocCaNhanCuaHocSinh',
          error: {'idHocSinh': idHocSinh},
        );
        return [];
      }

      final db = await _database;

      // JOIN để lấy thông tin lịch học chung, có lọc theo lớp nếu được truyền vào
      String sql =
          '''
        SELECT lhc.* 
        FROM $tenBangLHC lhc
        INNER JOIN $tenBangLHCN lhcn ON lhc.id = lhcn.id_lich_hoc_chung
        WHERE lhcn.id_hoc_sinh = ?
      ''';
      List<dynamic> args = [idHocSinh];

      if (idLop != null) {
        sql += ' AND lhc.id_lop = ?';
        args.add(idLop);
      }

      sql += ' ORDER BY lhc.ngay_trong_tuan ASC, lhc.gio_bat_dau ASC';

      final List<Map<String, dynamic>> maps = await db.rawQuery(sql, args);

      developer.log(
        '✅ Đọc thành công ${maps.length} lịch học cá nhân của học sinh ID: $idHocSinh${idLop != null ? ' tại lớp ID: $idLop' : ''}',
        name: 'LichHocChungService.layLichHocCaNhanCuaHocSinh',
      );

      return List.generate(maps.length, (i) {
        return LichHocChung.fromMap(maps[i]);
      });
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi đọc lịch học cá nhân',
        name: 'LichHocChungService.layLichHocCaNhanCuaHocSinh',
        error: {'idHocSinh': idHocSinh, 'error': e},
        stackTrace: st,
      );
      return [];
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi đọc lịch học cá nhân',
        name: 'LichHocChungService.layLichHocCaNhanCuaHocSinh',
        error: {'idHocSinh': idHocSinh, 'error': e},
        stackTrace: st,
      );
      return [];
    }
  }

  // ===================================================
  // 8. KIỂM TRA HỌC SINH ĐÃ ĐƯỢC GÁN LỊCH HỌC CHƯA
  // ===================================================
  Future<bool> kiemTraHocSinhCoLichHoc(
    int idHocSinh,
    int idLichHocChung,
  ) async {
    try {
      final db = await _database;

      final result = await db.query(
        tenBangLHCN,
        where: 'id_hoc_sinh = ? AND id_lich_hoc_chung = ?',
        whereArgs: [idHocSinh, idLichHocChung],
      );

      return result.isNotEmpty;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi khi kiểm tra lịch học',
        name: 'LichHocChungService.kiemTraHocSinhCoLichHoc',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  // ===================================================
  // 9. GÁN LỊCH HỌC CHUNG CHO NHIỀU HỌC SINH (TRANSACTION)
  // ===================================================
  Future<int> ganLichChoNhieuHS(List<int> hsIds, int lichHocChungId) async {
    if (hsIds.isEmpty || lichHocChungId <= 0) return 0;
    final db = await _database;
    int added = 0;
    try {
      await db.transaction((txn) async {
        for (final hsId in hsIds) {
          if (hsId <= 0) continue;
          final exists = await txn.query(
            tenBangLHCN,
            where: 'id_hoc_sinh = ? AND id_lich_hoc_chung = ?',
            whereArgs: [hsId, lichHocChungId],
          );
          if (exists.isEmpty) {
            await txn.insert(tenBangLHCN, {
              'id_hoc_sinh': hsId,
              'id_lich_hoc_chung': lichHocChungId,
            });
            added++;
            FirebaseSyncService.instance
                .pushRecordToCloud(tenBangLHCN, '${hsId}_$lichHocChungId', {
                  'id_hoc_sinh': hsId,
                  'id_lich_hoc_chung': lichHocChungId,
                })
                .catchError((e) => null);
          }
        }
      });
    } on DatabaseException catch (e, st) {
      developer.log('DB error ganLichChoNhieuHS', error: e, stackTrace: st);
    } catch (e, st) {
      developer.log('Error ganLichChoNhieuHS', error: e, stackTrace: st);
    }
    return added;
  }

  // ===================================================
  // 10. TÌM LỊCH HỌC CHUNG (HELPER)
  // ===================================================
  /// Tìm một LichHocChung dựa trên các thuộc tính của nó.
  /// Trả về đối tượng có ID nếu tìm thấy, ngược lại trả về null.
  Future<LichHocChung?> findLichHocChung(LichHocChung lichHoc) async {
    try {
      final db = await _database;
      final List<Map<String, dynamic>> maps = await db.query(
        tenBangLHC,
        where:
            'id_lop = ? AND ngay_trong_tuan = ? AND gio_bat_dau = ? AND gio_ket_thuc = ?',
        whereArgs: [
          lichHoc.idLop,
          lichHoc.ngayTrongTuan,
          lichHoc.gioBatDau,
          lichHoc.gioKetThuc,
        ],
        limit: 1,
      );
      if (maps.isNotEmpty) return LichHocChung.fromMap(maps.first);
      return null;
    } catch (e) {
      return null;
    }
  }

  // ===================================================
  // 11. ĐẾM SỐ BUỔI HỌC DỰ KIẾN CỦA CÁ NHÂN TRONG THÁNG
  // ===================================================
  /// Tính tổng số buổi học dự kiến của một học sinh trong một tháng dựa trên lịch đã gán.
  Future<int> demSoBuoiHocCaNhanTrongThang(
    int idHocSinh,
    String thang, { // YYYY-MM
    DateTime? ngayThamGia, // Thêm ngày tham gia để lọc
    int? idLop, // Thêm idLop để lọc theo lớp
    DateTime? ngayTamNgung,
    DateTime? ngayHocLai,
    DateTime? ngayNghiHoc,
    DateTime? ngayHocLaiSauNghi,
  }) async {
    try {
      // 1. Lấy tất cả lịch học cá nhân của học sinh trong lớp này
      final List<LichHocChung> lichCaNhan = await layLichHocCaNhanCuaHocSinh(
        idHocSinh,
        idLop: idLop,
      );
      if (lichCaNhan.isEmpty) return 0;

      // 2. Chuẩn bị thông tin về tháng
      final int nam = int.parse(thang.substring(0, 4));
      final int month = int.parse(thang.substring(5));
      final int daysInMonth = DateTime(nam, month + 1, 0).day;

      // Chuẩn hóa ngày chỉ lấy năm, tháng, ngày (bỏ giờ phút giây) để so sánh chính xác
      final joiningDateOnly = ngayThamGia != null
          ? DateTime(ngayThamGia.year, ngayThamGia.month, ngayThamGia.day)
          : null;
      final pauseDateOnly = ngayTamNgung != null
          ? DateTime(ngayTamNgung.year, ngayTamNgung.month, ngayTamNgung.day)
          : null;
      final resumeDateOnly = ngayHocLai != null
          ? DateTime(ngayHocLai.year, ngayHocLai.month, ngayHocLai.day)
          : null;
      final leaveDateOnly = ngayNghiHoc != null
          ? DateTime(ngayNghiHoc.year, ngayNghiHoc.month, ngayNghiHoc.day)
          : null;
      final resumeAfterLeaveOnly = ngayHocLaiSauNghi != null
          ? DateTime(ngayHocLaiSauNghi.year, ngayHocLaiSauNghi.month, ngayHocLaiSauNghi.day)
          : null;

      // Map 'Thứ Hai' -> 1, 'Thứ Ba' -> 2, ..., 'Chủ Nhật' -> 7
      final Map<String, int> weekdayMap = {
        'Thứ Hai': 1,
        'Thứ Ba': 2,
        'Thứ Tư': 3,
        'Thứ Năm': 4,
        'Thứ Sáu': 5,
        'Thứ Bảy': 6,
        'Chủ Nhật': 7,
      };
      final Set<int> lichHocWeekdays = lichCaNhan
          .map((l) => weekdayMap[l.ngayTrongTuan])
          .where((d) => d != null)
          .cast<int>()
          .toSet();

      // 3. Duyệt qua các ngày trong tháng và đếm
      int soBuoiHoc = 0;
      for (int day = 1; day <= daysInMonth; day++) {
        final currentDate = DateTime(nam, month, day);
        // Chỉ đếm nếu ngày hiện tại lớn hơn hoặc bằng ngày tham gia
        final bool afterJoiningDate =
            joiningDateOnly == null ||
            currentDate.isAtSameMomentAs(joiningDateOnly) ||
            currentDate.isAfter(joiningDateOnly);
        final bool inPausedPeriod =
            pauseDateOnly != null &&
            !currentDate.isBefore(pauseDateOnly) &&
            (resumeDateOnly == null || currentDate.isBefore(resumeDateOnly));
        final bool outsideLeavePeriod =
            leaveDateOnly == null ||
            currentDate.isBefore(leaveDateOnly) ||
            (resumeAfterLeaveOnly != null &&
                !currentDate.isBefore(resumeAfterLeaveOnly));
        if (lichHocWeekdays.contains(currentDate.weekday) &&
            afterJoiningDate &&
            !inPausedPeriod &&
            outsideLeavePeriod) {
          soBuoiHoc++;
        }
      }
      return soBuoiHoc;
    } catch (e) {
      developer.log('Lỗi khi đếm số buổi học cá nhân', error: e);
      return 0;
    }
  }
}
