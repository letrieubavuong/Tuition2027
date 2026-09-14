// File: lib/widgets/thu_tien_hoc_phi_dialog.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/hoc_phi_tong_hop.dart';
import '../services/diem_danh_service.dart';
import '../services/thanh_toan_service.dart';
import '../services/caidat_service.dart';
import '../services/lop_service.dart';
import '../utils/vietqr_util.dart';
import '../utils/toast_helper.dart';

class ThuTienHocPhiDialog extends StatefulWidget {
  final HocSinhNoHocPhi hocSinh;
  final String thang;
  final int soTienDaDongHienTai;
  final int idLop;

  const ThuTienHocPhiDialog({
    super.key,
    required this.hocSinh,
    required this.thang,
    required this.soTienDaDongHienTai,
    required this.idLop,
  });

  @override
  State<ThuTienHocPhiDialog> createState() => _ThuTienHocPhiDialogState();
}

class _ThuTienHocPhiDialogState extends State<ThuTienHocPhiDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final _formKey = GlobalKey<FormState>();
  final ThanhToanService _ttService = ThanhToanService();
  final CaiDatService _caiDatService = CaiDatService();
  final LopService _lopService = LopService();
  final DiemDanhService _diemDanhService = DiemDanhService();
  final formatCurrency = NumberFormat('#,##0', 'vi_VN');

  late int _soTienThuThem;
  late int _soTienDaDongMoi;
  late int _gioiHanThanhToanThucTe;
  String? _ghiChu;
  bool _isLoading = false;
  DateTime _ngayThanhToan = DateTime.now();
  int _khoanThuKhac = 0;
  String _lyDoThuKhac = '';
  String _tenLop = '';

  @override
  void initState() {
    super.initState();
    _taiGiaTriCaiDatVaTinhToan();
  }

  void _taiGiaTriCaiDatVaTinhToan() {
    _gioiHanThanhToanThucTe = widget.hocSinh.soTienCanNop;
    final int conNoThucTe =
        _gioiHanThanhToanThucTe - widget.soTienDaDongHienTai;
    _soTienThuThem = conNoThucTe > 0 ? conNoThucTe : 0;
    _soTienDaDongMoi = widget.soTienDaDongHienTai + _soTienThuThem;

    _lopService.docLop(widget.idLop).then((lop) {
      if (lop != null && mounted) {
        setState(() {
          _tenLop = lop.ten;
        });
      }
    });
  }

  void _capNhatSoTienDaDongMoi(String value) {
    final parsedValue = int.tryParse(value.replaceAll('.', ''));
    if (parsedValue != null) {
      _soTienThuThem = parsedValue < 0 ? 0 : parsedValue;
      int calculatedNewTotal = widget.soTienDaDongHienTai + _soTienThuThem;
      final int gioiHanHienTai = _gioiHanThanhToanThucTe + _khoanThuKhac;
      if (calculatedNewTotal > gioiHanHienTai) {
        calculatedNewTotal = gioiHanHienTai;
        _soTienThuThem = calculatedNewTotal - widget.soTienDaDongHienTai;
      }
      setState(() {
        _soTienDaDongMoi = calculatedNewTotal;
      });
    }
  }

  void _capNhatKhoanThuKhac(String value) {
    final parsedValue = int.tryParse(value.replaceAll('.', ''));
    setState(() {
      _khoanThuKhac = parsedValue ?? 0;
      final int gioiHanHienTai = _gioiHanThanhToanThucTe + _khoanThuKhac;
      final int conNoThucTe = gioiHanHienTai - widget.soTienDaDongHienTai;
      _soTienThuThem = conNoThucTe > 0 ? conNoThucTe : 0;
      _soTienDaDongMoi = widget.soTienDaDongHienTai + _soTienThuThem;
    });
  }

  Future<void> _chonNgayThanhToan() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _ngayThanhToan,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: accentColor,
            onSurface: lightText,
            surface: cardColor,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        final now = DateTime.now();
        _ngayThanhToan = DateTime(
          picked.year,
          picked.month,
          picked.day,
          now.hour,
          now.minute,
          now.second,
        );
      });
    }
  }

  Future<void> _handleThanhToan() async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (_soTienThuThem <= 0) {
        Navigator.of(context).pop(false);
        return;
      }
      String finalGhiChu = _ghiChu ?? '';
      if (_khoanThuKhac > 0) {
        final String moTa = _lyDoThuKhac.trim().isNotEmpty
            ? _lyDoThuKhac.trim()
            : (isVi ? 'Phát sinh' : 'Extra fee');
        finalGhiChu = finalGhiChu.isEmpty
            ? '+${formatCurrency.format(_khoanThuKhac)}đ ($moTa)'
            : '$finalGhiChu | +${formatCurrency.format(_khoanThuKhac)}đ ($moTa)';
      }

      setState(() => _isLoading = true);
      try {
        await _ttService.capNhatSoTienDaDong(
          widget.hocSinh.idHocSinh,
          widget.idLop,
          widget.thang,
          _soTienDaDongMoi,
          finalGhiChu.isEmpty ? null : finalGhiChu,
          ngayThanhToan: _ngayThanhToan,
        );
        if (mounted) {
          final isVi = Localizations.localeOf(context).languageCode == 'vi';
          ToastHelper.showSuccess(
            context,
            isVi
                ? 'Đã thu ${formatCurrency.format(_soTienThuThem)} VNĐ của ${widget.hocSinh.tenHocSinh}'
                : 'Collected ${formatCurrency.format(_soTienThuThem)} VND from ${widget.hocSinh.tenHocSinh}',
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          final isVi = Localizations.localeOf(context).languageCode == 'vi';
          ToastHelper.showError(context, isVi ? 'Lỗi: $e' : 'Error: $e');
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _hienThiMaQR() async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final String bankId =
        (await _caiDatService.layCaiDat('bank_id')) ?? 'sacombank';
    final String accountNo =
        (await _caiDatService.layCaiDat('account_no')) ?? '0905073175';
    final String accountName =
        (await _caiDatService.layCaiDat('account_name')) ?? 'LE TRIEU BA VUONG';
    final int amount = _soTienThuThem;
    final String studentNameNoAccent = VietQRUtil.removeVietnameseAccents(
      widget.hocSinh.tenHocSinh,
    );
    final String description = 'Hoc phi $studentNameNoAccent thang ${widget.thang}';
    final String qrPayload = VietQRUtil.generateVietQRPayload(
      bankId: bankId,
      accountNo: accountNo,
      amount: amount,
      description: description,
    );

    final GlobalKey qrKey = GlobalKey();
    if (!mounted) return;



    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isVi ? 'Phiếu Thông Báo Học Phí' : 'Tuition Payment Notice',
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
              key: qrKey,
              child: _buildThongBaoHocPhiCard(
                studentName: widget.hocSinh.tenHocSinh,
                className: _tenLop,
                thang: widget.thang,
                soBuoiDu: widget.hocSinh.soBuoiDu,
                tongSoBuoi: widget.hocSinh.tongSoBuoi,
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
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final bytes = await _capturePng(qrKey);
                  if (!ctx.mounted) return;
                  if (bytes != null) {
                    _luuMaQR(
                      ctx,
                      bytes,
                      'ThongBaoHocPhi_${studentNameNoAccent}_${widget.thang}.png',
                    );
                  }
                },
                icon: const Icon(Icons.save_alt),
                label: Text(isVi ? 'Lưu ảnh' : 'Save Card'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final bytes = await _capturePng(qrKey);
                  if (!ctx.mounted) return;
                  if (bytes != null) {
                    _chiaSeMaQR(
                      ctx,
                      bytes,
                      'ThongBaoHocPhi_${studentNameNoAccent}_${widget.thang}.png',
                    );
                  }
                },
                icon: const Icon(Icons.share),
                label: Text(isVi ? 'Chia sẻ' : 'Share'),
              ),
            ],
          ),
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
                      _buildBankRow(
                        isVi ? 'Ngân hàng' : 'Bank',
                        bankId.toUpperCase(),
                      ),
                      const SizedBox(height: 4),
                      _buildBankRow(isVi ? 'Số TK' : 'Account No', accountNo),
                      const SizedBox(height: 4),
                      _buildBankRow(
                        isVi ? 'Chủ TK' : 'Account Name',
                        accountName,
                      ),
                      const SizedBox(height: 4),
                      _buildBankRow(
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

  Widget _buildBankRow(
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

  Future<Uint8List?> _capturePng(GlobalKey key) async {
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

  Future<void> _luuMaQR(
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
        isVi ? 'Đã lưu vào Download' : 'Saved to Download',
      );
    }
  }

  Future<void> _chiaSeMaQR(
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

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final int conNoConLai =
        _gioiHanThanhToanThucTe - widget.soTienDaDongHienTai;
    return AlertDialog(
      backgroundColor: cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Center(
        child: Text(
          widget.hocSinh.tenHocSinh,
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow(
                  Icons.calendar_month,
                  isVi ? 'Tháng' : 'Month',
                  widget.thang,
                ),
                _buildInfoRow(
                  Icons.payment,
                  isVi ? 'Đã đóng' : 'Paid',
                  '${formatCurrency.format(widget.soTienDaDongHienTai)}đ',
                ),
                _buildInfoRow(
                  Icons.money_off,
                  isVi ? 'Còn nợ' : 'Debt',
                  '${formatCurrency.format(conNoConLai)}đ',
                  color: deleteColor,
                ),
                const Divider(height: 24),
                // Nút chọn nhanh số tiền thu
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          side: BorderSide(
                            color: accentColor.withOpacity(0.5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: conNoConLai > 0
                            ? () {
                                setState(() {
                                  _soTienThuThem = conNoConLai;
                                  _soTienDaDongMoi =
                                      widget.soTienDaDongHienTai + _soTienThuThem;
                                });
                              }
                            : null,
                        child: Text(
                          isVi ? 'Đóng đủ (100%)' : 'Full (100%)',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          side: BorderSide(
                            color: secondaryText.withOpacity(0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: conNoConLai > 0
                            ? () {
                                setState(() {
                                  _soTienThuThem = (conNoConLai / 2).round();
                                  _soTienDaDongMoi =
                                      widget.soTienDaDongHienTai + _soTienThuThem;
                                });
                              }
                            : null,
                        child: Text(
                          isVi ? 'Nửa tháng (50%)' : 'Half (50%)',
                          style: TextStyle(
                            color: lightText,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: ValueKey(_soTienThuThem),
                  initialValue: formatCurrency.format(_soTienThuThem),
                  keyboardType: TextInputType.number,
                  style: TextStyle(
                    color: lightText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: isVi ? 'Số tiền thu' : 'Amount to collect',
                    prefixIcon: Icon(
                      Icons.payments_outlined,
                      color: accentColor,
                    ),
                    suffixText: 'VNĐ',
                    suffixStyle: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                    filled: true,
                    fillColor: darkBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
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
                  onChanged: _capNhatSoTienDaDongMoi,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  style: TextStyle(color: lightText),
                  decoration: InputDecoration(
                    labelText: isVi ? 'Ghi chú' : 'Note',
                    filled: true,
                    fillColor: darkBackground,
                  ),
                  onSaved: (v) => _ghiChu = v,
                ),
                const Divider(height: 32),
                // Các khoản thu phát sinh khác
                TextFormField(
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: lightText, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: isVi
                        ? 'Thu thêm (Sách, tài liệu...)'
                        : 'Extra fee (Books, docs...)',
                    labelStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: darkBackground,
                    prefixIcon: Icon(
                      Icons.add_circle_outline,
                      color: accentColor,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: _capNhatKhoanThuKhac,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  style: TextStyle(color: lightText, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: isVi ? 'Lý do thu thêm' : 'Reason for extra fee',
                    labelStyle: const TextStyle(fontSize: 13),
                    filled: true,
                    fillColor: darkBackground,
                    prefixIcon: Icon(
                      Icons.description_outlined,
                      color: accentColor,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (v) => _lyDoThuKhac = v,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _chonNgayThanhToan,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: isVi ? 'Ngày thanh toán' : 'Payment date',
                      filled: true,
                      fillColor: darkBackground,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd/MM/yyyy').format(_ngayThanhToan),
                          style: TextStyle(
                            color: lightText,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: secondaryText,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: _soTienThuThem > 0 ? _hienThiMaQR : null,
              icon: const Icon(Icons.qr_code, size: 18),
              label: Text(
                isVi ? 'Mã QR' : 'QR Code',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isVi ? 'Hủy' : 'Cancel',
                    style: TextStyle(color: secondaryText, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : ElevatedButton(
                        onPressed: _handleThanhToan,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          isVi ? 'XÁC NHẬN' : 'CONFIRM',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: secondaryText, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: secondaryText, fontSize: 13)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color ?? lightText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
