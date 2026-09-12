// File: lib/widgets/danh_gia_dialog.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../models/nhan_xet_thang.dart';
import '../services/nhan_xet_service.dart';
import '../utils/toast_helper.dart';

class DanhGiaDialog extends StatefulWidget {
  final int idHocSinh;
  final String tenHocSinh;
  final int idLop;
  final String thang;

  const DanhGiaDialog({
    super.key,
    required this.idHocSinh,
    required this.tenHocSinh,
    required this.idLop,
    required this.thang,
  });

  @override
  State<DanhGiaDialog> createState() => _DanhGiaDialogState();
}

class _DanhGiaDialogState extends State<DanhGiaDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final _nhanXetService = NhanXetService();
  final _formKey = GlobalKey<FormState>();
  late Future<NhanXetThang> _nhanXetFuture;

  // Controllers
  final _thaiDoController = TextEditingController();
  final _baiTapController = TextEditingController();
  final _kiemTraController = TextEditingController();
  final _nhanXetChungController = TextEditingController();

  NhanXetThang? _currentNhanXet;

  @override
  void initState() {
    super.initState();
    _nhanXetFuture = _nhanXetService.layHoacTaoNhanXet(
      widget.idHocSinh,
      widget.idLop,
      widget.thang,
    );
    _nhanXetFuture.then((nx) {
      if (mounted) {
        setState(() {
          _currentNhanXet = nx;
          _thaiDoController.text = nx.diemThaiDo.toString();
          _baiTapController.text = nx.diemBaiTap.toString();
          _kiemTraController.text = nx.diemKiemTra.toString();
          _nhanXetChungController.text = nx.nhanXetChung ?? '';
        });
      }
    });
  }

  @override
  void dispose() {
    _thaiDoController.dispose();
    _baiTapController.dispose();
    _kiemTraController.dispose();
    _nhanXetChungController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate() && _currentNhanXet != null) {
      _currentNhanXet!.diemThaiDo =
          double.tryParse(_thaiDoController.text) ?? 0.0;
      _currentNhanXet!.diemBaiTap =
          double.tryParse(_baiTapController.text) ?? 0.0;
      _currentNhanXet!.diemKiemTra =
          double.tryParse(_kiemTraController.text) ?? 0.0;
      _currentNhanXet!.nhanXetChung = _nhanXetChungController.text;

      await _nhanXetService.capNhatNhanXet(_currentNhanXet!);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
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

  Future<void> _luuAnh(
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
      ToastHelper.showSuccess(context, 'Đã lưu phiếu học tập vào thư mục Download!');
    }
  }

  Future<void> _chiaSeAnh(
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

  void _hienThiPhieuAnhHocTap() {
    final cardKey = GlobalKey();
    final cc = _currentNhanXet?.diemChuyenCan ?? 10.0;
    final td = double.tryParse(_thaiDoController.text) ?? 0.0;
    final bt = double.tryParse(_baiTapController.text) ?? 0.0;
    final kt = double.tryParse(_kiemTraController.text) ?? 0.0;
    final nhanXetStr = _nhanXetChungController.text.trim();
    final xepHang = _nhanXetService.tinhXepHang(cc, td, kt, bt);

    String formattedThang = widget.thang;
    if (widget.thang.contains('-')) {
      final parts = widget.thang.split('-');
      if (parts.length == 2) formattedThang = '${parts[1]}/${parts[0]}';
    }



    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'PHIẾU BÁO CÁO KẾT QUẢ HỌC TẬP',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: RepaintBoundary(
            key: cardKey,
            child: _buildCardReportWidget(
              studentName: widget.tenHocSinh,
              thang: formattedThang,
              chuyenCan: cc,
              thaiDo: td,
              baiTap: bt,
              kiemTra: kt,
              xepHang: xepHang,
              nhanXet: nhanXetStr,
            ),
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final bytes = await _capturePng(cardKey);
                  if (bytes != null && ctx.mounted) {
                    final cleanName = widget.tenHocSinh.replaceAll(RegExp(r'[^\w]'), '_');
                    _luuAnh(ctx, bytes, 'PhieuHocTap_${cleanName}_$formattedThang.png');
                  }
                },
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Lưu ảnh'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final bytes = await _capturePng(cardKey);
                  if (bytes != null && ctx.mounted) {
                    final cleanName = widget.tenHocSinh.replaceAll(RegExp(r'[^\w]'), '_');
                    _chiaSeAnh(ctx, bytes, 'PhieuHocTap_${cleanName}_$formattedThang.png');
                  }
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Gửi Zalo / Chia sẻ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0068FF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Đóng', style: TextStyle(color: secondaryText)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardReportWidget({
    required String studentName,
    required String thang,
    required double chuyenCan,
    required double thaiDo,
    required double baiTap,
    required double kiemTra,
    required String xepHang,
    required String nhanXet,
  }) {
    Color xepHangColor = Colors.green;
    if (xepHang.contains('Xuất sắc') || xepHang.contains('Giỏi')) {
      xepHangColor = const Color(0xFF10B981);
    } else if (xepHang.contains('Khá')) {
      xepHangColor = const Color(0xFF3B82F6);
    } else if (xepHang.contains('Trung bình')) {
      xepHangColor = const Color(0xFFF59E0B);
    } else {
      xepHangColor = const Color(0xFFEF4444);
    }

    return Container(
      width: 330,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F3460), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'KẾT QUẢ HỌC TẬP TẠI LỚP',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'Tháng $thang',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Name
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.school_rounded, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        studentName,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Metrics Grid (4 môn/điểm)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildMetricItem('Chuyên cần', '${chuyenCan.toStringAsFixed(1)}/10', Icons.task_alt_rounded, Colors.green)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricItem('Thái độ học', '${thaiDo.toStringAsFixed(1)}/10', Icons.psychology_rounded, Colors.blue)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildMetricItem('Bài tập ở nhà', '${baiTap.toStringAsFixed(1)}/10', Icons.assignment_turned_in_rounded, Colors.orange)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildMetricItem('Bài kiểm tra', '${kiemTra.toStringAsFixed(1)}/10', Icons.quiz_rounded, Colors.purple)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Rank Badge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: xepHangColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: xepHangColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: xepHangColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'XẾP LOẠI: ',
                        style: TextStyle(
                          color: xepHangColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        xepHang.toUpperCase(),
                        style: TextStyle(
                          color: xepHangColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Teacher Remark Box
                const Text(
                  'NHẬN XÉT TỪ GIÁO VIÊN:',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(
                    nhanXet.isNotEmpty ? nhanXet : 'Học sinh đi học đầy đủ và có tiến bộ tốt trong tháng.',
                    style: const TextStyle(
                      color: Color(0xFF78350F),
                      fontSize: 12.5,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Footer note
                const Center(
                  child: Text(
                    'Kính mong quý phụ huynh đôn đốc học sinh duy trì nỗ lực!',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isVi
            ? 'Đánh giá tháng ${widget.thang} cho ${widget.tenHocSinh}'
            : 'Evaluation for ${widget.tenHocSinh} of ${widget.thang}',
        style: TextStyle(color: lightText, fontSize: 18),
        textAlign: TextAlign.center,
      ),
      content: FutureBuilder<NhanXetThang>(
        future: _nhanXetFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: accentColor));
          }
          if (snapshot.hasError) {
            return Text(
              isVi ? 'Lỗi: ${snapshot.error}' : 'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            );
          }

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow(
                    isVi ? 'Chuyên cần' : 'Attendance',
                    (_currentNhanXet?.diemChuyenCan ?? 10.0).toStringAsFixed(1),
                  ),
                  const SizedBox(height: 12),
                  _buildScoreField(
                    _thaiDoController,
                    isVi ? 'Điểm thái độ' : 'Attitude score',
                    isVi,
                  ),
                  const SizedBox(height: 12),
                  _buildScoreField(
                    _baiTapController,
                    isVi ? 'Điểm bài tập' : 'Homework score',
                    isVi,
                  ),
                  const SizedBox(height: 12),
                  _buildScoreField(
                    _kiemTraController,
                    isVi ? 'Điểm kiểm tra' : 'Test score',
                    isVi,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nhanXetChungController,
                    style: TextStyle(color: lightText),
                    maxLines: 3,
                    decoration: _inputDecoration(
                      isVi ? 'Nhận xét chung' : 'General remarks',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _hienThiPhieuAnhHocTap,
                      icon: const Icon(Icons.image_rounded, size: 18),
                      label: Text(
                        isVi ? 'XUẤT PHIẾU BÁO CÁO HỌC TẬP (ẢNH)' : 'EXPORT REPORT CARD (IMAGE)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0068FF),
                        side: const BorderSide(color: Color(0xFF0068FF)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            isVi ? 'Hủy' : 'Cancel',
            style: TextStyle(color: secondaryText),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {
            final cc = _currentNhanXet?.diemChuyenCan ?? 10.0;
            final td = double.tryParse(_thaiDoController.text) ?? 0.0;
            final bt = double.tryParse(_baiTapController.text) ?? 0.0;
            final kt = double.tryParse(_kiemTraController.text) ?? 0.0;
            setState(() {
              _nhanXetChungController.text = _nhanXetService
                  .sinhNhanXetThangTuDong(cc, td, kt, bt);
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor),
          ),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text(isVi ? 'Tự sinh' : 'Auto Remark'),
        ),
        ElevatedButton.icon(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: darkBackground,
          ),
          icon: const Icon(Icons.save),
          label: Text(isVi ? 'Lưu' : 'Save'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return InputDecorator(
      decoration: _inputDecoration(label).copyWith(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: lightText,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildScoreField(
    TextEditingController controller,
    String label,
    bool isVi,
  ) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: lightText),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _inputDecoration(label),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return isVi ? 'Không được để trống' : 'Cannot be empty';
        }
        final score = double.tryParse(value);
        if (score == null || score < -10 || score > 10) {
          return isVi ? 'Điểm phải từ -10 đến 10' : 'Score must be -10 to 10';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: TextStyle(color: secondaryText, fontSize: 13),
      filled: true,
      fillColor: darkBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: secondaryText),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: secondaryText),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
    );
  }
}
