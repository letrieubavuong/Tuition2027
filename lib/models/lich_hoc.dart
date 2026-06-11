// File: lib/models/lich_hoc.dart

class LichHoc {
  final int? id;
  final int idLop;
  final int thuTrongTuan; // 2=Thứ Hai, 3=Thứ Ba, ..., 7=Thứ Bảy, 1=Chủ Nhật
  final String gioBatDau; // Định dạng "HH:mm:ss"
  final String gioKetThuc; // Định dạng "HH:mm:ss"

  // Số học sinh đã được gán lịch (không bắt buộc, do service set khi load)
  final int? assignedCount;

  // Convenience: true nếu chưa có học sinh nào được gán lịch
  bool get chuaDuocGan => (assignedCount == null || assignedCount == 0);

  LichHoc({
    this.id,
    required this.idLop,
    required this.thuTrongTuan,
    required this.gioBatDau,
    required this.gioKetThuc,
    this.assignedCount,
  });

  // Helper parse int (hỗ trợ int hoặc string)
  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      // Chỉ xuất 'id_lop' để khớp schema SQLite
      'id_lop': idLop,
      'thuTrongTuan': thuTrongTuan,
      'gioBatDau': gioBatDau,
      'gioKetThuc': gioKetThuc,
      'assigned_count': assignedCount,
    };
  }

  factory LichHoc.fromMap(Map<String, dynamic> map) {
    return LichHoc(
      id: _parseInt(map['id']),
      // chấp nhận cả 'id_lop' hoặc 'lopId' khi đọc
      idLop: (_parseInt(map['id_lop']) ?? _parseInt(map['lopId'])) ?? 0,
      thuTrongTuan: (_parseInt(map['thuTrongTuan']) ?? 0),
      gioBatDau: (map['gioBatDau'] ?? '') as String,
      gioKetThuc: (map['gioKetThuc'] ?? '') as String,
      assignedCount: _parseInt(
        map['assigned_count'] ?? map['assignedCount'] ?? map['so_luong_da_gan'],
      ),
    );
  }

  LichHoc copyWith({
    int? id,
    int? idLop,
    int? thuTrongTuan,
    String? gioBatDau,
    String? gioKetThuc,
    int? assignedCount,
  }) {
    return LichHoc(
      id: id ?? this.id,
      idLop: idLop ?? this.idLop,
      thuTrongTuan: thuTrongTuan ?? this.thuTrongTuan,
      gioBatDau: gioBatDau ?? this.gioBatDau,
      gioKetThuc: gioKetThuc ?? this.gioKetThuc,
      assignedCount: assignedCount ?? this.assignedCount,
    );
  }
}
