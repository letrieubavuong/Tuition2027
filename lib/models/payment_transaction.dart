// File: lib/models/payment_transaction.dart

class PaymentTransaction {
  final int? id;
  final int hocSinhId;
  final int lopId;
  final String month;
  final int amount;
  final String status; // pending, success, failed
  final String? transactionId;
  final String createdAt;
  final String? updatedAt;

  PaymentTransaction({
    this.id,
    required this.hocSinhId,
    required this.lopId,
    required this.month,
    required this.amount,
    required this.status,
    this.transactionId,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hoc_sinh_id': hocSinhId,
      'lop_id': lopId,
      'month': month,
      'amount': amount,
      'status': status,
      'transaction_id': transactionId,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) {
    return PaymentTransaction(
      id: map['id'] as int?,
      hocSinhId: map['hoc_sinh_id'] as int,
      lopId: map['lop_id'] as int,
      month: map['month'] as String,
      amount: map['amount'] as int,
      status: map['status'] as String,
      transactionId: map['transaction_id'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String?,
    );
  }
}
