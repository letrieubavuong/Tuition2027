// File: lib/services/lop_hoc_sinh_service.dart (CẬP NHẬT)

import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/hs_lop_view_model.dart';
import '../utils/db.dart';
import '../models/lop_hoc_sinh.dart';
import '../models/hs.dart';
import 'hoc_sinh_service.dart';
import '../models/lop.dart';
import 'tuition_event_service.dart';
import 'dart:developer' as developer;

import 'report_service.dart';
import 'firebase_sync_service.dart';

class LopHocSinhService {
  final dbHelper = DBHelper.instance;
  final String tenBang = DBHelper.tenBangLopHS;
  final String tenBangHS = DBHelper.tenBangHS;
  final HocSinhService _hsService = HocSinhService();

  bool hoatDongTrongNgay(HSLopViewModel hs, DateTime date) {
    final status = (hs.trangThai).toUpperCase().trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    if (status == 'NGHI_HOC' || status == 'DA_NGHI' || status == 'NGHỈ HỌC' || status == 'ĐÃ NGHỈ') {
      if (hs.ngayHocLaiSauNghi != null && hs.ngayHocLaiSauNghi!.trim().isNotEmpty) {
        final nhl = ReportService.parseFlexibleDate(hs.ngayHocLaiSauNghi);
        if (nhl != null && DateFormat('yyyy-MM-dd').format(nhl).compareTo(dateStr) <= 0) {
          return true;
        }
      }
      if (hs.ngayNghiHoc != null && hs.ngayNghiHoc!.trim().isNotEmpty) {
        final nnh = ReportService.parseFlexibleDate(hs.ngayNghiHoc);
        if (nnh != null && DateFormat('yyyy-MM-dd').format(nnh).compareTo(dateStr) > 0) {
          return true;
        }
      }
      return false;
    }

    if (status == 'TAM_NGUNG' || status == 'TAM_NGHI' || status == 'TẠM NGỪNG' || status == 'TẠM NGHỈ') {
      if (hs.ngayHocLaiThucTe != null && hs.ngayHocLaiThucTe!.trim().isNotEmpty) {
        final nhl = ReportService.parseFlexibleDate(hs.ngayHocLaiThucTe);
        if (nhl != null && DateFormat('yyyy-MM-dd').format(nhl).compareTo(dateStr) <= 0) {
          return true;
        }
      }
      if (hs.ngayTamNgung != null && hs.ngayTamNgung!.trim().isNotEmpty) {
        final ntn = ReportService.parseFlexibleDate(hs.ngayTamNgung);
        if (ntn != null && DateFormat('yyyy-MM-dd').format(ntn).compareTo(dateStr) > 0) {
          return true;
        }
      }
      return false;
    }

    return true;
  }

