// File: lib/models/hs.dart

class HS {
  int? id;
  String ten;
  String? sdt; // So dien thoai
  String? truongDangHoc; // Truong đang học
  String? diaChi;
  String? ghiChu;
  String? facebook; // Địa chỉ Facebook học sinh
  int? mienGiam;
  int soBuoiDu;
  String caHocTruong; // 'Sáng', 'Chiều', 'Cả ngày'
  String? lichCanMonKhac; // Ví dụ: "Văn T2 17:30-19:00, Anh T4 18:00-19:30"

  HS({
    this.id,
    required this.ten,
    this.sdt,
    this.truongDangHoc,
    this.diaChi,
    this.ghiChu,
    this.facebook,
    this.mienGiam,
    this.soBuoiDu = 0,
    this.caHocTruong = 'Sáng',
    this.lichCanMonKhac,
  });

  // Chuyển đối tượng HS sang Map (để lưu vào database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ten': ten,
      'sdt': sdt,
      'truong_dang_hoc': truongDangHoc,
      'dia_chi': diaChi,
      'ghi_chu': ghiChu,
      'facebook': facebook,
      'mien_giam': mienGiam,
      'so_buoi_du': soBuoiDu,
      'ca_hoc_truong': caHocTruong,
      'lich_can_mon_khac': lichCanMonKhac,
    };
  }

  // Tạo đối tượng HS từ Map (đọc từ database)
  factory HS.fromMap(Map<String, dynamic> map) {
    int? parseInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    return HS(
      id: parseInt(map['id']),
      ten: map['ten']?.toString() ?? '',
      sdt: map['sdt']?.toString(),
      truongDangHoc: map['truong_dang_hoc']?.toString(),
      diaChi: map['dia_chi']?.toString(),
      ghiChu: map['ghi_chu']?.toString(),
      facebook: map['facebook']?.toString(),
      mienGiam: parseInt(map['mien_giam']),
      soBuoiDu: parseInt(map['so_buoi_du']) ?? 0,
      caHocTruong: map['ca_hoc_truong']?.toString() ?? 'Sáng',
      lichCanMonKhac: map['lich_can_mon_khac']?.toString(),
    );
  }

  // Hàm copyWith để tạo ra một bản sao với các thuộc tính được cập nhật (ví dụ: gán ID sau khi insert)
  HS copyWith({
    int? id,
    int? soBuoiDu,
    String? caHocTruong,
    String? lichCanMonKhac,
    String? facebook,
  }) {
    return HS(
      id: id ?? this.id,
      ten: ten,
      sdt: sdt,
      truongDangHoc: truongDangHoc,
      diaChi: diaChi,
      ghiChu: ghiChu,
      facebook: facebook ?? this.facebook,
      mienGiam: mienGiam,
      soBuoiDu: soBuoiDu ?? this.soBuoiDu,
      caHocTruong: caHocTruong ?? this.caHocTruong,
      lichCanMonKhac: lichCanMonKhac ?? this.lichCanMonKhac,
    );
  }
}
