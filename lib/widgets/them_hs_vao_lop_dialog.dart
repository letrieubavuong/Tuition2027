// File: lib/widgets/them_hs_vao_lop_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hs.dart';
import '../models/lop.dart';
import '../models/truong.dart';
import '../models/lop_hoc_sinh.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../services/hoc_sinh_service.dart';
import 'hs_form.dart';

// --- HẰNG SỐ MÀU SẮC (Lấy từ LopDetail để đồng bộ) ---
// const Color darkBackground = Color(0xFF1A1A2E);
// const Color cardColor = Color(0xFF16213E);
// const Color lightText = Colors.white;
// const Color secondaryText = Colors.white70;
// const Color accentColor = Color(0xFF00BFA5); // Teal Accent

class ThemHSVaoLopDialog extends StatefulWidget {
  final Lop lop;
  // Danh sách HS chỉ chứa những người chưa có trong lớp hiện tại
  final List<HS> danhSachTatCaHS;
  final LopHocSinhService lhsService;
  final HocSinhService hsService;
  final List<Truong> danhSachTruong;

  const ThemHSVaoLopDialog({
    super.key,
    required this.lop,
    required this.danhSachTatCaHS,
    required this.lhsService,
    required this.hsService,
    required this.danhSachTruong,
  });

  @override
  State<ThemHSVaoLopDialog> createState() => _ThemHSVaoLopDialogState();
}

