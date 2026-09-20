import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/hs.dart';
import '../../models/lich_hoc_chung.dart';
import '../../models/lop.dart';
import '../../models/truong.dart';
import '../../services/danh_gia_buoi_hoc_service.dart';
import '../../services/hoc_sinh_service.dart';
import '../../services/lich_hoc_chung_service.dart';
import '../../services/lop_hoc_sinh_service.dart';
import '../../services/report_service.dart';
import '../../services/student_event_service.dart';
import '../../services/su_kien_hoc_tap_service.dart';
import '../../services/truong_service.dart';
import '../../services/tuition_event_service.dart';
import '../../utils/db.dart';
import '../../widgets/hs_form.dart';
import '../student_schedule_page.dart';
import 'tabs/student_attendance_tab.dart';
import 'tabs/student_evaluation_tab.dart';
import 'tabs/student_overview_tab.dart';
import 'tabs/student_timeline_tab.dart';
import 'tabs/student_tuition_tab.dart';
import 'widgets/student_profile_header.dart';

class StudentClassInfo {
  final List<Lop> dsLop;
  final List<LichHocChung> dsLichHocCaNhan;
  StudentClassInfo(this.dsLop, this.dsLichHocCaNhan);
}

class StudentDetailPage extends ConsumerStatefulWidget {
  final HS hocSinh;
  final int initialTabIndex;

