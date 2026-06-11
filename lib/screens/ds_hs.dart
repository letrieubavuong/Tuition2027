// File: lib/screens/ds_hoc_sinh.dart (CẬP NHẬT HOÀN TOÀN)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
import '../main.dart';
import '../models/hs.dart';
import '../models/truong.dart'; // Import Model Trường
import '../widgets/hs_form.dart';
import '../widgets/main_drawer.dart';
import '../services/hoc_sinh_service.dart';
import '../services/truong_service.dart';
import 'hs_detail.dart'; // Import Service Trường
import '../l10n/app_localizations.dart'; // Import localization

class DSHocSinh extends StatefulWidget {
  final GlobalKey<MainScreenState> mainScreenKey;
  final int selectedIndex; // SỬA: Thêm tham số
  const DSHocSinh({
    super.key,
    required this.mainScreenKey,
    required this.selectedIndex, // SỬA: Thêm tham số
  });

  @override
  State<DSHocSinh> createState() => _DSHocSinhState();
}

class _DSHocSinhState extends State<DSHocSinh> {
  final _hsService = HocSinhService();
  final _truongService = TruongService(); // Khởi tạo Service Trường

  List<HS> _danhSachHS = []; // Danh sách gốc
  List<HS> _filteredDanhSachHS = []; // Danh sách đã lọc để hiển thị
  List<Truong> _danhSachTruong = []; // Danh sách Trường từ DB
  final TextEditingController _searchController = TextEditingController();

