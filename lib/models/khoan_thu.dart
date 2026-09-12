class KhoanThu {
  final int id;
  final int idLop;
  final String thang;
  final String ten;
  final int soTien;
  final String? hanThu;
  final String? ghiChu;
  final List<KhoanThuHocSinh> hocSinhs;

  const KhoanThu({
    required this.id,
    required this.idLop,
    required this.thang,
    required this.ten,
    required this.soTien,
    this.hanThu,
    this.ghiChu,
    this.hocSinhs = const [],
  });

  int get tongPhaiThu => soTien * hocSinhs.length;
  int get tongDaThu => hocSinhs.fold(0, (sum, item) => sum + item.daDong);
  int get tongConNo => tongPhaiThu - tongDaThu;
}

class KhoanThuHocSinh {
  final int idHocSinh;
  final String tenHocSinh;
  final String? sdt;
  final int daDong;
  final String? ngayThanhToan;

  const KhoanThuHocSinh({
    required this.idHocSinh,
    required this.tenHocSinh,
    required this.daDong,
    this.sdt,
    this.ngayThanhToan,
  });
}
