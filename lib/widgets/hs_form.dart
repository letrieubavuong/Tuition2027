// File: lib/widgets/hoc_sinh_form_dialog.dart

import 'package:flutter/material.dart';
import '../models/hs.dart';
import '../models/truong.dart';
import '../services/hoc_sinh_service.dart';
import '../services/truong_service.dart';

// --- HẰNG SỐ MÀU SẮC (Lấy từ DSHocSinh để đồng bộ) ---
// const Color darkBackground = Color(0xFF1A1A2E);
// const Color cardColor = Color(0xFF16213E);
// const Color lightText = Colors.white;
// const Color secondaryText = Colors.white70;
// const Color accentColor = Color(0xFF00BFA5); // Teal Accent

// =======================================================
// 1. WIDGET CHÍNH: Chứa Form và Logic
// =======================================================
class HocSinhFormDialog extends StatefulWidget {
  final HS? hocSinh;
  final List<Truong> danhSachTruong;
  final HocSinhService hsService;

  const HocSinhFormDialog({
    super.key,
    this.hocSinh,
    required this.danhSachTruong,
    required this.hsService,
  });

  @override
  State<HocSinhFormDialog> createState() => _HocSinhFormDialogState();
}

class _HocSinhFormDialogState extends State<HocSinhFormDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tenController;
  late final TextEditingController _sdtController;
  late final TextEditingController _diaChiController;
  late final TextEditingController _ghiChuController;
  late final TextEditingController _facebookController;
  late final TextEditingController _mienGiamController;
  late final TextEditingController _lichCanController;
  String? _selectedTruong;
  String _selectedCaHocTruong = 'Sáng';
  bool get isEditing => widget.hocSinh != null;
  final TruongService _truongService = TruongService();
  late Future<List<Truong>> _truongFuture;

  @override
  void initState() {
    super.initState();
    _tenController = TextEditingController(text: widget.hocSinh?.ten);
    _sdtController = TextEditingController(text: widget.hocSinh?.sdt);
    _diaChiController = TextEditingController(text: widget.hocSinh?.diaChi);
    _ghiChuController = TextEditingController(text: widget.hocSinh?.ghiChu);
    _facebookController = TextEditingController(text: widget.hocSinh?.facebook);
    _mienGiamController = TextEditingController(
      text: (widget.hocSinh?.mienGiam ?? 0).toString(),
    );
    _lichCanController = TextEditingController(
      text: widget.hocSinh?.lichCanMonKhac,
    );
    _selectedTruong = widget.hocSinh?.truongDangHoc;
    _selectedCaHocTruong = widget.hocSinh?.caHocTruong ?? 'Sáng';
    _truongFuture = _truongService.docTatCaTruong();
  }

  @override
  void dispose() {
    _tenController.dispose();
    _sdtController.dispose();
    _diaChiController.dispose();
    _ghiChuController.dispose();
    _facebookController.dispose();
    _mienGiamController.dispose();
    _lichCanController.dispose();
    super.dispose();
  }

  // Hàm xử lý lưu/cập nhật
  void _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final ten = _tenController.text.trim();
      final sdt = _sdtController.text.trim();
      final diaChi = _diaChiController.text.trim();
      final ghiChu = _ghiChuController.text.trim();
      final facebook = _facebookController.text.trim();
      final mienGiam = int.tryParse(_mienGiamController.text.trim()) ?? 0;
      final lichCan = _lichCanController.text.trim();

      try {
        HS newOrUpdatedHs;
        if (isEditing) {
          // CẬP NHẬT
          // 1. Tạo bản sao từ đối tượng hiện tại (đảm bảo giữ lại ID thông qua copyWith)
          newOrUpdatedHs = widget.hocSinh!.copyWith();

          // 2. Gán ID tường minh để đảm bảo an toàn cho lệnh UPDATE
          newOrUpdatedHs.id = widget.hocSinh!.id;

          // 3. Gán các giá trị mới
          newOrUpdatedHs.ten = ten;
          newOrUpdatedHs.sdt = sdt.isEmpty ? null : sdt;
          newOrUpdatedHs.truongDangHoc = _selectedTruong;
          newOrUpdatedHs.diaChi = diaChi.isEmpty ? null : diaChi;
          newOrUpdatedHs.ghiChu = ghiChu.isEmpty ? null : ghiChu;
          newOrUpdatedHs.facebook = facebook.isEmpty ? null : facebook;
          newOrUpdatedHs.mienGiam = mienGiam;
          newOrUpdatedHs.caHocTruong = _selectedCaHocTruong;
          newOrUpdatedHs.lichCanMonKhac = lichCan.isEmpty ? null : lichCan;

          await widget.hsService.capNhatHocSinh(newOrUpdatedHs);
        } else {
          // THÊM MỚI
          final hsMoi = HS(
            ten: ten,
            sdt: sdt.isEmpty ? null : sdt,
            truongDangHoc: _selectedTruong,
            diaChi: diaChi.isEmpty ? null : diaChi,
            ghiChu: ghiChu.isEmpty ? null : ghiChu,
            facebook: facebook.isEmpty ? null : facebook,
            mienGiam: mienGiam,
            caHocTruong: _selectedCaHocTruong,
            lichCanMonKhac: lichCan.isEmpty ? null : lichCan,
          );

          final result = await widget.hsService.taoHocSinh(hsMoi);
          newOrUpdatedHs = result;
        }

        // Trả về đối tượng HS đã được lưu/cập nhật
        if (mounted) {
          Navigator.of(context).pop(newOrUpdatedHs);
        }
      } catch (e) {
        // Log lỗi để debug (tùy chọn)
        debugPrint('Lỗi lưu/cập nhật học sinh: $e');

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: cardColor,
              title: const Text(
                'Lỗi',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Text(
                'Không thể lưu học sinh. Vui lòng kiểm tra kết nối database hoặc log lỗi.',
                style: TextStyle(color: lightText),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Đóng', style: TextStyle(color: secondaryText)),
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
    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      title: Center(
        child: Text(
          isEditing ? 'SỬA HỌC SINH' : 'THÊM HỌC SINH',
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Tên Học Sinh ---
              _buildTextField(
                _tenController,
                'Tên Học Sinh',
                Icons.person,
                isRequired: true,
              ),
              const SizedBox(height: 15),

              // --- Dropdown Chọn Trường ---
              _buildTruongDropdown(),
              const SizedBox(height: 15),

              // --- Mức Miễn Giảm ---
              _buildTextField(
                _mienGiamController,
                'Miễn Giảm (%) (0-100)',
                Icons.percent,
                isNumeric: true,
                isRequired: true,
                validatePercent: true,
              ),
              const SizedBox(height: 15),

              // --- SĐT Phụ Huynh ---
              _buildTextField(
                _sdtController,
                'SĐT Phụ Huynh',
                Icons.phone,
                isNumeric: true,
              ),
              const SizedBox(height: 15),

              // --- Địa Chỉ ---
              _buildTextField(_diaChiController, 'Địa Chỉ', Icons.home),
              const SizedBox(height: 15),

              // --- Link/Địa chỉ Facebook ---
              _buildTextField(
                _facebookController,
                'Link / Địa chỉ Facebook',
                Icons.facebook,
              ),
              const SizedBox(height: 15),

              // --- Ca Học Ở Trường ---
              _buildCaHocTruongDropdown(),
              const SizedBox(height: 15),

              // --- Lịch Cấn Môn Khác ---
              _buildTextField(
                _lichCanController,
                'Lịch cấn môn khác (VD: Văn T2, Anh T4)',
                Icons.event_busy_rounded,
                maxLines: 1,
              ),
              const SizedBox(height: 15),

              // --- Ghi Chú ---
              _buildTextField(
                _ghiChuController,
                'Ghi Chú',
                Icons.note,
                maxLines: 1,
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: _handleSave,
          style: ElevatedButton.styleFrom(
            // SỬA: Đồng bộ màu nút
            backgroundColor: accentColor,
            foregroundColor: darkBackground,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.0),
            ),
          ),
          child: Text(
            isEditing ? 'CẬP NHẬT' : 'TẠO HỌC SINH',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  // Widget hỗ trợ Dropdown
  Widget _buildTruongDropdown() {
    return FutureBuilder<List<Truong>>(
      future: _truongFuture,
      builder: (context, snapshot) {
        List<Truong> danhSach = snapshot.hasData
            ? snapshot.data!
            : widget.danhSachTruong;

        // Đảm bảo giá trị _selectedTruong tồn tại trong danh sách mới (Tránh lỗi văng app khi lỡ xóa trường cũ)
        bool valueExists =
            _selectedTruong == null ||
            danhSach.any((t) => t.ten == _selectedTruong);
        String? safeValue = valueExists ? _selectedTruong : null;

        return Container(
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: secondaryText)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.school, color: secondaryText, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: safeValue,
                    dropdownColor: darkBackground,
                    style: TextStyle(color: lightText, fontSize: 16),
                    icon: Icon(Icons.arrow_drop_down, color: secondaryText),
                    hint: Text(
                      'Trường Đang Học (Tùy chọn)',
                      style: TextStyle(color: secondaryText),
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedTruong = newValue;
                      });
                    },
                    isExpanded: true,
                    items: [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          '(Không chọn/Không có)',
                          style: TextStyle(color: secondaryText),
                        ),
                      ),
                      ...danhSach.map<DropdownMenuItem<String>>((
                        Truong truong,
                      ) {
                        return DropdownMenuItem<String>(
                          value: truong.ten,
                          child: Text(
                            truong.ten,
                            style: TextStyle(color: lightText),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCaHocTruongDropdown() {
    final caOptions = [
      {'val': 'Sáng', 'label': '☀️ Học Sáng ở trường', 'sub': 'Rảnh chiều/tối'},
      {'val': 'Chiều', 'label': '🌤️ Học Chiều ở trường', 'sub': 'Rảnh sáng/tối muộn'},
      {'val': 'Cả ngày', 'label': '🏫 Học Cả ngày ở trường', 'sub': 'Rảnh tối/cuối tuần'},
    ];

    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: secondaryText)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.wb_sunny_rounded, color: secondaryText, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCaHocTruong,
                dropdownColor: darkBackground,
                style: TextStyle(color: lightText, fontSize: 16),
                icon: Icon(Icons.arrow_drop_down, color: secondaryText),
                isExpanded: true,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCaHocTruong = newValue;
                    });
                  }
                },
                items: caOptions.map((opt) {
                  return DropdownMenuItem<String>(
                    value: opt['val'],
                    child: Text(
                      opt['label']!,
                      style: TextStyle(color: lightText, fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget hỗ trợ TextField (Giữ nguyên logic Dark Mode từ DSHocSinh)
  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumeric = false,
    int maxLines = 1,
    bool isRequired = false,
    bool validatePercent = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: lightText),
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: secondaryText),
        prefixIcon: Icon(icon, color: secondaryText),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: secondaryText),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: accentColor, width: 2),
        ),
        fillColor: Colors.transparent,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return 'Vui lòng nhập ${hint.toLowerCase()}';
        }
        if (validatePercent) {
          final number = int.tryParse(value!);
          if (number == null || number < 0 || number > 100) {
            return 'Miễn giảm phải là số nguyên từ 0 đến 100';
          }
        }
        return null;
      },
    );
  }
}

// =======================================================
// 2. HÀM HELPER: Dùng để gọi Dialog từ bất kỳ đâu
// =======================================================
Future<HS?> showHocSinhFormDialog({
  required BuildContext context,
  required List<Truong> danhSachTruong,
  required HocSinhService hsService,
  HS? hocSinh,
}) {
  return showDialog<HS?>(
    context: context,
    builder: (context) => HocSinhFormDialog(
      hocSinh: hocSinh,
      danhSachTruong: danhSachTruong,
      hsService: hsService,
    ),
  );
}
