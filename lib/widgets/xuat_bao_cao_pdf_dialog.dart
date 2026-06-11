// File: lib/widgets/xuat_bao_cao_pdf_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lop.dart';
import '../screens/hocphi.dart'; // For LopHocPhiViewModel
import '../services/lop_service.dart';
import '../services/pdf_export_service.dart';
import '../services/report_service.dart';
import '../models/hoc_phi_tong_hop.dart'; // THÊM IMPORT NÀY

// --- Hằng số màu sắc ---
// const Color darkBackground = Color(0xFF1A1A2E);
// const Color cardColor = Color(0xFF16213E);
// const Color lightText = Colors.white;
// const Color secondaryText = Colors.white70;
// const Color accentColor = Color(0xFF00BFA5);

class XuatBaoCaoPdfDialog extends StatefulWidget {
  const XuatBaoCaoPdfDialog({super.key});

  @override
  State<XuatBaoCaoPdfDialog> createState() => _XuatBaoCaoPdfDialogState();
}

class _XuatBaoCaoPdfDialogState extends State<XuatBaoCaoPdfDialog> {
  Color get darkBackground => Theme.of(context).scaffoldBackgroundColor;
  Color get cardColor => Theme.of(context).cardColor;
  Color get lightText => Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
  Color get secondaryText => Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white70;
  Color get accentColor => Theme.of(context).primaryColor;
  Color get deleteColor => Theme.of(context).colorScheme.error;

  final LopService _lopService = LopService();
  final ReportService _reportService = ReportService();
  final PdfExportService _pdfService = PdfExportService();

