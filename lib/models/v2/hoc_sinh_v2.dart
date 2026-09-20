// File: lib/models/v2/hoc_sinh_v2.dart

class HocSinhV2 {
  final int? id;
  final String hoTen;
  final String? tenPhuHuynh;
  final String? sdtPhuHuynh;
  final String? sdtHocSinh;
  final String? ngaySinh;
  final String? gioiTinh;
  final String? truongDangHoc;
  final int? khoi;
  final String? diaChi;
  final String? email;
  final String? facebook;
  final String? ghiChu;
  final String? zaloUserId;
  final String? zaloDisplayName;
  final String zaloLinkStatus;
  final int daLuuTru;
  final DateTime createdAt;
  final DateTime updatedAt;

  HocSinhV2({
    this.id,
    required this.hoTen,
    this.tenPhuHuynh,
    this.sdtPhuHuynh,
    this.sdtHocSinh,
    this.ngaySinh,
    this.gioiTinh,
    this.truongDangHoc,
    this.khoi,
    this.diaChi,
    this.email,
    this.facebook,
    this.ghiChu,
    this.zaloUserId,
    this.zaloDisplayName,
    this.zaloLinkStatus = 'UNLINKED',
    this.daLuuTru = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ho_ten': hoTen,
      'ten_phu_huynh': tenPhuHuynh,
      'sdt_phu_huynh': sdtPhuHuynh,
      'sdt_hoc_sinh': sdtHocSinh,
      'ngay_sinh': ngaySinh,
      'gioi_tinh': gioiTinh,
      'truong_dang_hoc': truongDangHoc,
      'khoi': khoi,
      'dia_chi': diaChi,
      'email': email,
      'facebook': facebook,
      'ghi_chu': ghiChu,
      'zalo_user_id': zaloUserId,
      'zalo_display_name': zaloDisplayName,
      'zalo_link_status': zaloLinkStatus,
      'da_luu_tru': daLuuTru,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory HocSinhV2.fromMap(Map<String, dynamic> map) {
    return HocSinhV2(
      id: map['id'] as int?,
      hoTen: map['ho_ten'] as String,
      tenPhuHuynh: map['ten_phu_huynh'] as String?,
      sdtPhuHuynh: map['sdt_phu_huynh'] as String?,
      sdtHocSinh: map['sdt_hoc_sinh'] as String?,
      ngaySinh: map['ngay_sinh'] as String?,
      gioiTinh: map['gioi_tinh'] as String?,
      truongDangHoc: map['truong_dang_hoc'] as String?,
      khoi: map['khoi'] as int?,
      diaChi: map['dia_chi'] as String?,
      email: map['email'] as String?,
      facebook: map['facebook'] as String?,
      ghiChu: map['ghi_chu'] as String?,
      zaloUserId: map['zalo_user_id'] as String?,
      zaloDisplayName: map['zalo_display_name'] as String?,
      zaloLinkStatus: map['zalo_link_status'] as String? ?? 'UNLINKED',
      daLuuTru: map['da_luu_tru'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
