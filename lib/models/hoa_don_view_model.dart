// File: lib/models/hoa_don_view_model.dart

class HoaDonViewModel {
  // --- THÔNG SỐ BUỔI HỌC (Từ Điểm Danh) ---
  final int tongSoBuoiHoc; // Tổng số buổi lớp học đã diễn ra trong tháng
  final int soBuoiCoMat; // Số buổi có mặt
  final int soBuoiVangCoPhep; // Buổi vắng được miễn 100% học phí
  final int soBuoiVangKhongPhep; // Buổi vắng vẫn tính 100% học phí

  // --- THÔNG SỐ HỌC PHÍ (Từ Cài Đặt) ---
  final int hocPhiThangCoDinh; // Học phí tháng cố định (ví dụ: 600,000)
  final int hocPhiBuoi; // Học phí buổi (ví dụ: 50,000)

  // --- THÔNG SỐ TÍNH TOÁN VÀ THANH TOÁN ---
  // Số tiền phải nộp tính theo công thức buổi:
  // (Tổng Buổi Học - Buổi Vắng Có Phép) * Học Phí Buổi
  final int soTienCanNopTheoBuoi;

  // Số tiền đã đóng thực tế (Lấy từ record ThanhToan cũ, dùng khi recalculate)
  final int soTienDaDong;

  HoaDonViewModel({
    required this.tongSoBuoiHoc,
    required this.soBuoiVangCoPhep,
    required this.soBuoiVangKhongPhep,
    required this.soBuoiCoMat,
    required this.hocPhiThangCoDinh,
    required this.hocPhiBuoi,
    required this.soTienCanNopTheoBuoi,
    required this.soTienDaDong,
  });
}