  Future<bool> coDonNghiTrongNgay(int idLop, int idHocSinh, dynamic dateOrStr) async {
    try {
      final String dateStr = dateOrStr is DateTime
          ? DateFormat('yyyy-MM-dd').format(dateOrStr)
          : dateOrStr.toString();
      final db = await dbHelper.database;
      final res = await db.query(
        DBHelper.tenBangDonNghiHoc,
        where: 'id_lop = ? AND id_hoc_sinh = ? AND tu_ngay <= ? AND den_ngay >= ?',
        whereArgs: [idLop, idHocSinh, dateStr, dateStr],
      );
      return res.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // READ: Đọc danh sách Học sinh thuộc một Lớp
  Future<List<HSLopViewModel>> docDSHSThuocLop(int idLop) async {
    try {
      if (idLop <= 0) {
        developer.log(
          '❌ Lỗi: ID lớp không hợp lệ',
          name: 'LopHocSinhService.docDSHSThuocLop',
          error: {'idLop': idLop},
        );
        return [];
      }

      final db = await dbHelper.database;
      List<Map<String, dynamic>> maps = await db.rawQuery(
        '''
            SELECT 
              T1.*,
              T1.id as hs_id,
              T2.id as lhs_id,
              T2.id_lop,
              T2.id_hoc_sinh,
              T2.ngay_tham_gia, 
              T2.trang_thai,
              T2.ngay_tam_ngung,
              T2.ngay_du_kien_hoc_lai,
              T2.ngay_hoc_lai_thuc_te,
              T2.ly_do_tam_ngung,
              T2.ngay_nghi_hoc,
              T2.ly_do_nghi_hoc,
              T2.ngay_hoc_lai_sau_nghi
            FROM $tenBangHS T1
            INNER JOIN $tenBang T2 ON (T1.id = T2.id_hoc_sinh OR CAST(T1.id AS TEXT) = CAST(T2.id_hoc_sinh AS TEXT) OR T1.id = CAST(T2.id_hoc_sinh AS INTEGER))
            WHERE (T2.id_lop = ? OR CAST(T2.id_lop AS TEXT) = ? OR CAST(T2.id_lop AS INTEGER) = ?)
            GROUP BY T1.id
            ORDER BY T1.ten ASC
          ''',
        [idLop, idLop.toString(), idLop],
      );

      if (maps.isEmpty) {
        // Fallback: Thử tìm theo chuỗi TRIM
        maps = await db.rawQuery(
          '''
              SELECT 
                T1.*,
                T1.id as hs_id,
                T2.id as lhs_id,
                T2.id_lop,
                T2.id_hoc_sinh,
                T2.ngay_tham_gia, 
                T2.trang_thai,
                T2.ngay_tam_ngung,
                T2.ngay_du_kien_hoc_lai,
                T2.ngay_hoc_lai_thuc_te,
                T2.ly_do_tam_ngung,
                T2.ngay_nghi_hoc,
                T2.ly_do_nghi_hoc,
                T2.ngay_hoc_lai_sau_nghi
              FROM $tenBangHS T1
              INNER JOIN $tenBang T2 ON TRIM(CAST(T1.id AS TEXT)) = TRIM(CAST(T2.id_hoc_sinh AS TEXT))
              WHERE TRIM(CAST(T2.id_lop AS TEXT)) = TRIM(CAST(? AS TEXT))
              GROUP BY T1.id
              ORDER BY T1.ten ASC
            ''',
          [idLop.toString()],
        );
      }

      developer.log(
        '✅ Đọc thành công ${maps.length} học sinh từ lớp ID: $idLop',
        name: 'LopHocSinhService.docDSHSThuocLop',
      );

      return List.generate(maps.length, (i) {
        final Map<String, dynamic> mapData = Map<String, dynamic>.from(maps[i]);
        final hsId = maps[i]['hs_id'] ?? maps[i]['id_hoc_sinh'] ?? maps[i]['id'];
        if (hsId != null) {
          mapData['id'] = (hsId is num)
              ? hsId.toInt()
              : int.tryParse(hsId.toString());
        }
        final hs = HS.fromMap(mapData);
        return HSLopViewModel(
          hocSinh: hs,
          ngayThamGia: (maps[i]['ngay_tham_gia'] as String?) ?? '',
          trangThai: (maps[i]['trang_thai'] as String?) ?? 'DANG_HOC',
          ngayTamNgung: maps[i]['ngay_tam_ngung'] as String?,
          ngayDuKienHocLai: maps[i]['ngay_du_kien_hoc_lai'] as String?,
          ngayHocLaiThucTe: maps[i]['ngay_hoc_lai_thuc_te'] as String?,
          lyDoTamNgung: maps[i]['ly_do_tam_ngung'] as String?,
          ngayNghiHoc: maps[i]['ngay_nghi_hoc'] as String?,
          lyDoNghiHoc: maps[i]['ly_do_nghi_hoc'] as String?,
          ngayHocLaiSauNghi: maps[i]['ngay_hoc_lai_sau_nghi'] as String?,
        );
      });
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi đọc danh sách học sinh',
        name: 'LopHocSinhService.docDSHSThuocLop',
        error: {'idLop': idLop, 'error': e},
        stackTrace: st,
      );
      return [];
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi đọc danh sách học sinh',
        name: 'LopHocSinhService.docDSHSThuocLop',
        error: {'idLop': idLop, 'error': e},
        stackTrace: st,
      );
      return [];
    }
  }

