import 'package:intl/intl.dart';

class VietQRUtil {
  /// Hàm bỏ dấu tiếng Việt chuẩn không bị mất chữ và loại bỏ ký tự đặc biệt không cần thiết
  static String removeVietnameseAccents(String str) {
    const accents =
        'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ'
        'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ';
    const withoutAccents =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyy'
        'dAAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
    String result = str;
    for (int i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], withoutAccents[i]);
    }
    return result
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Tạo nội dung thông báo học phí đồng bộ chuẩn cho Zalo/Messenger/SMS/QR
  static String taoNoiDungThongBaoHocPhi({
    int? studentId,
    required String tenHocSinh,
    required String tenLop,
    required String thang,
    required int soBuoiDu,
    int tongSoBuoi = 12,
    int? soBuoiCoMat,
    int? soBuoiNghiCoPhep,
    int? soBuoiNghiKhongPhep,
    required int soTienCanNop,
    required int soTienDaDong,
    required int soTienConNo,
    required String bankId,
    required String accountNo,
    required String accountName,
    bool isVi = true,
  }) {
    final formatCurrency = NumberFormat('#,##0', 'vi_VN');
    final StringBuffer buffer = StringBuffer();

    String formattedThang = thang;
    if (thang.contains('-')) {
      final parts = thang.split('-');
      if (parts.length == 2) {
        formattedThang = '${parts[1]}/${parts[0]}';
      }
    }

    final String studentNameNoAccent = removeVietnameseAccents(tenHocSinh);

    if (isVi) {
      buffer.writeln('Kính gửi phụ huynh học sinh $tenHocSinh (Lớp $tenLop),');
      buffer.writeln('Hệ thống gửi thông tin học phí tháng $formattedThang:');
      if (soBuoiCoMat != null) {
        buffer.writeln('- Số buổi có mặt: $soBuoiCoMat buổi');
      }
      if (soBuoiNghiCoPhep != null) {
        buffer.writeln('- Số buổi nghỉ có phép: $soBuoiNghiCoPhep buổi');
      }
      if (soBuoiNghiKhongPhep != null) {
        buffer.writeln('- Số buổi nghỉ không phép: $soBuoiNghiKhongPhep buổi');
      }
      buffer.writeln('- Số buổi dư tích lũy: $soBuoiDu buổi');
      buffer.writeln('- Số buổi dự kiến: $tongSoBuoi buổi');
      buffer.writeln('\nChi tiết học phí:');
      buffer.writeln('- Cần nộp: ${formatCurrency.format(soTienCanNop)}đ');
      buffer.writeln('- Đã đóng: ${formatCurrency.format(soTienDaDong)}đ');
      buffer.writeln('- Còn nợ: ${formatCurrency.format(soTienConNo)}đ');
      buffer.writeln('\nQuý phụ huynh vui lòng chuyển khoản thanh toán:');
      buffer.writeln('- Ngân hàng: ${bankId.toUpperCase()}');
      buffer.writeln('- Số tài khoản: $accountNo');
      buffer.writeln('- Chủ tài khoản: $accountName');
      final String refContent = (studentId != null && studentId > 0)
          ? taoNoiDungChuyenKhoanChuan(
              studentId: studentId,
              thang: thang,
              tenHocSinh: tenHocSinh,
            )
          : 'Hoc phi $studentNameNoAccent thang $formattedThang';

      buffer.writeln('- Nội dung CK: $refContent');
      buffer.writeln('\nXin chân thành cảm ơn quý phụ huynh!');
    } else {
      buffer.writeln('Dear parent of student $tenHocSinh (Class $tenLop),');
      buffer.writeln('Tuition summary for month $formattedThang:');
      if (soBuoiCoMat != null) {
        buffer.writeln('- Attended sessions: $soBuoiCoMat');
      }
      if (soBuoiNghiCoPhep != null) {
        buffer.writeln('- Excused absence sessions: $soBuoiNghiCoPhep');
      }
      if (soBuoiNghiKhongPhep != null) {
        buffer.writeln('- Unexcused absence sessions: $soBuoiNghiKhongPhep');
      }
      buffer.writeln('- Rollover excess sessions: $soBuoiDu');
      buffer.writeln('- Expected sessions: $tongSoBuoi');
      buffer.writeln('\nFee details:');
      buffer.writeln('- Amount due: ${formatCurrency.format(soTienCanNop)}đ');
      buffer.writeln('- Amount paid: ${formatCurrency.format(soTienDaDong)}đ');
      buffer.writeln(
        '- Remaining debt: ${formatCurrency.format(soTienConNo)}đ',
      );
      buffer.writeln('\nBank transfer details:');
      buffer.writeln('- Bank: ${bankId.toUpperCase()}');
      buffer.writeln('- Account Number: $accountNo');
      buffer.writeln('- Account Name: $accountName');
      final String refContent = (studentId != null && studentId > 0)
          ? taoNoiDungChuyenKhoanChuan(
              studentId: studentId,
              thang: thang,
              tenHocSinh: tenHocSinh,
            )
          : 'Hoc phi $studentNameNoAccent thang $formattedThang';
      buffer.writeln('- Reference: $refContent');
      buffer.writeln('\nThank you very much!');
    }

    return buffer.toString();
  }

  /// Tạo cú pháp nội dung chuyển khoản chuẩn máy quét: HP <STUDENT_ID> <YYYYMM> [TEN_HS]
  static String taoNoiDungChuyenKhoanChuan({
    required int studentId,
    required String thang,
    String? tenHocSinh,
  }) {
    String formattedMonth = thang;
    if (thang.contains('-')) {
      final parts = thang.split('-');
      if (parts.length == 2) {
        formattedMonth = '${parts[0]}${parts[1]}'; // 202609
      }
    } else if (thang.contains('/')) {
      final parts = thang.split('/');
      if (parts.length == 2) {
        formattedMonth = '${parts[1]}${parts[0]}'; // 202609
      }
    }
    final formattedId = studentId.toString().padLeft(6, '0');
    String ref = 'HP $formattedId $formattedMonth';
    if (tenHocSinh != null && tenHocSinh.trim().isNotEmpty) {
      ref += ' ${removeVietnameseAccents(tenHocSinh)}';
    }
    return ref;
  }

  /// Map of common Vietnamese banks to their 6-digit BIN codes
  static const Map<String, String> bankBinMap = {
    'sacombank': '970403',
    'vietcombank': '970436',
    'vcb': '970436',
    'acb': '970416',
    'bidv': '970418',
    'vietinbank': '970415',
    'ctg': '970415',
    'agribank': '970405',
    'mbbank': '970422',
    'mb': '970422',
    'techcombank': '970407',
    'tcb': '970407',
    'vpbank': '970432',
    'vpb': '970432',
    'tpbank': '970423',
    'tpb': '970423',
    'shb': '970443',
    'hdbank': '970437',
    'hdb': '970437',
    'scb': '970429',
    'vib': '970441',
    'msb': '970426',
    'seabank': '970440',
    'ocb': '970448',
    'eximbank': '970431',
    'lienvietpostbank': '970449',
    'lpbank': '970449',
    'lpb': '970449',
    'shinhan': '970424',
    'woori': '970457',
  };

  /// Lấy mã BIN từ tên viết tắt hoặc chuỗi nhập của ngân hàng.
  /// Fail-fast: Ném ArgumentError nếu không thể nhận diện được mã BIN hợp lệ.
  static String getBankBin(String bankInput) {
    final cleanInput = bankInput.trim().toLowerCase();
    if (cleanInput.isEmpty) {
      throw ArgumentError('Mã/tên ngân hàng không được để rỗng');
    }
    if (bankBinMap.containsKey(cleanInput)) {
      return bankBinMap[cleanInput]!;
    }
    // Nếu đã là 6 chữ số BIN thì giữ nguyên
    if (RegExp(r'^\d{6}$').hasMatch(cleanInput)) {
      return cleanInput;
    }
    throw ArgumentError(
      'Không thể nhận diện mã ngân hàng "$bankInput". Vui lòng kiểm tra lại tên ngân hàng hoặc nhập mã BIN 6 chữ số.',
    );
  }

  /// Tạo mã payload VietQR chuẩn EMVCo.
  /// Fail-fast: Validate toàn bộ dữ liệu trước khi sinh QR. Không bao giờ tạo QR với dữ liệu sai.
  static String generateVietQRPayload({
    required String bankId,
    required String accountNo,
    required int amount,
    required String description,
  }) {
    // 1. Validate & resolve bank BIN
    final String bin = getBankBin(bankId);
    if (!RegExp(r'^\d{6}$').hasMatch(bin)) {
      throw ArgumentError(
        'Mã BIN ngân hàng không hợp lệ (phải gồm 6 chữ số): $bin',
      );
    }

    // 2. Validate accountNo
    final String cleanAccountNo = accountNo.trim();
    if (cleanAccountNo.isEmpty) {
      throw ArgumentError('Số tài khoản không được để rỗng');
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cleanAccountNo)) {
      throw ArgumentError(
        'Số tài khoản chỉ được chứa chữ cái và chữ số: "$accountNo"',
      );
    }

    // 3. Validate amount (> 0)
    if (amount <= 0) {
      throw ArgumentError(
        'Số tiền thanh toán phải lớn hơn 0 (amount = $amount)',
      );
    }

    // 4. Validate description
    final String cleanDescription = description.trim();
    if (cleanDescription.isEmpty) {
      throw ArgumentError('Nội dung chuyển khoản không được để rỗng');
    }

    // 00: Payload Format Indicator
    String payload = _formatTag('00', '01');
    // 01: Point of Initiation Method (12: Tĩnh - có số tiền)
    payload += _formatTag('01', '12');

    // 38: Merchant Account Information (VietQR)
    String merchantInfo = _formatTag('00', 'A000000727'); // GUID
    String bankInfo = _formatTag('00', bin);
    bankInfo += _formatTag('01', cleanAccountNo);
    merchantInfo += _formatTag('01', bankInfo);
    merchantInfo += _formatTag(
      '02',
      'QRIBFTTA',
    ); // Service Code: Napas 247 chuyển khoản đến tài khoản
    payload += _formatTag('38', merchantInfo);

    // 53: Transaction Currency (704: VND)
    payload += _formatTag('53', '704');
    // 54: Transaction Amount
    payload += _formatTag('54', amount.toString());
    // 58: Country Code (VN)
    payload += _formatTag('58', 'VN');
    // 62: Additional Data Field Template (Description)
    payload += _formatTag('62', _formatTag('08', cleanDescription));

    // 63: CRC (Checksum)
    payload += '6304';
    payload += _calculateCRC(payload).toUpperCase();

    return payload;
  }

  static String _formatTag(String tag, String value) {
    return tag + value.length.toString().padLeft(2, '0') + value;
  }

  /// Tính Checksum CRC16-CCITT chuẩn VietQR
  static String _calculateCRC(String data) {
    int crc = 0xFFFF;
    List<int> bytes = data.codeUnits;

    for (int byte in bytes) {
      crc ^= (byte << 8) & 0xFFFF;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return (crc & 0xFFFF).toRadixString(16).padLeft(4, '0').toUpperCase();
  }
}
