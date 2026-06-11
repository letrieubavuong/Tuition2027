// File: lib/models/lop.dart (Đã cập nhật)

class Lop {
  int? id;
  String ten;
  int khoi; // Thêm thuộc tính khối (ví dụ: 6, 7, 8, ... 12)
  final int? siSo; // SỬA: Thêm sĩ số

  Lop({
    this.id,
    required this.ten,
    required this.khoi,
    this.siSo,
  }); // Yêu cầu khối khi tạo

  // Chuyển đối tượng Lop sang Map (để lưu vào database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ten': ten,
      'khoi': khoi, // Thêm khối
      // 'siSo' không cần thiết trong toMap vì nó là dữ liệu đọc ra
    };
  }

  // Tạo đối tượng Lop từ Map (đọc từ database)
  factory Lop.fromMap(Map<String, dynamic> map) {
    return Lop(
      id: map['id'] as int?,
      ten: map['ten'] as String,
      // Đảm bảo ép kiểu sang int
      khoi: map['khoi'] as int, // SỬA: Thêm sĩ số từ map
      siSo: map['si_so'] as int?,
    );
  }

  // Hàm copyWith
  Lop copyWith({int? id, String? ten, int? khoi, int? siSo}) {
    return Lop(
      id: id ?? this.id,
      ten: ten ?? this.ten,
      khoi: khoi ?? this.khoi,
      siSo: siSo ?? this.siSo,
    );
  }
}