class _ThemHSVaoLopDialogState extends State<ThemHSVaoLopDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  HS? _selectedHS;
  DateTime _ngayThamGia = DateTime.now();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Khởi tạo _selectedHS nếu danh sách không rỗng (chọn HS đầu tiên)
    if (widget.danhSachTatCaHS.isNotEmpty) {
      _selectedHS = widget.danhSachTatCaHS.first;
    }
  }

  // Hàm chọn ngày (Date Picker)
  Future<void> _chonNgayThamGia(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _ngayThamGia,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor, // Màu nhấn cho ngày được chọn
              onPrimary: darkBackground,
              surface: cardColor, // Màu nền của DatePicker
              onSurface: lightText,
            ),
            dialogTheme: DialogThemeData(backgroundColor: cardColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _ngayThamGia) {
      setState(() {
        _ngayThamGia = picked;
      });
    }
  }

  // Hàm tạo mới HS và thêm vào lớp
  Future<void> _handleTaoMoiVaThem() async {
    final newHs = await showHocSinhFormDialog(
      context: context,
      danhSachTruong: widget.danhSachTruong,
      hsService: widget.hsService,
    );

    if (newHs != null) {
      try {
        final lhs = LopHocSinh(
          idLop: widget.lop.id!,
          idHocSinh: newHs.id!,
          ngayThamGia: DateFormat('yyyy-MM-dd').format(_ngayThamGia),
        );

        await widget.lhsService.themHocSinhVaoLop(lhs);

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          final isVi = Localizations.localeOf(context).languageCode == 'vi';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isVi ? 'Lỗi khi thêm học sinh mới vào lớp: $e' : 'Error adding new student to class: $e')),
          );
        }
      }
    }
  }

  // Hàm lưu (Thêm HS vào Lớp)
  void _handleThemHS() async {
    // Đảm bảo đã chọn học sinh
    if (_formKey.currentState!.validate() && _selectedHS != null) {
      try {
        final lhs = LopHocSinh(
          idLop: widget.lop.id!,
          idHocSinh: _selectedHS!.id!,
          ngayThamGia: DateFormat(
            'yyyy-MM-dd',
          ).format(_ngayThamGia), // Lưu dưới dạng SQL format
          // trangThai sẽ dùng giá trị mặc định 'Dang hoc'
        );

        await widget.lhsService.themHocSinhVaoLop(lhs);

        // Trả về true để LopDetail refresh danh sách
        if (mounted) {
          Navigator.of(context).pop(true);
          // Không hiển thị SnackBar ở đây, để LopDetail xử lý (đã có ở bước trước)
        }
      } catch (e) {
        // Xử lý lỗi UNIQUE constraint (HS đã có trong lớp)
        final isVi = Localizations.localeOf(context).languageCode == 'vi';
        String errorMessage = isVi ? 'Lỗi: Không thể thêm học sinh.' : 'Error: Cannot add student.';
        if (e.toString().contains('UNIQUE constraint failed')) {
          errorMessage = isVi ? 'Lỗi: Học sinh này đã có trong lớp!' : 'Error: This student is already in the class!';
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Center(
        child: Text(
          isVi ? 'THÊM HỌC SINH' : 'ADD STUDENT',
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nút tạo mới học sinh
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _handleTaoMoiVaThem,
                  icon: const Icon(Icons.person_add_alt_1, size: 20),
                  label: Text(isVi ? 'TẠO MỚI HỌC SINH' : 'CREATE NEW STUDENT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accentColor,
                    side: BorderSide(color: accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: secondaryText)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(isVi ? 'HOẶC CHỌN TỪ DANH SÁCH' : 'OR SELECT FROM LIST',
                        style: TextStyle(color: secondaryText, fontSize: 10)),
                  ),
                  Expanded(child: Divider(color: secondaryText)),
                ],
              ),
              const SizedBox(height: 16),

              // --- 1. Dropdown Chọn Học Sinh ---
              if (widget.danhSachTatCaHS.isEmpty)
                Text(
                  isVi ? 'Tất cả học sinh hiện tại đã có trong lớp.' : 'All current students are already in this class.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryText, fontSize: 13),
                )
              else
                _buildDropdownChonHS(),

              const SizedBox(height: 20),

              // --- 2. Chọn Ngày Nhập Học ---
              _buildChonNgayThamGia(context),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            isVi ? 'HỦY' : 'CANCEL',
            style: TextStyle(color: secondaryText, fontWeight: FontWeight.bold),
          ),
        ),
        if (widget.danhSachTatCaHS.isNotEmpty)
          ElevatedButton(
            onPressed: _handleThemHS,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: darkBackground,
            ),
            child: Text(
              isVi ? 'THÊM' : 'ADD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: darkBackground,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDropdownChonHS() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: secondaryText.withOpacity(0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<HS>(
          value: _selectedHS,
          dropdownColor: darkBackground,
          style: TextStyle(color: lightText, fontSize: 16),
          icon: Icon(Icons.arrow_drop_down, color: secondaryText),
          onChanged: (HS? newValue) {
            setState(() {
              _selectedHS = newValue;
            });
          },
          isExpanded: true,
          items: widget.danhSachTatCaHS.map<DropdownMenuItem<HS>>((HS hs) {
            return DropdownMenuItem<HS>(
              value: hs,
              child: Text(
                '${hs.ten}',
                style: TextStyle(color: lightText),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChonNgayThamGia(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Căn lề trái cho các mục
      children: [
        // Dòng 1: Tiêu đề "Ngày Tham Gia"
        Row(
          children: [
            Icon(Icons.calendar_today, color: accentColor),
            const SizedBox(width: 10),
            Text(
              isVi ? 'Ngày Tham Gia:' : 'Date Joined:',
              style: TextStyle(
                color: lightText,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Dòng 2: Hiển thị ngày và Nút chọn ngày
        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween, // Đẩy hai mục ra hai bên
          children: [
            // Hiển thị ngày đã chọn
            Padding(
              padding: const EdgeInsets.only(left: 35),
              child: Text(
                // SỬA: Chuẩn hóa định dạng ngày
                DateFormat('dd/MM/yyyy').format(_ngayThamGia),
                style: TextStyle(
                  color: lightText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Nút Chọn Ngày
            TextButton(
              onPressed: () => _chonNgayThamGia(context),
              child: Text(
                isVi ? 'CHỌN NGÀY' : 'SELECT DATE',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
