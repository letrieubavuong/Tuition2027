// File: lib/screens/hoc_phi_page.dart (HOÀN THIỆN)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lop.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../services/report_service.dart'; // <-- IMPORT SERVICE MỚI
import '../services/lop_service.dart';
import '../services/pdf_export_service.dart';
import '../main.dart';
import '../widgets/main_drawer.dart';
import '../widgets/thu_tien_hoc_phi_dialog.dart';
import '../l10n/app_localizations.dart';

// --- Màu sắc động được định nghĩa trong _HocPhiPageState ---

// =======================================================
// MODEL TẠM: Kết hợp Lop và Báo cáo (Dùng cho ListView)
// =======================================================
class LopHocPhiViewModel {
  final Lop lop;
  final HocPhiTongHop report;

  LopHocPhiViewModel({required this.lop, required this.report});
}

// =======================================================
// MÀN HÌNH CHÍNH: HocPhiPage (TOP-LEVEL TAB)
// =======================================================
class HocPhiPage extends StatefulWidget {
  final GlobalKey<MainScreenState> mainScreenKey;
  final int selectedIndex; // SỬA: Thêm tham số
  const HocPhiPage({
    super.key,
    required this.mainScreenKey,
    required this.selectedIndex, // SỬA: Thêm tham số
  });

  @override
  State<HocPhiPage> createState() => _HocPhiPageState();
}