  const StudentDetailPage({
    super.key,
    required this.hocSinh,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends ConsumerState<StudentDetailPage> {
  late HS _currentHocSinh;
  StreamSubscription<HS>? _studentUpdatedSub;
  StreamSubscription<int>? _studentDeletedSub;

  final _hsService = HocSinhService();
  final _truongService = TruongService();
  final _lhsService = LopHocSinhService();
  final _lhcService = LichHocChungService();
  final _suKienService = SuKienHocTapService();

  List<Truong> _danhSachTruong = [];
  bool _dangTaiTruong = true;

  late Future<StudentClassInfo> _classInfoFuture;
  late Future<Map<String, dynamic>> _hocPhiFuture;
  late Future<Map<String, int>> _attendanceStatsFuture;
  late Future<List<dynamic>> _evaluationFuture;
  int _refreshCounter = 0;

  @override
  void initState() {
    super.initState();
    _currentHocSinh = widget.hocSinh;
    _taiDanhSachTruong();
    _refreshAll();

    TuitionEventService().addListener(_onTuitionEventChanged);

    _studentUpdatedSub = StudentEventService().onStudentUpdated.listen((
      updatedHs,
    ) {
      if (updatedHs.id == _currentHocSinh.id && mounted) {
        setState(() {
          _currentHocSinh = updatedHs;
        });
        _refreshAll();
      }
    });

    _studentDeletedSub = StudentEventService().onStudentDeleted.listen((
      deletedId,
    ) {
      if (deletedId == _currentHocSinh.id && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _onTuitionEventChanged() {
    if (mounted) {
      _refreshTuition();
    }
  }

  @override
  void dispose() {
    _studentUpdatedSub?.cancel();
    _studentDeletedSub?.cancel();
    TuitionEventService().removeListener(_onTuitionEventChanged);
    super.dispose();
  }

  void _refreshClassInfo() {
    setState(() {
      _classInfoFuture = _loadStudentClassInfo(_currentHocSinh.id!);
    });
  }

  void _refreshTuition() {
    setState(() {
      _hocPhiFuture = _layDuLieuHocPhi(_currentHocSinh.id!);
    });
  }

  void _refreshAttendance() {
    setState(() {
      _refreshCounter++;
      _attendanceStatsFuture = _layThongKeDiemDanhTongThe(_currentHocSinh.id!);
    });
  }

  void _refreshEvaluation() {
    setState(() {
      _evaluationFuture = Future.wait([
        _suKienService.layLichSuSuKien(_currentHocSinh.id!),
        DanhGiaBuoiHocService().layLichSuDanhGia(_currentHocSinh.id!),
      ]);
    });
  }

  void _refreshAll() {
    _refreshClassInfo();
    _refreshTuition();
    _refreshAttendance();
    _refreshEvaluation();
  }

  Future<StudentClassInfo> _loadStudentClassInfo(int hsId) async {
    final results = await Future.wait([
      _lhsService.docDSLopCuaHS(hsId),
      _lhcService.layLichHocCaNhanCuaHocSinh(hsId),
    ]);
    return StudentClassInfo(
      results[0] as List<Lop>,
      results[1] as List<LichHocChung>,
    );
  }

  Future<void> _taiDanhSachTruong() async {
    try {
      final ds = await _truongService.docTatCaTruong();
      if (mounted) {
        setState(() {
          _danhSachTruong = ds;
          _dangTaiTruong = false;
        });
      }
    } catch (e, st) {
      developer.log('Lỗi tải danh sách trường', error: e, stackTrace: st);
      if (mounted) setState(() => _dangTaiTruong = false);
    }
  }

  Future<Map<String, int>> _layThongKeDiemDanhTongThe(int hsId) async {
    final db = await DBHelper.instance.database;
    final results = await db.rawQuery(
      '''
      SELECT trang_thai, COUNT(*) as count
      FROM ${DBHelper.tenBangDiemDanh}
      WHERE id_hoc_sinh = ?
      GROUP BY trang_thai
    ''',
      [hsId],
    );

    int coMat = 0;
    int nghiCoPhep = 0;
    int nghiKhongPhep = 0;
    int hocBu = 0;
    int tre = 0;

    for (var row in results) {
      final trangThai = row['trang_thai'] as String;
      final count = row['count'] as int;
      if (trangThai == 'Có mặt') {
        coMat += count;
      } else if (trangThai == 'Trễ') {
        tre += count;
        coMat += count;
      } else if (trangThai == 'Nghỉ có phép') {
        nghiCoPhep += count;
      } else if (trangThai == 'Nghỉ không phép') {
        nghiKhongPhep += count;
      } else if (trangThai == 'Học bù') {
        hocBu += count;
      }
    }
    return {
      'coMat': coMat,
      'nghiCoPhep': nghiCoPhep,
      'nghiKhongPhep': nghiKhongPhep,
      'hocBu': hocBu,
      'tre': tre,
    };
  }

  Future<Map<String, dynamic>> _layDuLieuHocPhi(int hsId) async {
    final db = await DBHelper.instance.database;
    final currentMonthStr =
        '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';

    try {
      final classInfo = await _classInfoFuture;
      final reportService = ReportService();
      for (var lop in classInfo.dsLop) {
        if (lop.id != null) {
          await reportService.layBaoCaoHocPhiThang(
            lop.id!,
            currentMonthStr,
            persist: false,
          );
        }
      }
    } catch (e, st) {
      developer.log('Lỗi tính báo cáo học phí', error: e, stackTrace: st);
    }

    final List<Map<String, dynamic>> records = await db.rawQuery(
      '''
      SELECT t.id_lop, t.thang, l.ten as ten_lop, t.tong_thanh_toan, t.so_tien_da_dong, t.ngay_thanh_toan 
      FROM ${DBHelper.tenBangThanhToan} t
      JOIN ${DBHelper.tenBangLop} l ON t.id_lop = l.id
      WHERE t.id_hoc_sinh = ?
      ORDER BY t.thang DESC
    ''',
      [hsId],
    );

    List<Map<String, dynamic>> conNo = [];
    List<Map<String, dynamic>> lichSu = [];

    for (var r in records) {
      final tongThanhToan = r['tong_thanh_toan'] as int? ?? 0;
      final soTienDaDong = r['so_tien_da_dong'] as int? ?? 0;
      final tienNo = tongThanhToan - soTienDaDong;
      final thang = r['thang'] as String;

      if (tienNo > 0 && thang.compareTo(currentMonthStr) <= 0) {
        conNo.add({
          'id_lop': r['id_lop'],
          'thang': thang,
          'ten_lop': r['ten_lop'],
          'tong_thanh_toan': tongThanhToan,
          'so_tien_da_dong': soTienDaDong,
          'tien_no': tienNo,
        });
      }
    }

    final List<Map<String, dynamic>> rawTxRecords = await db.rawQuery(
      '''
      SELECT pt.id, pt.month, pt.amount, pt.status, pt.transaction_id, pt.created_at, l.ten as ten_lop
      FROM payment_transactions pt
      LEFT JOIN ${DBHelper.tenBangLop} l ON pt.lop_id = l.id
      WHERE pt.hoc_sinh_id = ?
      ORDER BY pt.created_at DESC, pt.id DESC
    ''',
      [hsId],
    );

    if (rawTxRecords.isNotEmpty) {
      for (var tx in rawTxRecords) {
        lichSu.add({
          'thang': tx['month'],
          'ten_lop': tx['ten_lop'] ?? '',
          'so_tien_da_dong': tx['amount'],
          'ngay_thanh_toan': tx['created_at'],
          'status': tx['status'],
          'transaction_id': tx['transaction_id'],
        });
      }
    } else {
      for (var r in records) {
        final soTienDaDong = r['so_tien_da_dong'] as int? ?? 0;
        if (soTienDaDong > 0) {
          lichSu.add({
            'thang': r['thang'] as String,
            'ten_lop': r['ten_lop'],
            'tong_thanh_toan': r['tong_thanh_toan'],
            'so_tien_da_dong': soTienDaDong,
            'ngay_thanh_toan': r['ngay_thanh_toan'],
          });
        }
      }
    }

    return {
      'current_month': currentMonthStr,
      'con_no': conNo,
      'lich_su': lichSu,
    };
  }

  void _moFormSuaHS() async {
    if (_dangTaiTruong) return;

    final updatedHs = await showHocSinhFormDialog(
      context: context,
      hocSinh: _currentHocSinh,
      danhSachTruong: _danhSachTruong,
      hsService: _hsService,
    );

    if (updatedHs != null && mounted) {
      setState(() {
        _currentHocSinh = updatedHs;
      });
      _refreshAll();
      final isVi = Localizations.localeOf(context).languageCode == 'vi';
      _hienThongBao(
        isVi ? 'Thành công' : 'Success',
        isVi
            ? 'Đã cập nhật thông tin học sinh!'
            : 'Student information updated!',
      );
    }
  }

  void _xoaHocSinh() async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isVi ? 'Xác nhận xóa' : 'Confirm deletion'),
        content: Text(
          isVi
              ? 'Bạn có chắc chắn muốn xóa học sinh "${_currentHocSinh.ten}"?'
              : 'Are you sure you want to delete student "${_currentHocSinh.ten}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isVi ? 'Xóa' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final hsId = _currentHocSinh.id!;
        await _hsService.xoaHocSinh(hsId);
        StudentEventService().notifyStudentDeleted(hsId);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          _hienThongBao(
            isVi ? 'Lỗi' : 'Error',
            isVi ? 'Không thể xóa học sinh: $e' : 'Failed to delete: $e',
          );
        }
      }
    }
  }

  void _moLichHoc() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentSchedulePage(
          studentId: _currentHocSinh.id!,
          studentName: _currentHocSinh.ten,
        ),
      ),
    ).then((_) => _refreshAll());
  }

