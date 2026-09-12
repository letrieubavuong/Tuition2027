import 'package:flutter/material.dart';
import '../models/hs.dart'; // Sử dụng model HS mới
import '../services/hoc_sinh_service.dart';
import '../l10n/app_localizations.dart';

class FormHocSinh extends StatefulWidget {
  final HS? hocSinh; // Dùng HS
  const FormHocSinh({super.key, this.hocSinh});

  @override
  State<FormHocSinh> createState() => _FormHocSinhState();
}

class _FormHocSinhState extends State<FormHocSinh> {
  final _hsService = HocSinhService();
  final _formKey = GlobalKey<FormState>();

  final _tenController = TextEditingController();
  final _sdtController = TextEditingController();
  final _truongController = TextEditingController();
  final _diaChiController = TextEditingController();
  final _ghiChuController = TextEditingController();

  // Màu sắc cho Dark Mode (đồng bộ)
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color lightText = Colors.white;
  static const Color secondaryText = Colors.white70;
  static const Color accentColor = Colors.blueAccent;
  static const Color darkBackground = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    if (widget.hocSinh != null) {
      _tenController.text = widget.hocSinh!.ten;
      _sdtController.text = widget.hocSinh!.sdt ?? '';
      _truongController.text = widget.hocSinh!.truongDangHoc ?? '';
      _diaChiController.text = widget.hocSinh!.diaChi ?? '';
      _ghiChuController.text = widget.hocSinh!.ghiChu ?? '';
    }
  }

  @override
  void dispose() {
    _tenController.dispose();
    _sdtController.dispose();
    _truongController.dispose();
    _diaChiController.dispose();
    _ghiChuController.dispose();
    super.dispose();
  }

  Future<void> _luuHocSinh() async {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    if (_formKey.currentState!.validate()) {
      final String ten = _tenController.text.trim();
      final String sdt = _sdtController.text.trim();
      final String truong = _truongController.text.trim();
      final String diaChi = _diaChiController.text.trim();
      final String ghiChu = _ghiChuController.text.trim();

      try {
        if (widget.hocSinh == null) {
          // Thêm mới
          final hsMoi = HS(
            ten: ten,
            sdt: sdt.isEmpty ? null : sdt,
            truongDangHoc: truong.isEmpty ? null : truong,
            diaChi: diaChi.isEmpty ? null : diaChi,
            ghiChu: ghiChu.isEmpty ? null : ghiChu,
          );
          await _hsService.taoHocSinh(hsMoi);
        } else {
          // Cập nhật
          widget.hocSinh!.ten = ten;
          widget.hocSinh!.sdt = sdt.isEmpty ? null : sdt;
          widget.hocSinh!.truongDangHoc = truong.isEmpty ? null : truong;
          widget.hocSinh!.diaChi = diaChi.isEmpty ? null : diaChi;
          widget.hocSinh!.ghiChu = ghiChu.isEmpty ? null : ghiChu;
          final result = await _hsService.capNhatHocSinh(widget.hocSinh!);
          if (result == 0) {
            throw Exception(
              isVi ? 'Cập nhật học sinh thất bại.' : 'Update student failed.',
            );
          }
        }

        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: cardColor,
              title: Text(
                isVi ? 'Thành công' : 'Success',
                style: const TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                widget.hocSinh == null
                    ? (isVi
                          ? 'Đã thêm học sinh!'
                          : 'Student added successfully!')
                    : (isVi
                          ? 'Đã cập nhật học sinh!'
                          : 'Student updated successfully!'),
                style: const TextStyle(color: lightText),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    isVi ? 'Đóng' : 'Close',
                    style: const TextStyle(color: secondaryText),
                  ),
                ),
              ],
            ),
          );
          if (mounted) {
            Navigator.pop(context, true); // Báo thành công và quay lại
          }
        }
      } catch (e) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: cardColor,
              title: Text(
                isVi ? 'Lỗi' : 'Error',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                isVi
                    ? 'Lỗi: Không thể lưu học sinh. Chi tiết: $e'
                    : 'Error: Unable to save student. Details: $e',
                style: const TextStyle(color: lightText),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(
                    isVi ? 'Đóng' : 'Close',
                    style: const TextStyle(color: secondaryText),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: Text(
          widget.hocSinh == null
              ? (isVi ? 'Thêm Học Sinh' : 'Add Student')
              : (isVi
                    ? 'Sửa Học Sinh: ${widget.hocSinh!.ten}'
                    : 'Edit Student: ${widget.hocSinh!.ten}'),
          style: const TextStyle(color: lightText),
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Tên Học Sinh (BẮT BUỘC) ---
              _buildTextField(
                _tenController,
                isVi ? 'Tên Học Sinh' : 'Student Name',
                Icons.person,
              ),
              const SizedBox(height: 20),

              // --- SĐT Phụ Huynh ---
              _buildTextField(
                _sdtController,
                isVi ? 'SĐT Phụ Huynh' : 'Parent Phone',
                Icons.phone,
                isNumeric: true,
                isRequired: false,
              ),
              const SizedBox(height: 20),

              // --- Trường Đang Học ---
              _buildTextField(
                _truongController,
                isVi ? 'Trường Đang Học' : 'Current School',
                Icons.school,
                isRequired: false,
              ),
              const SizedBox(height: 20),

              // --- Địa Chỉ ---
              _buildTextField(
                _diaChiController,
                isVi ? 'Địa Chỉ' : 'Address',
                Icons.home,
                isRequired: false,
              ),
              const SizedBox(height: 20),

              // --- Ghi Chú ---
              _buildTextField(
                _ghiChuController,
                isVi ? 'Ghi Chú' : 'Notes',
                Icons.note,
                maxLines: 3,
                isRequired: false,
              ),
              const SizedBox(height: 30),

              // --- Nút Lưu ---
              ElevatedButton(
                onPressed: _luuHocSinh,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: darkBackground,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  widget.hocSinh == null
                      ? (isVi ? 'LƯU HỌC SINH' : 'SAVE STUDENT')
                      : (isVi ? 'CẬP NHẬT' : 'UPDATE'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget chung cho TextFormField (Cập nhật để hỗ trợ trường không bắt buộc)
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool isNumeric = false,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: lightText),
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        labelStyle: const TextStyle(color: secondaryText),
        prefixIcon: Icon(icon, color: secondaryText),
        border: const OutlineInputBorder(),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: secondaryText),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        fillColor: cardColor,
        filled: true,
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          final isVi =
              AppLocalizations.of(context)?.locale.languageCode == 'vi';
          return isVi ? 'Vui lòng nhập $label' : 'Please enter $label';
        }
        return null;
      },
    );
  }
}
