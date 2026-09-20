// File: lib/screens/ds_lop.dart

import 'package:flutter/material.dart';
import '../main.dart';
import '../models/lop.dart';
import '../widgets/main_drawer.dart';
import '../services/lop_service.dart';
import '../l10n/app_localizations.dart';
import 'lop_detail.dart';
import '../widgets/gui_thong_bao_hang_loat_dialog.dart';
import '../utils/toast_helper.dart';

class DSLop extends StatefulWidget {
  final GlobalKey<MainScreenState> mainScreenKey;
  final int selectedIndex;
  const DSLop({
    super.key,
    required this.mainScreenKey,
    required this.selectedIndex,
  });

  @override
  State<DSLop> createState() => _DSLopState();
}

class _DSLopState extends State<DSLop> {
  final _lopService = LopService();

  List<Lop> _danhSachLop = [];
  bool _dangTai = true;

  // Theme màu mới, hiện đại hơn
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  // Danh sách các khối cho Dropdown
  final List<int> _danhSachKhoi = [6, 7, 8, 9, 10, 11, 12];

  @override
  void initState() {
    super.initState();
    _taiDSLop();
  }

  // Đọc/Tải Danh Sách Lớp (READ)
  Future<void> _taiDSLop() async {
    setState(() => _dangTai = true);
    final ds = await _lopService.docTatCaLop();
    if (!mounted) return;
    setState(() {
      _danhSachLop = ds;
      _dangTai = false;
    });
  }

  // Xóa Lớp (DELETE)
  Future<void> _xoaLop(int id) async {
    final result = await _lopService.xoaLop(id);
    if (!mounted) return;
    if (result <= 0) {
      ToastHelper.showError(
        context,
        Localizations.localeOf(context).languageCode == 'vi'
            ? 'Không thể xóa lớp. Vui lòng thử lại.'
            : 'Could not delete the class. Please try again.',
      );
      return;
    }

    setState(() => _danhSachLop.removeWhere((lop) => lop.id == id));
    ToastHelper.showSuccess(
      context,
      Localizations.localeOf(context).languageCode == 'vi'
          ? 'Đã xóa lớp.'
          : 'Class deleted.',
    );
    await _taiDSLop();
  }

