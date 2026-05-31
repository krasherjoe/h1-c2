import '../../models/invoice_models.dart';

class InvoiceDetailSnapshot {
  final String formalName;
  final String notes;
  final List<InvoiceItem> items;
  final double taxRate;
  final bool includeTax;
  final bool isDraft;

  const InvoiceDetailSnapshot({
    required this.formalName,
    required this.notes,
    required this.items,
    required this.taxRate,
    required this.includeTax,
    required this.isDraft,
  });
}
