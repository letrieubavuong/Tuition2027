// File: lib/widgets/thu_tien_hoc_phi_dialog.dart

import 'dart:io';
import 'dart:typed_data';
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
import '../services/thanh_toan_service.dart';
import '../services/caidat_service.dart';
import '../services/lop_service.dart';
import '../models/lop.dart';
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
  Color get lightText => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final _formKey = GlobalKey<FormState>();
  final ThanhToanService _ttService = ThanhToanService();
  final CaiDatService _caiDatService = CaiDatService();
  final LopService _lopService = LopService();
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
    final int conNoThucTe = _gioiHanThanhToanThucTe - widget.soTienDaDongHienTai;
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
        _ngayThanhToan = DateTime(picked.year, picked.month, picked.day, now.hour, now.minute, now.second);
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
        final String moTa = _lyDoThuKhac.trim().isNotEmpty ? _lyDoThuKhac.trim() : (isVi ? 'Phát sinh' : 'Extra fee');
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
          ToastHelper.showSuccess(context, isVi 
              ? 'Đã thu ${formatCurrency.format(_soTienThuThem)} VNĐ của ${widget.hocSinh.tenHocSinh}'
              : 'Collected ${formatCurrency.format(_soTienThuThem)} VND from ${widget.hocSinh.tenHocSinh}');
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

  String _removeVietnameseAccents(String str) {
    const accents = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
    const withoutAccents = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyy d';
    String result = str.toLowerCase();
    for (int i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], withoutAccents[i]);
    }
    return result.replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
  }

  void _hienThiMaQR() async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final String bankId = (await _caiDatService.layCaiDat('bank_id')) ?? 'sacombank';
    final String accountNo = (await _caiDatService.layCaiDat('account_no')) ?? '0905073175';
    final int amount = _soTienThuThem;
    final String studentName = _removeVietnameseAccents(widget.hocSinh.tenHocSinh);
    final String description = 'Hoc phi $studentName thang ${widget.thang}';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isVi ? 'Mã QR Chuyển Khoản' : 'Bank Transfer QR Code', style: TextStyle(color: lightText), textAlign: TextAlign.center),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: qrKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(data: qrPayload, size: 240, version: QrVersions.auto),
                ),
              ),
              const SizedBox(height: 16),
              Text('${formatCurrency.format(amount)}đ', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 18)),
              Text('NH: ${bankId.toUpperCase()} - $accountNo', style: TextStyle(color: secondaryText, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final bytes = await _capturePng(qrKey);
                  if (bytes != null) _luuMaQR(ctx, bytes, 'QR_${studentName}_${widget.thang}.png');
                },
                icon: const Icon(Icons.save_alt),
                label: Text(isVi ? 'Lưu' : 'Save'),
              ),
              TextButton.icon(
                onPressed: () async {
                  final bytes = await _capturePng(qrKey);
                  if (bytes != null) {
                    // Chuyển đổi widget.thang (định dạng YYYY-MM) thành MM/YYYY
                    String formattedThang = widget.thang;
                    final parts = widget.thang.split('-');
                    if (parts.length == 2) {
                      formattedThang = '${parts[1]}/${parts[0]}';
                    }

                    final String shareText = isVi
                        ? 'Kính gửi phụ huynh học sinh, đây là thông tin học phí ${widget.hocSinh.tenHocSinh}, tháng $formattedThang môn học: $_tenLop. Quý phụ huynh thanh toán vào đầu tháng. Xin chân thành cảm ơn.'
                        : 'Dear parents, here is the tuition fee details for ${widget.hocSinh.tenHocSinh}, month $formattedThang subject: $_tenLop. Please settle at the beginning of the month. Thank you very much.';
                    _chiaSeMaQR(ctx, bytes, 'QR_${studentName}_${widget.thang}.png', shareText);
                  }
                },
                icon: const Icon(Icons.share),
                label: Text(isVi ? 'Chia sẻ' : 'Share'),
              ),
            ],
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isVi ? 'Đóng' : 'Close', style: TextStyle(color: secondaryText))),
        ],
      ),
    );
  }

  Future<Uint8List?> _capturePng(GlobalKey key) async {
    try {
      RenderRepaintBoundary? boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) { return null; }
  }

  Future<void> _luuMaQR(BuildContext context, Uint8List bytes, String fileName) async {
    var status = await Permission.manageExternalStorage.request();
    if (!status.isGranted) return;
    final dir = Directory('/storage/emulated/0/Download');
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    if (context.mounted) {
      final isVi = Localizations.localeOf(context).languageCode == 'vi';
      ToastHelper.showSuccess(context, isVi ? 'Đã lưu vào Download' : 'Saved to Download');
    }
  }

  Future<void> _chiaSeMaQR(BuildContext context, Uint8List bytes, String fileName, String text) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    // Sao chép thông tin học phí vào bộ nhớ tạm để có thể dán (paste) ở Messenger/Zalo
    await Clipboard.setData(ClipboardData(text: text));

    if (context.mounted) {
      final isVi = Localizations.localeOf(context).languageCode == 'vi';
      ToastHelper.showInfo(context, isVi
              ? 'Đã copy thông tin học phí vào bộ nhớ tạm. Bạn có thể dán (paste) khi gửi tin nhắn!'
              : 'Tuition information copied to clipboard. You can paste it when sending the message!');
    }

    await Share.shareXFiles([XFile(file.path)], text: text);
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final int conNoConLai = _gioiHanThanhToanThucTe - widget.soTienDaDongHienTai;
    return AlertDialog(
      backgroundColor: cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Center(child: Text(widget.hocSinh.tenHocSinh, style: TextStyle(color: lightText, fontWeight: FontWeight.bold))),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(Icons.calendar_month, isVi ? 'Tháng' : 'Month', widget.thang),
              _buildInfoRow(Icons.payment, isVi ? 'Đã đóng' : 'Paid', '${formatCurrency.format(widget.soTienDaDongHienTai)}đ'),
              _buildInfoRow(Icons.money_off, isVi ? 'Còn nợ' : 'Debt', '${formatCurrency.format(conNoConLai)}đ', color: deleteColor),
              const Divider(height: 32),
              TextFormField(
                initialValue: formatCurrency.format(conNoConLai > 0 ? conNoConLai : 0),
                keyboardType: TextInputType.number,
                style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: isVi ? 'Số tiền thu' : 'Amount to collect',
                  filled: true,
                  fillColor: darkBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: _capNhatSoTienDaDongMoi,
              ),
              const SizedBox(height: 16),
              TextFormField(
                style: TextStyle(color: lightText),
                decoration: InputDecoration(labelText: isVi ? 'Ghi chú' : 'Note', filled: true, fillColor: darkBackground),
                onSaved: (v) => _ghiChu = v,
              ),
              const Divider(height: 32),
              // Các khoản thu phát sinh khác
              TextFormField(
                keyboardType: TextInputType.number,
                style: TextStyle(color: lightText, fontSize: 14),
                decoration: InputDecoration(
                  labelText: isVi ? 'Thu thêm (Sách, tài liệu...)' : 'Extra fee (Books, docs...)',
                  labelStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: darkBackground,
                  prefixIcon: Icon(Icons.add_circle_outline, color: accentColor, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                  prefixIcon: Icon(Icons.description_outlined, color: accentColor, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy').format(_ngayThanhToan),
                        style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
                      ),
                      Icon(Icons.calendar_today, color: secondaryText, size: 20),
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
              label: Text(isVi ? 'Mã QR' : 'QR Code', style: const TextStyle(fontSize: 12)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isVi ? 'Hủy' : 'Cancel', style: TextStyle(color: secondaryText, fontSize: 13)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: Text(isVi ? 'XÁC NHẬN' : 'CONFIRM', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: secondaryText, size: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: secondaryText, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: color ?? lightText, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