  Future<void> dangKyNghiCoPhep({
    required int idLop,
    required int idHocSinh,
    required String tuNgay,
    required String denNgay,
    String? lyDo,
  }) async {
    try {
      final db = await dbHelper.database;
      final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      await db.insert(DBHelper.tenBangDonNghiHoc, {
        'id_lop': idLop,
        'id_hoc_sinh': idHocSinh,
        'tu_ngay': tuNgay,
        'den_ngay': denNgay,
        'ly_do': lyDo ?? '',
        'created_at': nowStr,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      TuitionEventService().notifyTuitionChanged();
    } catch (e, st) {
      developer.log('Lỗi dangKyNghiCoPhep', error: e, stackTrace: st);
    }
  }

  Future<int> dangKyNghiCoPhepHangLoat({
    required int idLop,
    required List<int> dsHocSinhIds,
    required String tuNgay,
    required String denNgay,
    String? lyDo,
  }) async {
    try {
      if (dsHocSinhIds.isEmpty) return 0;
      final db = await dbHelper.database;
      final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      int successCount = 0;
      await db.transaction((txn) async {
        for (final hsId in dsHocSinhIds) {
          await txn.insert(DBHelper.tenBangDonNghiHoc, {
            'id_lop': idLop,
            'id_hoc_sinh': hsId,
            'tu_ngay': tuNgay,
            'den_ngay': denNgay,
            'ly_do': lyDo ?? '',
            'created_at': nowStr,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          successCount++;
        }
      });
      if (successCount > 0) {
        TuitionEventService().notifyTuitionChanged();
      }
      return successCount;
    } catch (e, st) {
      developer.log('Lỗi dangKyNghiCoPhepHangLoat', error: e, stackTrace: st);
      return 0;
    }
  }

  Future<int> tamNgungHoc({
    required int idLop,
    required int idHocSinh,
    required String ngayBatDau,
    String? ngayDuKienHocLai,
    String? lyDo,
  }) async {
    try {
      final db = await dbHelper.database;
      final updateData = {
        'trang_thai': 'TAM_NGUNG',
        'ngay_tam_ngung': ngayBatDau,
        'ngay_du_kien_hoc_lai': ngayDuKienHocLai,
        'ly_do_tam_ngung': lyDo,
      };
      final res = await db.update(
        tenBang,
        updateData,
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [idLop, idHocSinh],
      );
      if (res > 0) {
        final rowMap = Map<String, dynamic>.from(updateData)
          ..['id_lop'] = idLop
          ..['id_hoc_sinh'] = idHocSinh;
        FirebaseSyncService.instance.pushRecordToCloud(tenBang, '${idHocSinh}_${idLop}', rowMap);
        TuitionEventService().notifyTuitionChanged();
      }
      return res;
    } catch (e, st) {
      developer.log('Lỗi tamNgungHoc', error: e, stackTrace: st);
      return 0;
    }
  }

  Future<int> choHocLai({
    required int idLop,
    required int idHocSinh,
    required String ngayHocLai,
  }) async {
    try {
      final db = await dbHelper.database;
      final updateData = {
        'trang_thai': 'DANG_HOC',
        'ngay_hoc_lai_thuc_te': ngayHocLai,
      };
      final res = await db.update(
        tenBang,
        updateData,
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [idLop, idHocSinh],
      );
      if (res > 0) {
        final rowMap = Map<String, dynamic>.from(updateData)
          ..['id_lop'] = idLop
          ..['id_hoc_sinh'] = idHocSinh;
        FirebaseSyncService.instance.pushRecordToCloud(tenBang, '${idHocSinh}_${idLop}', rowMap);
        TuitionEventService().notifyTuitionChanged();
      }
      return res;
    } catch (e, st) {
      developer.log('Lỗi choHocLai', error: e, stackTrace: st);
      return 0;
    }
  }

  Future<int> kichHoatHocLai({
    required int idLop,
    required int idHocSinh,
    required String ngayHocLai,
  }) async {
    try {
      final db = await dbHelper.database;
      final updateData = {
        'trang_thai': 'DANG_HOC',
        'ngay_hoc_lai_sau_nghi': ngayHocLai,
      };
      final res = await db.update(
        tenBang,
        updateData,
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [idLop, idHocSinh],
      );
      if (res > 0) {
        final rowMap = Map<String, dynamic>.from(updateData)
          ..['id_lop'] = idLop
          ..['id_hoc_sinh'] = idHocSinh;
        FirebaseSyncService.instance.pushRecordToCloud(tenBang, '${idHocSinh}_${idLop}', rowMap);
        TuitionEventService().notifyTuitionChanged();
      }
      return res;
    } catch (e, st) {
      developer.log('Lỗi kichHoatHocLai', error: e, stackTrace: st);
      return 0;
    }
  }

  Future<int> choHocSinhNghiHoc({
    required int idLop,
    required int idHocSinh,
    required String ngayNghiHoc,
    String? lyDo,
  }) async {
    try {
      final db = await dbHelper.database;
      final updateData = {
        'trang_thai': 'NGHI_HOC',
        'ngay_nghi_hoc': ngayNghiHoc,
        'ly_do_nghi_hoc': lyDo,
      };
      final res = await db.update(
        tenBang,
        updateData,
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [idLop, idHocSinh],
      );
      if (res > 0) {
        final rowMap = Map<String, dynamic>.from(updateData)
          ..['id_lop'] = idLop
          ..['id_hoc_sinh'] = idHocSinh;
        FirebaseSyncService.instance.pushRecordToCloud(tenBang, '${idHocSinh}_${idLop}', rowMap);
        TuitionEventService().notifyTuitionChanged();
      }
      return res;
    } catch (e, st) {
      developer.log('Lỗi choHocSinhNghiHoc', error: e, stackTrace: st);
      return 0;
    }
  }

  // ===================================================
  // HÀM MỚI: ĐỌC DANH SÁCH HỌC SINH THEO MỘT CA HỌC CỤ THỂ
  // ===================================================
  /// Lấy danh sách học sinh được gán lịch học cho một ca học (LichHoc) cụ thể.
  /// Dùng cho trang điểm danh để hiển thị đúng học sinh.
  Future<List<HSLopViewModel>> docDSHSTheoCaHoc(int idLichHoc) async {
    try {
      if (idLichHoc <= 0) {
        developer.log(
          '❌ Lỗi: ID Lịch học không hợp lệ',
          name: 'LopHocSinhService.docDSHSTheoCaHoc',
          error: {'idLichHoc': idLichHoc},
        );
        return [];
      }

      final db = await dbHelper.database;
      // Truy vấn phức tạp để liên kết từ LichHoc -> LichHocChung -> LichHocCaNhan -> HocSinh
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        '''
        SELECT 
          HS.*, 
          LHS.ngay_tham_gia, 
          LHS.trang_thai
        FROM ${DBHelper.tenBangHS} HS
        JOIN ${DBHelper.tenBangLopHS} LHS ON HS.id = LHS.id_hoc_sinh AND LHS.id_lop = LH.id_lop
        JOIN ${DBHelper.tenBangLichHocCaNhan} LHCN ON HS.id = LHCN.id_hoc_sinh
        JOIN ${DBHelper.tenBangLichHocChung} LHC ON LHCN.id_lich_hoc_chung = LHC.id
        JOIN ${DBHelper.tenBangLichHoc} LH ON 
            LHC.id_lop = LH.id_lop AND 
            LHC.gio_bat_dau LIKE SUBSTR(LH.gioBatDau, 1, 5) || '%' AND
            LHC.ngay_trong_tuan = CASE LH.thuTrongTuan 
                                    WHEN 1 THEN 'Chủ Nhật'
                                    WHEN 2 THEN 'Thứ Hai'
                                    WHEN 3 THEN 'Thứ Ba'
                                    WHEN 4 THEN 'Thứ Tư'
                                    WHEN 5 THEN 'Thứ Năm'
                                    WHEN 6 THEN 'Thứ Sáu'
                                    ELSE 'Thứ Bảy' END
        WHERE LH.id = ?
        ORDER BY HS.ten ASC
      ''',
        [idLichHoc],
      );

      return List.generate(maps.length, (i) {
        final hs = HS.fromMap(maps[i]);
        return HSLopViewModel(
          hocSinh: hs,
          ngayThamGia: (maps[i]['ngay_tham_gia'] as String?) ?? '',
          trangThai: (maps[i]['trang_thai'] as String?) ?? '',
        );
      });
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi đọc DS HS theo ca học',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // HÀM MỚI: Tối ưu hóa, lấy tất cả ID học sinh đã được gán cho các ca học của một lớp
  Future<Map<int, Set<int>>> layTatCaHsIdDaGanLich(int idLop) async {
    final db = await dbHelper.database;
    final Map<int, Set<int>> result = {};

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT 
        LH.id as id_lich_hoc,
        LHCN.id_hoc_sinh
      FROM ${DBHelper.tenBangLichHoc} LH
      JOIN ${DBHelper.tenBangLichHocChung} LHC ON 
          LHC.id_lop = LH.id_lop AND 
          LHC.gio_bat_dau LIKE SUBSTR(LH.gioBatDau, 1, 5) || '%' AND
          LHC.ngay_trong_tuan = CASE LH.thuTrongTuan 
                                  WHEN 1 THEN 'Chủ Nhật'
                                  WHEN 2 THEN 'Thứ Hai'
                                  WHEN 3 THEN 'Thứ Ba'
                                  WHEN 4 THEN 'Thứ Tư'
                                  WHEN 5 THEN 'Thứ Năm'
                                  WHEN 6 THEN 'Thứ Sáu'
                                  ELSE 'Thứ Bảy' END
      JOIN ${DBHelper.tenBangLichHocCaNhan} LHCN ON LHCN.id_lich_hoc_chung = LHC.id
      WHERE LH.id_lop = ?
    ''',
      [idLop],
    );

    for (var map in maps) {
      final idLichHoc = map['id_lich_hoc'] as int;
      final idHocSinh = map['id_hoc_sinh'] as int;
      if (result[idLichHoc] == null) {
        result[idLichHoc] = <int>{};
      }
      result[idLichHoc]!.add(idHocSinh);
    }
    return result;
  }

  // ===================================================
  // HÀM MỚI: ĐỌC DANH SÁCH LỚP CỦA MỘT HỌC SINH
  // ===================================================
  Future<List<Lop>> docDSLopCuaHS(int idHocSinh) async {
    try {
      if (idHocSinh <= 0) {
        developer.log(
          '❌ Lỗi: ID học sinh không hợp lệ',
          name: 'LopHocSinhService.docDSLopCuaHS',
          error: {'idHocSinh': idHocSinh},
        );
        return [];
      }

      final db = await dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        '''
        SELECT L.* 
        FROM ${DBHelper.tenBangLop} L
        INNER JOIN $tenBang LHS ON L.id = LHS.id_lop
        WHERE LHS.id_hoc_sinh = ?
        ORDER BY L.ten ASC
      ''',
        [idHocSinh],
      );

      developer.log(
        '✅ Đọc thành công ${maps.length} lớp của học sinh ID: $idHocSinh',
        name: 'LopHocSinhService.docDSLopCuaHS',
      );

      return List.generate(maps.length, (i) => Lop.fromMap(maps[i]));
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi đọc DS Lớp của HS',
        error: e,
        stackTrace: st,
      );
      return [];
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi đọc DS Lớp của HS',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  // CREATE: Thêm Học sinh vào Lớp (Sử dụng Model đã cập nhật)
  Future<LopHocSinh?> themHocSinhVaoLop(LopHocSinh lhs) async {
    try {
      final db = await dbHelper.database;
      final map = lhs.toMap();
      // Lấy giá trị id_hoc_sinh / id_lop từ map (hợp với nhiều naming)
      final dynamic hsVal =
          map['id_hoc_sinh'] ?? map['hsId'] ?? map['hs_id'] ?? map['id_hs'];
      final dynamic lopVal =
          map['id_lop'] ?? map['lopId'] ?? map['lop_id'] ?? map['id_l'];

      if (hsVal == null || lopVal == null) {
        developer.log(
          'Không tìm được id_hoc_sinh hoặc id_lop trong toMap() khi thêm LopHocSinh',
          error: {'map': map},
        );
        return null;
      }

      // Kiểm tra đã tồn tại
      final existing = await db.query(
        tenBang,
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [lopVal, hsVal],
      );
      if (existing.isNotEmpty) {
        developer.log(
          'Học sinh đã tồn tại trong lớp',
          error: {'hs': hsVal, 'lop': lopVal},
        );
        return null;
      }

      final id = await db.insert(
        tenBang,
        map,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      developer.log(
        'Thêm học sinh vào lớp thành công',
        name: 'themHocSinhVaoLop',
        error: {'id': id},
      );
      FirebaseSyncService.instance.pushRecordToCloud(tenBang, '${hsVal}_${lopVal}', map);
      TuitionEventService().notifyTuitionChanged();
      return lhs.copyWith(id: id);
    } on DatabaseException catch (e, st) {
      developer.log(
        'Lỗi Database khi thêm học sinh vào lớp',
        error: e,
        stackTrace: st,
      );
      return null;
    } catch (e, st) {
      developer.log(
        'Lỗi không xác định khi thêm học sinh vào lớp',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  // Gán 1 lịch học chung cho 1 học sinh (ghi vào lich_hoc_ca_nhan)
  Future<bool> ganLichHocChoHocSinh(int hsId, int lichHocChungId) async {
    try {
      if (hsId <= 0 || lichHocChungId <= 0) return false;
      final db = await dbHelper.database;
      final exists = await db.query(
        DBHelper.tenBangLichHocCaNhan,
        where: 'id_hoc_sinh = ? AND id_lich_hoc_chung = ?',
        whereArgs: [hsId, lichHocChungId],
      );
      if (exists.isNotEmpty) return false;
      await db.insert(DBHelper.tenBangLichHocCaNhan, {
        'id_hoc_sinh': hsId,
        'id_lich_hoc_chung': lichHocChungId,
      }, conflictAlgorithm: ConflictAlgorithm.abort);
      return true;
    } on DatabaseException catch (e, st) {
      developer.log('DB error ganLichHocChoHocSinh', error: e, stackTrace: st);
      return false;
    } catch (e, st) {
      developer.log('Error ganLichHocChoHocSinh', error: e, stackTrace: st);
      return false;
    }
  }

  // UPDATE: Cập nhật ngày tham gia của học sinh
  Future<int> capNhatNgayThamGia(
    int idLop,
    int idHocSinh,
    String ngayThamGia,
  ) async {
    try {
      final db = await dbHelper.database;
      final res = await db.update(
        tenBang,
        {'ngay_tham_gia': ngayThamGia},
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [idLop, idHocSinh],
      );
      if (res > 0) TuitionEventService().notifyTuitionChanged();
      return res;
    } catch (e, st) {
      developer.log('Lỗi khi cập nhật ngày tham gia', error: e, stackTrace: st);
      return 0;
    }
  }

  // DELETE: Rút Học sinh khỏi Lớp
  Future<int> xoaHocSinhKhoiLop(int lopId, int hsId) async {
    try {
      developer.log(
        '🔄 Đang xóa học sinh ID: $hsId khỏi lớp ID: $lopId',
        name: 'LopHocSinhService.xoaHocSinhKhoiLop',
      );

      final db = await dbHelper.database;

      // Kiểm tra học sinh có tồn tại trong lớp không
      final existing = await db.query(
        tenBang,
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [lopId, hsId],
      );

      if (existing.isEmpty) {
        developer.log(
          '⚠️ Cảnh báo: Học sinh ID $hsId không có trong lớp ID $lopId',
          name: 'LopHocSinhService.xoaHocSinhKhoiLop',
          error: {'lopId': lopId, 'hsId': hsId},
        );
        return 0;
      }

      final result = await db.delete(
        tenBang,
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [lopId, hsId],
      );

      if (result > 0) {
        // Xóa bản ghi học phí chưa thu tiền của học sinh này khỏi lớp
        await db.delete(
          DBHelper.tenBangThanhToan,
          where: 'id_lop = ? AND id_hoc_sinh = ? AND so_tien_da_dong = 0',
          whereArgs: [lopId, hsId],
        );
        developer.log(
          '✅ Xóa học sinh khỏi lớp thành công! Số bản ghi đã xóa: $result',
          name: 'LopHocSinhService.xoaHocSinhKhoiLop',
        );
        FirebaseSyncService.instance.deleteRecordFromCloud(tenBang, '${hsId}_${lopId}');
        TuitionEventService().notifyTuitionChanged();
      }

      return result;
    } on DatabaseException catch (e, st) {
      developer.log(
        '❌ Lỗi Database khi xóa học sinh khỏi lớp',
        name: 'LopHocSinhService.xoaHocSinhKhoiLop',
        error: {'lopId': lopId, 'hsId': hsId, 'error': e},
        stackTrace: st,
      );
      return 0;
    } catch (e, st) {
      developer.log(
        '❌ Lỗi không xác định khi xóa học sinh khỏi lớp',
        name: 'LopHocSinhService.xoaHocSinhKhoiLop',
        error: {'lopId': lopId, 'hsId': hsId, 'error': e},
        stackTrace: st,
      );
      return 0;
    }
  }
}
