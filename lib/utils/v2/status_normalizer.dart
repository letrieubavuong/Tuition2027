// File: lib/utils/v2/status_normalizer.dart

class StatusNormalizer {
  static String normalizeAttendance(String? status) {
    if (status == null) return 'CHUA_DIEM_DANH';
    final s = status.trim();
    
    // Legacy Vietnamese mapping
    if (s == 'Có mặt') return 'CO_MAT';
    if (s == 'Trễ' || s == 'Muộn') return 'TRE';
    if (s == 'Nghỉ có phép' || s == 'Vắng có phép') return 'NGHI_CO_PHEP';
    if (s == 'Nghỉ không phép' || s == 'Vắng không phép') return 'NGHI_KHONG_PHEP';
    if (s == 'Học bù') return 'HOC_BU';
    
    // Canonical V2 values
    final upper = s.toUpperCase();
    if (['CO_MAT', 'TRE', 'NGHI_CO_PHEP', 'NGHI_KHONG_PHEP', 'HOC_BU'].contains(upper)) {
      return upper;
    }
    
    return 'UNKNOWN';
  }

  static String normalizeSessionStatus(String? status) {
    if (status == null) return 'DU_KIEN';
    final upper = status.trim().toUpperCase();
    if (['DU_KIEN', 'DA_HOC', 'HUY', 'NGHI_LE'].contains(upper)) {
      return upper;
    }
    return 'DU_KIEN';
  }

  static String normalizeSessionType(String? type) {
    if (type == null) return 'CHINH';
    final upper = type.trim().toUpperCase();
    if (['CHINH', 'HOC_BU', 'PHAT_SINH'].contains(upper)) {
      return upper;
    }
    return 'CHINH';
  }
}
