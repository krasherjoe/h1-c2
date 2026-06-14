import 'package:uuid/uuid.dart';
import '../models/document_model.dart';

DocumentModel copyAsDocument(DocumentModel source, DocumentType targetType) {
  if (targetType == source.documentType) {
    throw ArgumentError('同じ伝票種別にはコピーできません');
  }

  return DocumentModel(
    id: const Uuid().v4(),
    documentType: targetType,
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
      maker: item.maker,
      productCode: item.productCode,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      taxRate: item.taxRate,
      discountAmount: item.discountAmount,
      discountRate: item.discountRate,
      variantLabel: item.variantLabel,
      notes: item.notes,
    )).toList(),
  );
}
