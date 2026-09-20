// File: lib/services/lop_hoc_sinh_service.dart (CẬP NHẬT)

import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/hs_lop_view_model.dart';
import '../utils/db.dart';
import '../models/lop_hoc_sinh.dart';
import '../models/hs.dart';
import '../models/lop.dart';
import 'tuition_event_service.dart';
import 'dart:developer' as developer;

import 'firebase_sync_service.dart';
import 'lich_hoc_chung_service.dart';
import 'diem_danh_service.dart';
import '../utils/attendance_calculator.dart';
import '../utils/student_status.dart';

class StudentClassSummary {
  final int soBuoiDu;
  final int nghiCoPhep;
  final int nghiKhongPhep;
  final int tongNghi;
  final String? facebook;
  final int tongThanhToan;
  final int soTienDaDong;
  final int conNo;
  final bool isDaDong;
  final bool isKhoiTao;

  StudentClassSummary({
    required this.soBuoiDu,
    required this.nghiCoPhep,
    required this.nghiKhongPhep,
    required this.tongNghi,
    this.facebook,
    required this.tongThanhToan,
    required this.soTienDaDong,
    required this.conNo,
    required this.isDaDong,
    required this.isKhoiTao,
  });
}

class LopHocSinhService {
  final dbHelper = DBHelper.instance;
  final String tenBang = DBHelper.tenBangLopHS;
  final String tenBangHS = DBHelper.tenBangHS;

  bool hoatDongTrongNgay(HSLopViewModel hs, DateTime date) {
    return AttendanceCalculator.isDateInParticipationWindow(
      date: date,
      ngayThamGia: AttendanceCalculator.parseDateSafely(hs.ngayThamGia),
      ngayTamNgung: AttendanceCalculator.parseDateSafely(hs.ngayTamNgung),
      ngayHocLai: AttendanceCalculator.parseDateSafely(
        hs.ngayHocLaiThucTe ?? hs.ngayDuKienHocLai,
      ),
      ngayNghiHoc: AttendanceCalculator.parseDateSafely(hs.ngayNghiHoc),
      ngayHocLaiSauNghi: AttendanceCalculator.parseDateSafely(
        hs.ngayHocLaiSauNghi,
      ),
    );
  }

  bool isStudentPaused(HSLopViewModel hs) {
    return AttendanceCalculator.isStudentPaused(hs.trangThai);
  }

  Future<bool> isStudentActiveOnDate(
    int studentId,
    int classId,
    DateTime date,
  ) async {
    final hsList = await docDSHSThuocLop(classId);
    final hs = hsList.firstWhere(
      (x) => x.id == studentId,
      orElse: () => HSLopViewModel(
        hocSinh: HS(id: studentId, ten: ''),
        ngayThamGia: '',
        trangThai: 'DANG_HOC',
      ),
    );
    if (hs.id == null || hs.ngayThamGia.isEmpty) return true;
    return hoatDongTrongNgay(hs, date);
  }

