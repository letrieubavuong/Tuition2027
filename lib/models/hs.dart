// File: lib/models/hs.dart

class HS {
  int? id;
  String ten;
  String? sdt; // So dien thoai
  String? truongDangHoc; // Truong đang học
  String? diaChi;
  String? ghiChu;
  int? mienGiam;
  int soBuoiDu;

  HS({
    this.id,
    required this.ten,
    this.sdt,
    this.truongDangHoc,
    this.diaChi,
    this.ghiChu,
    this.mienGiam,
    this.soBuoiDu = 0,
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
      'mien_giam': mienGiam,
      'so_buoi_du': soBuoiDu,
    };
  }

  // Tạo đối tượng HS từ Map (đọc từ database)
  factory HS.fromMap(Map<String, dynamic> map) {
    return HS(
      id: map['id'] as int?,
      ten: map['ten'] as String,
      sdt: map['sdt'] as String?,
      truongDangHoc: map['truong_dang_hoc'] as String?,
      diaChi: map['dia_chi'] as String?,
      ghiChu: map['ghi_chu'] as String?,
      mienGiam: map['mien_giam'] as int?,
      soBuoiDu: map['so_buoi_du'] as int? ?? 0,
    );
  }

  // Hàm copyWith để tạo ra một bản sao với các thuộc tính được cập nhật (ví dụ: gán ID sau khi insert)
  HS copyWith({int? id, int? soBuoiDu}) {
    return HS(
      id: id ?? this.id,
      ten: ten,
      sdt: sdt,
      truongDangHoc: truongDangHoc,
      diaChi: diaChi,
      ghiChu: ghiChu,
      mienGiam: mienGiam,
      soBuoiDu: soBuoiDu ?? this.soBuoiDu,
    );
  }
}
