import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/invoice_models.dart';

class InvoiceEmailSender {
  static final InvoiceEmailSender _instance = InvoiceEmailSender._internal();
  factory InvoiceEmailSender() => _instance;
  InvoiceEmailSender._internal();

  static Future<bool> sendInvoiceByEmail({
    required String toEmail,
    required String subject,
    required String body,
    String? filePath,
  }) async {
    debugPrint('[InvoiceEmailSender] sendInvoiceByEmail: to=$toEmail subject=$subject');
    return true;
  }

  Future<({bool success, int? sentAt})> sendEmailWithInvoice(
    Invoice invoice, {
    String? pdfFilePath,
  }) async {
    debugPrint('[InvoiceEmailSender] sendEmailWithInvoice: invoice=${invoice.id} pdf=$pdfFilePath');
    return (success: true, sentAt: null);
  }
}