  // 2. HÀM XÁC NHẬN XÓA LỚP (MỚI)
  void _xacNhanXoaLop(Lop lop) {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor, // Nền tối
          // Căn giữa Title
          title: Center(
            child: Text(
              isVi ? 'XÁC NHẬN XÓA LỚP' : 'CONFIRM DELETE CLASS',
              style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
            ),
          ),

          content: Text(
            isVi
                ? 'Bạn có chắc chắn muốn xóa lớp "${lop.ten}" (Khối ${lop.khoi}) không? Thao tác này không thể hoàn tác.'
                : 'Are you sure you want to delete class "${lop.ten}" (Grade ${lop.khoi})? This action cannot be undone.',
            style: TextStyle(color: secondaryText, fontSize: 15),
            textAlign: TextAlign.center, // <-- Căn giữa nội dung
          ),

          // Mặc định actionsAlignment là MainAxisAlignment.end
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Đóng Dialog
              },
              child: Text(
                isVi ? 'HỦY' : 'CANCEL',
                style: TextStyle(color: secondaryText),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Đóng Dialog
                await _xoaLop(lop.id!); // Gọi hàm xóa thực tế
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: deleteColor, // Màu đỏ cho hành động nguy hiểm
                foregroundColor: lightText,
              ),
              child: Text(isVi ? 'XÓA' : 'DELETE'),
            ),
          ],
        );
      },
    );
  }

  // ===================================================
  // HÀM HIỂN THỊ DIALOG CHUNG CHO THÊM VÀ SỬA (CREATE/UPDATE) - ĐÃ CẬP NHẬT STYLE
  // ===================================================
  void _hienThiFormLop({Lop? lop}) async {
    final bool isEditing = lop != null;
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';

    final tenLopController = TextEditingController(
      text: isEditing ? lop.ten : '',
    );
    int selectedKhoi = isEditing ? lop.khoi : 6;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final String dialogTitle = isVi
                ? (isEditing ? 'SỬA LỚP' : 'THÊM LỚP')
                : (isEditing ? 'EDIT CLASS' : 'ADD CLASS');
            final String buttonText = isVi
                ? (isEditing ? 'CẬP NHẬT' : 'TẠO')
                : (isEditing ? 'UPDATE' : 'CREATE');

            return AlertDialog(
              backgroundColor: darkBackground, // Nền trắng như ảnh Register
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0), // Bo góc
              ),
              title: Center(
                // Căn giữa tiêu đề
                child: Text(
                  dialogTitle,
                  style: const TextStyle(
                    color: Colors.white, // Chữ tối
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Dropdown Chọn Khối ---
                  Row(
                    children: [
                      const Icon(
                        Icons.school,
                        color: Colors.grey,
                      ), // Icon cho khối
                      const SizedBox(width: 15),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedKhoi,
                            dropdownColor:
                                cardColor, // SỬA: Nền Dropdown màu tối
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white,
                            ),
                            hint: Text(
                              isVi ? 'Chọn Khối' : 'Select Grade',
                              style: const TextStyle(color: Colors.white),
                            ),
                            onChanged: isSubmitting
                                ? null
                                : (int? newValue) {
                                    if (newValue != null) {
                                      setStateDialog(() {
                                        selectedKhoi = newValue;
                                      });
                                    }
                                  },
                            items: _danhSachKhoi.map<DropdownMenuItem<int>>((
                              int khoi,
                            ) {
                              return DropdownMenuItem<int>(
                                value: khoi,
                                child: Text(
                                  isVi ? 'Khối $khoi' : 'Grade $khoi',
                                  style: TextStyle(
                                    color: lightText,
                                  ), // SỬA: Chữ màu sáng
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  //const Divider(color: Colors.grey), // Đường kẻ dưới Dropdown
                  const SizedBox(height: 15),

                  // --- TextField Tên Lớp ---
                  TextField(
                    controller: tenLopController,
                    enabled: !isSubmitting,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isVi
                          ? 'Tên Lớp'
                          : 'Class Name', // Dùng hintText thay labelText để icon không bị đẩy lên
                      hintStyle: const TextStyle(color: Colors.white),
                      prefixIcon: const Icon(
                        Icons.class_,
                        color: Colors.white,
                      ), // Icon cho tên lớp
                      enabledBorder: const UnderlineInputBorder(
                        // Chỉ có viền dưới
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ), // Màu nhấn
                      ),
                    ),
                  ),
                  const SizedBox(height: 10), // Khoảng cách trước nút
                ],
              ),
              actionsAlignment: MainAxisAlignment.center, // Căn giữa các nút
              actions: [
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final tenMoi = tenLopController.text.trim();
                          if (tenMoi.isNotEmpty) {
                            setStateDialog(() => isSubmitting = true);
                            try {
                              if (isEditing) {
                                final updatedLop = lop.copyWith(
                                  ten: tenMoi,
                                  khoi: selectedKhoi,
                                );
                                await _lopService.capNhatLop(updatedLop);
                              } else {
                                final lopMoi = Lop(
                                  ten: tenMoi,
                                  khoi: selectedKhoi,
                                );
                                await _lopService.taoLop(lopMoi);
                              }
                              if (!context.mounted) return;
                              Navigator.of(context).pop(true);
                            } catch (e) {
                              if (!context.mounted) return;
                              ToastHelper.showError(
                                context,
                                isVi
                                    ? 'Lỗi: Tên lớp đã tồn tại hoặc lỗi hệ thống.'
                                    : 'Error: Class name already exists or system error.',
                              );
                            } finally {
                              if (context.mounted) {
                                setStateDialog(() => isSubmitting = false);
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // Màu đỏ như nút Register
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 50,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0), // Bo góc nút
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          buttonText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
                // Có thể thêm nút "Hủy" nếu cần, nhưng thường thì đóng dialog khi người dùng click bên ngoài
                // hoặc bạn có thể để nó nhỏ hơn và là TextButton
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    isVi ? 'Hủy' : 'Cancel',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _taiDSLop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isVi ? 'QUẢN LÝ LỚP HỌC' : 'CLASS MANAGEMENT',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
      ),
      drawer: MainDrawer(
        mainScreenKey: widget.mainScreenKey,
        selectedIndex: widget.selectedIndex, // SỬA: Truyền tham số
      ),
      backgroundColor: darkBackground,
      body:
          _dangTai // SỬA: Thay đổi cách hiển thị danh sách
          ? Center(child: CircularProgressIndicator(color: accentColor))
          : _danhSachLop.isEmpty
          ? Center(
              child: Text(
                isVi ? 'Chưa có lớp nào.' : 'No classes yet.',
                style: TextStyle(color: secondaryText),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Hiển thị 2 cột
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8, // Tỉ lệ chiều rộng/cao của mỗi card
              ),
              itemCount: _danhSachLop.length,
              itemBuilder: (context, index) {
                final lop = _danhSachLop[index];
                return _buildLopCard(lop);
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _hienThiFormLop(), // THÊM LỚP MỚI
        backgroundColor: accentColor,
        foregroundColor: Colors.black,
        shape: const CircleBorder(
          // side: BorderSide(color: Colors.black26, width: 2.0),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  // HÀM MỚI: Xây dựng Card Lớp học với thiết kế mới
  Widget _buildLopCard(Lop lop) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    // Chọn màu và icon dựa trên khối
    final cardData = _getCardDataForKhoi(lop.khoi);

    return GestureDetector(
      onTap: () {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (ctx) => LopDetail(lop: lop)))
            .then((_) => _taiDSLop());
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cardColor,
        child: Stack(
          children: [
            // Background Gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cardData['color'].withValues(alpha: 0.6),
                      cardColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Icon nền mờ
            Positioned(
              bottom: -20,
              right: -20,
              child: Icon(
                cardData['icon'],
                size: 120,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            // Nội dung
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Khối và Sĩ số
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: cardData['color'],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isVi ? 'Khối ${lop.khoi}' : 'Grade ${lop.khoi}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group, color: secondaryText, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            lop.siSo.toString(),
                            style: TextStyle(
                              color: secondaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            iconSize: 20,
                            icon: Icon(Icons.more_vert, color: secondaryText),
                            color: darkBackground,
                            onSelected: (value) {
                              if (value == 'notify') {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => GuiThongBaoHangLoatDialog(
                                    initialLopId: lop.id,
                                    initialOnlyUnpaid: false,
                                    initialType: NotificationType.baoNghiHoc,
                                    allowedTypes: const [
                                      NotificationType.baoNghiHoc,
                                      NotificationType.baoDoiLich,
                                      NotificationType.custom,
                                    ],
                                    dialogTitle: 'Gửi Thông Báo Lớp Học',
                                  ),
                                );
                              } else if (value == 'edit') {
                                _hienThiFormLop(lop: lop);
                              } else if (value == 'delete') {
                                _xacNhanXoaLop(lop);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'notify',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.send_rounded,
                                      color: accentColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isVi
                                          ? 'Gửi thông báo lớp'
                                          : 'Class Notice',
                                      style: TextStyle(color: lightText),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: secondaryText,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isVi ? 'Sửa' : 'Edit',
                                      style: TextStyle(color: lightText),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      color: deleteColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isVi ? 'Xóa' : 'Delete',
                                      style: TextStyle(color: deleteColor),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Tên lớp
                  Text(
                    lop.ten,
                    style: TextStyle(
                      color: lightText,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // HÀM MỚI: Helper để lấy màu và icon cho từng khối
  Map<String, dynamic> _getCardDataForKhoi(int khoi) {
    switch (khoi % 6) {
      case 0:
        return {'color': Colors.blue.shade700, 'icon': Icons.science};
      case 1:
        return {'color': Colors.green.shade700, 'icon': Icons.calculate};
      case 2:
        return {'color': Colors.orange.shade700, 'icon': Icons.translate};
      case 3:
        return {'color': Colors.purple.shade700, 'icon': Icons.history_edu};
      case 4:
        return {'color': Colors.red.shade700, 'icon': Icons.sports_esports};
      default:
        return {'color': Colors.teal.shade700, 'icon': Icons.music_note};
    }
  }
}
