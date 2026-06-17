// File: lib/utils/number_parser.dart

double parseDoubleSafely(dynamic value, {double defaultValue = 0.0}) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = value.replaceAll(',', '.').trim();
    return double.tryParse(normalized) ?? defaultValue;
  }
  return defaultValue;
}

double? parseDoubleOrNullSafely(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = value.replaceAll(',', '.').trim();
    return double.tryParse(normalized);
  }
  return null;
}