  late Future<List<Lop>> _lopListFuture;
  Lop? _selectedLop;
  late int _selectedYear;
  late int _selectedMonth;
  final Lop _lopTatCa = Lop(
    id: -1,
    ten: 'Tất cả các lớp',
    khoi: 0,
  ); // THÊM BIẾN NÀY

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _lopListFuture = _lopService.docTatCaLop();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  Future<void> _handleExport() async {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    if (_selectedLop == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            isVi ? 'Thông báo' : 'Notification',
            style: TextStyle(color: accentColor, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isVi ? 'Vui lòng chọn một lớp để xuất báo cáo.' : 'Please select a class to export the report.',
            style: TextStyle(color: lightText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isVi ? 'Đóng' : 'Close', style: TextStyle(color: secondaryText)),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // SỬA: Tạo chuỗi tháng từ các dropdown đã chọn
      final thang =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';

      LopHocPhiViewModel viewModel;

      if (_selectedLop!.id == -1) {
        // Nếu chọn "Tất cả các lớp", tiến hành gom dữ liệu
        int tongSoHocSinh = 0;
        int tongTienCanThu = 0;
        int tongTienDaThu = 0;
        int tongTienConNo = 0;
        List<HocSinhNoHocPhi> dsNoGop = [];

        final allLops = await _lopService.docTatCaLop();
        for (var lop in allLops) {
          final report = await _reportService.layBaoCaoHocPhiThang(
            lop.id!,
            thang,
          );
          tongSoHocSinh += report.tongSoHocSinh;
          tongTienCanThu += report.tongSoTienCanThu;
          tongTienDaThu += report.tongSoTienDaThu;
          tongTienConNo += report.tongSoTienConNo;

          // Thêm tên lớp vào sau tên học sinh để dễ nhận biết trong danh sách nợ
          dsNoGop.addAll(
            report.dsHocSinhConNo.map(
              (hs) => HocSinhNoHocPhi(
                idHocSinh: hs.idHocSinh,
                tenHocSinh: '${hs.tenHocSinh} (${lop.ten})',
                soTienCanNop: hs.soTienCanNop,
                soTienDaDong: hs.soTienDaDong,
                soTienConNo: hs.soTienConNo,
                mienGiam: hs.mienGiam,
                soBuoiDu: hs.soBuoiDu,
              ),
            ),
          );
        }

        final mergedReport = HocPhiTongHop(
          tongSoBuoi: 0, // Không áp dụng cho nhiều lớp
          tongSoHocSinh: tongSoHocSinh,
          tongSoTienCanThu: tongTienCanThu,
          tongSoTienDaThu: tongTienDaThu,
          tongSoTienConNo: tongTienConNo,
          dsHocSinhConNo: dsNoGop,
        );
        viewModel = LopHocPhiViewModel(lop: _lopTatCa, report: mergedReport);
      } else {
        // Xuất cho 1 lớp bình thường
        final report = await _reportService.layBaoCaoHocPhiThang(
          _selectedLop!.id!,
          thang,
        );
        viewModel = LopHocPhiViewModel(lop: _selectedLop!, report: report);
      }

      await _pdfService.generateAndOpenHocPhiPdf(viewModel, thang);

      if (mounted) {
        Navigator.of(context).pop(); // Đóng dialog sau khi xuất thành công
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
              isVi ? 'Lỗi khi xuất PDF: $e' : 'Error exporting PDF: $e',
              style: TextStyle(color: lightText),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  isVi ? 'Đóng' : 'Close',
                  style: TextStyle(color: secondaryText),
                ),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
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
          isVi ? 'XUẤT BÁO CÁO HỌC PHÍ' : 'EXPORT TUITION REPORT',
          style: TextStyle(color: lightText, fontWeight: FontWeight.bold),
        ),
      ),
      content: FutureBuilder<List<Lop>>(
        future: _lopListFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return Text(
              isVi ? 'Không có lớp nào để chọn.' : 'No classes available to select.',
              style: TextStyle(color: secondaryText),
            );
          }

          // SỬA: Chèn tùy chọn "Tất cả các lớp" vào đầu danh sách
          final lopList = [_lopTatCa, ...snapshot.data!];
          if (_selectedLop == null && lopList.isNotEmpty) {
            _selectedLop = lopList.first;
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dropdown Chọn Lớp
              DropdownButtonFormField<Lop>(
                value: _selectedLop,
                items: lopList.map((lop) {
                  return DropdownMenuItem<Lop>(
                    value: lop,
                    child: Text(
                      lop.id == -1
                          ? (isVi ? 'Tất cả các lớp' : 'All classes')
                          : (isVi ? 'Lớp ${lop.ten} (Khối ${lop.khoi})' : 'Class ${lop.ten} (Grade ${lop.khoi})'),
                    ),
                  );
                }).toList(),
                onChanged: (Lop? newValue) {
                  setState(() {
                    _selectedLop = newValue;
                  });
                },
                decoration: InputDecoration(
                  labelText: isVi ? 'Chọn Lớp' : 'Select Class',
                  labelStyle: TextStyle(color: secondaryText),
                  prefixIcon: Icon(Icons.class_, color: secondaryText),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: darkBackground,
                ),
                dropdownColor: cardColor,
                style: TextStyle(color: lightText),
              ),
              const SizedBox(height: 20),
              // SỬA: Dùng 2 Dropdown cho Tháng và Năm
              Row(
                children: [
                  // Dropdown Chọn Tháng
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedMonth,
                      items: List.generate(12, (index) => index + 1).map((m) {
                        return DropdownMenuItem<int>(
                          value: m,
                          child: Text(isVi ? 'Tháng $m' : 'Month $m'),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedMonth = newValue);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: isVi ? 'Tháng' : 'Month',
                        labelStyle: TextStyle(color: secondaryText),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: darkBackground,
                      ),
                      dropdownColor: cardColor,
                      style: TextStyle(color: lightText),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Dropdown Chọn Năm
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedYear,
                      items:
                          List.generate(
                            11,
                            (index) => DateTime.now().year - 5 + index,
                          ).map((y) {
                            return DropdownMenuItem<int>(
                              value: y,
                              child: Text('$y'),
                            );
                          }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedYear = newValue);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: isVi ? 'Năm' : 'Year',
                        labelStyle: TextStyle(color: secondaryText),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: darkBackground,
                      ),
                      dropdownColor: cardColor,
                      style: TextStyle(color: lightText),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: Text(isVi ? 'HỦY' : 'CANCEL', style: TextStyle(color: secondaryText)),
        ),
        ElevatedButton.icon(
          onPressed: _isExporting ? null : _handleExport,
          icon: _isExporting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: darkBackground,
                  ),
                )
              : const Icon(Icons.picture_as_pdf),
          label: Text(isVi ? 'XUẤT PDF' : 'EXPORT PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: darkBackground,
          ),
        ),
      ],
    );
  }
}
