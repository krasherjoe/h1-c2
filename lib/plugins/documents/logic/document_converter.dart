import 'package:uuid/uuid.dart';
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

String _nextLabel(DocumentType current) {
  return switch (current) {
    DocumentType.estimation => '受注',
    DocumentType.order => '納品',
    DocumentType.delivery => '請求',
    DocumentType.invoice => '領収',
    DocumentType.receipt => '',
  };
}

String copyButtonLabel(DocumentType current) {
  final next = _nextLabel(current);
  return next.isNotEmpty ? 'コピーして${next}を作成' : '';
}

DocumentModel copyAsNextDocument(DocumentModel source) {
  final next = nextDocumentType(source.documentType);
  if (next == null) throw ArgumentError('これ以上作成できません: ${source.documentType.label}');

  return DocumentModel(
    id: const Uuid().v4(),
    documentType: next,
    customerId: source.customerId,
    customerName: source.customerName,
    documentNumber: '',
    date: DateTime.now(),
    total: source.total,
    status: 'draft',
    linkedDocumentId: source.id,
    includeTax: source.includeTax,
    taxRate: source.taxRate,
    totalDiscountAmount: source.totalDiscountAmount,
    totalDiscountRate: source.totalDiscountRate,
    priceAdjustmentType: source.priceAdjustmentType,
    priceAdjustmentUnit: source.priceAdjustmentUnit,
    items: source.items.map((item) => DocumentItem(
      id: const Uuid().v4(),
      productId: item.productId,
      productName: item.productName,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxRate: item.taxRate,
      discountAmount: item.discountAmount,
      discountRate: item.discountRate,
      variantLabel: item.variantLabel,
    )).toList(),
  );
}
