// File: lib/screens/hoc_phi_page.dart (HOÀN THIỆN)

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
import '../widgets/gui_thong_bao_hang_loat_dialog.dart';
import '../l10n/app_localizations.dart';
import '../services/tuition_event_service.dart';
import '../utils/vietqr_util.dart';
import '../utils/toast_helper.dart';

// --- Màu sắc động được định nghĩa trong HocPhiPageState ---

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
  State<HocPhiPage> createState() => HocPhiPageState();
}

class HocPhiPageState extends State<HocPhiPage> {
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

    TuitionEventService().addListener(_onTuitionEventChanged);
  }

  @override
  void dispose() {
    TuitionEventService().removeListener(_onTuitionEventChanged);
    super.dispose();
  }

  void _onTuitionEventChanged() {
    if (mounted) {
      lamMoiDuLieu();
    }
  }

  void lamMoiDuLieu() {
    setState(() {
      _tongHopFuture = _taiDuLieuTongHop(_selectedMonthYear);
    });
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

  void _chiaSeNoCaNhan(HocSinhNoHocPhi hs, int idLop, String tenLop) async {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    final caiDatService = CaiDatService();

    // Đọc thông tin ngân hàng từ cài đặt
    final String bankId =
        (await caiDatService.layCaiDat('bank_id')) ?? 'sacombank';
    final String accountNo =
        (await caiDatService.layCaiDat('account_no')) ?? '0905073175';
    final String accountName =
        (await caiDatService.layCaiDat('account_name')) ?? 'LE TRIEU BA VUONG';

    final int amount = hs.soTienConNo > 0 ? hs.soTienConNo : hs.soTienCanNop;
    final String studentNameNoAccent = VietQRUtil.removeVietnameseAccents(
      hs.tenHocSinh,
    );
    final String description =
        'Hoc phi $studentNameNoAccent thang $_selectedMonthYear';
    final String qrPayload = VietQRUtil.generateVietQRPayload(
      bankId: bankId,
      accountNo: accountNo,
      amount: amount,
      description: description,
    );

    final String message = VietQRUtil.taoNoiDungThongBaoHocPhi(
      tenHocSinh: hs.tenHocSinh,
      tenLop: tenLop,
      thang: _selectedMonthYear,
      soBuoiDu: hs.soBuoiDu,
      tongSoBuoi: hs.tongSoBuoi,
      soTienCanNop: hs.soTienCanNop,
      soTienDaDong: hs.soTienDaDong,
      soTienConNo: hs.soTienConNo,
      bankId: bankId,
      accountNo: accountNo,
      accountName: accountName,
      isVi: isVi,
    );

    final GlobalKey cardKey = GlobalKey();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isVi ? 'Phiếu Nhắc Nợ Học Phí' : 'Tuition Debt Notice Card',
          style: TextStyle(
            color: lightText,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: RepaintBoundary(
              key: cardKey,
              child: _buildThongBaoHocPhiCard(
                studentName: hs.tenHocSinh,
                className: tenLop,
                thang: _selectedMonthYear,
                soBuoiDu: hs.soBuoiDu,
                tongSoBuoi: hs.tongSoBuoi,
                amount: amount,
                bankId: bankId,
                accountNo: accountNo,
                accountName: accountName,
                description: description,
                qrPayload: qrPayload,
                isVi: isVi,
              ),
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final bytes = await _captureCardPng(cardKey);
                  if (!ctx.mounted) return;
                  if (bytes != null) {
                    _chiaSeAnhMaQR(
                      ctx,
                      bytes,
                      'NhacNo_${studentNameNoAccent}_$_selectedMonthYear.png',
                    );
                  }
                },
                icon: const Icon(Icons.share, size: 16),
                label: Text(
                  isVi ? 'Chia sẻ ảnh' : 'Share Image',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: lightText,
                  side: BorderSide(color: secondaryText.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final bytes = await _captureCardPng(cardKey);
                  if (!ctx.mounted) return;
                  if (bytes != null) {
                    _luuAnhMaQR(
                      ctx,
                      bytes,
                      'NhacNo_${studentNameNoAccent}_$_selectedMonthYear.png',
                    );
                  }
                },
                icon: const Icon(Icons.save_alt, size: 16),
                label: Text(
                  isVi ? 'Lưu ảnh' : 'Save Image',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: lightText,
                  side: BorderSide(color: secondaryText.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message));
                  if (!ctx.mounted) return;
                  ToastHelper.showInfo(
                    ctx,
                    isVi
                        ? 'Đã sao chép văn bản vào bộ nhớ tạm!'
                        : 'Text copied to clipboard!',
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(
                  isVi ? 'Copy chữ' : 'Copy Text',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isVi ? 'Đóng' : 'Close',
              style: TextStyle(color: secondaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThongBaoHocPhiCard({
    required String studentName,
    required String className,
    required String thang,
    required int soBuoiDu,
    required int tongSoBuoi,
    required int amount,
    required String bankId,
    required String accountNo,
    required String accountName,
    required String description,
    required String qrPayload,
    required bool isVi,
  }) {
    String formattedThang = thang;
    if (thang.contains('-')) {
      final parts = thang.split('-');
      if (parts.length == 2) {
        formattedThang = '${parts[1]}/${parts[0]}';
      }
    }
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner tiêu đề
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F3460), Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Text(
              isVi ? 'THÔNG BÁO HỌC PHÍ' : 'TUITION NOTICE',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isVi ? "Lớp" : "Class"}: $className   |   ${isVi ? "Tháng" : "Month"}: $formattedThang',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi ? '• Số buổi dư tích lũy:' : '• Rollover sessions:',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$soBuoiDu ${isVi ? "buổi" : "sessions"}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi ? '• Số buổi dự kiến:' : '• Expected sessions:',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '$tongSoBuoi ${isVi ? "buổi" : "sessions"}',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        isVi ? 'SỐ TIỀN CẦN THANH TOÁN' : 'TOTAL AMOUNT DUE',
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatCurrency.format(amount)} VNĐ',
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      size: 180,
                      version: QrVersions.auto,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    isVi
                        ? 'Quét mã VietQR bằng ứng dụng Ngân hàng'
                        : 'Scan VietQR using your Mobile Banking App',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBankRowCard(
                        isVi ? 'Ngân hàng' : 'Bank',
                        bankId.toUpperCase(),
                      ),
                      const SizedBox(height: 4),
                      _buildBankRowCard(isVi ? 'Số TK' : 'Account No', accountNo),
                      const SizedBox(height: 4),
                      _buildBankRowCard(
                        isVi ? 'Chủ TK' : 'Account Name',
                        accountName,
                      ),
                      const SizedBox(height: 4),
                      _buildBankRowCard(
                        isVi ? 'Nội dung CK' : 'Reference',
                        description,
                        isBoldValue: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    isVi
                        ? 'Trân trọng cảm ơn quý phụ huynh!'
                        : 'Thank you very much!',
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankRowCard(
    String label,
    String value, {
    bool isBoldValue = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            '$label:',
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: const Color(0xFF0F172A),
              fontSize: 11.5,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Future<Uint8List?> _captureCardPng(GlobalKey key) async {
    try {
      RenderRepaintBoundary? boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _luuAnhMaQR(
    BuildContext context,
    Uint8List bytes,
    String fileName,
  ) async {
    var status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) return;
    final dir = Directory('/storage/emulated/0/Download');
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    if (context.mounted) {
      final isVi = Localizations.localeOf(context).languageCode == 'vi';
      ToastHelper.showSuccess(
        context,
        isVi ? 'Đã lưu ảnh vào thư mục Download' : 'Saved image to Download',
      );
    }
  }

  Future<void> _chiaSeAnhMaQR(
    BuildContext context,
    Uint8List bytes,
    String fileName,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
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
                  onTap: () => _chiaSeNoCaNhan(hs, idLop, tenLop),
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
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => GuiThongBaoHangLoatDialog(
                  initialThang: _selectedMonthYear,
                  initialOnlyUnpaid: true,
                  initialType: NotificationType.hocPhi,
                  allowedTypes: const [NotificationType.hocPhi],
                  dialogTitle: 'Gửi Nhắc Học Phí Hàng Loạt',
                ),
              );
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: Text(
              isVi ? 'Gửi nhắc học phí hàng loạt' : 'Bulk Fee Reminders',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              minimumSize: const Size.fromHeight(38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.send_rounded),
            tooltip: isVi ? 'Gửi thông báo hàng loạt' : 'Bulk Notifications',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => GuiThongBaoHangLoatDialog(
                  initialThang: _selectedMonthYear,
                  initialOnlyUnpaid: true,
                  initialType: NotificationType.hocPhi,
                  allowedTypes: const [NotificationType.hocPhi],
                  dialogTitle: 'Gửi Nhắc Học Phí Hàng Loạt',
                ),
              );
            },
          ),
        ],
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
            child: RefreshIndicator(
              onRefresh: () async {
                lamMoiDuLieu();
                await _tongHopFuture;
              },
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
        ),
        ],
      ),
    );
  }
}
