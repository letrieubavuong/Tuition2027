// File: lib/screens/hoc_phi_page.dart (HOÀN THIỆN)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lop.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../services/report_service.dart'; // <-- IMPORT SERVICE MỚI
import '../services/lop_service.dart';
import '../services/pdf_export_service.dart';
import '../services/caidat_service.dart';
import '../main.dart';
import '../widgets/main_drawer.dart';
import '../widgets/thu_tien_hoc_phi_dialog.dart';
import '../l10n/app_localizations.dart';
import '../utils/toast_helper.dart';

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
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get primaryButtonColor =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF0F3460)
      : Theme.of(context).primaryColor.withValues(alpha: 0.15);
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final LopService _lopService = LopService();
  final ReportService _reportService = ReportService();

  // Trạng thái tháng và năm đang chọn (YYYY-MM)
  late String _selectedMonthYear;
  // Trạng thái năm đang hiển thị
  late int _currentYear;
  // Future cho tất cả báo cáo của tất cả các lớp trong tháng
  late Future<List<LopHocPhiViewModel>> _tongHopFuture;
  // Trạng thái bộ lọc
  int? _selectedLopId;

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
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Hàm tải dữ liệu tổng hợp cho TẤT CẢ các lớp trong tháng
  Future<List<LopHocPhiViewModel>> _taiDuLieuTongHop(String thang) async {
    final List<Lop> lopList = await _lopService.docTatCaLop();
    final List<Future<LopHocPhiViewModel?>> tasks = lopList.map((lop) async {
      if (lop.id != null) {
        final report = await _reportService.layBaoCaoHocPhiThang(
          lop.id!,
          thang,
        );
        return LopHocPhiViewModel(lop: lop, report: report);
      }
      return null;
    }).toList();

    final results = await Future.wait(tasks);
    return results.whereType<LopHocPhiViewModel>().toList();
  }

  // Hàm xử lý khi chọn một tháng/năm mới
  void _chonThangMoi(int thang, int nam) {
    // Tạo chuỗi YYYY-MM
    final newMonthYear = '$nam-${thang.toString().padLeft(2, '0')}';

    // Chỉ cập nhật nếu tháng mới khác tháng cũ
    if (newMonthYear != _selectedMonthYear) {
      setState(() {
        _selectedMonthYear = newMonthYear;
        _selectedLopId = null; // SỬA: Reset lớp được chọn khi đổi tháng
        // Tải lại dữ liệu cho tháng mới
        _tongHopFuture = _taiDuLieuTongHop(newMonthYear);
      });
    }
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
            isVi
                ? 'Đã cập nhật thanh toán và làm mới dữ liệu!'
                : 'Payment updated and data refreshed!',
            style: TextStyle(color: lightText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                isVi ? 'Đóng' : 'Close',
                style: TextStyle(color: secondaryText),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _chiaSeNoCaNhan(HocSinhNoHocPhi hs, String tenLop) async {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');
    final caiDatService = CaiDatService();

    // Đọc thông tin ngân hàng từ cài đặt
    final String bankId =
        (await caiDatService.layCaiDat('bank_id')) ?? 'sacombank';
    final String accountNo =
        (await caiDatService.layCaiDat('account_no')) ?? '0905073175';
    final String accountName =
        (await caiDatService.layCaiDat('account_name')) ?? 'LE TRIEU BA VUONG';

    final StringBuffer buffer = StringBuffer();
    final parts = _selectedMonthYear.split('-');
    final formattedMonth = parts.reversed.join('/');

    if (isVi) {
      buffer.writeln(
        'Kính gửi phụ huynh học sinh ${hs.tenHocSinh} (Lớp $tenLop),',
      );
      buffer.writeln('Học phí tháng $formattedMonth của học sinh là:');
      buffer.writeln('- Cần nộp: ${formatCurrency.format(hs.soTienCanNop)}đ');
      buffer.writeln('- Đã đóng: ${formatCurrency.format(hs.soTienDaDong)}đ');
      buffer.writeln('- Còn nợ: ${formatCurrency.format(hs.soTienConNo)}đ');
      buffer.writeln(
        '\nQuý phụ huynh vui lòng thanh toán chuyển khoản vào tài khoản ngân hàng:',
      );
      buffer.writeln('- Ngân hàng: ${bankId.toUpperCase()}');
      buffer.writeln('- Số tài khoản: $accountNo');
      buffer.writeln('- Chủ tài khoản: $accountName');
      buffer.writeln('Xin chân thành cảm ơn quý phụ huynh!');
    } else {
      buffer.writeln(
        'Dear parent of student ${hs.tenHocSinh} (Class $tenLop),',
      );
      buffer.writeln('Tuition fee for month $formattedMonth:');
      buffer.writeln(
        '- Amount due: ${formatCurrency.format(hs.soTienCanNop)}đ',
      );
      buffer.writeln('- Paid: ${formatCurrency.format(hs.soTienDaDong)}đ');
      buffer.writeln('- Debt: ${formatCurrency.format(hs.soTienConNo)}đ');
      buffer.writeln('\nPlease settle the payment via bank transfer:');
      buffer.writeln('- Bank: ${bankId.toUpperCase()}');
      buffer.writeln('- Account Number: $accountNo');
      buffer.writeln('- Account Name: $accountName');
      buffer.writeln('Thank you very much!');
    }

    final String message = buffer.toString();

    // Copy vào clipboard
    await Clipboard.setData(ClipboardData(text: message));

    if (mounted) {
      ToastHelper.showInfo(
        context,
        isVi
            ? 'Đã copy thông tin nhắc nợ của học sinh vào bộ nhớ tạm!'
            : 'Copied student debt details to clipboard!',
      );
    }

    await Share.share(message);
  }

  void _moZaloPhuHuynh(String sdt) async {
    if (sdt.isEmpty) return;
    final cleanSdt = sdt.replaceAll(RegExp(r'[^\d]'), '');
    final url = Uri.parse('https://zalo.me/$cleanSdt');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ToastHelper.showError(context, 'Không thể mở liên kết Zalo: $url');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi mở Zalo: $e');
      }
    }
  }

  // Widget hiển thị Học sinh còn nợ (Tái sử dụng logic cũ)
  Widget _buildHocSinhNoItem(HocSinhNoHocPhi hs, int idLop, String tenLop) {
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: ListTile(
        dense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: Colors.redAccent.withOpacity(0.1),
          child: Text(
            hs.tenHocSinh.isNotEmpty ? hs.tenHocSinh[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(
          hs.tenHocSinh,
          style: TextStyle(
            color: lightText,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              (isVi ? 'Đã đóng: ' : 'Paid: ') +
                  '${formatCurrency.format(hs.soTienDaDong)}đ',
              style: TextStyle(color: secondaryText, fontSize: 12),
            ),
            if (hs.sdt != null && hs.sdt!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'SĐT: ${hs.sdt}',
                style: TextStyle(color: secondaryText, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (hs.sdt != null && hs.sdt!.isNotEmpty) ...[
                  InkWell(
                    onTap: () => _moZaloPhuHuynh(hs.sdt!),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue, width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.message,
                            size: 14,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Zalo',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  onTap: () => _chiaSeNoCaNhan(hs, tenLop),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.share, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          isVi ? 'Nhắc nợ' : 'Remind',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
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
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isVi ? 'Thu tiền' : 'Collect',
                  style: TextStyle(color: accentColor, fontSize: 11),
                ),
                Icon(Icons.chevron_right, size: 14, color: accentColor),
              ],
            ),
          ],
        ),
        onTap: () => _moTrangThanhToan(hs, idLop),
      ),
    );
  }

  Widget _buildMonthYearSelector() {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    final currentMonth = int.parse(_selectedMonthYear.substring(5, 7));

    // Generate list of years (e.g. from current year - 3 to current year + 3)
    final int baseYear = DateTime.now().year;
    final List<int> yearsList = List.generate(
      7,
      (index) => baseYear - 3 + index,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              // Chọn Tháng Dropdown
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: currentMonth,
                  dropdownColor: cardColor,
                  style: TextStyle(color: lightText, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: isVi ? 'Tháng' : 'Month',
                    labelStyle: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentColor, width: 1.5),
                    ),
                  ),
                  items: List.generate(12, (index) {
                    final m = index + 1;
                    return DropdownMenuItem<int>(
                      value: m,
                      child: Text('${isVi ? "Tháng" : "Month"} $m'),
                    );
                  }),
                  onChanged: (newMonth) {
                    if (newMonth != null) {
                      _chonThangMoi(newMonth, _currentYear);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Chọn Năm Dropdown
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _currentYear,
                  dropdownColor: cardColor,
                  style: TextStyle(color: lightText, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: isVi ? 'Năm' : 'Year',
                    labelStyle: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: accentColor, width: 1.5),
                    ),
                  ),
                  items: yearsList.map((y) {
                    return DropdownMenuItem<int>(
                      value: y,
                      child: Text('${isVi ? "Năm" : "Year"} $y'),
                    );
                  }).toList(),
                  onChanged: (newYear) {
                    if (newYear != null) {
                      setState(() {
                        _currentYear = newYear;
                        _chonThangMoi(currentMonth, newYear);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          //const SizedBox(height: 8),
          //const Divider(color: Colors.white10, height: 16, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildTotalSummaryItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
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
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
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
                      isVi
                          ? 'Lỗi tải dữ liệu: ${snapshot.error}'
                          : 'Error loading data: ${snapshot.error}',
                      style: TextStyle(color: deleteColor),
                    ),
                  );
                }

                final List<LopHocPhiViewModel> dataList = snapshot.data ?? [];

                if (dataList.isEmpty) {
                  return Center(
                    child: Text(
                      isVi
                          ? 'Chưa có lớp nào được tạo.'
                          : 'No classes created yet.',
                      style: TextStyle(color: secondaryText),
                    ),
                  );
                }

                // Lọc danh sách lớp còn nợ
                final List<LopHocPhiViewModel> classesWithDebt = dataList
                    .where((item) => item.report.tongSoTienConNo > 0)
                    .toList();

                // Tính toán lớp đang được chọn
                int? activeId = _selectedLopId;
                if (classesWithDebt.isNotEmpty) {
                  if (activeId == null ||
                      !classesWithDebt.any((x) => x.lop.id == activeId)) {
                    activeId = classesWithDebt.first.lop.id;
                  }
                } else {
                  activeId = null;
                }

                // Tìm viewModel tương ứng với lớp đang được chọn
                final activeViewModel = activeId != null
                    ? classesWithDebt.firstWhere((x) => x.lop.id == activeId)
                    : null;

                int tongTienDaThu = 0;
                int tongTienConNo = 0;
                for (var item in dataList) {
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
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildTotalSummaryItem(
                            isVi ? 'ĐÃ THU' : 'COLLECTED',
                            '${formatCurrency.format(tongTienDaThu)}đ',
                            accentColor,
                            Icons.check_circle_outline,
                          ),
                          Container(
                            height: 20,
                            width: 1,
                            color: Colors.white10,
                          ),
                          _buildTotalSummaryItem(
                            isVi ? 'CÒN NỢ' : 'DEBT',
                            '${formatCurrency.format(tongTienConNo)}đ',
                            deptColor,
                            Icons.error_outline_rounded,
                          ),
                        ],
                      ),
                    ),

                    if (classesWithDebt.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            isVi
                                ? 'Tất cả các lớp đã hoàn thành học phí!'
                                : 'All classes completed tuition fees!',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                    else ...[
                      // Combobox chọn lớp còn nợ
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: DropdownButtonFormField<int>(
                          value: activeId,
                          dropdownColor: cardColor,
                          style: TextStyle(color: lightText, fontSize: 14),
                          decoration: InputDecoration(
                            labelText: isVi
                                ? 'Lớp học còn nợ'
                                : 'Class with debt',
                            labelStyle: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                            filled: true,
                            fillColor: cardColor,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.white24,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.white12,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: accentColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                          items: classesWithDebt.map((item) {
                            return DropdownMenuItem<int>(
                              value: item.lop.id,
                              child: Text(
                                '${item.lop.ten} (Còn nợ: ${formatCurrency.format(item.report.tongSoTienConNo)}đ)',
                                style: TextStyle(color: lightText),
                              ),
                            );
                          }).toList(),
                          onChanged: (newId) {
                            setState(() {
                              _selectedLopId = newId;
                            });
                          },
                        ),
                      ),

                      // Danh sách học sinh nợ của lớp được chọn
                      if (activeViewModel != null) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isVi
                                    ? 'Học sinh chưa hoàn thành học phí:'
                                    : 'Students with unpaid tuition fees:',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              // Nút xuất PDF báo cáo lớp
                              IconButton(
                                icon: const Icon(Icons.picture_as_pdf),
                                color: accentColor,
                                tooltip: isVi
                                    ? 'Xuất PDF báo cáo lớp'
                                    : 'Export Class PDF Report',
                                onPressed: () {
                                  PdfExportService().generateAndOpenHocPhiPdf(
                                    activeViewModel,
                                    _selectedMonthYear,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            itemCount:
                                activeViewModel.report.dsHocSinhConNo.length,
                            itemBuilder: (context, idx) {
                              final hs =
                                  activeViewModel.report.dsHocSinhConNo[idx];
                              return _buildHocSinhNoItem(
                                hs,
                                activeViewModel.lop.id!,
                                activeViewModel.lop.ten,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
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
