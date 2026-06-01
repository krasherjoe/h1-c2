import '../models/document_model.dart';

DocumentType? nextDocumentType(DocumentType current) {
  return switch (current) {
    DocumentType.estimation => DocumentType.order,
    DocumentType.order => DocumentType.delivery,
    DocumentType.delivery => DocumentType.invoice,
    DocumentType.invoice => DocumentType.receipt,
    DocumentType.receipt => null,
  };
}

DocumentModel convertDocument(DocumentModel source) {
  final next = nextDocumentType(source.documentType);
  if (next == null) throw ArgumentError('これ以上変換できません: ${source.documentType.label}');

  return DocumentModel(
    id: source.id,
    documentType: next,
    customerId: source.customerId,
    customerName: source.customerName,
    documentNumber: source.documentNumber,
    date: DateTime.now(),
    total: source.total,
    status: 'draft',
    linkedDocumentId: source.id,
    items: source.items.map((item) => DocumentItem(
      id: _IdGenerator().v4(),
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxRate: item.taxRate,
    )).toList(),
  );
}

class _IdGenerator {
  int _counter = 0;
  String v4() => 'conv_${DateTime.now().millisecondsSinceEpoch}_${_counter++}';
}