  void _hienThongBao(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              Localizations.localeOf(context).languageCode == 'vi'
                  ? 'Đóng'
                  : 'Close',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    return DefaultTabController(
      length: 5,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          titleSpacing: 0,
          elevation: 0,
          leading: BackButton(color: theme.colorScheme.onSurface),
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            _currentHocSinh.ten,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        body: Column(
          children: [
            // Student Profile Header V2
            StudentProfileHeader(
              hocSinh: _currentHocSinh,
              classInfoFuture: _classInfoFuture,
              hocPhiFuture: _hocPhiFuture,
              onEditInfo: _moFormSuaHS,
              onSchedule: _moLichHoc,
              onRefresh: () {
                _refreshAll();
                _hienThongBao(
                  isVi ? 'Thông báo' : 'Notification',
                  isVi ? 'Đã làm mới dữ liệu.' : 'Data refreshed.',
                );
              },
              onDelete: _xoaHocSinh,
            ),

            // Tab Bar V2
            Material(
              color: theme.colorScheme.surface,
              elevation: 1,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: theme.colorScheme.primary,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(text: isVi ? 'Tổng quan' : 'Overview'),
                  const Tab(text: 'Timeline'),
                  Tab(text: isVi ? 'Điểm danh' : 'Attendance'),
                  Tab(text: isVi ? 'Học phí' : 'Tuition'),
                  Tab(text: isVi ? 'Đánh giá' : 'Evaluation'),
                ],
              ),
            ),

            // Tab Views V2
            Expanded(
              child: TabBarView(
                children: [
                  StudentOverviewTab(
                    hocSinh: _currentHocSinh,
                    classInfoFuture: _classInfoFuture,
                    attendanceStatsFuture: _attendanceStatsFuture,
                    hocPhiFuture: _hocPhiFuture,
                    onRefresh: _refreshAll,
                  ),
                  StudentTimelineTab(studentId: _currentHocSinh.id!),
                  StudentAttendanceTab(
                    hocSinh: _currentHocSinh,
                    refreshTrigger: _refreshCounter,
                  ),
                  StudentTuitionTab(
                    hocSinh: _currentHocSinh,
                    hocPhiFuture: _hocPhiFuture,
                    onRefresh: _refreshTuition,
                  ),
                  StudentEvaluationTab(evaluationFuture: _evaluationFuture),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
