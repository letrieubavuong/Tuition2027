// File: lib/services/nhan_xet_service.dart

import 'dart:developer' as developer;
import 'package:sqflite/sqflite.dart';
import '../models/hs_lop_view_model.dart';
import '../models/nhan_xet_thang.dart';
import '../utils/db.dart';
import 'diem_danh_service.dart';
import 'danh_gia_buoi_hoc_service.dart';
import 'firebase_sync_service.dart';

import '../utils/attendance_calculator.dart';
import '../utils/student_status.dart';

class NhanXetService {
  final String _tenBang = DBHelper.tenBangNhanXetThang;
  final DiemDanhService _diemDanhService = DiemDanhService();
  final String _tenBangDGBH = DBHelper.tenBangDanhGiaBuoiHoc;

  Future<Database> get _database async {
    return await DBHelper.instance.database;
  }

  /// Push log an toàn lên Firebase không nuốt exception lặng lẽ
  void _pushFirebaseRecord(
    String table,
    String key,
    Map<String, dynamic> data,
  ) {
    FirebaseSyncService.instance.pushRecordToCloud(table, key, data).catchError(
      (e, st) {
        developer.log(
          'Firebase sync error [$table / $key]: $e',
          error: e,
          stackTrace: st,
        );
      },
    );
  }

  /// Công thức điểm chuyên cần thống nhất (Single Source of Truth qua AttendanceCalculator)
  static double tinhDiemChuyenCanFromCounts(int coMat, int nghiCP, int nghiKP) {
    return AttendanceCalculator.tinhDiemChuyenCan(
      coMat: coMat,
      nghiCP: nghiCP,
      nghiKP: nghiKP,
    );
  }

