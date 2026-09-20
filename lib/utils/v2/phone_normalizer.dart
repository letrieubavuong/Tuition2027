// File: lib/utils/v2/phone_normalizer.dart

class PhoneNormalizer {
  /// Normalizes a phone number to a canonical Vietnamese format (e.g. 0905123456).
  static String? normalize(String? phone) {
    if (phone == null) return null;
    
    // Remove all non-numeric characters
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (digits.isEmpty) return null;

    // Handle +84 or 84 prefix
    if (digits.startsWith('84') && digits.length > 10) {
      digits = '0' + digits.substring(2);
    }
    
    // Vietnamese mobile numbers usually have 10 digits starting with 0
    if (digits.length == 9 && !digits.startsWith('0')) {
      digits = '0' + digits;
    }

    return digits;
  }

  /// Checks if two phone numbers represent the same canonical number.
  static bool isSame(String? p1, String? p2) {
    final n1 = normalize(p1);
    final n2 = normalize(p2);
    if (n1 == null || n2 == null) return false;
    return n1 == n2;
  }
}
