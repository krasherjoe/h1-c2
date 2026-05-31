import '../../../models/invoice_models.dart';

List<InvoiceItem> cloneItems(
  List<InvoiceItem> source, {
  bool resetIds = false,
}) {
  return source
      .map(
        (e) => InvoiceItem(
          id: resetIds ? null : e.id,
          productId: e.productId,
          description: e.description,
          quantity: e.quantity,
          unitPrice: e.unitPrice,
        ),
      )
      .toList(growable: true);
}
