// File: lib/models/hs.dart

class HS {
  int? id;
  String ten;
  String? sdt; // Legacy SĐT field (dùng làm fallback cho SĐT Phụ Huynh)
  String? tenPhuHuynh;
  String? sdtPhuHuynh;
  String? sdtHocSinh;
  String? truongDangHoc; // Truong đang học
  String? diaChi;
  String? ghiChu;
  String? facebook; // Địa chỉ Facebook học sinh
  int? mienGiam;
  int soBuoiDu;
  String caHocTruong; // 'Sáng', 'Chiều', 'Cả ngày'
  String? lichCanMonKhac; // Ví dụ: "Văn T2 17:30-19:00, Anh T4 18:00-19:30"
  String? zaloDisplayName;
  String? zaloPhone;
  String? zaloProfileLink;
  String? zaloNote;
  String
  zaloLinkStatus; // UNLINKED, PHONE_AVAILABLE, MANUAL_NAME, PROFILE_LINKED, VERIFIED

  HS({
    this.id,
    required this.ten,
    this.sdt,
    this.tenPhuHuynh,
    this.sdtPhuHuynh,
    this.sdtHocSinh,
    this.truongDangHoc,
    this.diaChi,
    this.ghiChu,
    this.facebook,
    this.mienGiam,
    this.soBuoiDu = 0,
    this.caHocTruong = 'Sáng',
    this.lichCanMonKhac,
    this.zaloDisplayName,
    this.zaloPhone,
    this.zaloProfileLink,
    this.zaloNote,
    this.zaloLinkStatus = 'UNLINKED',
  });

  /// Lấy SĐT Phụ huynh ưu tiên: sdtPhuHuynh > zaloPhone > sdt (fallback)
  String? get effectiveParentPhone {
    if (sdtPhuHuynh != null && sdtPhuHuynh!.trim().isNotEmpty) {
      return sdtPhuHuynh!.trim();
    }
    if (zaloPhone != null && zaloPhone!.trim().isNotEmpty) {
      return zaloPhone!.trim();
    }
    if (sdt != null && sdt!.trim().isNotEmpty) {
      return sdt!.trim();
    }
    return null;
  }

  /// Tính toán trạng thái liên kết Zalo dựa trên dữ liệu hiện có nếu chưa VERIFIED
  String get effectiveZaloStatus {
    if (zaloLinkStatus == 'VERIFIED') return 'VERIFIED';
    if (zaloProfileLink != null && zaloProfileLink!.trim().isNotEmpty) {
      return 'PROFILE_LINKED';
    }
    if ((zaloDisplayName != null && zaloDisplayName!.trim().isNotEmpty) ||
        (zaloNote != null && zaloNote!.trim().isNotEmpty)) {
      return 'MANUAL_NAME';
    }
    if (effectiveParentPhone != null && effectiveParentPhone!.isNotEmpty) {
      return 'PHONE_AVAILABLE';
    }
    return 'UNLINKED';
  }

  // Chuyển đối tượng HS sang Map (để lưu vào database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ten': ten,
      'sdt': sdt ?? sdtPhuHuynh,
      'ten_phu_huynh': tenPhuHuynh,
      'sdt_phu_huynh': sdtPhuHuynh ?? sdt,
      'sdt_hoc_sinh': sdtHocSinh,
      'truong_dang_hoc': truongDangHoc,
      'dia_chi': diaChi,
      'ghi_chu': ghiChu,
      'facebook': facebook,
      'mien_giam': mienGiam ?? 0,
      'so_buoi_du': soBuoiDu,
      'ca_hoc_truong': caHocTruong,
      'lich_can_mon_khac': lichCanMonKhac,
      'zalo_display_name': zaloDisplayName,
      'zalo_phone': zaloPhone,
      'zalo_profile_link': zaloProfileLink,
      'zalo_note': zaloNote,
      'zalo_link_status': zaloLinkStatus,
    };
  }

  // Tạo đối tượng HS từ Map (đọc từ database)
  factory HS.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic v) =>
        v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    return HS(
      id: parseInt(map['id']),
      ten: map['ten']?.toString() ?? '',
      sdt: map['sdt']?.toString() ?? map['sdt_phu_huynh']?.toString(),
      tenPhuHuynh: map['ten_phu_huynh']?.toString(),
      sdtPhuHuynh: map['sdt_phu_huynh']?.toString() ?? map['sdt']?.toString(),
      sdtHocSinh: map['sdt_hoc_sinh']?.toString(),
      truongDangHoc: map['truong_dang_hoc']?.toString(),
      diaChi: map['dia_chi']?.toString(),
      ghiChu: map['ghi_chu']?.toString(),
      facebook: map['facebook']?.toString(),
      mienGiam: parseInt(map['mien_giam']),
      soBuoiDu: parseInt(map['so_buoi_du']) ?? 0,
      caHocTruong: map['ca_hoc_truong']?.toString() ?? 'Sáng',
      lichCanMonKhac: map['lich_can_mon_khac']?.toString(),
      zaloDisplayName: map['zalo_display_name']?.toString(),
      zaloPhone: map['zalo_phone']?.toString(),
      zaloProfileLink: map['zalo_profile_link']?.toString(),
      zaloNote: map['zalo_note']?.toString(),
      zaloLinkStatus: map['zalo_link_status']?.toString() ?? 'UNLINKED',
    );
  }

  // Hàm copyWith để tạo ra một bản sao với các thuộc tính được cập nhật
  HS copyWith({
    int? id,
    String? ten,
    String? sdt,
    String? tenPhuHuynh,
    String? sdtPhuHuynh,
    String? sdtHocSinh,
    String? truongDangHoc,
    String? diaChi,
    String? ghiChu,
    String? facebook,
    int? mienGiam,
    int? soBuoiDu,
    String? caHocTruong,
    String? lichCanMonKhac,
    String? zaloDisplayName,
    String? zaloPhone,
    String? zaloProfileLink,
    String? zaloNote,
    String? zaloLinkStatus,
  }) {
    return HS(
      id: id ?? this.id,
      ten: ten ?? this.ten,
      sdt: sdt ?? this.sdt,
      tenPhuHuynh: tenPhuHuynh ?? this.tenPhuHuynh,
      sdtPhuHuynh: sdtPhuHuynh ?? this.sdtPhuHuynh,
      sdtHocSinh: sdtHocSinh ?? this.sdtHocSinh,
      truongDangHoc: truongDangHoc ?? this.truongDangHoc,
      diaChi: diaChi ?? this.diaChi,
      ghiChu: ghiChu ?? this.ghiChu,
      facebook: facebook ?? this.facebook,
      mienGiam: mienGiam ?? this.mienGiam,
      soBuoiDu: soBuoiDu ?? this.soBuoiDu,
      caHocTruong: caHocTruong ?? this.caHocTruong,
      lichCanMonKhac: lichCanMonKhac ?? this.lichCanMonKhac,
      zaloDisplayName: zaloDisplayName ?? this.zaloDisplayName,
      zaloPhone: zaloPhone ?? this.zaloPhone,
      zaloProfileLink: zaloProfileLink ?? this.zaloProfileLink,
      zaloNote: zaloNote ?? this.zaloNote,
      zaloLinkStatus: zaloLinkStatus ?? this.zaloLinkStatus,
    );
  }
}
