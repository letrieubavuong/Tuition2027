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
import '../utils/db.dart';

class PdfExportService {
  Future<void> generateAndOpenHocPhiPdf(
    LopHocPhiViewModel viewModel,
    String thang,
  ) async {
    final pdf = pw.Document();
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');

    // Load fonts hỗ trợ tiếng Việt
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFontData);

    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: ttf,
      bold: boldTtf,
      italic: ttf,
      boldItalic: boldTtf,
    );

    final report = viewModel.report;
    final lop = viewModel.lop;

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

    // SỬA: Sử dụng package 'printing' để hiển thị bản xem trước (hoạt động trên cả máy ảo)
    await Printing.layoutPdf(
      // Đặt tên cho file khi chia sẻ/lưu
      name: "BaoCaoHocPhi_${lop.ten.replaceAll(' ', '_')}_$thang.pdf",
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

    final data = report.dsHocSinhConNo.map((hs) {
      return [
        (report.dsHocSinhConNo.indexOf(hs) + 1).toString(),
        hs.tenHocSinh,
        (formatCurrency.format(hs.soTienCanNop)),
        (formatCurrency.format(hs.soTienDaDong)),
        (formatCurrency.format(hs.soTienConNo)),
      ];
    }).toList();

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

  Future<void> generateAndOpenBaoCaoHocTapPdf(
    HSLopViewModel hs,
    NhanXetThang nhanXet,
    String tenLop,
    String thang,
  ) async {
    final pdf = pw.Document();

    // Load fonts hỗ trợ tiếng Việt
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFontData);

    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: ttf,
      bold: boldTtf,
      italic: ttf,
      boldItalic: boldTtf,
    );
    final String formattedThang = DateFormat(
      'MM/yyyy',
    ).format(DateFormat('yyyy-MM').parse(thang));

    pdf.addPage(
      pw.Page(
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
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
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
      ),
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

    await Printing.layoutPdf(
      name: "BaoCaoHocTap_${hs.ten.replaceAll(' ', '_')}_$thang.pdf",
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
    final pdf = pw.Document();

    // Load fonts hỗ trợ tiếng Việt
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFontData);

    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: ttf,
      bold: boldTtf,
      italic: ttf,
      boldItalic: boldTtf,
    );
    final String formattedThang = DateFormat(
      'MM/yyyy',
    ).format(DateFormat('yyyy-MM').parse(thang));

    pdf.addPage(
      pw.Page(
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
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
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
      ),
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

    final pdfBytes = await pdf.save();

    // Convert PDF pages to PNG image bytes
    final List<XFile> shareFiles = [];
    final tempDir = await getTemporaryDirectory();
    int pageNum = 1;

    await for (final page in Printing.raster(
      pdfBytes,
      pages: [0, 1],
      dpi: 200,
    )) {
      final pngBytes = await page.toPng();
      final imgPath =
          '${tempDir.path}/PhieuDanhGia_${hs.ten.replaceAll(' ', '_')}_${pageNum}_$thang.png';
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

    // 1. Lấy danh sách điểm danh
    final List<Map<String, dynamic>> sessions = await db.query(
      DBHelper.tenBangDiemDanh,
      where:
          'id_hoc_sinh = ? AND id_lop = ? AND gio_diem_danh >= ? AND gio_diem_danh < ?',
      whereArgs: [idHocSinh, idLop, startDateStr, endDateStr],
      orderBy: 'gio_diem_danh ASC',
    );

    // 2. Lấy danh sách quy tắc điểm
    final List<Map<String, dynamic>> rules = await db.query(
      DBHelper.tenBangQuyTacDiem,
      orderBy: 'loai_quy_tac ASC, thu_tu_hien_thi ASC, mo_ta ASC',
    );

    // 3. Lấy sự kiện
    final List<int> sessionIds = sessions.map((s) => s['id'] as int).toList();
    final Map<int, List<String>> sessionEvents = {};
    if (sessionIds.isNotEmpty) {
      final placeholders = List.filled(sessionIds.length, '?').join(',');
      final List<Map<String, dynamic>> events = await db.rawQuery(
        'SELECT id_diem_danh, mo_ta FROM ${DBHelper.tenBangSuKienHocTap} WHERE id_diem_danh IN ($placeholders)',
        sessionIds,
      );
      for (var ev in events) {
        final idDD = ev['id_diem_danh'] as int;
        final moTa = ev['mo_ta'] as String;
        sessionEvents.putIfAbsent(idDD, () => []).add(moTa);
      }
    }

    final String formattedThang = DateFormat(
      'MM/yyyy',
    ).format(DateFormat('yyyy-MM').parse(thang));

    return pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        // Build table headers
        final headers = ['Quy tắc cộng/trừ'];
        for (var sess in sessions) {
          final dt = DateTime.parse(sess['gio_diem_danh'] as String);
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

        // Build table rows
        final data = <List<dynamic>>[];
        for (var rule in rules) {
          final moTa = rule['mo_ta'] as String;
          final isCong = rule['loai_quy_tac'] == 'CONG_DIEM';
          final row = <dynamic>[moTa];

          for (var sess in sessions) {
            final idDD = sess['id'] as int;
            final events = sessionEvents[idDD] ?? [];
            if (events.contains(moTa)) {
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
}
