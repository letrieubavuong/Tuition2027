// File: lib/utils/vietqr_util.dart

class VietQRUtil {
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

  /// Lấy mã BIN từ tên viết tắt hoặc chuỗi nhập của ngân hàng
  static String getBankBin(String bankInput) {
    final cleanInput = bankInput.trim().toLowerCase();
    if (bankBinMap.containsKey(cleanInput)) {
      return bankBinMap[cleanInput]!;
    }
    // Nếu đã là 6 chữ số BIN thì giữ nguyên
    if (RegExp(r'^\d{6}$').hasMatch(cleanInput)) {
      return cleanInput;
    }
    return bankInput;
  }

  /// Tạo mã payload VietQR chuẩn EMVCo
  static String generateVietQRPayload({
    required String bankId,
    required String accountNo,
    required int amount,
    required String description,
  }) {
    // 00: Payload Format Indicator
    String payload = _formatTag('00', '01');
    // 01: Point of Initiation Method (12: Tĩnh - có số tiền)
    payload += _formatTag('01', '12');

    // 38: Merchant Account Information (VietQR)
    String merchantInfo = _formatTag('00', 'A000000727'); // GUID
    final String bin = getBankBin(bankId);
    String bankInfo = _formatTag('00', bin);
    bankInfo += _formatTag('01', accountNo);
    merchantInfo += _formatTag('01', bankInfo);
    merchantInfo += _formatTag('02', 'QRIBFTTA'); // Service Code: Napas 247 chuyển khoản đến tài khoản
    payload += _formatTag('38', merchantInfo);

    // 53: Transaction Currency (704: VND)
    payload += _formatTag('53', '704');
    // 54: Transaction Amount
    payload += _formatTag('54', amount.toString());
    // 58: Country Code (VN)
    payload += _formatTag('58', 'VN');
    // 62: Additional Data Field Template (Description)
    payload += _formatTag('62', _formatTag('08', description));

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
