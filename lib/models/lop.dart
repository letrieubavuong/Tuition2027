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
    int? parseInt(dynamic v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));
    return Lop(
      id: parseInt(map['id']),
      ten: map['ten']?.toString() ?? '',
      khoi: parseInt(map['khoi']) ?? 0,
      siSo: parseInt(map['si_so']),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lop && runtimeType == other.runtimeType && id == other.id);

  @override
  int get hashCode => id.hashCode;
}

