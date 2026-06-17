// File: lib/screens/hs_detail.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

// Import Models
import '../models/su_kien_lich_su_view_model.dart';
import '../models/su_kien_hoc_tap.dart';
import '../models/hs.dart';
import '../models/truong.dart';
import '../models/lop.dart';
import '../models/lich_hoc_chung.dart';
import '../models/danh_gia_lich_su_view_model.dart';

// Import Services
import '../services/su_kien_hoc_tap_service.dart';
import '../services/hoc_sinh_service.dart';
import '../services/truong_service.dart';
import '../services/lich_hoc_chung_service.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/report_service.dart';
import '../services/danh_gia_buoi_hoc_service.dart';
import '../utils/db.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../widgets/thu_tien_hoc_phi_dialog.dart';

// Import Widgets & Screens
import '../widgets/hs_form.dart';
import '../widgets/bao_cao_diem_danh_widget.dart';
import 'lop_detail.dart';

class HSDetail extends ConsumerStatefulWidget {
  final HS hocSinh;
  const HSDetail({super.key, required this.hocSinh});

  @override
  ConsumerState<HSDetail> createState() => _HSDetailState();
}

class _StudentClassInfo {
  final List<Lop> dsLop;
  final List<LichHocChung> dsLichHocCaNhan;
  _StudentClassInfo(this.dsLop, this.dsLichHocCaNhan);
}

