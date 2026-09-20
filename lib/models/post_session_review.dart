// File: lib/models/post_session_review.dart

class StudentReviewData {
  final int studentId;
  final String studentName;
  final String? phone;
  final String
  attendanceStatus; // 'Có mặt', 'Trễ', 'Nghỉ có phép', 'Nghỉ không phép', 'Học bù'
  String
  thaiDo; // 'Tốt', 'Khá', 'Cần nhắc', 'Mất tập trung', 'Nói chuyện', 'Tích cực'
  String baiCu; // 'Đã chuẩn bị', 'Chưa tốt', 'Không chuẩn bị', 'Chưa thuộc'
  String baiTap; // 'Đầy đủ', 'Thiếu', 'Không làm'
  String tiepThu; // 'Tốt', 'Khá', 'Cần củng cố'
  bool canPhPhoiHop;
  String? customNote;

  StudentReviewData({
    required this.studentId,
    required this.studentName,
    this.phone,
    required this.attendanceStatus,
    this.thaiDo = 'Tốt',
    this.baiCu = 'Đã chuẩn bị',
    this.baiTap = 'Đầy đủ',
    this.tiepThu = 'Tốt',
    this.canPhPhoiHop = false,
    this.customNote,
  });

  bool get isAbsent =>
      attendanceStatus == 'Nghỉ có phép' ||
      attendanceStatus == 'Nghỉ không phép';

  bool get isUnexcusedAbsent => attendanceStatus == 'Nghỉ không phép';

  bool get isExcusedAbsent => attendanceStatus == 'Nghỉ có phép';

  /// Lọc thông minh: Học sinh có dấu hiệu cần lưu ý / thông báo phụ huynh
  bool get isAttentionNeeded {
    if (isUnexcusedAbsent) return true;
    if (isExcusedAbsent) return false;
    if (canPhPhoiHop) return true;

    if (baiTap == 'Thiếu' || baiTap == 'Không làm') return true;
    if (baiCu == 'Chưa tốt' ||
        baiCu == 'Không chuẩn bị' ||
        baiCu == 'Chưa thuộc')
      return true;
    if (thaiDo == 'Cần nhắc' ||
        thaiDo == 'Mất tập trung' ||
        thaiDo == 'Nói chuyện')
      return true;
    if (tiepThu == 'Cần củng cố') return true;

    return false;
  }

  /// Lý do gợi ý cần liên hệ phụ huynh
  String get attentionReason {
    if (isUnexcusedAbsent) return 'Nghỉ không phép';
    if (canPhPhoiHop) return 'Giáo viên đánh dấu Cần PH phối hợp';

    final List<String> reasons = [];
    if (baiTap == 'Không làm') {
      reasons.add('Không làm BTVN');
    } else if (baiTap == 'Thiếu') {
      reasons.add('Thiếu BTVN');
    }

    if (baiCu == 'Chưa thuộc' || baiCu == 'Không chuẩn bị') {
      reasons.add('Chưa học bài cũ');
    }

    if (thaiDo == 'Mất tập trung') {
      reasons.add('Mất tập trung trong giờ');
    } else if (thaiDo == 'Nói chuyện') {
      reasons.add('Nói chuyện trong giờ');
    } else if (thaiDo == 'Cần nhắc') {
      reasons.add('Thái độ cần nhắc nhở');
    }

    if (tiepThu == 'Cần củng cố') {
      reasons.add('Tiếp thu bài cần củng cố');
    }

    return reasons.isNotEmpty
        ? reasons.join(', ')
        : 'Cần thông báo tình hình học';
  }

  StudentReviewData copyWith({
    int? studentId,
    String? studentName,
    String? phone,
    String? attendanceStatus,
    String? thaiDo,
    String? baiCu,
    String? baiTap,
    String? tiepThu,
    bool? canPhPhoiHop,
    String? customNote,
  }) {
    return StudentReviewData(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      phone: phone ?? this.phone,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      thaiDo: thaiDo ?? this.thaiDo,
      baiCu: baiCu ?? this.baiCu,
      baiTap: baiTap ?? this.baiTap,
      tiepThu: tiepThu ?? this.tiepThu,
      canPhPhoiHop: canPhPhoiHop ?? this.canPhPhoiHop,
      customNote: customNote ?? this.customNote,
    );
  }
}

class ParentCommunicationRecord {
  final int? id;
  final int studentId;
  final String studentName;
  final int classId;
  final String className;
  final String sessionDate; // YYYY-MM-DD
  final String sessionTime; // HH:mm
  final String? parentPhone;
  final String reason;
  final String messageType; // 'POST_SESSION_REVIEW', 'ABSENT_ALERT'
  String messageContent;
  String status; // 'DRAFT', 'READY', 'SENT_MANUALLY_CONFIRMED', 'SKIPPED'
  final String createdAt;

  ParentCommunicationRecord({
    this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.className,
    required this.sessionDate,
    required this.sessionTime,
    this.parentPhone,
    required this.reason,
    this.messageType = 'POST_SESSION_REVIEW',
    required this.messageContent,
    this.status = 'READY',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_hoc_sinh': studentId,
      'ten_hoc_sinh': studentName,
      'id_lop': classId,
      'ten_lop': className,
      'ngay_hoc': sessionDate,
      'gio_hoc': sessionTime,
      'sdt_phu_huynh': parentPhone,
      'ly_do': reason,
      'loai_tin_nhan': messageType,
      'noi_dung': messageContent,
      'trang_thai': status,
      'created_at': createdAt,
    };
  }

  factory ParentCommunicationRecord.fromMap(Map<String, dynamic> map) {
    return ParentCommunicationRecord(
      id: map['id'] as int?,
      studentId: map['id_hoc_sinh'] as int,
      studentName: map['ten_hoc_sinh'] as String? ?? 'Học sinh',
      classId: map['id_lop'] as int,
      className: map['ten_lop'] as String? ?? 'Lớp học',
      sessionDate: map['ngay_hoc'] as String,
      sessionTime: map['gio_hoc'] as String,
      parentPhone: map['sdt_phu_huynh'] as String?,
      reason: map['ly_do'] as String? ?? '',
      messageType: map['loai_tin_nhan'] as String? ?? 'POST_SESSION_REVIEW',
      messageContent: map['noi_dung'] as String,
      status: map['trang_thai'] as String? ?? 'READY',
      createdAt: map['created_at'] as String,
    );
  }

  ParentCommunicationRecord copyWith({
    int? id,
    int? studentId,
    String? studentName,
    int? classId,
    String? className,
    String? sessionDate,
    String? sessionTime,
    String? parentPhone,
    String? reason,
    String? messageType,
    String? messageContent,
    String? status,
    String? createdAt,
  }) {
    return ParentCommunicationRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      classId: classId ?? this.classId,
      className: className ?? this.className,
      sessionDate: sessionDate ?? this.sessionDate,
      sessionTime: sessionTime ?? this.sessionTime,
      parentPhone: parentPhone ?? this.parentPhone,
      reason: reason ?? this.reason,
      messageType: messageType ?? this.messageType,
      messageContent: messageContent ?? this.messageContent,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
