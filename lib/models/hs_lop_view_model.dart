// File: lib/models/hs_lop_view_model.dart

import 'hs.dart'; // Import Model HS

// Kết hợp thông tin HS với thông tin lớp học sinh
class HSLopViewModel extends HS {
  final String ngayThamGia;
  final String trangThai;

  HSLopViewModel({
    required HS hocSinh,
    required this.ngayThamGia,
    required this.trangThai,
  }) : super(
    id: hocSinh.id,
    ten: hocSinh.ten,
    sdt: hocSinh.sdt,
    truongDangHoc: hocSinh.truongDangHoc,
    diaChi: hocSinh.diaChi,
    ghiChu: hocSinh.ghiChu,
    mienGiam: hocSinh.mienGiam,
  );
}