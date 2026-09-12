// File: lib/widgets/bao_cao_diem_danh_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/hs.dart';
import '../models/lop.dart';
import '../services/lop_hoc_sinh_service.dart';
import '../utils/db.dart';

// SỬA: Chuyển sang ConsumerStatefulWidget để dùng Riverpod
class BaoCaoDiemDanhWidget extends ConsumerStatefulWidget {
  final HS hocSinh;
  final int refreshTrigger;

  const BaoCaoDiemDanhWidget({
    super.key,
    required this.hocSinh,
    this.refreshTrigger = 0,
  });

  @override
  ConsumerState<BaoCaoDiemDanhWidget> createState() =>
      _BaoCaoDiemDanhWidgetState();
}

class _BaoCaoDiemDanhWidgetState extends ConsumerState<BaoCaoDiemDanhWidget> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText =>
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText =>
      Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  // --- Services ---
  final LopHocSinhService _lhsService = LopHocSinhService();
  // --- State ---
  List<Lop> _lopCuaHocSinh = [];
  Lop? _selectedLop;
  late String _selectedMonthYear;
  bool _isLoading = true;

  // --- Theme Colors ---
  // static const Color darkBackground = Color(0xFF1A1A2E);
  // static const Color cardColor = Color(0xFF16213E);
  // static const Color lightText = Colors.white;
  // static const Color secondaryText = Colors.white70;
  // static const Color accentColor = Color(0xFF00BFA5); // Teal Accent

  @override
  void initState() {
    super.initState();
    _selectedMonthYear = DateFormat('yyyy-MM').format(DateTime.now());
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final lopList = await _lhsService.docDSLopCuaHS(widget.hocSinh.id!);
    setState(() {
      _lopCuaHocSinh = lopList;
      if (lopList.isNotEmpty) {
        _selectedLop = lopList.first; // Chọn lớp đầu tiên làm mặc định
      }
      _isLoading = false;
    });
    // Dữ liệu báo cáo sẽ được tải bởi reportProvider
  }

  @override
  void didUpdateWidget(BaoCaoDiemDanhWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTrigger != widget.refreshTrigger &&
        _selectedLop != null) {
      ref.invalidate(
        reportProvider((
          idHocSinh: widget.hocSinh.id!,
          idLop: _selectedLop!.id!,
          thang: _selectedMonthYear,
        )),
      );
    }
  }

  void _showMonthPicker() async {
    final now = DateTime.now();
    final selectedDate =
        DateFormat('yyyy-MM').tryParse(_selectedMonthYear) ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              onSurface: lightText,
              surface: cardColor,
            ),
            dialogTheme: DialogThemeData(backgroundColor: darkBackground),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final newMonthYear = DateFormat('yyyy-MM').format(picked);
      if (newMonthYear != _selectedMonthYear) {
        setState(() {
          _selectedMonthYear = newMonthYear;
          // Vô hiệu hóa provider để nó tải lại dữ liệu cho tháng mới
          ref.invalidate(
            reportProvider((
              idHocSinh: widget.hocSinh.id!,
              idLop: _selectedLop!.id!,
              thang: _selectedMonthYear,
            )),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: accentColor));
    }

    if (_lopCuaHocSinh.isEmpty) {
      return Center(
        child: Text(
          isVi
              ? 'Học sinh chưa được thêm vào lớp nào.'
              : 'Student has not been added to any class yet.',
          style: TextStyle(color: secondaryText, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: RefreshIndicator(
        onRefresh: () async {
          // Khi kéo để làm mới, vô hiệu hóa provider để tải lại
          ref.invalidate(
            reportProvider((
              idHocSinh: widget.hocSinh.id!,
              idLop: _selectedLop!.id!,
              thang: _selectedMonthYear,
            )),
          );
        },
        color: accentColor,
        backgroundColor: cardColor,
        child: Column(
          children: [
            _buildSelector(isVi),
            const SizedBox(height: 12),
            // SỬA: Dùng Consumer để lắng nghe reportProvider
            Consumer(
              builder: (context, ref, child) {
                if (_selectedLop == null) return const SizedBox.shrink();
                final reportAsyncValue = ref.watch(
                  reportProvider((
                    idHocSinh: widget.hocSinh.id!,
                    idLop: _selectedLop!.id!,
                    thang: _selectedMonthYear,
                  )),
                );
                return _buildReportContent(reportAsyncValue, isVi);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelector(bool isVi) {
    return Column(
      children: [
        // Lớp
        DropdownButtonFormField<Lop>(
          initialValue: _selectedLop,
          items: _lopCuaHocSinh.map((lop) {
            return DropdownMenuItem<Lop>(value: lop, child: Text(lop.ten));
          }).toList(),
          onChanged: (Lop? newValue) {
            if (newValue != null && newValue != _selectedLop) {
              setState(() {
                _selectedLop = newValue;
              });
            }
          },
          decoration: InputDecoration(
            labelText: isVi ? 'Chọn Lớp' : 'Select Class',
            labelStyle: TextStyle(color: secondaryText),
            prefixIcon: Icon(Icons.class_, color: secondaryText),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: cardColor,
          ),
          dropdownColor: cardColor,
          style: TextStyle(color: lightText),
        ),
        const SizedBox(height: 16),
        // Tháng
        InkWell(
          onTap: _showMonthPicker,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: isVi
                  ? 'Chọn Tháng (Bấm 1 ngày bất kỳ)'
                  : 'Select Month (Tap any date)',
              labelStyle: TextStyle(color: secondaryText),
              prefixIcon: Icon(Icons.calendar_month, color: secondaryText),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              DateFormat(
                'MM / yyyy',
              ).format(DateFormat('yyyy-MM').parse(_selectedMonthYear)),
              style: TextStyle(
                color: lightText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // SỬA: Nhận AsyncValue làm tham số
  Widget _buildReportContent(
    AsyncValue<Map<String, dynamic>> reportAsyncValue,
    bool isVi,
  ) {
    return reportAsyncValue.when(
      loading: () => Expanded(
        child: Center(child: CircularProgressIndicator(color: accentColor)),
      ),
      error: (err, stack) => Expanded(
        child: Center(
          child: Text(
            isVi ? 'Lỗi tải báo cáo: $err' : 'Error loading report: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ),
      data: (reportData) {
        return _buildReportCards(reportData, isVi);
      },
    );
  }

  Widget _buildReportCards(Map<String, dynamic> reportData, bool isVi) {
    final coMat = reportData['coMat'] as int? ?? 0;
    final nghiCoPhep = reportData['nghiCoPhep'] as int? ?? 0;
    final nghiKhongPhep = reportData['nghiKhongPhep'] as int? ?? 0;
    final hocBu = reportData['hocBu'] as int? ?? 0;
    final tongSoBuoi = coMat + nghiCoPhep + nghiKhongPhep + hocBu;

    final listCoMat =
        reportData['listCoMat'] as List<Map<String, dynamic>>? ?? [];
    final listNghiCoPhep =
        reportData['listNghiCoPhep'] as List<Map<String, dynamic>>? ?? [];
    final listNghiKhongPhep =
        reportData['listNghiKhongPhep'] as List<Map<String, dynamic>>? ?? [];
    final listHocBu =
        reportData['listHocBu'] as List<Map<String, dynamic>>? ?? [];

    return Expanded(
      child: ListView(
        children: [
          _buildReportCard(
            icon: Icons.check_circle,
            label: isVi ? 'Tổng số buổi có mặt' : 'Total attended sessions',
            value: coMat.toString(),
            color: Colors.green,
            onTap: coMat > 0
                ? () => _showChiTietDiemDanh(
                    isVi ? 'Có mặt' : 'Present',
                    listCoMat,
                    isVi,
                  )
                : null,
          ),
          _buildReportCard(
            icon: Icons.event_available,
            label: isVi ? 'Số buổi nghỉ có phép' : 'Excused absences',
            value: nghiCoPhep.toString(),
            color: Colors.orange,
            onTap: nghiCoPhep > 0
                ? () => _showChiTietDiemDanh(
                    isVi ? 'Nghỉ có phép' : 'Excused absences',
                    listNghiCoPhep,
                    isVi,
                  )
                : null,
          ),
          _buildReportCard(
            icon: Icons.cancel,
            label: isVi ? 'Số buổi nghỉ không phép' : 'Unexcused absences',
            value: nghiKhongPhep.toString(),
            color: Colors.redAccent,
            onTap: nghiKhongPhep > 0
                ? () => _showChiTietDiemDanh(
                    isVi ? 'Nghỉ không phép' : 'Unexcused absences',
                    listNghiKhongPhep,
                    isVi,
                  )
                : null,
          ),
          _buildReportCard(
            icon: Icons.school,
            label: isVi ? 'Số buổi học bù' : 'Make-up sessions',
            value: hocBu.toString(),
            color: Colors.lightBlueAccent,
            onTap: hocBu > 0
                ? () => _showChiTietDiemDanh(
                    isVi ? 'Học bù' : 'Make-up sessions',
                    listHocBu,
                    isVi,
                  )
                : null,
          ),
          Divider(color: secondaryText, height: 32),
          _buildReportCard(
            icon: Icons.functions,
            label: isVi
                ? 'Tổng số buổi đã điểm danh'
                : 'Total sessions checked',
            value: tongSoBuoi.toString(),
            color: accentColor,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isTotal = false,
    VoidCallback? onTap,
  }) {
    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color, size: 32),
        title: Text(label, style: TextStyle(color: secondaryText)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: isTotal ? lightText : color,
                fontSize: isTotal ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (onTap != null)
              Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.chevron_right,
                  color: secondaryText,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showChiTietDiemDanh(
    String title,
    List<Map<String, dynamic>> records,
    bool isVi,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          isVi ? 'Chi tiết: $title' : 'Details: $title',
          style: TextStyle(color: lightText),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: records.length,
            itemBuilder: (context, index) {
              final r = records[index];
              final datetimeStr = r['gio_diem_danh'] as String;
              final ghiChu = r['ghi_chu'] as String?;

              final dt = DateTime.tryParse(datetimeStr);

              final displayTime = dt != null
                  ? DateFormat('dd/MM/yyyy HH:mm').format(dt)
                  : datetimeStr;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.circle, size: 12, color: accentColor),
                title: Text(displayTime, style: TextStyle(color: lightText)),
                subtitle: ghiChu != null && ghiChu.isNotEmpty
                    ? Text(
                        '${isVi ? 'Ghi chú' : 'Note'}: $ghiChu',
                        style: TextStyle(
                          color: secondaryText,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              isVi ? 'Đóng' : 'Close',
              style: TextStyle(color: accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

// SỬA: Thêm autoDispose để xóa cache khi thoát trang, đồng thời query SQL trực tiếp để đảm bảo đếm chính xác
final reportProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({int idHocSinh, int idLop, String thang})>((
      ref,
      params,
    ) async {
      final db = await DBHelper.instance.database;

      final results = await db.rawQuery(
        '''
        SELECT trang_thai, gio_diem_danh, ghi_chu
        FROM ${DBHelper.tenBangDiemDanh}
        WHERE id_hoc_sinh = ? AND id_lop = ? AND gio_diem_danh LIKE ?
        ORDER BY gio_diem_danh DESC
      ''',
        [params.idHocSinh, params.idLop, '${params.thang}-%'],
      );

      List<Map<String, dynamic>> listCoMat = [];
      List<Map<String, dynamic>> listNghiCoPhep = [];
      List<Map<String, dynamic>> listNghiKhongPhep = [];
      List<Map<String, dynamic>> listHocBu = [];

      for (var row in results) {
        final trangThai = row['trang_thai'] as String;
        if (trangThai == 'Có mặt') {
          listCoMat.add(row);
        } else if (trangThai == 'Nghỉ có phép') {
          listNghiCoPhep.add(row);
        } else if (trangThai == 'Nghỉ không phép') {
          listNghiKhongPhep.add(row);
        } else if (trangThai == 'Học bù') {
          listHocBu.add(row);
        }
      }

      return {
        'coMat': listCoMat.length,
        'nghiCoPhep': listNghiCoPhep.length,
        'nghiKhongPhep': listNghiKhongPhep.length,
        'hocBu': listHocBu.length,
        'listCoMat': listCoMat,
        'listNghiCoPhep': listNghiCoPhep,
        'listNghiKhongPhep': listNghiKhongPhep,
        'listHocBu': listHocBu,
      };
    });
