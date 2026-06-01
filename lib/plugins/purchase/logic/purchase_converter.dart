import '../models/purchase_model.dart';

PurchaseType? nextPurchaseType(PurchaseType current) {
  return switch (current) {
    PurchaseType.order => PurchaseType.receipt,
    PurchaseType.receipt => PurchaseType.payment,
    PurchaseType.return_ => null,
    PurchaseType.payment => null,
  };
}

PurchaseModel convertPurchase(PurchaseModel source) {
  final next = nextPurchaseType(source.purchaseType);
  if (next == null) throw ArgumentError('これ以上変換できません: ${source.purchaseType.label}');

  return PurchaseModel(
    id: source.id,
    purchaseType: next,
    supplierId: source.supplierId,
    supplierName: source.supplierName,
    documentNumber: source.documentNumber,
    date: DateTime.now(),
    total: source.total,
    status: 'draft',
    linkedDocumentId: source.id,
    items: source.items.map((item) => PurchaseItem(
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
