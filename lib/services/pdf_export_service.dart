// File: lib/services/pdf_export_service.dart

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../screens/hocphi.dart'; // For LopHocPhiViewModel
import '../models/hoc_phi_tong_hop.dart'; // For HocPhiTongHop
import '../models/hs_lop_view_model.dart';
import '../models/nhan_xet_thang.dart';

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

    final pw.ThemeData theme = pw.ThemeData.withFont(base: ttf, bold: boldTtf);

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
                'Lớp: ${lop.ten} (Khối ${lop.khoi})',
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
        '${formatCurrency.format(hs.soTienCanNop)}',
        '${formatCurrency.format(hs.soTienDaDong)}',
        '${formatCurrency.format(hs.soTienConNo)}',
      ];
    }).toList();

    return pw.Table.fromTextArray(
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

    final pw.ThemeData theme = pw.ThemeData.withFont(base: ttf, bold: boldTtf);
    final String formattedThang = DateFormat('MM/yyyy').format(DateFormat('yyyy-MM').parse(thang));

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
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20, color: PdfColors.teal800),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Tháng $formattedThang',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 13),
                ),
              ),
              pw.SizedBox(height: 24),

              // Học sinh Info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Học sinh: ${hs.ten}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('Lớp: $tenLop', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                ],
              ),
              pw.Divider(height: 16, thickness: 1.5, color: PdfColors.teal),
              pw.SizedBox(height: 8),

              // Điểm chi tiết
              pw.Text('Kết Quả Học Tập Chi Tiết:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.teal900)),
              pw.SizedBox(height: 8),

              _buildEvaluationRow('Chuyên cần (Điểm danh)', nhanXet.diemChuyenCan, '/ 10.0'),
              _buildEvaluationRow('Thái độ học tập trên lớp', nhanXet.diemThaiDo, '/ 10.0'),
              _buildEvaluationRow('Hoàn thành bài tập về nhà', nhanXet.diemBaiTap, '/ 10.0'),
              _buildEvaluationRow('Hiểu bài & Điểm kiểm tra', nhanXet.diemKiemTra, '/ 10.0'),

              pw.SizedBox(height: 16),
              pw.Divider(height: 8),
              pw.SizedBox(height: 8),

              // Điểm trung bình & Xếp hạng
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ĐIỂM TRUNG BÌNH:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text(nhanXet.diemTrungBinh.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.teal)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('XẾP HẠNG THÁNG:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text(nhanXet.xepHang ?? 'Chưa xếp hạng', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.amber800)),
                ],
              ),

              pw.SizedBox(height: 24),

              // Nhận xét chung
              pw.Text('Nhận xét chung của giáo viên:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.teal900)),
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
                  nhanXet.nhanXetChung ?? 'Học sinh đi học đầy đủ, có thái độ học tập tích cực, chuẩn bị bài tốt.',
                  style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
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
                      pw.Text('Giáo viên chủ nhiệm', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.SizedBox(height: 36),
                      pw.Text('(Ký và ghi rõ họ tên)', style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text('Trân trọng gửi đến quý phụ huynh học sinh!', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

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
          pw.Text('${score.toStringAsFixed(1)} $suffix', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }
}