class _HSDetailState extends ConsumerState<HSDetail> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;

  late HS _currentHocSinh;

  final _hsService = HocSinhService();
  final _truongService = TruongService();
  final _lhsService = LopHocSinhService();
  final _lhcService = LichHocChungService();
  final _suKienService = SuKienHocTapService();

  List<Truong> _danhSachTruong = [];
  bool _dangTaiTruong = true;
  late Future<_StudentClassInfo> _classInfoFuture;
  late Future<Map<String, dynamic>> _hocPhiFuture;
  int _refreshCounter = 0;
  late Future<Map<String, int>> _attendanceStatsFuture;

  @override
  void initState() {
    super.initState();
    _currentHocSinh = widget.hocSinh;
    _taiDanhSachTruong();
    _lamMoiDuLieuLop();
  }

  void _lamMoiDuLieuLop() {
    setState(() {
      _refreshCounter++;
      _classInfoFuture = _loadStudentClassInfo(_currentHocSinh.id!);
      _hocPhiFuture = _layDuLieuHocPhi(_currentHocSinh.id!);
      _attendanceStatsFuture = _layThongKeDiemDanhTongThe(_currentHocSinh.id!);
    });
  }

  Future<_StudentClassInfo> _loadStudentClassInfo(int hsId) async {
    final results = await Future.wait([
      _lhsService.docDSLopCuaHS(hsId),
      _lhcService.layLichHocCaNhanCuaHocSinh(hsId),
    ]);
    return _StudentClassInfo(
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
    } catch (e) {
      if (mounted) setState(() => _dangTaiTruong = false);
    }
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
      final isVi = Localizations.localeOf(context).languageCode == 'vi';
      _hienThongBao(isVi ? 'Thành công' : 'Success', isVi ? 'Đã cập nhật thông tin học sinh!' : 'Student information updated!');
    }
  }

  void _hienThongBao(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          title,
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: TextStyle(color: lightText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Localizations.localeOf(context).languageCode == 'vi' ? 'Đóng' : 'Close', style: TextStyle(color: secondaryText)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: darkBackground,
        appBar: AppBar(
          title: Text(
            _currentHocSinh.ten,
            style: TextStyle(color: lightText),
          ),
          centerTitle: true,
          backgroundColor: cardColor,
          foregroundColor: lightText,
          actions: [
            IconButton(
              icon: Icon(Icons.edit, color: accentColor),
              tooltip: isVi ? 'Sửa thông tin' : 'Edit info',
              onPressed: _moFormSuaHS,
            ),
            IconButton(
              icon: Icon(Icons.refresh, color: accentColor),
              tooltip: isVi ? 'Làm mới' : 'Refresh',
              onPressed: () {
                _lamMoiDuLieuLop();
                _hienThongBao(isVi ? 'Thông báo' : 'Notification', isVi ? 'Đã làm mới dữ liệu.' : 'Data refreshed.');
              },
            ),
          ],
          bottom: TabBar(
            indicatorColor: accentColor,
            labelColor: accentColor,
            unselectedLabelColor: secondaryText,
            tabs: [
              Tab(icon: const Icon(Icons.info_outline, size: 20), text: isVi ? 'Tổng quan' : 'Overview'),
              Tab(icon: const Icon(Icons.checklist_rtl, size: 20), text: isVi ? 'Điểm danh' : 'Attendance'),
              Tab(icon: const Icon(Icons.payment, size: 20), text: isVi ? 'Học phí' : 'Tuition'),
              Tab(icon: const Icon(Icons.star_border, size: 20), text: isVi ? 'Đánh giá' : 'Evaluation'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTongQuanTab(_currentHocSinh),
            BaoCaoDiemDanhWidget(
              hocSinh: _currentHocSinh,
              refreshTrigger: _refreshCounter,
            ),
            _buildHocPhiTab(_currentHocSinh),
            _buildDanhGiaTab(_currentHocSinh),
          ],
        ),
      ),
    );
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

    for (var row in results) {
      final trangThai = row['trang_thai'] as String;
      final count = row['count'] as int;
      if (trangThai == 'Có mặt') {
        coMat = count;
      } else if (trangThai == 'Nghỉ có phép') {
        nghiCoPhep = count;
      } else if (trangThai == 'Nghỉ không phép') {
        nghiKhongPhep = count;
      }
    }
    return {
      'coMat': coMat,
      'nghiCoPhep': nghiCoPhep,
      'nghiKhongPhep': nghiKhongPhep,
    };
  }

  Widget _buildTongQuanTab(HS hs) {
    final currencyFmt = NumberFormat('#,##0', 'vi_VN');
    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    return RefreshIndicator(
      onRefresh: () async => _lamMoiDuLieuLop(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Dashboard Grid ---
            FutureBuilder<List<dynamic>>(
              future: Future.wait([_attendanceStatsFuture, _hocPhiFuture]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();

                final attData = snapshot.data![0] as Map<String, int>;
                final hpData = snapshot.data![1] as Map<String, dynamic>;

                final coMat = attData['coMat'] ?? 0;
                final nghiCoPhep = attData['nghiCoPhep'] ?? 0;
                final nghiKhongPhep = attData['nghiKhongPhep'] ?? 0;
                final tongBuoi = coMat + nghiCoPhep + nghiKhongPhep;
                final attRate = tongBuoi > 0 ? coMat / tongBuoi : 0.0;

                final conNoList =
                    hpData['con_no'] as List<Map<String, dynamic>>? ?? [];
                final tongNo = conNoList.fold<int>(
                  0,
                  (sum, item) => sum + (item['tien_no'] as int),
                );

                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    _buildSummaryCard(
                      isVi ? 'Chuyên Cần' : 'Attendance',
                      '${(attRate * 100).round()}%',
                      Icons.trending_up,
                      attRate > 0.8
                          ? accentColor
                          : (attRate > 0.5
                              ? Colors.orangeAccent
                              : Colors.redAccent),
                      progress: attRate,
                      subtitle: isVi ? '$coMat/$tongBuoi buổi' : '$coMat/$tongBuoi sessions',
                    ),
                    _buildSummaryCard(
                      isVi ? 'Học Phí Nợ' : 'Tuition Debt',
                      '${currencyFmt.format(tongNo)}đ',
                      Icons.warning_amber_rounded,
                      tongNo > 0 ? Colors.redAccent : Colors.greenAccent,
                      subtitle: tongNo > 0 
                          ? (isVi ? 'Cần thanh toán' : 'Needs payment') 
                          : (isVi ? 'Đã hoàn thành' : 'Completed'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // --- Hồ sơ cơ bản ---
            _buildSectionHeader(isVi ? 'THÔNG TIN LIÊN HỆ' : 'CONTACT INFORMATION', Icons.person_outline),
            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  children: [
                    _buildInfoTile(
                      Icons.school,
                      isVi ? 'Trường' : 'School',
                      hs.truongDangHoc ?? (isVi ? 'Chưa cập nhật' : 'Not updated'),
                    ),
                    _buildInfoTile(
                      Icons.phone,
                      isVi ? 'Phụ huynh' : 'Parent',
                      hs.sdt ?? (isVi ? 'Chưa có SĐT' : 'No Phone Number'),
                    ),
                    _buildInfoTile(
                      Icons.location_on_outlined,
                      isVi ? 'Địa chỉ' : 'Address',
                      hs.diaChi ?? (isVi ? 'Chưa cập nhật' : 'Not updated'),
                    ),
                    _buildInfoTile(
                      Icons.card_membership,
                      isVi ? 'Miễn giảm' : 'Discount',
                      isVi ? '${hs.mienGiam ?? 0}% mức thu' : '${hs.mienGiam ?? 0}% rate',
                    ),
                  ],
                ),
              ),
            ),

            if (hs.ghiChu != null && hs.ghiChu!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionHeader(isVi ? 'GHI CHÚ' : 'NOTES', Icons.sticky_note_2_outlined),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  hs.ghiChu!,
                  style: TextStyle(
                    color: secondaryText,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            _buildSectionHeader(isVi ? 'LỚP ĐANG THEO HỌC' : 'CURRENT CLASSES', Icons.class_outlined),

            FutureBuilder<_StudentClassInfo>(
              future: _classInfoFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: accentColor),
                    ),
                  );
                }
                final dsLop = snapshot.data?.dsLop ?? [];
                final dsLich = snapshot.data?.dsLichHocCaNhan ?? [];

                if (dsLop.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        isVi ? 'Chưa tham gia lớp nào' : 'Not enrolled in any class',
                        style: TextStyle(color: secondaryText),
                      ),
                    ),
                  );
                }

                return Column(
                  children: dsLop.map((lop) {
                    final lichCuaLop =
                        dsLich.where((l) => l.idLop == lop.id).toList();
                    return _buildLopCard(lop, lichCuaLop);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: secondaryText,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: accentColor.withValues(alpha: 0.7), size: 20),
      title: Text(
        label,
        style: TextStyle(color: secondaryText, fontSize: 12),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          color: lightText,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    double? progress,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: secondaryText, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: lightText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          if (progress != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                color: color,
                minHeight: 4,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLopCard(Lop lop, List<LichHocChung> lichHoc) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: accentColor.withValues(alpha: 0.1),
          child: Text(
            '${lop.khoi}',
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          lop.ten,
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isVi ? '${lichHoc.length} buổi/tuần' : '${lichHoc.length} sessions/week',
          style: TextStyle(color: secondaryText, fontSize: 12),
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: secondaryText,
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LopDetail(lop: lop)),
          ),
        ),
        children: lichHoc.isEmpty
            ? [
                ListTile(
                  title: Text(
                    isVi ? 'Chưa có lịch' : 'No schedule yet',
                    style: TextStyle(color: secondaryText, fontSize: 13),
                  ),
                ),
              ]
            : lichHoc
                  .map(
                    (lh) => ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.access_time,
                        size: 16,
                        color: secondaryText,
                      ),
                      title: Text(
                        '${lh.ngayTrongTuan}: ${lh.gioBatDau} - ${lh.gioKetThuc}',
                        style: TextStyle(color: secondaryText),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }

  Future<Map<String, dynamic>> _layDuLieuHocPhi(int hsId) async {
    final db = await DBHelper.instance.database;
    final currentMonthStr = DateFormat('yyyy-MM').format(DateTime.now());

    try {
      final classInfo = await _classInfoFuture;
      final reportService = ReportService();
      for (var lop in classInfo.dsLop) {
        if (lop.id != null) {
          await reportService.layBaoCaoHocPhiThang(lop.id!, currentMonthStr);
        }
      }
    } catch (e) {}

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

      if (soTienDaDong > 0) {
        lichSu.add({
          'thang': thang,
          'ten_lop': r['ten_lop'],
          'tong_thanh_toan': tongThanhToan,
          'so_tien_da_dong': soTienDaDong,
          'ngay_thanh_toan': r['ngay_thanh_toan'],
        });
      }
    }

    return {
      'current_month': currentMonthStr,
      'con_no': conNo,
      'lich_su': lichSu,
    };
  }

  String _dinhDangNgay(dynamic value) {
    if (value == null) return '';
    try {
      final dateTime = DateTime.parse(value.toString());
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (_) {
      return value.toString();
    }
  }

  Widget _buildHocPhiTab(HS hs) {
    final fmt = NumberFormat('#,##0', 'vi_VN');
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return FutureBuilder<Map<String, dynamic>>(
      future: _hocPhiFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return Center(
            child: CircularProgressIndicator(color: accentColor),
          );
        if (snapshot.hasError) {
          return Center(
            child: Text(
              isVi ? 'Lỗi tải dữ liệu' : 'Error loading data',
              style: TextStyle(color: secondaryText),
            ),
          );
        }

        final data = snapshot.data ?? {};
        final currentMonth =
            data['current_month'] as String? ??
            DateFormat('yyyy-MM').format(DateTime.now());
        final conNo = data['con_no'] as List<Map<String, dynamic>>? ?? [];
        final lichSu = data['lich_su'] as List<Map<String, dynamic>>? ?? [];

        final totalDebt = conNo.fold<int>(
          0,
          (sum, item) => sum + (item['tien_no'] as int),
        );

        if (conNo.isEmpty && lichSu.isEmpty)
          return Center(
            child: Text(
              isVi ? 'Chưa có dữ liệu học phí' : 'No tuition data available',
              style: TextStyle(color: secondaryText),
            ),
          );

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // --- CỘNG DỒN TỔNG NỢ ---
            if (totalDebt > 0)
              Card(
                color: Colors.redAccent.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              isVi ? 'TỔNG NỢ TÍCH LŨY' : 'TOTAL ACCUMULATED DEBT',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                letterSpacing: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${fmt.format(totalDebt)}đ',
                        style: TextStyle(
                          color: lightText,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isVi ? 'Bao gồm ${conNo.length} tháng chưa hoàn thành' : 'Includes ${conNo.length} unpaid months',
                        style: TextStyle(color: secondaryText, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            if (conNo.isNotEmpty) ...[
              Text(
                isVi ? 'CHI TIẾT THÁNG CÒN NỢ' : 'UNPAID MONTHS DETAILS',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...conNo.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    onTap: () async {
                      final hsNo = HocSinhNoHocPhi(
                        idHocSinh: hs.id!,
                        tenHocSinh: hs.ten,
                        soTienCanNop: item['tong_thanh_toan'],
                        soTienDaDong: item['so_tien_da_dong'],
                        soTienConNo: item['tien_no'],
                        mienGiam: hs.mienGiam ?? 0,
                        soBuoiDu: hs.soBuoiDu,
                      );
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => ThuTienHocPhiDialog(
                          hocSinh: hsNo,
                          thang: item['thang'],
                          soTienDaDongHienTai: item['so_tien_da_dong'],
                          idLop: item['id_lop'],
                        ),
                      );
                      if (result == true) {
                        _lamMoiDuLieuLop();
                      }
                    },
                    title: Text(
                      isVi 
                          ? 'Tháng ${item['thang'].toString().split('-').reversed.join('/')}'
                          : 'Month ${item['thang'].toString().split('-').reversed.join('/')}',
                      style: TextStyle(
                        color: lightText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      isVi 
                          ? 'Lớp: ${item['ten_lop']}\nCần nộp: ${fmt.format(item['tong_thanh_toan'])}đ | Đã đóng: ${fmt.format(item['so_tien_da_dong'])}đ'
                          : 'Class: ${item['ten_lop']}\nDue: ${fmt.format(item['tong_thanh_toan'])}đ | Paid: ${fmt.format(item['so_tien_da_dong'])}đ',
                      style: TextStyle(color: secondaryText),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isVi ? 'NỢ' : 'DEBT',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${fmt.format(item['tien_no'])}đ',
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.payment, color: accentColor),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            if (lichSu.isNotEmpty || conNo.isNotEmpty) ...[
              Text(
                isVi ? 'LỊCH SỬ NỘP HỌC PHÍ' : 'PAYMENT HISTORY',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              if (lichSu.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    isVi ? 'Chưa có lịch sử nộp học phí' : 'No payment history yet',
                    style: TextStyle(
                      color: secondaryText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ...lichSu.map(
                  (item) => Card(
                    color: cardColor,
                    child: ListTile(
                      title: Text(
                        isVi
                            ? 'Tháng ${item['thang'].toString().split('-').reversed.join('/')}'
                            : 'Month ${item['thang'].toString().split('-').reversed.join('/')}',
                        style: TextStyle(color: lightText),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVi ? 'Lớp: ${item['ten_lop']}' : 'Class: ${item['ten_lop']}',
                            style: TextStyle(color: secondaryText),
                          ),
                          if (item['ngay_thanh_toan'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                isVi 
                                    ? 'Ngày đóng: ${_dinhDangNgay(item['ngay_thanh_toan'])}'
                                    : 'Paid date: ${_dinhDangNgay(item['ngay_thanh_toan'])}',
                                style: TextStyle(color: secondaryText.withOpacity(0.7), fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                      trailing: Text(
                        '${fmt.format(item['so_tien_da_dong'])}đ',
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDanhGiaTab(HS hs) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _suKienService.layLichSuSuKien(hs.id!),
        DanhGiaBuoiHocService().layLichSuDanhGia(hs.id!),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              isVi ? 'Lỗi tải đánh giá học tập' : 'Error loading academic evaluations',
              style: TextStyle(color: secondaryText),
            ),
          );
        }

        final List<SuKienLichSuViewModel> events = snapshot.data?[0] as List<SuKienLichSuViewModel>? ?? [];
        final List<DanhGiaLichSuViewModel> danhGiaList = snapshot.data?[1] as List<DanhGiaLichSuViewModel>? ?? [];

        final chartData = danhGiaList.reversed.toList(); // Sắp xếp theo trình tự thời gian tăng dần

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- BIỂU ĐỒ TIẾN BỘ HỌC TẬP ---
              if (chartData.length >= 2) ...[
                Card(
                  color: cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? 'BIỂU ĐỒ TIẾN BỘ HỌC TẬP' : 'ACADEMIC PROGRESS CHART',
                          style: TextStyle(
                            color: lightText,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 200,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: 10,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: Colors.white.withOpacity(0.05),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    getTitlesWidget: (value, meta) {
                                      if (value % 2 != 0) return const SizedBox();
                                      return Text(
                                        value.toInt().toString(),
                                        style: TextStyle(color: secondaryText, fontSize: 10),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 24,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 || index >= chartData.length) return const SizedBox();
                                      // Chỉ hiển thị nhãn ngày nếu danh sách không quá nhiều hoặc hiển thị xen kẽ
                                      if (chartData.length > 5 && index % 2 != 0) return const SizedBox();
                                      return SideTitleWidget(
                                        axisSide: meta.axisSide,
                                        child: Text(
                                          DateFormat('dd/MM').format(chartData[index].ngayHoc),
                                          style: TextStyle(color: secondaryText, fontSize: 9),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                // Đường điểm Thái độ (Thái độ học tập) - Màu xanh lục
                                LineChartBarData(
                                  spots: List.generate(chartData.length, (idx) {
                                    return FlSpot(idx.toDouble(), chartData[idx].diemThaiDo ?? 0.0);
                                  }),
                                  isCurved: true,
                                  color: Colors.greenAccent,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(show: false),
                                ),
                                // Đường điểm Hiểu bài - Màu xanh dương
                                LineChartBarData(
                                  spots: List.generate(chartData.length, (idx) {
                                    return FlSpot(idx.toDouble(), chartData[idx].diemHieuBai ?? 0.0);
                                  }),
                                  isCurved: true,
                                  color: Colors.blueAccent,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(show: false),
                                ),
                                // Đường điểm Bài tập về nhà - Màu cam
                                LineChartBarData(
                                  spots: List.generate(chartData.length, (idx) {
                                    return FlSpot(idx.toDouble(), chartData[idx].diemBaiTap ?? 0.0);
                                  }),
                                  isCurved: true,
                                  color: Colors.orangeAccent,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(show: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Chú thích biểu đồ
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem(isVi ? 'Thái độ' : 'Attitude', Colors.greenAccent),
                            const SizedBox(width: 16),
                            _buildLegendItem(isVi ? 'Hiểu bài' : 'Understanding', Colors.blueAccent),
                            const SizedBox(width: 16),
                            _buildLegendItem(isVi ? 'Bài tập' : 'Homework', Colors.orangeAccent),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ] else if (danhGiaList.isNotEmpty) ...[
                Card(
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text(
                        isVi
                            ? 'Cần thêm đánh giá buổi học để vẽ biểu đồ tiến độ'
                            : 'Need more session ratings to draw progress chart',
                        style: TextStyle(color: secondaryText, fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // --- NHẬT KÝ THI ĐUA & SỰ KIỆN ---
              _buildSectionHeader(isVi ? 'NHẬT KÝ THI ĐUA' : 'COMPETITION LOG', Icons.stars_outlined),
              const SizedBox(height: 8),
              if (events.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      isVi ? 'Chưa có nhận xét hay sự kiện thi đua nào' : 'No comments or events logged yet',
                      style: TextStyle(color: secondaryText, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  itemBuilder: (context, i) {
                    final sk = events[i];
                    final isTichCuc = sk.loaiSuKien == LoaiSuKien.tichCuc;
                    return Card(
                      color: cardColor,
                      child: ListTile(
                        leading: Icon(
                          isTichCuc ? Icons.add_circle : Icons.remove_circle,
                          color: isTichCuc ? Colors.greenAccent : Colors.redAccent,
                        ),
                        title: Text(sk.moTa, style: TextStyle(color: lightText)),
                        subtitle: Text(
                          isVi
                              ? 'Ngày: ${DateFormat('dd/MM/yyyy').format(sk.ngayHoc)}'
                              : 'Date: ${DateFormat('dd/MM/yyyy').format(sk.ngayHoc)}',
                          style: TextStyle(color: secondaryText, fontSize: 11),
                        ),
                        trailing: Text(
                          '${isTichCuc ? "+" : ""}${sk.diemThayDoi}',
                          style: TextStyle(
                            color: isTichCuc ? Colors.greenAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: secondaryText, fontSize: 12)),
      ],
    );
  }
}
