import 'package:flutter/material.dart';
import '../models/lop.dart';
import '../services/lop_service.dart'; // Import LopService
import '../l10n/app_localizations.dart';

// Định nghĩa Class FormLop (StatefulWidget)
class FormLop extends StatefulWidget {
  final Lop? lop; // Dùng cho trường hợp SỬA
  const FormLop({super.key, this.lop});

  @override
  State<FormLop> createState() => _FormLopState();
}

class _FormLopState extends State<FormLop> {
  // KHAI BÁO SERVICE
  final _lopService = LopService();

  final _formKey = GlobalKey<FormState>();
  final _tenLopController = TextEditingController();

  late int _selectedKhoi;
  final List<int> _danhSachKhoi = [6, 7, 8, 9, 10, 11, 12];

  // Màu sắc cho Dark Mode (đồng bộ)
  static const Color cardColor = Color(0xFF1E1E1E);
  static const Color lightText = Colors.white;
  static const Color secondaryText = Colors.white70;
  static const Color accentColor = Colors.blueAccent;
  static const Color darkBackground = Color(0xFF121212);


  @override
  void initState() {
    super.initState();
    if (widget.lop != null) {
      _tenLopController.text = widget.lop!.ten;
      _selectedKhoi = _danhSachKhoi.contains(widget.lop!.khoi) ? widget.lop!.khoi : 6;
    } else {
      _selectedKhoi = 6; // Mặc định là khối 6 khi tạo mới
    }
  }

  @override
  void dispose() {
    _tenLopController.dispose();
    super.dispose();
  }

  Future<void> _luuLop() async {
    final isVi = AppLocalizations.of(context)?.locale.languageCode == 'vi';
    if (_formKey.currentState!.validate()) {
      final String tenMoi = _tenLopController.text.trim();

      try {
        if (widget.lop == null) {
          // 1. THÊM MỚI (CREATE)
          final lopMoi = Lop(ten: tenMoi, khoi: _selectedKhoi);
          await _lopService.taoLop(lopMoi);
        } else {
          // 2. CẬP NHẬT (UPDATE)
          widget.lop!.ten = tenMoi;
          widget.lop!.khoi = _selectedKhoi;
          await _lopService.capNhatLop(widget.lop!);
        }

        // Báo thành công và quay lại
        if (mounted) {
          // Trả về true để màn hình trước (DSLop) biết và tải lại danh sách
          Navigator.pop(context, true);
        }

      } catch (e) {
        if (mounted) {
          // Xử lý lỗi (ví dụ: tên lớp bị trùng)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isVi ? 'Lỗi lưu lớp: Tên lớp có thể bị trùng hoặc lỗi hệ thống.' : 'Error saving class: Class name might be duplicated or system error.')),
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
        title: Text(widget.lop == null 
            ? (isVi ? 'Thêm Lớp Học Mới' : 'Add New Class') 
            : (isVi ? 'Sửa Lớp Học: ${widget.lop!.ten}' : 'Edit Class: ${widget.lop!.ten}')),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Chọn Khối ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(color: secondaryText),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedKhoi,
                    dropdownColor: cardColor,
                    style: const TextStyle(color: lightText, fontSize: 16),
                    icon: const Icon(Icons.arrow_drop_down, color: secondaryText),
                    hint: Text(isVi ? 'Chọn Khối' : 'Select Grade', style: const TextStyle(color: secondaryText)),
                    onChanged: (int? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedKhoi = newValue;
                        });
                      }
                    },
                    items: _danhSachKhoi.map<DropdownMenuItem<int>>((int khoi) {
                      return DropdownMenuItem<int>(
                        value: khoi,
                        child: Text(isVi ? 'Khối $khoi' : 'Grade $khoi', style: const TextStyle(color: lightText)),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- Tên Lớp ---
              TextFormField(
                controller: _tenLopController,
                style: const TextStyle(color: lightText),
                decoration: InputDecoration(
                  labelText: isVi ? 'Tên Lớp' : 'Class Name',
                  labelStyle: const TextStyle(color: secondaryText),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: secondaryText)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accentColor, width: 2)),
                  fillColor: cardColor,
                  filled: true,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return isVi ? 'Vui lòng nhập tên lớp' : 'Please enter class name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // --- Nút Lưu ---
              ElevatedButton(
                onPressed: _luuLop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: darkBackground,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(
                  widget.lop == null 
                      ? (isVi ? 'TẠO LỚP' : 'CREATE CLASS') 
                      : (isVi ? 'CẬP NHẬT LỚP' : 'UPDATE CLASS'), 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}