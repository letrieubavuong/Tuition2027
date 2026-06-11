// File: lib/services/payment_service.dart

import 'dart:async';
import 'package:flutter/material.dart';

/// A placeholder payment service for ZaloPay integration.
/// In a real implementation you would import the ZaloPay SDK and
/// call its APIs to create a payment request, handle callbacks, etc.
class PaymentService {
  final BuildContext context;

  PaymentService(this.context);

  /// Simulates a payment process.
  /// Returns true if payment succeeded, false otherwise.
  Future<bool> pay({
    required int amount,
    required String description,
    required String orderId,
  }) async {
    // Show a loading indicator while simulating payment.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Simulate network delay and payment processing.
    await Future.delayed(const Duration(seconds: 2));

    // Dismiss loading.
    Navigator.of(context).pop();

    // For demo purposes we always return success.
    // In production replace this with actual SDK callback handling.
    return true;
  }
}
