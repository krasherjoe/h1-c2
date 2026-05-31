import '../../../models/customer_model.dart';
import '../../../models/invoice_models.dart';
import '../invoice_snapshot.dart';
import '../models/invoice_section_data.dart';

String calcStateKey({
  required Customer? customer,
  required DateTime? selectedDate,
  required bool includeTax,
  required double taxRate,
  required DocumentType documentType,
  required bool isDraft,
  required List<InvoiceItem> items,
}) {
  final buf = StringBuffer()
    ..write(customer?.id ?? '')
    ..write('|${selectedDate?.toIso8601String() ?? ''}|$includeTax|$taxRate|${documentType.index}|$isDraft');
  for (final item in items) {
    buf.write('|${item.productId}:${item.description}:${item.quantity}:${item.unitPrice}:${item.discountAmount}:${item.discountRate}');
  }
  return buf.toString();
}

InvoiceSnapshot buildSnapshot({
  required Customer? customer,
  required List<InvoiceItem> items,
  required double taxRate,
  required bool includeTax,
  required bool isTaxInclusiveMode,
  required DocumentType documentType,
  required DateTime date,
  required bool isDraft,
  required String subject,
}) {
  return InvoiceSnapshot(
    customer: customer,
    items: cloneItems(items),
    taxRate: taxRate,
    includeTax: includeTax,
    isTaxInclusiveMode: isTaxInclusiveMode,
    documentType: documentType,
    date: date,
    isDraft: isDraft,
    subject: subject,
  );
}

String documentTypeLabel(DocumentType type) {
  switch (type) {
    case DocumentType.estimation:
      return "見積書";
    case DocumentType.order:
      return "受注伝票";
    case DocumentType.delivery:
      return "納品書";
    case DocumentType.invoice:
      return "請求書";
    case DocumentType.receipt:
      return "領収書";
  }
}
