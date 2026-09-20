// File: lib/services/pdf_export_service.dart

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/hocphi.dart'; // For LopHocPhiViewModel
import '../models/hoc_phi_tong_hop.dart'; // For HocPhiTongHop
import '../models/hs_lop_view_model.dart';
import '../models/nhan_xet_thang.dart';
import '../models/report_models.dart';
import '../utils/db.dart';

enum PdfAction { preview, print, share }

class PdfExportService {
  static pw.ThemeData? _cachedTheme;

  Future<pw.ThemeData> _getTheme() async {
    if (_cachedTheme != null) return _cachedTheme!;

    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFontData);

    _cachedTheme = pw.ThemeData.withFont(
      base: ttf,
      bold: boldTtf,
      italic: ttf,
      boldItalic: boldTtf,
    );
    return _cachedTheme!;
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
  }

  Future<void> _cleanupOldTempFiles(Directory tempDir) async {
    try {
      final files = tempDir.listSync();
      final now = DateTime.now();
      for (var f in files) {
        if (f is File &&
            f.path.contains('PhieuDanhGia_') &&
            f.path.endsWith('.png')) {
          final lastModified = await f.lastModified();
          if (now.difference(lastModified).inHours >= 1) {
            await f.delete().catchError((_) => f);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> generateAndOpenHocPhiPdf(
    LopHocPhiViewModel viewModel,
    String thang,
  ) async {
    final pdf = pw.Document();
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');
    final theme = await _getTheme();

    final report = viewModel.report;
    final lop = viewModel.lop;
    final safeLopTen = _sanitizeFileName(lop.ten);

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'BÁO CÁO HỌC PHÍ THÁNG ${DateFormat('MM/yyyy').format(DateFormat('yyyy-MM').parse(thang))}',
                      textScaleFactor: 1.5,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Ngày xuất: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Thông tin lớp và tổng quan
              pw.Text(
                lop.id == -1
                    ? 'Tất cả các lớp'
                    : 'Lớp: ${lop.ten} (Khối ${lop.khoi})',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Tổng cần thu: ${formatCurrency.format(report.tongSoTienCanThu)} VNĐ',
                  ),
                  pw.Text(
                    'Tổng đã thu: ${formatCurrency.format(report.tongSoTienDaThu)} VNĐ',
                  ),
                  pw.Text(
                    'Tổng còn nợ: ${formatCurrency.format(report.tongSoTienConNo)} VNĐ',
                    style: pw.TextStyle(
                      color: PdfColors.red,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Divider(height: 20),

              // Tiêu đề danh sách nợ
              pw.Text(
                'CHI TIẾT HỌC SINH CÒN NỢ',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              pw.SizedBox(height: 10),

              // Bảng danh sách học sinh nợ
              _buildStudentDebtTable(report, formatCurrency),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: "BaoCaoHocPhi_${safeLopTen}_$thang.pdf",
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildStudentDebtTable(
    HocPhiTongHop report,
    NumberFormat formatCurrency,
  ) {
    if (report.dsHocSinhConNo.isEmpty) {
      return pw.Center(
        child: pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Text('Tất cả học sinh đã hoàn thành học phí.'),
        ),
      );
    }

    final headers = ['STT', 'Tên Học Sinh', 'Cần Nộp', 'Đã Đóng', 'Còn Nợ'];

    final data = List.generate(report.dsHocSinhConNo.length, (index) {
      final hs = report.dsHocSinhConNo[index];
      return [
        '${index + 1}',
        hs.tenHocSinh,
        formatCurrency.format(hs.soTienCanNop),
        formatCurrency.format(hs.soTienDaDong),
        formatCurrency.format(hs.soTienConNo),
      ];
    });

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      cellStyle: const pw.TextStyle(fontSize: 10),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
        4: const pw.FlexColumnWidth(1),
      },
    );
  }

  pw.Page _buildEvaluationPage(
    HSLopViewModel hs,
    NhanXetThang nhanXet,
    String tenLop,
    String formattedThang,
    pw.ThemeData theme,
  ) {
    return pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header / Banner
            pw.Center(
              child: pw.Text(
                'PHIẾU ĐÁNH GIÁ KẾT QUẢ HỌC TẬP',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 20,
                  color: PdfColors.teal800,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Tháng $formattedThang',
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),
            pw.SizedBox(height: 24),

            // Học sinh Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Học sinh: ${hs.ten}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                pw.Text(
                  'Lớp: $tenLop',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            pw.Divider(height: 16, thickness: 1.5, color: PdfColors.teal),
            pw.SizedBox(height: 8),

            // Điểm chi tiết
            pw.Text(
              'Kết Quả Học Tập Chi Tiết:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 13,
                color: PdfColors.teal900,
              ),
            ),
            pw.SizedBox(height: 8),

            _buildEvaluationRow(
              'Chuyên cần (Điểm danh)',
              nhanXet.diemChuyenCan,
              '/ 10.0',
            ),
            _buildEvaluationRow(
              'Thái độ học tập trên lớp',
              nhanXet.diemThaiDo,
              '/ 10.0',
            ),
            _buildEvaluationRow(
              'Hoàn thành bài tập về nhà',
              nhanXet.diemBaiTap,
              '/ 10.0',
            ),
            _buildEvaluationRow(
              'Hiểu bài & Điểm kiểm tra',
              nhanXet.diemKiemTra,
              '/ 10.0',
            ),

            pw.SizedBox(height: 16),
            pw.Divider(height: 8),
            pw.SizedBox(height: 8),

            // Điểm trung bình & Xếp hạng
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'ĐIỂM TRUNG BÌNH:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                pw.Text(
                  nhanXet.diemTrungBinh.toStringAsFixed(2),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 16,
                    color: PdfColors.teal,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'XẾP HẠNG THÁNG:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                pw.Text(
                  nhanXet.xepHang ?? 'Chưa xếp hạng',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 13,
                    color: PdfColors.amber800,
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 24),

            // Nhận xét chung
            pw.Text(
              'Nhận xét chung của giáo viên:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 13,
                color: PdfColors.teal900,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400, width: 1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColors.grey100,
              ),
              child: pw.Text(
                nhanXet.nhanXetChung ??
                    'Học sinh đi học đầy đủ, có thái độ học tập tích cực, chuẩn bị bài tốt.',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),

            pw.SizedBox(height: 32),

            // Chữ ký & Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.SizedBox(),
                pw.Column(
                  children: [
                    pw.Text(
                      'Giáo viên chủ nhiệm',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(height: 36),
                    pw.Text(
                      '(Ký và ghi rõ họ tên)',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'Trân trọng gửi đến quý phụ huynh học sinh!',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<pw.Document> _buildBaoCaoHocTapDocument(
    HSLopViewModel hs,
    NhanXetThang nhanXet,
    String tenLop,
    String thang,
  ) async {
    final pdf = pw.Document();
    final theme = await _getTheme();
    final String formattedThang = DateFormat(
      'MM/yyyy',
    ).format(DateFormat('yyyy-MM').parse(thang));

    pdf.addPage(
      _buildEvaluationPage(hs, nhanXet, tenLop, formattedThang, theme),
    );

    final page2 = await _buildMatrixPage(
      hs.id!,
      nhanXet.idLop,
      thang,
      theme,
      hs.ten,
      tenLop,
    );
    pdf.addPage(page2);

    return pdf;
  }

  Future<void> generateAndOpenBaoCaoHocTapPdf(
    HSLopViewModel hs,
    NhanXetThang nhanXet,
    String tenLop,
    String thang,
  ) async {
    final pdf = await _buildBaoCaoHocTapDocument(hs, nhanXet, tenLop, thang);
    final safeHsTen = _sanitizeFileName(hs.ten);

    await Printing.layoutPdf(
      name: "BaoCaoHocTap_${safeHsTen}_$thang.pdf",
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildEvaluationRow(String label, double score, String suffix) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(
            '${score.toStringAsFixed(1)} $suffix',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> generateAndShareBaoCaoHocTapImage(
    HSLopViewModel hs,
    NhanXetThang nhanXet,
    String tenLop,
    String thang,
  ) async {
    final pdf = await _buildBaoCaoHocTapDocument(hs, nhanXet, tenLop, thang);
    final pdfBytes = await pdf.save();
    final String formattedThang = DateFormat(
      'MM/yyyy',
    ).format(DateFormat('yyyy-MM').parse(thang));
    final safeHsTen = _sanitizeFileName(hs.ten);

    final List<XFile> shareFiles = [];
    final tempDir = await getTemporaryDirectory();
    await _cleanupOldTempFiles(tempDir);

    int pageNum = 1;

    await for (final page in Printing.raster(
      pdfBytes,
      pages: [0, 1],
      dpi: 200,
    )) {
      final pngBytes = await page.toPng();
      final imgPath =
          '${tempDir.path}/PhieuDanhGia_${safeHsTen}_${pageNum}_$thang.png';
      final imgFile = File(imgPath);
      await imgFile.writeAsBytes(pngBytes);
      shareFiles.add(XFile(imgFile.path));
      pageNum++;
    }

    if (shareFiles.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(
          files: shareFiles,
          text:
              'Phiếu đánh giá & Bảng thống kê học tập tháng $formattedThang của học sinh ${hs.ten}',
        ),
      );
    }
  }

  Future<pw.Page> _buildMatrixPage(
    int idHocSinh,
    int idLop,
    String thang,
    pw.ThemeData theme,
    String tenHocSinh,
    String tenLop,
  ) async {
    final db = await DBHelper.instance.database;
    final parts = thang.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final startDateStr = '$thang-01 00:00:00';
    final nextMonth = month == 12 ? 1 : month + 1;
    final nextYear = month == 12 ? year + 1 : year;
    final endDateStr =
        '$nextYear-${nextMonth.toString().padLeft(2, '0')}-01 00:00:00';

    // 1. Lấy danh sách điểm danh (Chỉ SELECT các cột cần thiết)
    final List<Map<String, dynamic>> sessions = await db.query(
      DBHelper.tenBangDiemDanh,
      columns: ['id', 'gio_diem_danh'],
      where:
          'id_hoc_sinh = ? AND id_lop = ? AND gio_diem_danh >= ? AND gio_diem_danh < ?',
      whereArgs: [idHocSinh, idLop, startDateStr, endDateStr],
      orderBy: 'gio_diem_danh ASC',
    );

    // 2. Lấy danh sách quy tắc điểm (Chỉ SELECT các cột cần thiết)
    final List<Map<String, dynamic>> rules = await db.query(
      DBHelper.tenBangQuyTacDiem,
      columns: ['mo_ta', 'loai_quy_tac'],
      orderBy: 'loai_quy_tac ASC, thu_tu_hien_thi ASC, mo_ta ASC',
    );

    // 3. Lấy sự kiện bằng Batch IN query & lưu dưới dạng Set<String> cho lookup O(1)
    final List<int> sessionIds = sessions.map((s) => s['id'] as int).toList();
    final Map<int, Set<String>> sessionEvents = {};
    if (sessionIds.isNotEmpty) {
      final placeholders = List.filled(sessionIds.length, '?').join(',');
      final List<Map<String, dynamic>> events = await db.rawQuery(
        'SELECT id_diem_danh, mo_ta FROM ${DBHelper.tenBangSuKienHocTap} WHERE id_diem_danh IN ($placeholders)',
        sessionIds,
      );
      for (var ev in events) {
        final idDD = ev['id_diem_danh'] as int;
        final moTa = ev['mo_ta'] as String;
        sessionEvents.putIfAbsent(idDD, () => {}).add(moTa);
      }
    }

    final String formattedThang = DateFormat(
      'MM/yyyy',
    ).format(DateFormat('yyyy-MM').parse(thang));

    return pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        // Build table headers với tryParse an toàn
        final headers = ['Quy tắc cộng/trừ'];
        for (var sess in sessions) {
          final gioStr = (sess['gio_diem_danh'] as String?)?.trim() ?? '';
          final dt = DateTime.tryParse(gioStr) ?? DateTime.now();
          final weekdayStr = [
            'CN',
            'T2',
            'T3',
            'T4',
            'T5',
            'T6',
            'T7',
          ][dt.weekday % 7];
          headers.add('$weekdayStr\n${DateFormat('dd/MM').format(dt)}');
        }

        // Build table rows với Set lookup O(1)
        final data = <List<dynamic>>[];
        for (var rule in rules) {
          final moTa = rule['mo_ta'] as String;
          final isCong = rule['loai_quy_tac'] == 'CONG_DIEM';
          final row = <dynamic>[moTa];

          for (var sess in sessions) {
            final idDD = sess['id'] as int;
            final events = sessionEvents[idDD];
            if (events != null && events.contains(moTa)) {
              if (isCong) {
                row.add('v');
              } else {
                row.add('x');
              }
            } else {
              row.add('');
            }
          }
          data.add(row);
        }

        // Column widths
        final colWidths = <int, pw.TableColumnWidth>{
          0: const pw.FlexColumnWidth(3.0),
        };
        for (int i = 1; i <= sessions.length; i++) {
          colWidths[i] = const pw.FlexColumnWidth(0.8);
        }

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                'BẢNG THỐNG KÊ CHI TIẾT TỪNG BUỔI HỌC',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                  color: PdfColors.teal800,
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Tháng $formattedThang',
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Học sinh: $tenHocSinh',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                pw.Text(
                  'Lớp: $tenLop',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            pw.Divider(height: 12, color: PdfColors.teal),
            pw.SizedBox(height: 10),

            if (sessions.isEmpty)
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Text(
                    'Không có dữ liệu buổi học nào trong tháng này.',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: colWidths,
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                    children: headers.map((h) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          h,
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Data Rows
                  ...data.map((row) {
                    return pw.TableRow(
                      children: row.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final val = entry.value as String;
                        if (idx == 0) {
                          return pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            alignment: pw.Alignment.centerLeft,
                            child: pw.Text(
                              val,
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          );
                        } else {
                          // Render tick/cross with colors
                          pw.TextStyle textStyle;
                          if (val == 'v') {
                            textStyle = pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green,
                              fontSize: 9,
                            );
                          } else if (val == 'x') {
                            textStyle = pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red,
                              fontSize: 9,
                            );
                          } else {
                            textStyle = const pw.TextStyle(fontSize: 9);
                          }
                          return pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            alignment: pw.Alignment.center,
                            child: pw.Text(val, style: textStyle),
                          );
                        }
                      }).toList(),
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.start,
              children: [
                pw.Text(
                  'Chú thích:   ',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  'v',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  ' : Được cộng điểm (phát biểu, bài tập tốt, ngoan...)   ',
                  style: pw.TextStyle(fontSize: 8),
                ),
                pw.Text(
                  'x',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  ' : Bị trừ điểm (nói chuyện, đi muộn, thiếu bài...)',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> generateAndExportUnifiedPdf(
    FacilityReportData reportData, {
    required PdfAction action,
  }) async {
    final pdf = pw.Document();
    final theme = await _getTheme();
    final currencyFormat = NumberFormat('#,##0', 'vi_VN');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final request = reportData.request;

    final String periodTitle;
    if (request.periodType == ReportPeriodType.month) {
      final parts = request.monthStr.split('-');
      periodTitle = 'Tháng ${parts[1]}/${parts[0]}';
    } else {
      periodTitle =
          'Từ ${dateFormat.format(request.startDate)} đến ${dateFormat.format(request.endDate)}';
    }

    final safeScopeName = request.scope == ReportScope.singleClass
        ? _sanitizeFileName(
            reportData.classReports.isNotEmpty
                ? reportData.classReports.first.lop.ten
                : 'Lop',
          )
        : 'TatCaCacLop';
    final fileName =
        'BaoCao_${safeScopeName}_${request.monthStr.replaceAll('-', '')}.pdf';

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.all(32),
        ),
        header: (pw.Context context) {
          if (context.pageNumber == 1) return pw.SizedBox();
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 10),
            padding: const pw.EdgeInsets.only(bottom: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'BÁO CÁO THỐNG KÊ - $periodTitle',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Trang ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            padding: const pw.EdgeInsets.only(top: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Hệ thống quản lý học phí & điểm danh',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Trang ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          final widgets = <pw.Widget>[];

          // 1. Title Banner
          widgets.add(
            pw.Center(
              child: pw.Text(
                'BÁO CÁO THỐNG KÊ TỔNG HỢP',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                  color: PdfColors.teal800,
                ),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 4));
          widgets.add(
            pw.Center(
              child: pw.Text(
                periodTitle,
                style: pw.TextStyle(
                  fontStyle: pw.FontStyle.italic,
                  fontSize: 12,
                  color: PdfColors.grey800,
                ),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 16));

          // 2. Overview / Facility KPI Summary
          if (request.sections.contains(ReportSection.classSummary) ||
              request.scope == ReportScope.allClasses) {
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal50,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: PdfColors.teal200),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'TỔNG QUAN HỆ THỐNG',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                        color: PdfColors.teal900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildKpiBox(
                          'Tổng số lớp',
                          '${reportData.totalClasses} lớp',
                        ),
                        _buildKpiBox(
                          'Tổng học sinh',
                          '${reportData.totalStudents} HS',
                        ),
                        _buildKpiBox(
                          'Tỷ lệ đi học trung bình',
                          '${(reportData.overallAttendanceRate * 100).toStringAsFixed(0)}%',
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildKpiBox(
                          'Cần thu',
                          '${currencyFormat.format(reportData.totalExpectedTuition)} VNĐ',
                        ),
                        _buildKpiBox(
                          'Đã thu',
                          '${currencyFormat.format(reportData.totalCollectedTuition)} VNĐ',
                        ),
                        _buildKpiBox(
                          'Còn nợ',
                          '${currencyFormat.format(reportData.totalDebtTuition)} VNĐ',
                          isAlert: reportData.totalDebtTuition > 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 20));
          }

          // 3. Render Class Reports
          if (reportData.classReports.isEmpty) {
            widgets.add(
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(20),
                  child: pw.Text(
                    'Không có dữ liệu lớp học phù hợp với báo cáo.',
                  ),
                ),
              ),
            );
          } else {
            for (int cIdx = 0; cIdx < reportData.classReports.length; cIdx++) {
              final classData = reportData.classReports[cIdx];
              if (cIdx > 0) {
                widgets.add(pw.SizedBox(height: 20));
                widgets.add(pw.Divider(thickness: 1, color: PdfColors.grey400));
                widgets.add(pw.SizedBox(height: 16));
              }

              // Header lớp
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.teal700,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'LỚP: ${classData.lop.ten.toUpperCase()}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      pw.Text(
                        'Khối: ${classData.lop.khoi} | Sĩ số: ${classData.totalStudents} HS',
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 10));

              // Class Overview Summary
              widgets.add(
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Số buổi đã dạy: ${classData.totalSessions}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Cần thu: ${currencyFormat.format(classData.totalExpectedTuition)}đ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Đã thu: ${currencyFormat.format(classData.totalCollectedTuition)}đ',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Còn nợ: ${currencyFormat.format(classData.totalDebtTuition)}đ',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: classData.totalDebtTuition > 0
                            ? PdfColors.red
                            : PdfColors.black,
                      ),
                    ),
                  ],
                ),
              );
              widgets.add(pw.SizedBox(height: 12));

              // Section 1: Điểm danh
              if (request.sections.contains(ReportSection.attendance)) {
                widgets.add(
                  pw.Text(
                    '1. Thống Kê Điểm Danh',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: PdfColors.teal900,
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 6));
                widgets.add(
                  _buildUnifiedAttendanceTable(classData.attendanceList),
                );
                widgets.add(pw.SizedBox(height: 14));
              }

              // Section 2: Học phí
              if (request.sections.contains(ReportSection.tuition)) {
                widgets.add(
                  pw.Text(
                    '2. Thống Kê Học Phí',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: PdfColors.teal900,
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 6));
                widgets.add(
                  _buildUnifiedTuitionTable(
                    classData.tuitionList,
                    currencyFormat,
                  ),
                );
                widgets.add(pw.SizedBox(height: 14));
              }

              // Section 3: Đánh giá học tập
              if (request.sections.contains(ReportSection.evaluation)) {
                widgets.add(
                  pw.Text(
                    '3. Đánh Giá Học Tập',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11,
                      color: PdfColors.teal900,
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 6));
                widgets.add(
                  _buildUnifiedEvaluationTable(classData.evaluationList),
                );
                widgets.add(pw.SizedBox(height: 14));
              }
            }
          }

          return widgets;
        },
      ),
    );

    // Perform requested PDF action
    if (action == PdfAction.share) {
      final pdfBytes = await pdf.save();
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
    } else {
      // action == PdfAction.preview or print
      await Printing.layoutPdf(
        name: fileName,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
  }

  pw.Widget _buildKpiBox(String title, String value, {bool isAlert = false}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: isAlert ? PdfColors.red : PdfColors.black,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildUnifiedAttendanceTable(
    List<StudentAttendanceReportItem> items,
  ) {
    if (items.isEmpty) {
      return pw.Text(
        'Không có dữ liệu điểm danh.',
        style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
      );
    }
    final headers = [
      'STT',
      'Họ và tên',
      'Tổng buổi',
      'Có mặt',
      'Nghỉ (P)',
      'Nghỉ (KP)',
      'Tỷ lệ',
    ];
    final data = List.generate(items.length, (index) {
      final item = items[index];
      final tileString = item.totalSessions > 0
          ? '${(item.attendanceRate * 100).toStringAsFixed(0)}%'
          : '-';
      return [
        '${index + 1}',
        item.studentName,
        '${item.totalSessions}',
        '${item.presentCount}',
        '${item.excusedAbsenceCount}',
        '${item.unexcusedAbsenceCount}',
        tileString,
      ];
    });

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 22,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
        6: pw.Alignment.center,
      },
      cellStyle: const pw.TextStyle(fontSize: 8),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.0),
        3: const pw.FlexColumnWidth(1.0),
        4: const pw.FlexColumnWidth(1.0),
        5: const pw.FlexColumnWidth(1.0),
        6: const pw.FlexColumnWidth(1.0),
      },
    );
  }

  pw.Widget _buildUnifiedTuitionTable(
    List<StudentTuitionReportItem> items,
    NumberFormat currencyFormat,
  ) {
    if (items.isEmpty) {
      return pw.Text(
        'Không có dữ liệu học phí.',
        style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
      );
    }
    final headers = [
      'STT',
      'Họ và tên',
      'Cần nộp',
      'Đã đóng',
      'Còn nợ',
      'Trạng thái',
    ];
    final data = List.generate(items.length, (index) {
      final item = items[index];
      final statusText = item.debtAmount > 0 ? 'Còn nợ' : 'Hoàn thành';
      return [
        '${index + 1}',
        item.studentName,
        currencyFormat.format(item.totalFee),
        currencyFormat.format(item.paidAmount),
        currencyFormat.format(item.debtAmount),
        statusText,
      ];
    });

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 22,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
      },
      cellStyle: const pw.TextStyle(fontSize: 8),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(2.5),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  pw.Widget _buildUnifiedEvaluationTable(
    List<StudentEvaluationReportItem> items,
  ) {
    if (items.isEmpty) {
      return pw.Text(
        'Không có dữ liệu đánh giá.',
        style: const pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
      );
    }
    final headers = [
      'STT',
      'Họ và tên',
      'CC',
      'TĐ',
      'BT',
      'KT',
      'ĐTB',
      'Xếp loại',
      'Nhận xét',
    ];
    final data = List.generate(items.length, (index) {
      final item = items[index];
      return [
        '${index + 1}',
        item.studentName,
        item.attendanceScore.toStringAsFixed(1),
        item.attitudeScore.toStringAsFixed(1),
        item.homeworkScore.toStringAsFixed(1),
        item.testScore.toStringAsFixed(1),
        item.averageScore.toStringAsFixed(1),
        item.rank,
        item.remark,
      ];
    });

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 22,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
        5: pw.Alignment.center,
        6: pw.Alignment.center,
        7: pw.Alignment.center,
        8: pw.Alignment.centerLeft,
      },
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(2.0),
        2: const pw.FlexColumnWidth(0.6),
        3: const pw.FlexColumnWidth(0.6),
        4: const pw.FlexColumnWidth(0.6),
        5: const pw.FlexColumnWidth(0.6),
        6: const pw.FlexColumnWidth(0.7),
        7: const pw.FlexColumnWidth(1.0),
        8: const pw.FlexColumnWidth(2.2),
      },
    );
  }
}