  bool _dangTai = true;

  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
    // SỬA: Thêm listener để tự động lọc khi người dùng nhập
    _searchController.addListener(_filterHocSinh);
  }

  @override
  void dispose() {
    // SỬA: Hủy controller khi widget bị hủy
    _searchController.dispose();
    super.dispose();
  }

  // Tải đồng thời cả DS Học sinh và DS Trường
  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);
    try {
      final dsHS = await _hsService.docTatCaHocSinh(); // SỬA: Sắp xếp theo tên
      final dsTruong = await _truongService.docTatCaTruong();
      setState(() {
        _danhSachHS = dsHS;
        _filteredDanhSachHS = dsHS; // SỬA: Khởi tạo danh sách lọc ban đầu
        _danhSachTruong = dsTruong;
        _dangTai = false;
      });
    } catch (e) {
      print('Lỗi tải dữ liệu: $e');
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        setState(() {
          _dangTai = false; // Ẩn loading
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(loc.locale.languageCode == 'vi' ? 'Lỗi tải dữ liệu: $e' : 'Error loading data: $e')));
        });
      }
    }
  }

  // Hàm tải DS Học Sinh (READ)
  Future<void> _taiDSHS() async {
    setState(() => _dangTai = true);
    final dsHS = await _hsService.docTatCaHocSinh();
    // SỬA: Cập nhật cả hai danh sách sau khi tải lại
    setState(() {
      _danhSachHS = dsHS;
      _filterHocSinh(); // Áp dụng lại bộ lọc hiện tại
      _dangTai = false;
    });
  }

  // HÀM MỚI: Lọc danh sách học sinh dựa trên query
  void _filterHocSinh() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDanhSachHS = _danhSachHS.where((hs) {
        return hs.ten.toLowerCase().contains(query);
      }).toList();
    });
  }

  // 3. Xóa Học Sinh THỰC TẾ (DELETE)
  Future<void> _xoaHS(int id) async {
    final result = await _hsService.xoaHocSinh(id);

    if (result > 0) {
      _taiDSHS();
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.deleteStudentSuccess)),
        );
      }
    }
  }

  // 4. Xác Nhận Xóa Học Sinh (CONFIRMATION DIALOG)
  void _xacNhanXoaHocSinh(HS hs) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: cardColor,
          title: Center(
            child: Text(
              loc.deleteStudentConfirmTitle,
              style: TextStyle(color: lightText),
            ),
          ),
          content: Text(
            loc.deleteStudentConfirmContent(hs.ten),
            style: TextStyle(color: secondaryText),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(loc.cancel, style: TextStyle(color: secondaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _xoaHS(hs.id!); // Gọi hàm xóa thực tế
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: deleteColor,
                foregroundColor: lightText,
              ),
              child: Text(loc.delete),
            ),
          ],
        );
      },
    );
  }

  // ===================================================
  // HÀM HIỂN THỊ DIALOG CHUNG CHO THÊM VÀ SỬA (CREATE/UPDATE)
  // ===================================================
  void _hienThiFormHocSinh({HS? hs}) async {
    // SỬ DỤNG HÀM HELPER ĐỘC LẬP
    final newOrUpdatedHs = await showHocSinhFormDialog(
      context: context,
      hocSinh: hs,
      danhSachTruong: _danhSachTruong,
      hsService: _hsService,
    );

    if (newOrUpdatedHs != null) {
      _taiDSHS(); // Chỉ cần tải lại danh sách
    }
  }

  // ===================================================
  // HÀM MỚI: XUẤT DANH SÁCH HỌC SINH RA FILE CSV
  // ===================================================
  Future<void> _xuatDanhSachCSV() async {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    var status = await Permission.manageExternalStorage.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isVi ? 'Cần cấp quyền bộ nhớ để xuất file!' : 'Storage permission required to export file!')),
      );
      return;
    }

    try {
      List<List<dynamic>> rows = [];
      // Dòng tiêu đề
      rows.add([
        isVi ? "Tên Học Sinh" : "Student Name",
        isVi ? "Số Điện Thoại" : "Phone Number",
        isVi ? "Trường Học" : "School",
        isVi ? "Địa Chỉ" : "Address",
        isVi ? "Miễn Giảm (%)" : "Discount (%)",
        isVi ? "Ghi Chú" : "Notes",
        isVi ? "Số Buổi Dư" : "Remaining Sessions",
      ]);

      for (var hs in _danhSachHS) {
        rows.add([
          hs.ten,
          hs.sdt ?? "",
          hs.truongDangHoc ?? "",
          hs.diaChi ?? "",
          hs.mienGiam ?? 0,
          hs.ghiChu ?? "",
          hs.soBuoiDu,
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      // Thêm BOM UTF-8 để Microsoft Excel hiển thị đúng tiếng Việt có dấu
      final bytes = [0xEF, 0xBB, 0xBF, ...csvData.codeUnits];

      final downloadsDir = '/storage/emulated/0/Download';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$downloadsDir/danh_sach_hs_$timestamp.csv';
      final file = File(path);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVi ? 'Đã xuất file CSV thành công tại thư mục Download!' : 'Exported CSV file successfully to Download folder!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(isVi ? 'Lỗi khi xuất file: $e' : 'Error exporting file: $e')));
    }
  }

  // ===================================================
  // HÀM MỚI: NHẬP DANH SÁCH HỌC SINH TỪ FILE CSV - ĐÃ TỐI ƯU HÓA
  // ===================================================
  Future<void> _nhapDanhSachCSV() async {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (!mounted) return;
    if (result != null && result.files.single.path != null) {
      setState(() => _dangTai = true);
      try {
        final file = File(result.files.single.path!);
        final csvString = await file.readAsString();
        List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter().convert(csvString);

        if (rowsAsListOfValues.isEmpty) {
          setState(() => _dangTai = false);
          return;
        }

        // TỐI ƯU HÓA: Sử dụng BATCH để chèn nhiều bản ghi cùng lúc
        final db = await _hsService.database;
        final batch = db.batch();
        int count = 0;

        for (int i = 1; i < rowsAsListOfValues.length; i++) {
          final row = rowsAsListOfValues[i];
          if (row.isEmpty || row[0].toString().trim().isEmpty) continue;

          final hs = HS(
            ten: row[0].toString().trim(),
            sdt: row.length > 1 ? row[1].toString().trim() : null,
            truongDangHoc: row.length > 2 ? row[2].toString().trim() : null,
            diaChi: row.length > 3 ? row[3].toString().trim() : null,
            mienGiam: row.length > 4 ? int.tryParse(row[4].toString()) ?? 0 : 0,
            ghiChu: row.length > 5 ? row[5].toString().trim() : null,
            soBuoiDu: row.length > 6 ? int.tryParse(row[6].toString()) ?? 0 : 0,
          );

          batch.insert('hoc_sinh', hs.toMap());
          count++;
        }

        await batch.commit(noResult: true);
        await _taiDSHS();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isVi ? 'Đã nhập thành công $count học sinh!' : 'Imported $count students successfully!')),
          );
        }
      } catch (e) {
        setState(() => _dangTai = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isVi ? 'Lỗi: Định dạng file CSV không hợp lệ.' : 'Error: Invalid CSV file format.')),
          );
        }
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        title: Text(
          loc.studentListTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: lightText,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.import_export, color: accentColor),
            color: darkBackground,
            onSelected: (value) {
              if (value == 'import') _nhapDanhSachCSV();
              if (value == 'export') _xuatDanhSachCSV();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: Text(
                  isVi ? 'Nhập từ file CSV' : 'Import from CSV',
                  style: TextStyle(color: lightText),
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Text(
                  isVi ? 'Xuất ra file CSV' : 'Export to CSV',
                  style: TextStyle(color: lightText),
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: MainDrawer(
        mainScreenKey: widget.mainScreenKey,
        selectedIndex: widget.selectedIndex, // SỬA: Truyền tham số
      ),
      body: Column(
        children: [
          // HÀM MỚI: Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: lightText),
              decoration: InputDecoration(
                hintText: loc.searchStudentHint,
                hintStyle: TextStyle(color: secondaryText),
                prefixIcon: Icon(Icons.search, color: secondaryText),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: secondaryText),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // Danh sách học sinh
          Expanded(
            child: _dangTai
                ? Center(
                    child: CircularProgressIndicator(color: accentColor),
                  )
                : _filteredDanhSachHS.isEmpty
                ? Center(
                    child: Text(
                      _danhSachHS.isEmpty
                          ? loc.noStudentsYet
                          : loc.noStudentsFound,
                      style: TextStyle(color: secondaryText),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredDanhSachHS.length,
                    itemBuilder: (context, index) {
                      final hs = _filteredDanhSachHS[index];
                      return _buildHocSinhCard(hs);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _hienThiFormHocSinh(), // SỬ DỤNG DIALOG
        backgroundColor: accentColor,
        foregroundColor: Colors.black,
        shape: const CircleBorder(
          // side: BorderSide(color: Colors.black26, width: 2.0),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  // HÀM MỚI: Xây dựng Card Học sinh với thiết kế mới
  Widget _buildHocSinhCard(HS hs) {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (ctx) => HSDetail(hocSinh: hs)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: accentColor.withValues(alpha: 0.8),
                child: Text(
                  hs.ten.isNotEmpty ? hs.ten[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: lightText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Thông tin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hs.ten,
                      style: TextStyle(
                        color: lightText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (hs.truongDangHoc != null &&
                        hs.truongDangHoc!.isNotEmpty)
                      _buildInfoRow(Icons.school, hs.truongDangHoc!),
                    if (hs.sdt != null && hs.sdt!.isNotEmpty)
                      _buildInfoRow(Icons.phone, hs.sdt!),
                  ],
                ),
              ),
              // Nút actions
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _hienThiFormHocSinh(hs: hs);
                  } else if (value == 'delete') {
                    _xacNhanXoaHocSinh(hs);
                  }
                },
                icon: Icon(Icons.more_vert, color: secondaryText),
                color: darkBackground,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: secondaryText),
                      title: Text(loc.edit, style: TextStyle(color: lightText)),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: deleteColor),
                      title: Text(loc.delete, style: TextStyle(color: deleteColor)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // HÀM MỚI: Widget hỗ trợ hiển thị thông tin phụ (trường, sđt)
  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      // SỬA: Xóa cặp ngoặc đơn thừa "()" ở đây
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        children: [
          Icon(icon, color: secondaryText, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: secondaryText, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
