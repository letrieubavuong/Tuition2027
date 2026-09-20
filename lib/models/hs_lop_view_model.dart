// File: lib/models/hs_lop_view_model.dart

import 'hs.dart'; // Import Model HS

// Kết hợp thông tin HS với thông tin lớp học sinh
class HSLopViewModel extends HS {
  final String ngayThamGia;
  final String trangThai;
  final String? ngayTamNgung;
  final String? ngayDuKienHocLai;
  final String? ngayHocLaiThucTe;
  final String? lyDoTamNgung;
  final String? ngayNghiHoc;
  final String? lyDoNghiHoc;
  final String? ngayHocLaiSauNghi;

  HSLopViewModel({
    required HS hocSinh,
    required this.ngayThamGia,
    required this.trangThai,
    this.ngayTamNgung,
    this.ngayDuKienHocLai,
    this.ngayHocLaiThucTe,
    this.lyDoTamNgung,
    this.ngayNghiHoc,
    this.lyDoNghiHoc,
    this.ngayHocLaiSauNghi,
  }) : super(
         id: hocSinh.id,
         ten: hocSinh.ten,
         sdt: hocSinh.sdt,
         tenPhuHuynh: hocSinh.tenPhuHuynh,
         sdtPhuHuynh: hocSinh.sdtPhuHuynh,
         sdtHocSinh: hocSinh.sdtHocSinh,
         truongDangHoc: hocSinh.truongDangHoc,
         diaChi: hocSinh.diaChi,
         ghiChu: hocSinh.ghiChu,
         facebook: hocSinh.facebook,
         mienGiam: hocSinh.mienGiam,
         soBuoiDu: hocSinh.soBuoiDu,
         caHocTruong: hocSinh.caHocTruong,
         lichCanMonKhac: hocSinh.lichCanMonKhac,
         zaloDisplayName: hocSinh.zaloDisplayName,
         zaloPhone: hocSinh.zaloPhone,
         zaloProfileLink: hocSinh.zaloProfileLink,
         zaloNote: hocSinh.zaloNote,
         zaloLinkStatus: hocSinh.zaloLinkStatus,
       );
}
