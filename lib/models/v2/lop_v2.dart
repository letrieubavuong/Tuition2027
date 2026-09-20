// File: lib/models/v2/lop_v2.dart

class LopV2 {
  final int? id;
  final String tenLop;
  final int? khoi;
  final String? monHoc;
  final int? hocPhiMoiBuoi;
  final int soBuoiChuanThang;
  final int? hocPhiThangToiDa;
  final int? siSoToiDa;
  final String? ghiChu;
  final int daLuuTru;
  final DateTime createdAt;
  final DateTime updatedAt;

  LopV2({
    this.id,
    required this.tenLop,
    this.khoi,
    this.monHoc,
    this.hocPhiMoiBuoi,
    this.soBuoiChuanThang = 12,
    this.hocPhiThangToiDa,
    this.siSoToiDa,
    this.ghiChu,
    this.daLuuTru = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ten_lop': tenLop,
      'khoi': khoi,
      'mon_hoc': monHoc,
      'hoc_phi_moi_buoi': hocPhiMoiBuoi,
      'so_buoi_chuan_thang': soBuoiChuanThang,
      'hoc_phi_thang_toi_da': hocPhiThangToiDa,
      'si_so_toi_da': siSoToiDa,
      'ghi_chu': ghiChu,
      'da_luu_tru': daLuuTru,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory LopV2.fromMap(Map<String, dynamic> map) {
    return LopV2(
      id: map['id'] as int?,
      tenLop: map['ten_lop'] as String,
      khoi: map['khoi'] as int?,
      monHoc: map['mon_hoc'] as String?,
      hocPhiMoiBuoi: map['hoc_phi_moi_buoi'] as int?,
      soBuoiChuanThang: map['so_buoi_chuan_thang'] as int? ?? 12,
      hocPhiThangToiDa: map['hoc_phi_thang_toi_da'] as int?,
      siSoToiDa: map['si_so_toi_da'] as int?,
      ghiChu: map['ghi_chu'] as String?,
      daLuuTru: map['da_luu_tru'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