class _HocPhiPageState extends State<HocPhiPage> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get primaryButtonColor => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0F3460)
      : Theme.of(context).primaryColor.withValues(alpha: 0.15);
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final LopService _lopService = LopService();
  final ReportService _reportService = ReportService();

  // Trạng thái tháng và năm đang chọn (YYYY-MM)
  late String _selectedMonthYear;
  // Trạng thái năm đang hiển thị trên thanh trượt
  late int _currentYear;
  // Future cho tất cả báo cáo của tất cả các lớp trong tháng
  late Future<List<LopHocPhiViewModel>> _tongHopFuture;
  // Controller để tự động cuộn đến tháng hiện tại
  late ScrollController _monthScrollController;
  // Trạng thái bộ lọc
  bool _chiHienThiLopConNo = false;

  @override
  void initState() {
    super.initState();
    // Mặc định là tháng và năm hiện tại
    final now = DateTime.now();
    _currentYear = now.year;
    // Đảm bảo tháng hiện tại hợp lệ
    final defaultMonth = now.month;
    _selectedMonthYear = DateFormat(
      'yyyy-MM',
    ).format(DateTime(now.year, defaultMonth));
    _tongHopFuture = _taiDuLieuTongHop(_selectedMonthYear);

    // Khởi tạo ScrollController
    _monthScrollController = ScrollController();

    // Cuộn đến tháng hiện tại sau khi frame đầu tiên được build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedMonth();
    });
  }

  @override
  void dispose() {
    _monthScrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedMonth() {
    final int currentMonth = int.parse(_selectedMonthYear.substring(5, 7));
    // (width + margin * 2) * (month_index) - (viewport_width / 2) + (item_width / 2)
    final double offset =
        (60.0 * (currentMonth - 1)) -
        (MediaQuery.of(context).size.width / 2) +
        30.0;
    _monthScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // Hàm tải dữ liệu tổng hợp cho TẤT CẢ các lớp trong tháng
  Future<List<LopHocPhiViewModel>> _taiDuLieuTongHop(String thang) async {
    final List<Lop> lopList = await _lopService.docTatCaLop();
    final List<LopHocPhiViewModel> results = [];

    // Tải dữ liệu lần lượt, đồng thời kích hoạt việc tính toán học phí
    for (var lop in lopList) {
      if (lop.id != null) {
        // SỬA: Gọi hàm từ ReportService
        final report = await _reportService.layBaoCaoHocPhiThang(
          lop.id!,
          thang,
        );
        results.add(LopHocPhiViewModel(lop: lop, report: report));
      }
    }
    return results;
  }

  // Hàm xử lý khi chọn một tháng/năm mới
  void _chonThangMoi(int thang, int nam) {
    // Tạo chuỗi YYYY-MM
    final newMonthYear = '$nam-${thang.toString().padLeft(2, '0')}';

    // Chỉ cập nhật nếu tháng mới khác tháng cũ
    if (newMonthYear != _selectedMonthYear) {
      setState(() {
        _selectedMonthYear = newMonthYear;
        // Tải lại dữ liệu cho tháng mới
        _tongHopFuture = _taiDuLieuTongHop(newMonthYear);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToSelectedMonth();
        });
      });
    }
  }

  // Hàm xử lý thay đổi năm trên thanh trượt
  void _thayDoiNam(int delta) {
    setState(() {
      _currentYear += delta;
      // Giả sử: nếu đang chọn 2024-09, chuyển sang 2025 thì vẫn chọn 2025-09
      int selectedMonth = int.parse(_selectedMonthYear.substring(5, 7));
      _chonThangMoi(selectedMonth, _currentYear);
    });
  }

  // HÀM MỚI: Xử lý mở trang thanh toán (Sử dụng Dialog giả lập)
  void _moTrangThanhToan(HocSinhNoHocPhi hs, int idLop) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ThuTienHocPhiDialog(
        hocSinh: hs,
        thang: _selectedMonthYear,
        soTienDaDongHienTai: hs.soTienDaDong,
        idLop: idLop,
      ),
    );

    // Nếu thanh toán thành công (hoặc quay lại từ trang chi tiết)
    if (result == true) {
      // Tải lại dữ liệu cho tháng hiện tại để cập nhật báo cáo
      setState(() {
        _tongHopFuture = _taiDuLieuTongHop(_selectedMonthYear);
      });
      if (!mounted) return;
      final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            isVi ? 'Thành công' : 'Success',
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isVi ? 'Đã cập nhật thanh toán và làm mới dữ liệu!' : 'Payment updated and data refreshed!',
            style: TextStyle(color: lightText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isVi ? 'Đóng' : 'Close', style: TextStyle(color: secondaryText)),
            ),
          ],
        ),
      );
    }
  }

  // Widget hiển thị Học sinh còn nợ (Tái sử dụng logic cũ)
  Widget _buildHocSinhNoItem(HocSinhNoHocPhi hs, int idLop) {
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: CircleAvatar(
          radius: 12,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
          child: Text(
            hs.tenHocSinh.isNotEmpty ? hs.tenHocSinh[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
        title: Text(
          hs.tenHocSinh,
          style: TextStyle(color: lightText, fontWeight: FontWeight.w500, fontSize: 13),
        ),
        subtitle: Text(
          (isVi ? 'Đã đóng: ' : 'Paid: ') + '${formatCurrency.format(hs.soTienDaDong)}đ',
          style: TextStyle(color: secondaryText, fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${formatCurrency.format(hs.soTienConNo)}đ',
              style: const TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Icon(Icons.chevron_right, size: 14, color: secondaryText),
          ],
        ),
        onTap: () => _moTrangThanhToan(hs, idLop),
      ),
    );
  }

  // Widget hiển thị ô chọn Tháng
  Widget _buildMonthBox(int month) {
    final isSelected =
        _selectedMonthYear ==
        '$_currentYear-${month.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _chonThangMoi(month, _currentYear),
      child: Container(
        width: 52, // Giảm chiều rộng
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryButtonColor
              : cardColor, // Màu nền của ô tháng
          borderRadius: BorderRadius.circular(10), // Giảm bo góc
          border: Border.all(
            color: isSelected ? accentColor : secondaryText.withValues(alpha: 0.3),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            '$month', // Chỉ hiển thị số tháng
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? lightText : secondaryText,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16, // Tăng kích thước số cho dễ nhìn
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    return Column(
      children: [
        // Chọn Năm
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_left,
                  color: accentColor,
                  size: 30,
                ),
                onPressed: () => _thayDoiNam(-1),
              ),
              Text(
                (isVi ? 'NĂM ' : 'YEAR ') + '$_currentYear',
                style: TextStyle(
                  color: lightText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_right,
                  color: accentColor,
                  size: 30,
                ),
                onPressed: () => _thayDoiNam(1),
              ),
            ],
          ),
        ),

        // Thanh trượt chọn Tháng
        SizedBox(
          height: 50, // Giảm chiều cao thanh trượt
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            controller: _monthScrollController, // Gán controller
            itemCount: 12,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemBuilder: (context, index) {
              final month = index + 1; // 1 đến 12
              return _buildMonthBox(month);
            },
          ),
        ),
        const Divider(color: Colors.white10, height: 16, thickness: 1),
      ],
    );
  }

  Widget _buildTotalSummaryItem(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: secondaryText, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: lightText,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          // Thêm style
          isVi ? 'QUẢN LÍ HỌC PHÍ' : 'FEE MANAGEMENT',
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
        backgroundColor: cardColor,
        foregroundColor: lightText,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      // SỬA: Thêm drawer vào Scaffold để nút menu hoạt động
      drawer: MainDrawer(
        mainScreenKey: widget.mainScreenKey,
        selectedIndex: widget.selectedIndex, // SỬA: Truyền tham số
      ),
      body: Column(
        children: [
          // THANH TRƯỢT CHỌN THÁNG/NĂM
          _buildMonthYearSelector(),

          // BỘ LỌC: Chỉ hiển thị lớp còn nợ
          Container(
            color: cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isVi ? 'Chỉ hiển thị lớp còn nợ' : 'Only show classes with debt',
                  style: TextStyle(color: secondaryText),
                ),
                Switch(
                  value: _chiHienThiLopConNo,
                  onChanged: (bool value) {
                    setState(() => _chiHienThiLopConNo = value);
                  },
                  activeThumbColor: accentColor,
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LopHocPhiViewModel>>(
              future: _tongHopFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: accentColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      isVi ? 'Lỗi tải dữ liệu: ${snapshot.error}' : 'Error loading data: ${snapshot.error}',
                      style: TextStyle(color: deleteColor),
                    ),
                  );
                }

                final List<LopHocPhiViewModel> dataList = snapshot.data ?? [];

                if (dataList.isEmpty) {
                  return Center(
                    child: Text(
                      isVi ? 'Chưa có lớp nào được tạo.' : 'No classes created yet.',
                      style: TextStyle(color: secondaryText),
                    ),
                  );
                }

                // ÁP DỤNG BỘ LỌC
                final List<LopHocPhiViewModel> filteredList =
                    _chiHienThiLopConNo
                    ? dataList
                          .where((item) => item.report.tongSoTienConNo > 0)
                          .toList()
                    : dataList;

                if (filteredList.isEmpty) {
                  return Center(
                    child: Text(
                      _chiHienThiLopConNo
                          ? (isVi ? 'Tất cả các lớp đã hoàn thành học phí.' : 'All classes completed fee payments.')
                          : (isVi ? 'Chưa có lớp nào được tạo.' : 'No classes created yet.'),
                      style: TextStyle(color: secondaryText),
                    ),
                  );
                }

                int tongTienDaThu = 0;
                int tongTienConNo = 0;
                for (var item in filteredList) {
                  tongTienDaThu += item.report.tongSoTienDaThu;
                  tongTienConNo += item.report.tongSoTienConNo;
                }
                final Color deptColor = tongTienConNo > 0
                    ? deleteColor
                    : secondaryText;

                return Column(
                  children: [
                    // Vùng Tổng kết toàn bộ
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          _buildTotalSummaryItem(
                            isVi ? 'ĐÃ THU' : 'COLLECTED',
                            '${formatCurrency.format(tongTienDaThu)}đ',
                            accentColor,
                            Icons.check_circle_outline,
                          ),
                          Container(height: 20, width: 1, color: Colors.white10),
                          _buildTotalSummaryItem(
                            isVi ? 'CÒN NỢ' : 'DEBT',
                            '${formatCurrency.format(tongTienConNo)}đ',
                            deptColor,
                            Icons.error_outline_rounded,
                          ),
                        ],
                      ),
                    ),

                    // Danh sách chi tiết từng lớp
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final item = filteredList[index];
                          final lop = item.lop;
                          final report = item.report;
                          final totalClassAmount = report.tongSoTienCanThu;
                          final progress = totalClassAmount > 0 
                              ? report.tongSoTienDaThu / totalClassAmount 
                              : 0.0;
                          final Color deptColorLop = report.tongSoTienConNo > 0
                              ? deleteColor
                              : accentColor;

                          return Card(
                            color: cardColor,
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: accentColor.withValues(alpha: 0.1),
                                child: Text(
                                  lop.khoi.toString(),
                                  style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              title: Text(
                                lop.ten,
                                style: TextStyle(color: lightText, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 8),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          (isVi ? 'Nợ: ' : 'Debt: ') + '${formatCurrency.format(report.tongSoTienConNo)}đ',
                                          style: TextStyle(color: deptColorLop, fontSize: 12),
                                        ),
                                        Text(
                                          '${(progress * 100).round()}%',
                                          style: TextStyle(color: secondaryText, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                                        color: progress == 1.0 ? accentColor : Colors.orangeAccent,
                                        minHeight: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              collapsedIconColor: secondaryText,
                              iconColor: accentColor,
                              children: (report.dsHocSinhConNo.isEmpty)
                                  ? [
                                      Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check_circle_outline, color: accentColor, size: 20),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Text(
                                                isVi ? 'Lớp đã hoàn thành học phí' : 'Class has completed tuition fees',
                                                style: TextStyle(color: accentColor, fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]
                                  : report.dsHocSinhConNo.map((hs) {
                                      return _buildHocSinhNoItem(hs, lop.id!);
                                    }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