  Future<bool> coDonNghiTrongNgay(
    int idLop,
    int idHocSinh,
    dynamic dateOrStr,
  ) async {
    try {
      final String dateStr = dateOrStr is DateTime
          ? DateFormat('yyyy-MM-dd').format(dateOrStr)
          : dateOrStr.toString();
      final db = await dbHelper.database;
      final res = await db.query(
        DBHelper.tenBangDonNghiHoc,
        columns: ['id'],
        where:
            'id_lop = ? AND id_hoc_sinh = ? AND tu_ngay <= ? AND den_ngay >= ?',
        whereArgs: [idLop, idHocSinh, dateStr, dateStr],
        limit: 1,
      );
      return res.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Lấy tất cả ID học sinh có đơn nghỉ phép trong ngày của một lớp.
  /// Trả về `Set<int>` để tra cứu O(1) trên UI/Controller, tránh lỗi N+1 query.
  Future<Set<int>> layHsCoDonNghiTrongNgay(int idLop, dynamic dateOrStr) async {
    try {
      final String dateStr = dateOrStr is DateTime
          ? DateFormat('yyyy-MM-dd').format(dateOrStr)
          : dateOrStr.toString();
      final db = await dbHelper.database;
      final maps = await db.query(
        DBHelper.tenBangDonNghiHoc,
        columns: ['id_hoc_sinh'],
        where: 'id_lop = ? AND tu_ngay <= ? AND den_ngay >= ?',
        whereArgs: [idLop, dateStr, dateStr],
      );
      return maps
          .map((m) => m['id_hoc_sinh'])
          .whereType<num>()
          .map((n) => n.toInt())
          .toSet();
    } catch (e, st) {
      developer.log('Lỗi layHsCoDonNghiTrongNgay', error: e, stackTrace: st);
      return {};
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
      // GHI CHÚ BẢO TRÌ:
      // Hiện tại query giữ lại CAST(...) và TRIM(...) fallback để hỗ trợ dữ liệu legacy (ID dạng chuỗi/khoảng trắng).
      // Khi hoàn tất migration chuẩn hóa id_lop & id_hoc_sinh về INTEGER và làm sạch bản ghi trùng lặp trong DB,
      // query này sẽ được rút gọn về:
      //   INNER JOIN lop_hoc_sinh LHS ON HS.id = LHS.id_hoc_sinh WHERE LHS.id_lop = ? ORDER BY HS.ten ASC
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
        // Fallback: Thử tìm theo chuỗi TRIM cho dữ liệu legacy
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
        final hsId =
            maps[i]['hs_id'] ?? maps[i]['id_hoc_sinh'] ?? maps[i]['id'];
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
    String loaiNghi = 'CANHAN',
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
        'loai_nghi': loaiNghi,
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
    String loaiNghi = 'CANHAN',
  }) async {
    try {
      if (dsHocSinhIds.isEmpty) return 0;
      final db = await dbHelper.database;
      final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      int successCount = 0;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final hsId in dsHocSinhIds) {
          batch.insert(
            DBHelper.tenBangDonNghiHoc,
            {
              'id_lop': idLop,
              'id_hoc_sinh': hsId,
              'tu_ngay': tuNgay,
              'den_ngay': denNgay,
              'ly_do': lyDo ?? '',
              'created_at': nowStr,
              'loai_nghi': loaiNghi,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          successCount++;
        }
        await batch.commit(noResult: true);
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

  /// Internal helper dùng chung cho các hàm thay đổi trạng thái học sinh trong lớp
  Future<int> _updateStudentClassState({
    required int idLop,
    required int idHocSinh,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final db = await dbHelper.database;
      final res = await db.update(
        tenBang,
        updates,
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [idLop, idHocSinh],
      );
      if (res > 0) {
        final rowMap = Map<String, dynamic>.from(updates)
          ..['id_lop'] = idLop
          ..['id_hoc_sinh'] = idHocSinh;
        FirebaseSyncService.instance.pushRecordToCloud(
          tenBang,
          '${idHocSinh}_$idLop',
          rowMap,
        );
        TuitionEventService().notifyTuitionChanged();
      }
      return res;
    } catch (e, st) {
      developer.log('Lỗi _updateStudentClassState', error: e, stackTrace: st);
      return 0;
    }
  }

  Future<int> tamNgungHoc({
    required int idLop,
    required int idHocSinh,
    required String ngayBatDau,
    String? ngayDuKienHocLai,
    String? lyDo,
  }) {
    return _updateStudentClassState(
      idLop: idLop,
      idHocSinh: idHocSinh,
      updates: {
        'trang_thai': StudentStatus.tamNgung.toDbString(),
        'ngay_tam_ngung': ngayBatDau,
        'ngay_du_kien_hoc_lai': ngayDuKienHocLai,
        'ly_do_tam_ngung': lyDo,
      },
    );
  }

  Future<int> choHocLai({
    required int idLop,
    required int idHocSinh,
    required String ngayHocLai,
  }) {
    return _updateStudentClassState(
      idLop: idLop,
      idHocSinh: idHocSinh,
      updates: {
        'trang_thai': StudentStatus.dangHoc.toDbString(),
        'ngay_hoc_lai_thuc_te': ngayHocLai,
      },
    );
  }

  Future<int> kichHoatHocLai({
    required int idLop,
    required int idHocSinh,
    required String ngayHocLai,
  }) {
    return _updateStudentClassState(
      idLop: idLop,
      idHocSinh: idHocSinh,
      updates: {
        'trang_thai': StudentStatus.dangHoc.toDbString(),
        'ngay_hoc_lai_sau_nghi': ngayHocLai,
      },
    );
  }

  Future<int> choHocSinhNghiHoc({
    required int idLop,
    required int idHocSinh,
    required String ngayNghiHoc,
    String? lyDo,
  }) {
    return _updateStudentClassState(
      idLop: idLop,
      idHocSinh: idHocSinh,
      updates: {
        'trang_thai': StudentStatus.nghiHoc.toDbString(),
        'ngay_nghi_hoc': ngayNghiHoc,
        'ly_do_nghi_hoc': lyDo,
      },
    );
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
      // Liên kết theo thứ tự tuyến tính: LichHoc -> LichHocChung -> LichHocCaNhan -> HS -> LopHocSinh
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        '''
        SELECT DISTINCT
          HS.*, 
          LHS.ngay_tham_gia, 
          LHS.trang_thai
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
        JOIN ${DBHelper.tenBangHS} HS ON HS.id = LHCN.id_hoc_sinh
        JOIN ${DBHelper.tenBangLopHS} LHS ON HS.id = LHS.id_hoc_sinh AND LHS.id_lop = LH.id_lop
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
      SELECT DISTINCT
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
        WHERE (LHS.id_hoc_sinh = ? OR CAST(LHS.id_hoc_sinh AS INTEGER) = ?)
        ORDER BY 
          CASE WHEN LHS.trang_thai LIKE '%Đang học%' OR LHS.trang_thai LIKE '%DANG_HOC%' THEN 0 ELSE 1 END ASC,
          LHS.ngay_tham_gia DESC,
          L.ten ASC
      ''',
        [idHocSinh, idHocSinh],
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

      final intHsId = (hsVal is num)
          ? hsVal.toInt()
          : int.tryParse(hsVal.toString());
      final intLopId = (lopVal is num)
          ? lopVal.toInt()
          : int.tryParse(lopVal.toString());

      if (intHsId != null && intLopId != null) {
        map['id_hoc_sinh'] = intHsId;
        map['id_lop'] = intLopId;
      }

      // Kiểm tra đã tồn tại
      final existing = await db.query(
        tenBang,
        columns: ['id'],
        where: 'id_lop = ? AND id_hoc_sinh = ?',
        whereArgs: [lopVal, hsVal],
        limit: 1,
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
      FirebaseSyncService.instance.pushRecordToCloud(
        tenBang,
        '${hsVal}_$lopVal',
        map,
      );
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

  // Gán 1 lịch học chung cho 1 học sinh (ghi vào lich_hoc_ca_nhan) - Delegate sang LichHocChungService
  Future<bool> ganLichHocChoHocSinh(int hsId, int lichHocChungId) async {
    return LichHocChungService().ganLichHocChoHocSinh(hsId, lichHocChungId);
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
      if (res > 0) {
        FirebaseSyncService.instance.pushRecordToCloud(
          tenBang,
          '${idHocSinh}_$idLop',
          {
            'id_lop': idLop,
            'id_hoc_sinh': idHocSinh,
            'ngay_tham_gia': ngayThamGia,
          },
        );
        TuitionEventService().notifyTuitionChanged();
      }
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
      int result = 0;
      List<int> removedLhcIds = [];

      await db.transaction((txn) async {
        // 1. Trực tiếp xóa học sinh khỏi lớp (không cần SELECT kiểm tra trước)
        result = await txn.delete(
          tenBang,
          where: 'id_lop = ? AND id_hoc_sinh = ?',
          whereArgs: [lopId, hsId],
        );

        if (result > 0) {
          // 2. Xóa bản ghi học phí chưa thu tiền của học sinh này khỏi lớp
          await txn.delete(
            DBHelper.tenBangThanhToan,
            where: 'id_lop = ? AND id_hoc_sinh = ? AND so_tien_da_dong = 0',
            whereArgs: [lopId, hsId],
          );

          // 3. Cascade cleanup: Xóa các lịch học cá nhân thuộc về lớp này của học sinh
          final lhcRows = await txn.query(
            DBHelper.tenBangLichHocChung,
            columns: ['id'],
            where: 'id_lop = ?',
            whereArgs: [lopId],
          );
          if (lhcRows.isNotEmpty) {
            removedLhcIds = lhcRows
                .map((r) => r['id'])
                .whereType<num>()
                .map((n) => n.toInt())
                .toList();

            await txn.delete(
              DBHelper.tenBangLichHocCaNhan,
              where:
                  'id_hoc_sinh = ? AND id_lich_hoc_chung IN (${removedLhcIds.map((_) => '?').join(',')})',
              whereArgs: [hsId, ...removedLhcIds],
            );
          }
        }
      });

      if (result > 0) {
        developer.log(
          '✅ Xóa học sinh khỏi lớp thành công! Số bản ghi đã xóa: $result',
          name: 'LopHocSinhService.xoaHocSinhKhoiLop',
        );
        // Đồng bộ xóa Firebase SAU KHI transaction hoàn tất thành công
        FirebaseSyncService.instance.deleteRecordFromCloud(
          tenBang,
          '${hsId}_$lopId',
        );
        for (final lhcId in removedLhcIds) {
          FirebaseSyncService.instance.deleteRecordFromCloud(
            DBHelper.tenBangLichHocCaNhan,
            '${hsId}_$lhcId',
          );
        }
        TuitionEventService().notifyTuitionChanged();
      } else {
        developer.log(
          '⚠️ Cảnh báo: Học sinh ID $hsId không có trong lớp ID $lopId',
          name: 'LopHocSinhService.xoaHocSinhKhoiLop',
          error: {'lopId': lopId, 'hsId': hsId},
        );
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

  Future<StudentClassSummary> docStudentSummary({
    required int studentId,
    required int classId,
    required String month,
  }) async {
    final db = await dbHelper.database;
    final counts = await DiemDanhService().demSoBuoiTheoTrangThai(
      studentId,
      classId,
      month,
    );
    final int nghiCoPhep = counts['nghiCoPhep'] ?? 0;
    final int nghiKhongPhep = counts['nghiKhongPhep'] ?? 0;
    final int tongNghi = nghiCoPhep + nghiKhongPhep;

    final List<Map<String, dynamic>> records = await db.query(
      DBHelper.tenBangThanhToan,
      where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
      whereArgs: [studentId, classId, month],
    );

    int tongThanhToan = 0;
    int soTienDaDong = 0;
    if (records.isNotEmpty) {
      tongThanhToan = records.first['tong_thanh_toan'] as int? ?? 0;
      soTienDaDong = records.first['so_tien_da_dong'] as int? ?? 0;
    }

    final int conNo = tongThanhToan - soTienDaDong;
    final bool isDaDong = records.isNotEmpty && conNo <= 0;
    final bool isKhoiTao = records.isNotEmpty;

    final hsRows = await db.query(
      DBHelper.tenBangHS,
      columns: ['so_buoi_du', 'facebook'],
      where: 'id = ?',
      whereArgs: [studentId],
    );
    int soBuoiDu = 0;
    String? facebook;
    if (hsRows.isNotEmpty) {
      soBuoiDu = hsRows.first['so_buoi_du'] as int? ?? 0;
      facebook = hsRows.first['facebook'] as String?;
    }

    return StudentClassSummary(
      soBuoiDu: soBuoiDu,
      nghiCoPhep: nghiCoPhep,
      nghiKhongPhep: nghiKhongPhep,
      tongNghi: tongNghi,
      facebook: facebook,
      tongThanhToan: tongThanhToan,
      soTienDaDong: soTienDaDong,
      conNo: conNo,
      isDaDong: isDaDong,
      isKhoiTao: isKhoiTao,
    );
  }
}
