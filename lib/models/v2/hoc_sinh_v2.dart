// File: lib/models/v2/hoc_sinh_v2.dart

import '../../utils/v2/db_value_parser.dart';

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

  String get ten => hoTen;
  String? get sdt => sdtPhuHuynh;

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
      id: DbValueParser.parseInt(map['id']),
      hoTen: DbValueParser.parseString(map['ho_ten']) ?? 'Không tên',
      tenPhuHuynh: DbValueParser.parseString(map['ten_phu_huynh']),
      sdtPhuHuynh: DbValueParser.parseString(map['sdt_phu_huynh']),
      sdtHocSinh: DbValueParser.parseString(map['sdt_hoc_sinh']),
      ngaySinh: DbValueParser.parseString(map['ngay_sinh']),
      gioiTinh: DbValueParser.parseString(map['gioi_tinh']),
      truongDangHoc: DbValueParser.parseString(map['truong_dang_hoc']),
      khoi: DbValueParser.parseInt(map['khoi']),
      diaChi: DbValueParser.parseString(map['dia_chi']),
      email: DbValueParser.parseString(map['email']),
      facebook: DbValueParser.parseString(map['facebook']),
      ghiChu: DbValueParser.parseString(map['ghi_chu']),
      zaloUserId: DbValueParser.parseString(map['zalo_user_id']),
      zaloDisplayName: DbValueParser.parseString(map['zalo_display_name']),
      zaloLinkStatus: DbValueParser.parseString(map['zalo_link_status']) ?? 'UNLINKED',
      daLuuTru: DbValueParser.parseInt(map['da_luu_tru']) ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
