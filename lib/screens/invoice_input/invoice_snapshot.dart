import '../../models/customer_model.dart';
import '../../models/invoice_models.dart';

class InvoiceSnapshot {
  final Customer? customer;
  final List<InvoiceItem> items;
  final double taxRate;
  final bool includeTax;
  final bool isTaxInclusiveMode;
  final DocumentType documentType;
  final DateTime date;
  final bool isDraft;
  final String subject;

  InvoiceSnapshot({
    required this.customer,
    required this.items,
    required this.taxRate,
    required this.includeTax,
    required this.isTaxInclusiveMode,
    required this.documentType,
    required this.date,
    required this.isDraft,
    required this.subject,
  });
}
