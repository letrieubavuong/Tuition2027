// File: lib/models/exam_result_contract.dart

/// Contract model đại diện cho kết quả kiểm tra/thi từ Hệ thống Thi độc lập trong tương lai.
/// Nối với hệ thống hiện tại thông qua canonical `studentId` (INTEGER).
class ExamResultContract {
  final int studentId;
  final String examId;
  final String examTitle;
  final String subject;
  final double score;
  final double maxScore;
  final DateTime submittedAt;
  final String? note;

  const ExamResultContract({
    required this.studentId,
    required this.examId,
    required this.examTitle,
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.submittedAt,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'exam_id': examId,
      'exam_title': examTitle,
      'subject': subject,
      'score': score,
      'max_score': maxScore,
      'submitted_at': submittedAt.toIso8601String(),
      'note': note,
    };
  }

  factory ExamResultContract.fromMap(Map<String, dynamic> map) {
    return ExamResultContract(
      studentId: (map['student_id'] is num)
          ? (map['student_id'] as num).toInt()
          : int.parse(map['student_id'].toString()),
      examId: (map['exam_id'] ?? '').toString(),
      examTitle: (map['exam_title'] ?? '').toString(),
      subject: (map['subject'] ?? '').toString(),
      score: (map['score'] is num) ? (map['score'] as num).toDouble() : 0.0,
      maxScore: (map['max_score'] is num)
          ? (map['max_score'] as num).toDouble()
          : 10.0,
      submittedAt: map['submitted_at'] != null
          ? DateTime.parse(map['submitted_at'].toString())
          : DateTime.now(),
      note: map['note'] as String?,
    );
  }
}
