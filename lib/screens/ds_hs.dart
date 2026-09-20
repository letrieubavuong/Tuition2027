// File: lib/screens/ds_hs.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
import '../main.dart';
import '../models/hs.dart';
import '../models/truong.dart';
import '../widgets/hs_form.dart';
import '../widgets/main_drawer.dart';
import '../services/hoc_sinh_service.dart';
import '../services/truong_service.dart';
import '../services/student_event_service.dart';
import '../services/student_signal_service.dart';
import '../services/thanh_toan_service.dart';
import '../services/zalo_contact_service.dart';
import '../utils/vietqr_util.dart';
import '../utils/toast_helper.dart';
import 'hs_detail.dart';
import '../l10n/app_localizations.dart';

enum StudentListFilter { all, active, attention, debt }

class DSHocSinh extends StatefulWidget {
  final GlobalKey<MainScreenState> mainScreenKey;
  final int selectedIndex;

  const DSHocSinh({
    super.key,
    required this.mainScreenKey,
    required this.selectedIndex,
  });

  @override
  State<DSHocSinh> createState() => _DSHocSinhState();
}

class _DSHocSinhState extends State<DSHocSinh> {
  final _hsService = HocSinhService();
  final _truongService = TruongService();
  final _signalService = StudentSignalService.instance;
  final _thanhToanService = ThanhToanService();

  List<HS> _danhSachHS = [];
  List<HS> _filteredDanhSachHS = [];
  List<Truong> _danhSachTruong = [];
  Set<int> _activeStudentIds = {};
  Set<int> _studentsWithWarnings = {};
  Set<int> _studentsWithDebt = {};

  final TextEditingController _searchController = TextEditingController();
  StudentListFilter _currentFilter = StudentListFilter.all;

  StreamSubscription<HS>? _studentUpdatedSub;
  StreamSubscription<HS>? _studentCreatedSub;
  StreamSubscription<int>? _studentDeletedSub;

  bool _dangTai = true;

  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
    _searchController.addListener(_filterHocSinh);

    _studentUpdatedSub = StudentEventService().onStudentUpdated.listen((
      updatedHs,
    ) {
      if (!mounted) return;
      final index = _danhSachHS.indexWhere((x) => x.id == updatedHs.id);
      if (index != -1) {
        _danhSachHS[index] = updatedHs;
        _filterHocSinh();
      }
    });

    _studentCreatedSub = StudentEventService().onStudentCreated.listen((
      createdHs,
    ) {
      if (!mounted) return;
      if (!_danhSachHS.any((x) => x.id == createdHs.id)) {
        _danhSachHS.add(createdHs);
        _danhSachHS.sort((a, b) => a.ten.compareTo(b.ten));
        _filterHocSinh();
      }
    });