  // Lấy hoặc tạo mới một bản ghi nhận xét (Draft mode - không tự động ghi DB trên câu lệnh đọc)
  Future<NhanXetThang> layHoacTaoNhanXet(
    int idHocSinh,
    int idLop,
    String thang,
  ) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'id_hoc_sinh = ? AND id_lop = ? AND thang = ?',
      whereArgs: [idHocSinh, idLop, thang],
    );

    if (maps.isNotEmpty) {
      return NhanXetThang.fromMap(maps.first);
    } else {
      // Nếu chưa có trong DB, trả về một bản ghi mặc định trong bộ nhớ (Draft mode)
      final nhanXetMoi = NhanXetThang(
        idHocSinh: idHocSinh,
        idLop: idLop,
        thang: thang,
      );
      // Tự động tính điểm chuyên cần lần đầu theo công thức chuẩn
      nhanXetMoi.diemChuyenCan = await _tinhDiemChuyenCan(
        idHocSinh,
        idLop,
        thang,
      );
      // Tính luôn xếp hạng
      nhanXetMoi.xepHang = _tinhToanXepHang(nhanXetMoi.diemTrungBinh);
      return nhanXetMoi;
    }
  }

  // Cập nhật hoặc lưu mới một bản ghi nhận xét (An toàn với manual override)
  Future<int> capNhatNhanXet(NhanXetThang nhanXet) async {
    final db = await _database;
    // Đánh dấu đây là dữ liệu giáo viên nhập tay/chỉnh sửa trực tiếp
    nhanXet.isManualOverride = true;
    nhanXet.diemChuyenCan = nhanXet.diemChuyenCan.clamp(0.0, 10.0);
    nhanXet.diemThaiDo = nhanXet.diemThaiDo.clamp(0.0, 10.0);
    nhanXet.diemBaiTap = nhanXet.diemBaiTap.clamp(0.0, 10.0);
    nhanXet.diemKiemTra = nhanXet.diemKiemTra.clamp(0.0, 10.0);

    // Tính lại xếp hạng trước khi lưu
    nhanXet.xepHang = _tinhToanXepHang(nhanXet.diemTrungBinh);
    final mapData = nhanXet.toMap();

    if (nhanXet.id != null) {
      final result = await db.update(
        _tenBang,
        mapData,
        where: 'id = ?',
        whereArgs: [nhanXet.id],
      );
      if (result > 0) {
        _pushFirebaseRecord(_tenBang, nhanXet.id.toString(), mapData);
      }
      return result;
    } else {
      final id = await db.insert(
        _tenBang,
        mapData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (id > 0) {
        nhanXet.id = id;
        _pushFirebaseRecord(_tenBang, id.toString(), nhanXet.toMap());
      }
      return id;
    }
  }

  // Lấy tất cả nhận xét của một lớp trong một tháng
  Future<List<NhanXetThang>> layDanhSachNhanXet(int idLop, String thang) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tenBang,
      where: 'id_lop = ? AND thang = ?',
      whereArgs: [idLop, thang],
    );
    return maps.map((map) => NhanXetThang.fromMap(map)).toList();
  }

  // Tự động tổng hợp điểm từ các buổi học và cập nhật cho cả lớp (High-Speed Batch Pipeline)
  Future<void> tongHopVaCapNhatNhanXetThang(
    List<HSLopViewModel> dsHocSinh,
    int idLop,
    String thang,
  ) async {
    if (dsHocSinh.isEmpty || idLop <= 0) return;

    final db = await _database;

    final parts = thang.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final startDateStr = '$thang-01 00:00:00';

    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endDateStr =
        '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01 00:00:00';

    // 1. Prefetch tất cả nhận xét tháng hiện có của lớp trong tháng
    final List<Map<String, dynamic>> existingNxMaps = await db.query(
      _tenBang,
      where: 'id_lop = ? AND thang = ?',
      whereArgs: [idLop, thang],
    );
    final Map<int, NhanXetThang> existingNxMap = {
      for (var m in existingNxMaps)
        if (m['id_hoc_sinh'] != null)
          (m['id_hoc_sinh'] as num).toInt(): NhanXetThang.fromMap(m),
    };

    // 2. Prefetch tất cả các điểm danh của lớp trong tháng
    final List<Map<String, dynamic>> allSessions = await db.query(
      DBHelper.tenBangDiemDanh,
      columns: ['id', 'id_hoc_sinh', 'trang_thai', 'gio_diem_danh'],
      where: 'id_lop = ? AND gio_diem_danh >= ? AND gio_diem_danh < ?',
      whereArgs: [idLop, startDateStr, endDateStr],
    );

    // Group điểm danh theo id_hoc_sinh trong RAM
    final Map<int, List<Map<String, dynamic>>> studentSessionsMap = {};
    for (var sess in allSessions) {
      final hsId = sess['id_hoc_sinh'] as int?;
      if (hsId != null) {
        studentSessionsMap.putIfAbsent(hsId, () => []).add(sess);
      }
    }

    // 3. Prefetch danh sách id_diem_danh đã được đánh giá trong danh_gia_buoi_hoc (Chỉ 1 SQL IN query)
    final List<int> allSessionIds = allSessions
        .map((s) => s['id'] as int)
        .toList();
    final Set<int> evaluatedSessionIds = {};
    if (allSessionIds.isNotEmpty) {
      final placeholders = List.filled(allSessionIds.length, '?').join(',');
      final List<Map<String, dynamic>> evalRows = await db.rawQuery(
        'SELECT DISTINCT id_diem_danh FROM $_tenBangDGBH WHERE id_diem_danh IN ($placeholders)',
        allSessionIds,
      );
      for (var r in evalRows) {
        if (r['id_diem_danh'] != null) {
          evaluatedSessionIds.add((r['id_diem_danh'] as num).toInt());
        }
      }
    }

    // 4. (No fake inserts for unevaluated sessions - preserving pure no-data semantics)

    // 5. Query AVG điểm từ danh_gia_buoi_hoc theo id_hoc_sinh bằng 1 câu SQL GROUP BY duy nhất
    final String sqlAvg =
        '''
      SELECT 
        DD.id_hoc_sinh,
        AVG(DGBH.diem_thai_do) as avg_thai_do,
        AVG(DGBH.diem_hieu_bai) as avg_hieu_bai,
        AVG(DGBH.diem_bai_tap) as avg_bai_tap
      FROM $_tenBangDGBH DGBH
      JOIN ${DBHelper.tenBangDiemDanh} DD ON DGBH.id_diem_danh = DD.id
      WHERE DD.id_lop = ? 
        AND DD.gio_diem_danh >= ? 
        AND DD.gio_diem_danh < ? 
        AND (DGBH.diem_thai_do IS NOT NULL OR DGBH.diem_hieu_bai IS NOT NULL OR DGBH.diem_bai_tap IS NOT NULL)
      GROUP BY DD.id_hoc_sinh
    ''';

    final List<Map<String, dynamic>> avgResults = await db.rawQuery(sqlAvg, [
      idLop,
      startDateStr,
      endDateStr,
    ]);

    final Map<int, Map<String, double>> studentAvgMap = {};
    for (var row in avgResults) {
      final hsId = (row['id_hoc_sinh'] as num).toInt();
      studentAvgMap[hsId] = {
        'avg_thai_do': (row['avg_thai_do'] as num?)?.toDouble() ?? 0.0,
        'avg_hieu_bai': (row['avg_hieu_bai'] as num?)?.toDouble() ?? 0.0,
        'avg_bai_tap': (row['avg_bai_tap'] as num?)?.toDouble() ?? 0.0,
      };
    }

    // 6. Tính toán điểm cho tất cả học sinh trong RAM và Batch Upsert SQLite an toàn
    final List<NhanXetThang> listToSave = [];

    for (var hs in dsHocSinh) {
      if (hs.id == null) continue;
      final hsId = hs.id!;

      final nhanXetThang =
          existingNxMap[hsId] ??
          NhanXetThang(idHocSinh: hsId, idLop: idLop, thang: thang);

      final sessions = studentSessionsMap[hsId] ?? [];
      int coMat = 0;
      int nghiCP = 0;
      int nghiKP = 0;

      for (var s in sessions) {
        final st = s['trang_thai'] as String?;
        if (st == 'Có mặt') {
          coMat++;
        } else if (st == 'Nghỉ có phép') {
          nghiCP++;
        } else if (st == 'Nghỉ không phép') {
          nghiKP++;
        }
      }

      final tongSoBuoi = coMat + nghiCP + nghiKP;

      if (tongSoBuoi == 0) {
        nhanXetThang.diemChuyenCan = 0;
        if (!nhanXetThang.isManualOverride) {
          nhanXetThang.diemThaiDo = 0;
          nhanXetThang.diemBaiTap = 0;
          nhanXetThang.diemKiemTra = 0;
        }
        nhanXetThang.xepHang = 'Chưa xếp hạng';
      } else {
        nhanXetThang.diemChuyenCan = tinhDiemChuyenCanFromCounts(
          coMat,
          nghiCP,
          nghiKP,
        );

        if (!nhanXetThang.isManualOverride) {
          final avgMap = studentAvgMap[hsId];
          if (avgMap != null) {
            nhanXetThang.diemThaiDo = (avgMap['avg_thai_do'] ?? 0.0).clamp(
              0.0,
              10.0,
            );
            nhanXetThang.diemKiemTra = (avgMap['avg_hieu_bai'] ?? 0.0).clamp(
              0.0,
              10.0,
            );
            nhanXetThang.diemBaiTap = (avgMap['avg_bai_tap'] ?? 0.0).clamp(
              0.0,
              10.0,
            );
          } else {
            nhanXetThang.diemThaiDo = 0.0;
            nhanXetThang.diemBaiTap = 0.0;
            nhanXetThang.diemKiemTra = 0.0;
          }
        }

        nhanXetThang.xepHang = _tinhToanXepHang(nhanXetThang.diemTrungBinh);

        if (nhanXetThang.nhanXetChung == null ||
            nhanXetThang.nhanXetChung!.isEmpty ||
            nhanXetThang.nhanXetChung == 'Con ngoan, học tập chăm chỉ.' ||
            nhanXetThang.nhanXetChung!.startsWith('Trong tháng này, em ')) {
          nhanXetThang.nhanXetChung = sinhNhanXetThangTuDong(
            nhanXetThang.diemChuyenCan,
            nhanXetThang.diemThaiDo,
            nhanXetThang.diemKiemTra,
            nhanXetThang.diemBaiTap,
          );
        }
      }

      listToSave.add(nhanXetThang);
    }

    // 7. Thực hiện batch insert/update trong SQLite Transaction duy nhất (bảo toàn primary key ID)
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var nx in listToSave) {
        final mapData = nx.toMap();
        if (nx.id != null) {
          batch.update(_tenBang, mapData, where: 'id = ?', whereArgs: [nx.id]);
        } else {
          batch.insert(
            _tenBang,
            mapData,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      await batch.commit(noResult: true);
    });
  }

  /// Tự động sinh nhận xét đánh giá tháng dựa trên điểm số chuyên cần, thái độ, hiểu bài, bài tập.
  String sinhNhanXetThangTuDong(
    double chuyenCan,
    double thaiDo,
    double hieuBai,
    double baiTap,
  ) {
    String nxChuyenCan = '';
    if (chuyenCan >= 9.0) {
      nxChuyenCan = 'đi học rất chuyên cần và đầy đủ';
    } else if (chuyenCan >= 7.0) {
      nxChuyenCan = 'đi học tương đối đầy đủ';
    } else {
      nxChuyenCan = 'vắng mặt nhiều buổi học, cần đi học đều đặn hơn';
    }

    String nxThaiDo = '';
    if (thaiDo >= 5.0) {
      nxThaiDo =
          'thái độ học tập trên lớp rất xuất sắc, luôn hăng hái phát biểu';
    } else if (thaiDo >= 1.5) {
      nxThaiDo = 'thái độ học tập tốt, tập trung nghe giảng';
    } else if (thaiDo >= 0.0) {
      nxThaiDo = 'ngoan ngoãn, thực hiện đầy đủ hướng dẫn của thầy cô';
    } else if (thaiDo >= -2.5) {
      nxThaiDo = 'đôi khi còn chưa tập trung hoặc nói chuyện riêng trong lớp';
    } else {
      nxThaiDo =
          'thường xuyên làm việc riêng, cần nghiêm túc chấn chỉnh thái độ học';
    }

    String nxHieuBai = '';
    if (hieuBai >= 5.0) {
      nxHieuBai = 'tiếp thu kiến thức cực tốt, kết quả kiểm tra rất xuất sắc';
    } else if (hieuBai >= 1.5) {
      nxHieuBai = 'hiểu bài tốt, nắm vững kiến thức trọng tâm';
    } else if (hieuBai >= 0.0) {
      nxHieuBai = 'hiểu bài ở mức cơ bản, cần ôn tập thêm';
    } else if (hieuBai >= -2.5) {
      nxHieuBai = 'tiếp thu bài còn chậm, cần kiên nhẫn làm nhiều bài tập hơn';
    } else {
      nxHieuBai = 'gặp nhiều khó khăn khi tiếp thu kiến thức, cần kèm cặp thêm';
    }

    String nxBaiTap = '';
    if (baiTap >= 5.0) {
      nxBaiTap =
          'hoàn thành bài tập về nhà rất tốt, trình bày khoa học và cẩn thận';
    } else if (baiTap >= 1.5) {
      nxBaiTap = 'làm bài tập đầy đủ trước khi lên lớp';
    } else if (baiTap >= 0.0) {
      nxBaiTap = 'có làm bài tập nhưng đôi lúc còn thiếu hoặc làm chưa kỹ';
    } else if (baiTap >= -2.5) {
      nxBaiTap = 'làm bài tập về nhà còn đối phó hoặc nộp muộn';
    } else {
      nxBaiTap = 'không làm bài tập về nhà, cần tự giác hơn';
    }

    return 'Trong tháng này, em $nxChuyenCan. Về học tập, em có $nxThaiDo, $nxHieuBai và $nxBaiTap.';
  }

  // Hàm tính điểm chuyên cần
  Future<double> _tinhDiemChuyenCan(
    int idHocSinh,
    int idLop,
    String thang,
  ) async {
    final counts = await _diemDanhService.demSoBuoiTheoTrangThai(
      idHocSinh,
      idLop,
      thang,
    );
    final coMat = counts['coMat'] ?? 0;
    final nghiCP = counts['nghiCoPhep'] ?? 0;
    final nghiKP = counts['nghiKhongPhep'] ?? 0;
    return tinhDiemChuyenCanFromCounts(coMat, nghiCP, nghiKP);
  }

  String tinhXepHang(double cc, double td, double kt, double bt) {
    final double dtb = (cc + td + kt + bt) / 4.0;
    return _tinhToanXepHang(dtb);
  }

  // Hàm tính toán xếp hạng theo game Liên Quân Mobile (Đặc tả: TB = 0.0 thì xếp hạng Vàng)
  String _tinhToanXepHang(double diemTrungBinh) {
    if (diemTrungBinh == 0.0) {
      return 'Vàng'; // Tổng trung bình bằng 0.0 thì xếp hạng Vàng (Giữ nguyên 100% theo đặc tả nghiệp vụ)
    }

    if (diemTrungBinh >= 8.5) {
      return 'Thách Đấu';
    } else if (diemTrungBinh >= 7.0) {
      return 'Cao Thủ';
    } else if (diemTrungBinh >= 5.5) {
      return 'Tinh Anh';
    } else if (diemTrungBinh >= 4.0) {
      return 'Kim Cương';
    } else if (diemTrungBinh >= 2.5) {
      return 'Bạch Kim';
    } else if (diemTrungBinh >= 1.0) {
      return 'Vàng';
    } else if (diemTrungBinh >= -2.0) {
      return 'Bạc';
    } else {
      return 'Đồng';
    }
  }

  // Lấy bảng xếp hạng học sinh theo Khối (Grade) trong tháng YYYY-MM
  Future<List<Map<String, dynamic>>> layBangXepHangTheoKhoi(
    int khoi,
    String thang,
  ) async {
    final db = await _database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      '''
      SELECT 
        HS.id as id_hoc_sinh,
        HS.ten as ten_hoc_sinh,
        L.ten as ten_lop,
        L.id as id_lop,
        MAX(NX.diem_chuyen_can) as diem_chuyen_can,
        MAX(NX.diem_thai_do) as diem_thai_do,
        MAX(NX.diem_bai_tap) as diem_bai_tap,
        MAX(NX.diem_kiem_tra) as diem_kiem_tra,
        NX.xep_hang
      FROM ${DBHelper.tenBangHS} HS
      JOIN ${DBHelper.tenBangLopHS} LHS ON HS.id = LHS.id_hoc_sinh
      JOIN ${DBHelper.tenBangLop} L ON LHS.id_lop = L.id
      LEFT JOIN $_tenBang NX ON HS.id = NX.id_hoc_sinh AND L.id = NX.id_lop AND NX.thang = ?
      WHERE L.khoi = ? 
        AND ${StudentStatus.activeSqlCondition}
      GROUP BY HS.id
    ''',
      [thang, khoi],
    );

    // Tiến hành ánh xạ dữ liệu và tính toán điểm trung bình
    final List<Map<String, dynamic>> processed = results.map((row) {
      final double cc = (row['diem_chuyen_can'] as num?)?.toDouble() ?? 0.0;
      final double td = (row['diem_thai_do'] as num?)?.toDouble() ?? 0.0;
      final double bt = (row['diem_bai_tap'] as num?)?.toDouble() ?? 0.0;
      final double kt = (row['diem_kiem_tra'] as num?)?.toDouble() ?? 0.0;
      final double dtb = (cc + td + bt + kt) / 4.0;
      final String rankStr = row['xep_hang'] as String? ?? 'Đồng';

      return {
        'id_hoc_sinh': row['id_hoc_sinh'],
        'ten_hoc_sinh': row['ten_hoc_sinh'],
        'ten_lop': row['ten_lop'],
        'id_lop': row['id_lop'],
        'diem_trung_binh': dtb,
        'xep_hang': rankStr,
      };
    }).toList();

    // Sắp xếp theo điểm trung bình giảm dần, nếu bằng điểm sắp xếp phụ theo tên (A-Z)
    processed.sort((a, b) {
      final cmp = (b['diem_trung_binh'] as double).compareTo(
        a['diem_trung_binh'] as double,
      );
      if (cmp != 0) return cmp;
      final nameA = (a['ten_hoc_sinh'] as String?) ?? '';
      final nameB = (b['ten_hoc_sinh'] as String?) ?? '';
      return nameA.compareTo(nameB);
    });
    return processed;
  }

  /// High-speed Batch Summary for Class Evaluation Dashboard
  Future<List<StudentEvaluationSummaryViewModel>>
  getClassEvaluationBatchSummary({
    required int classId,
    required String month,
    required List<HSLopViewModel> students,
  }) async {
    if (students.isEmpty) return [];

    final db = await _database;
    final parts = month.split('-');
    final year = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final startDateStr = '$month-01 00:00:00';
    final nextM = m == 12 ? 1 : m + 1;
    final nextY = m == 12 ? year + 1 : year;
    final endDateStr = '$nextY-${nextM.toString().padLeft(2, '0')}-01 00:00:00';

    final studentIds = students.map((s) => s.id!).toList();
    final placeholders = List.filled(studentIds.length, '?').join(',');

    // 1. Query all attendance in month
    final attendanceRows = await db.rawQuery(
      '''
      SELECT id, id_hoc_sinh, trang_thai, gio_diem_danh
      FROM ${DBHelper.tenBangDiemDanh}
      WHERE id_lop = ? AND id_hoc_sinh IN ($placeholders)
        AND gio_diem_danh >= ? AND gio_diem_danh < ?
      ORDER BY gio_diem_danh DESC
    ''',
      [classId, ...studentIds, startDateStr, endDateStr],
    );

    final Map<int, List<Map<String, dynamic>>> attByStudent = {};
    for (var r in attendanceRows) {
      final sId = r['id_hoc_sinh'] as int;
      attByStudent.putIfAbsent(sId, () => []).add(r);
    }

    // 2. Query evaluation scores per session
    final List<int> allAttIds = attendanceRows
        .map((r) => r['id'] as int)
        .toList();
    final Map<int, Map<String, dynamic>> evalByAttId = {};
    if (allAttIds.isNotEmpty) {
      final attPlaceholders = List.filled(allAttIds.length, '?').join(',');
      final evalRows = await db.rawQuery('''
        SELECT id_diem_danh, diem_thai_do, diem_hieu_bai, diem_bai_tap, nhan_xet
        FROM $_tenBangDGBH
        WHERE id_diem_danh IN ($attPlaceholders)
      ''', allAttIds);
      for (var r in evalRows) {
        final attId = r['id_diem_danh'] as int;
        evalByAttId[attId] = r;
      }
    }

    // 3. Query monthly evaluation overrides
    final nxList = await layDanhSachNhanXet(classId, month);
    final Map<int, NhanXetThang> nxMap = {
      for (var nx in nxList) nx.idHocSinh: nx,
    };

    final List<StudentEvaluationSummaryViewModel> summaries = [];

    for (var hs in students) {
      final sId = hs.id!;
      final records = attByStudent[sId] ?? [];

      int presentCount = 0;
      int lateCount = 0;
      int excusedCount = 0;
      int unexcusedCount = 0;

      final List<String> recent5 = [];
      int evalCount = 0;
      double sumThaiDo = 0;
      double sumHieuBai = 0;
      double sumBaiTap = 0;
      int missingHw = 0;

      for (int i = 0; i < records.length; i++) {
        final r = records[i];
        final st = r['trang_thai'] as String? ?? '';
        final attId = r['id'] as int;

        if (i < 5) {
          recent5.add(st);
        }

        if (st == 'Có mặt') {
          presentCount++;
        } else if (st.contains('Trễ') || st.contains('muộn')) {
          presentCount++;
          lateCount++;
        } else if (st == 'Nghỉ có phép') {
          excusedCount++;
        } else if (st == 'Nghỉ không phép') {
          unexcusedCount++;
        }

        final eval = evalByAttId[attId];
        if (eval != null) {
          final td = (eval['diem_thai_do'] as num?)?.toDouble();
          final hb = (eval['diem_hieu_bai'] as num?)?.toDouble();
          final bt = (eval['diem_bai_tap'] as num?)?.toDouble();

          if (td != null || hb != null || bt != null) {
            evalCount++;
            if (td != null) sumThaiDo += td;
            if (hb != null) sumHieuBai += hb;
            if (bt != null) {
              sumBaiTap += bt;
              if (bt < 0) missingHw++;
            }
          }
        }
      }

      final totalSessions = presentCount + excusedCount + unexcusedCount;
      final attRate = totalSessions > 0
          ? (presentCount / totalSessions) * 100.0
          : 100.0;

      final nxThang =
          nxMap[sId] ??
          NhanXetThang(idHocSinh: sId, idLop: classId, thang: month);
      if (!nxThang.isManualOverride && totalSessions > 0) {
        nxThang.diemChuyenCan = (attRate / 10.0).clamp(0.0, 10.0);
      }

      String? warning;
      if (unexcusedCount > 0) {
        warning = '⚠ Vắng $unexcusedCount buổi không phép';
      } else if (lateCount > 0) {
        warning = '⚠ $lateCount lần đi muộn';
      } else if (missingHw > 0) {
        warning = '⚠ Thiếu $missingHw lần BTVN';
      }

      final hasData = evalCount > 0 || totalSessions > 0;
      final needsAttention =
          unexcusedCount > 0 ||
          lateCount >= 2 ||
          missingHw >= 2 ||
          attRate < 80;

      summaries.add(
        StudentEvaluationSummaryViewModel(
          studentId: sId,
          studentName: hs.ten,
          attendanceRate: attRate,
          totalSessions: totalSessions,
          presentCount: presentCount,
          lateCount: lateCount,
          excusedAbsenceCount: excusedCount,
          unexcusedAbsenceCount: unexcusedCount,
          avgAttitudeScore: evalCount > 0 ? (sumThaiDo / evalCount) : null,
          avgUnderstandingScore: evalCount > 0
              ? (sumHieuBai / evalCount)
              : null,
          avgHomeworkScore: evalCount > 0 ? (sumBaiTap / evalCount) : null,
          missingHomeworkCount: missingHw,
          recent5Sessions: recent5,
          warningBadge: warning,
          hasEnoughData: hasData,
          needsAttention: needsAttention,
          nhanXetThang: nxThang,
        ),
      );
    }

    return summaries;
  }
}

class StudentEvaluationSummaryViewModel {
  final int studentId;
  final String studentName;
  final double attendanceRate;
  final int totalSessions;
  final int presentCount;
  final int lateCount;
  final int excusedAbsenceCount;
  final int unexcusedAbsenceCount;
  final double? avgAttitudeScore;
  final double? avgUnderstandingScore;
  final double? avgHomeworkScore;
  final int missingHomeworkCount;
  final List<String> recent5Sessions;
  final String? warningBadge;
  final bool hasEnoughData;
  final bool needsAttention;
  final NhanXetThang nhanXetThang;

  StudentEvaluationSummaryViewModel({
    required this.studentId,
    required this.studentName,
    required this.attendanceRate,
    required this.totalSessions,
    required this.presentCount,
    required this.lateCount,
    required this.excusedAbsenceCount,
    required this.unexcusedAbsenceCount,
    this.avgAttitudeScore,
    this.avgUnderstandingScore,
    this.avgHomeworkScore,
    required this.missingHomeworkCount,
    required this.recent5Sessions,
    this.warningBadge,
    required this.hasEnoughData,
    required this.needsAttention,
    required this.nhanXetThang,
  });
}
