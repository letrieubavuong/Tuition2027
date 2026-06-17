// File: lib/widgets/danh_gia_dialog.dart

import 'package:flutter/material.dart';
import '../models/nhan_xet_thang.dart';
import '../services/nhan_xet_service.dart';

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
  Color get lightText => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
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

  // Theme
  // static const Color cardColor = Color(0xFF16213E);
  // static const Color lightText = Colors.white;
  // static const Color secondaryText = Colors.white70;
  // static const Color accentColor = Color(0xFF00BFA5);
  // static const Color darkBackground = Color(0xFF1A1A2E);

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
        Navigator.of(context).pop(true); // Trả về true để báo hiệu cần làm mới
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return AlertDialog(
      backgroundColor: cardColor,
      title: Text(
        isVi ? 'Đánh giá tháng ${widget.thang} cho ${widget.tenHocSinh}' : 'Evaluation for ${widget.tenHocSinh} of ${widget.thang}',
        style: TextStyle(color: lightText, fontSize: 18),
        textAlign: TextAlign.center,
      ),
      content: FutureBuilder<NhanXetThang>(
        future: _nhanXetFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: accentColor),
            );
          }
          if (snapshot.hasError) {
            return Text(
              isVi ? 'Lỗi: ${snapshot.error}' : 'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            );
          }

          final nhanXet = snapshot.data!;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoRow(
                    isVi ? 'Chuyên cần' : 'Attendance',
                    nhanXet.diemChuyenCan.toStringAsFixed(1),
                  ),
                  const SizedBox(height: 16),
                  _buildScoreField(_thaiDoController, isVi ? 'Điểm thái độ' : 'Attitude score', isVi),
                  const SizedBox(height: 16),
                  _buildScoreField(_baiTapController, isVi ? 'Điểm bài tập' : 'Homework score', isVi),
                  const SizedBox(height: 16),
                  _buildScoreField(_kiemTraController, isVi ? 'Điểm kiểm tra' : 'Test score', isVi),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nhanXetChungController,
                    style: TextStyle(color: lightText),
                    maxLines: 3,
                    decoration: _inputDecoration(isVi ? 'Nhận xét chung' : 'General remarks'),
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
          child: Text(isVi ? 'Hủy' : 'Cancel', style: TextStyle(color: secondaryText)),
        ),
        OutlinedButton.icon(
          onPressed: () {
            final cc = _currentNhanXet?.diemChuyenCan ?? 10.0;
            final td = double.tryParse(_thaiDoController.text) ?? 0.0;
            final bt = double.tryParse(_baiTapController.text) ?? 0.0;
            final kt = double.tryParse(_kiemTraController.text) ?? 0.0;
            setState(() {
              _nhanXetChungController.text = _nhanXetService.sinhNhanXetThangTuDong(cc, td, kt, bt);
            });
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: accentColor,
            side: BorderSide(color: accentColor),
          ),
          icon: const Icon(Icons.auto_awesome, size: 16),
          label: Text(isVi ? 'Tự sinh nhận xét' : 'Auto Remark'),
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
          vertical: 16,
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: lightText,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildScoreField(TextEditingController controller, String label, bool isVi) {
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
      labelText: label,
      labelStyle: TextStyle(color: secondaryText),
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
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
    );
  }
}