    _studentDeletedSub = StudentEventService().onStudentDeleted.listen((
      deletedId,
    ) {
      if (!mounted) return;
      _danhSachHS.removeWhere((x) => x.id == deletedId);
      _filterHocSinh();
    });
  }

  @override
  void dispose() {
    _studentUpdatedSub?.cancel();
    _studentCreatedSub?.cancel();
    _studentDeletedSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _taiDuLieu() async {
    setState(() => _dangTai = true);

    List<HS> dsHS = [];
    List<Truong> dsTruong = [];
    Set<int> activeStudentIds = {};
    Set<int> warningStudentIds = {};
    Set<int> debtStudentIds = {};

    // 1. Tải dữ liệu danh sách học sinh và trường (Dữ liệu chính - Bắt buộc)
    try {
      dsHS = await _hsService.docTatCaHocSinh();
      dsTruong = await _truongService.docTatCaTruong();
    } catch (e, st) {
      debugPrint('Lỗi tải danh sách học sinh chính: $e\n$st');
      if (mounted) {
        setState(() => _dangTai = false);
        ToastHelper.showError(
          context,
          'Không thể tải danh sách học sinh. Vui lòng thử lại.',
        );
      }
      return;
    }

    // 2. Tải danh sách học sinh đang học (Dữ liệu phụ - Không crash ứng dụng nếu lỗi)
    try {
      activeStudentIds = await _hsService.docDanhSachIdHocSinhDangHoc();
    } catch (e, st) {
      debugPrint('Lỗi tải danh sách học sinh đang học: $e\n$st');
    }

    // 3. Tải danh sách tín hiệu cảnh báo (Dữ liệu phụ - Không crash ứng dụng nếu lỗi)
    try {
      final activeSignals = await _signalService.getAllActiveSignals();
      warningStudentIds = activeSignals.map((s) => s.studentId).toSet();
    } catch (e, st) {
      debugPrint('Lỗi tải cảnh báo học sinh: $e\n$st');
    }

    // 4. Tải danh sách nợ học phí (Dữ liệu phụ - Không crash ứng dụng nếu lỗi)
    try {
      debtStudentIds = await _thanhToanService.layDanhSachHocSinhConNo();
    } catch (e, st) {
      debugPrint('Lỗi tải nợ học phí: $e\n$st');
    }

    if (!mounted) return;
    setState(() {
      _danhSachHS = dsHS;
      _danhSachTruong = dsTruong;
      _activeStudentIds = activeStudentIds;
      _studentsWithWarnings = warningStudentIds;
      _studentsWithDebt = debtStudentIds;
      _dangTai = false;
    });
    _filterHocSinh();
  }

  /// Lọc danh sách học sinh dựa trên search query (có dấu/không dấu/SĐT/Trường) và filter chips
  void _filterHocSinh() {
    if (!mounted) return;
    final queryRaw = _searchController.text.trim().toLowerCase();
    final queryNoAccents = VietQRUtil.removeVietnameseAccents(queryRaw);

    setState(() {
      _filteredDanhSachHS = _danhSachHS.where((hs) {
        // 1. Check Filter Chips
        if (_currentFilter == StudentListFilter.active) {
          if (_activeStudentIds.isNotEmpty &&
              !_activeStudentIds.contains(hs.id)) {
            return false;
          }
        } else if (_currentFilter == StudentListFilter.attention) {
          if (!_studentsWithWarnings.contains(hs.id)) return false;
        } else if (_currentFilter == StudentListFilter.debt) {
          if (!_studentsWithDebt.contains(hs.id)) return false;
        }

        // 2. Check Search Query
        if (queryRaw.isEmpty) return true;

        final tenLower = hs.ten.toLowerCase();
        final tenNoAccents = VietQRUtil.removeVietnameseAccents(tenLower);
        final sdt = hs.sdt?.toLowerCase() ?? '';
        final parentSdt = hs.effectiveParentPhone?.toLowerCase() ?? '';
        final parentName = hs.tenPhuHuynh?.toLowerCase() ?? '';
        final parentNameNoAccents = VietQRUtil.removeVietnameseAccents(
          parentName,
        );
        final truong = hs.truongDangHoc?.toLowerCase() ?? '';
        final truongNoAccents = VietQRUtil.removeVietnameseAccents(truong);

        return tenLower.contains(queryRaw) ||
            tenNoAccents.contains(queryNoAccents) ||
            sdt.contains(queryRaw) ||
            parentSdt.contains(queryRaw) ||
            parentName.contains(queryRaw) ||
            parentNameNoAccents.contains(queryNoAccents) ||
            truong.contains(queryRaw) ||
            truongNoAccents.contains(queryNoAccents);
      }).toList();
    });
  }

  Future<void> _xoaHS(int id) async {
    final loc = AppLocalizations.of(context)!;
    final result = await _hsService.xoaHocSinh(id);

    if (result > 0) {
      _taiDuLieu();
      if (mounted) {
        ToastHelper.showSuccess(context, loc.deleteStudentSuccess);
      }
    }
  }

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
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc.cancel, style: TextStyle(color: secondaryText)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _xoaHS(hs.id!);
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

  void _hienThiFormHocSinh({HS? hs}) async {
    final newOrUpdatedHs = await showHocSinhFormDialog(
      context: context,
      hocSinh: hs,
      danhSachTruong: _danhSachTruong,
      hsService: _hsService,
    );

    if (newOrUpdatedHs != null && mounted) {
      final index = _danhSachHS.indexWhere((x) => x.id == newOrUpdatedHs.id);
      if (index != -1) {
        _danhSachHS[index] = newOrUpdatedHs;
      } else if (!_danhSachHS.any((x) => x.id == newOrUpdatedHs.id)) {
        _danhSachHS.add(newOrUpdatedHs);
        _danhSachHS.sort((a, b) => a.ten.compareTo(b.ten));
      }
      _filterHocSinh();
    }
  }

  Future<void> _xuatDanhSachCSV() async {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    var status = await Permission.manageExternalStorage.request();
    if (!mounted) return;
    if (!status.isGranted) {
      ToastHelper.showWarning(
        context,
        isVi
            ? 'Cần cấp quyền bộ nhớ để xuất file!'
            : 'Storage permission required to export file!',
      );
      return;
    }

    try {
      List<List<dynamic>> rows = [];
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
      final bytes = [0xEF, 0xBB, 0xBF, ...csvData.codeUnits];

      final downloadsDir = '/storage/emulated/0/Download';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$downloadsDir/danh_sach_hs_$timestamp.csv';
      final file = File(path);
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      ToastHelper.showSuccess(
        context,
        isVi
            ? 'Đã xuất file CSV thành công tại thư mục Download!'
            : 'Exported CSV file successfully to Download folder!',
      );
    } catch (e) {
      if (!mounted) return;
      ToastHelper.showError(
        context,
        isVi ? 'Lỗi khi xuất file: $e' : 'Error exporting file: $e',
      );
    }
  }

  Future<void> _nhapDanhSachCSV() async {
    final loc = AppLocalizations.of(context)!;
    final isVi = loc.locale.languageCode == 'vi';
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (!mounted) return;
    if (result != null && result.files.single.path != null) {
      setState(() => _dangTai = true);
      try {
        final file = File(result.files.single.path!);
        final csvString = await file.readAsString();
        List<List<dynamic>> rowsAsListOfValues = const CsvToListConverter()
            .convert(csvString);

        if (rowsAsListOfValues.isEmpty) {
          setState(() => _dangTai = false);
          return;
        }

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
        await _taiDuLieu();

        if (mounted) {
          ToastHelper.showSuccess(
            context,
            isVi
                ? 'Đã nhập thành công $count học sinh!'
                : 'Imported $count students successfully!',
          );
        }
      } catch (e) {
        setState(() => _dangTai = false);
        if (mounted) {
          ToastHelper.showError(
            context,
            isVi
                ? 'Lỗi: Định dạng file CSV không hợp lệ.'
                : 'Error: Invalid CSV file format.',
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
        toolbarHeight: 64,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.studentListTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Text(
              '${_filteredDanhSachHS.length} / ${_danhSachHS.length} ${isVi ? "học sinh" : "students"}',
              style: TextStyle(
                color: secondaryText,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: cardColor,
        foregroundColor: lightText,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) {
              if (value == 'import') _nhapDanhSachCSV();
              if (value == 'export') _xuatDanhSachCSV();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(
                      Icons.file_upload_outlined,
                      size: 20,
                      color: accentColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isVi ? 'Nhập từ file CSV' : 'Import from CSV',
                      style: TextStyle(color: lightText),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(
                      Icons.file_download_outlined,
                      size: 20,
                      color: accentColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isVi ? 'Xuất ra file CSV' : 'Export to CSV',
                      style: TextStyle(color: lightText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: MainDrawer(
        mainScreenKey: widget.mainScreenKey,
        selectedIndex: widget.selectedIndex,
      ),
      body: Column(
        children: [
          // 1. Search Bar Nâng Cao
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 3),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: lightText, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: isVi
                    ? 'Tìm theo tên, không dấu, SĐT, trường...'
                    : 'Search name, phone, school...',
                hintStyle: TextStyle(
                  color: secondaryText.withValues(alpha: 0.6),
                  fontSize: 13.5,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: secondaryText,
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 38,
                  minHeight: 38,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9.5,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. Filter Chips Horizontal Scroll
          _buildFilterChips(isVi),

          // 3. Danh sách học sinh V2 Card List
          Expanded(
            child: _dangTai
                ? Center(child: CircularProgressIndicator(color: accentColor))
                : _filteredDanhSachHS.isEmpty
                ? _buildEmptyState(isVi)
                : RefreshIndicator(
                    onRefresh: _taiDuLieu,
                    color: accentColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      itemCount: _filteredDanhSachHS.length,
                      itemBuilder: (context, index) {
                        final hs = _filteredDanhSachHS[index];
                        return _buildHocSinhCardV2(hs, isVi);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _hienThiFormHocSinh(),
        tooltip: isVi ? 'Thêm học sinh' : 'Add student',
        backgroundColor: accentColor,
        foregroundColor: Colors.black,
        elevation: 3,
        child: const Icon(Icons.person_add_alt_1_rounded, size: 24),
      ),
    );
  }

  /// Filter Chips Horizontal Scroll
  Widget _buildFilterChips(bool isVi) {
    final activeCount = _danhSachHS
        .where((hs) => hs.id != null && _activeStudentIds.contains(hs.id))
        .length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          _buildFilterChip(
            label: isVi
                ? 'Tất cả ${_danhSachHS.length}'
                : 'All ${_danhSachHS.length}',
            filter: StudentListFilter.all,
          ),
          const SizedBox(width: 5),
          _buildFilterChip(
            label: isVi ? 'Đang học $activeCount' : 'Active $activeCount',
            filter: StudentListFilter.active,
          ),
          if (_studentsWithWarnings.isNotEmpty) ...[
            const SizedBox(width: 5),
            _buildFilterChip(
              label: isVi
                  ? 'Cần chú ý ${_studentsWithWarnings.length}'
                  : 'Attention ${_studentsWithWarnings.length}',
              filter: StudentListFilter.attention,
              chipColor: Colors.orangeAccent,
            ),
          ],
          if (_studentsWithDebt.isNotEmpty) ...[
            const SizedBox(width: 5),
            _buildFilterChip(
              label: isVi
                  ? 'Nợ HP ${_studentsWithDebt.length}'
                  : 'Debt ${_studentsWithDebt.length}',
              filter: StudentListFilter.debt,
              chipColor: Colors.redAccent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required StudentListFilter filter,
    Color? chipColor,
  }) {
    final isSelected = _currentFilter == filter;
    final effectiveColor = chipColor ?? accentColor;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 11.5,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _currentFilter = filter;
          });
          _filterHocSinh();
        }
      },
      selectedColor: effectiveColor,
      backgroundColor: cardColor,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  /// Empty State UI
  Widget _buildEmptyState(bool isVi) {
    if (_danhSachHS.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: secondaryText.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              isVi ? 'Chưa có học sinh nào trong cơ sở' : 'No students found',
              style: TextStyle(color: secondaryText, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.black,
              ),
              onPressed: () => _hienThiFormHocSinh(),
              icon: const Icon(Icons.add, size: 20),
              label: Text(isVi ? 'Thêm học sinh mới' : 'Add new student'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: secondaryText.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            isVi
                ? 'Không tìm thấy học sinh phù hợp'
                : 'No matching students found',
            style: TextStyle(color: secondaryText, fontSize: 15),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: accentColor),
            onPressed: () {
              _searchController.clear();
              setState(() => _currentFilter = StudentListFilter.all);
              _filterHocSinh();
            },
            child: Text(isVi ? 'Xóa bộ lọc search' : 'Clear filter'),
          ),
        ],
      ),
    );
  }

  /// Student Card V2 Design
  Widget _buildHocSinhCardV2(HS hs, bool isVi) {
    final hasWarning = _studentsWithWarnings.contains(hs.id);
    final hasDebt = _studentsWithDebt.contains(hs.id);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: hasWarning
              ? Colors.orangeAccent.withValues(alpha: 0.4)
              : (hasDebt
                    ? Colors.redAccent.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.05)),
          width: hasWarning || hasDebt ? 1.2 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (ctx) => HSDetail(hocSinh: hs)));
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar V2 (Radius 22)
              CircleAvatar(
                radius: 22,
                backgroundColor: accentColor.withValues(alpha: 0.2),
                child: Text(
                  hs.ten.isNotEmpty ? hs.ten[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hs.ten,
                      style: TextStyle(
                        color: lightText,
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Badges (Placed on separate line so student name gets full width)
                    if (hasWarning || hasDebt) ...[
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (hasWarning)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: Colors.orangeAccent.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 11,
                                    color: Colors.orangeAccent,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Cần chú ý',
                                    style: TextStyle(
                                      color: Colors.orangeAccent,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (hasDebt)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.4,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 11,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'Nợ học phí',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),

                    // School
                    if (hs.truongDangHoc != null &&
                        hs.truongDangHoc!.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 14,
                            color: secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hs.truongDangHoc!,
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    // Phone
                    if (hs.effectiveParentPhone != null &&
                        hs.effectiveParentPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hs.effectiveParentPhone!,
                            style: TextStyle(
                              color: secondaryText,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Zalo Action Button
              ZaloContactService.instance.buildZaloQuickButton(context, hs),

              // Context Menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'zalo') {
                    ZaloContactService.instance.openParentZalo(context, hs);
                  } else if (value == 'edit') {
                    _hienThiFormHocSinh(hs: hs);
                  } else if (value == 'delete') {
                    _xacNhanXoaHocSinh(hs);
                  }
                },
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: secondaryText,
                  size: 20,
                ),
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'zalo',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.send_rounded,
                          color: Color(0xFF0068FF),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Zalo Phụ Huynh',
                          style: TextStyle(color: lightText),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: secondaryText,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isVi ? 'Sửa thông tin' : 'Edit info',
                          style: TextStyle(color: lightText),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: deleteColor,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isVi ? 'Xóa học sinh' : 'Delete student',
                          style: TextStyle(color: deleteColor),
                        ),
                      ],
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
}
