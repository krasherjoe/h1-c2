enum StockTransactionType {
  inbound,
  outbound,
  transfer,
  adjustment,
  stocktake,
}

extension StockTransactionTypeLabel on StockTransactionType {
  String get label {
    switch (this) {
      case StockTransactionType.inbound:
        return '入庫';
      case StockTransactionType.outbound:
        return '出庫';
      case StockTransactionType.transfer:
        return '移動';
      case StockTransactionType.adjustment:
        return '調整';
      case StockTransactionType.stocktake:
        return '棚卸';
    }
  }
}

class StockTransaction {
  final String id;
  final String productId;
  final String productName;
  final String? warehouseId;
  final String? warehouseName;
  final int quantity;
  final String type;
  final String? referenceId;
  final String? referenceNumber;
  final String? notes;
  final DateTime createdAt;

  const StockTransaction({
    required this.id,
    required this.productId,
    required this.productName,
    this.warehouseId,
    this.warehouseName,
    required this.quantity,
    required this.type,
    this.referenceId,
    this.referenceNumber,
    this.notes,
    required this.createdAt,
  });

  StockTransactionType get transactionType {
    return StockTransactionType.values.firstWhere(
      (t) => t.name == type,
      orElse: () => StockTransactionType.adjustment,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'product_id': productId,
    'product_name': productName,
    'warehouse_id': warehouseId,
    'warehouse_name': warehouseName,
    'quantity': quantity,
    'type': type,
    'reference_id': referenceId,
    'reference_number': referenceNumber,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };

  factory StockTransaction.fromMap(Map<String, dynamic> map) => StockTransaction(
    id: map['id'] as String? ?? '',
    productId: map['product_id'] as String? ?? '',
    productName: map['product_name'] as String? ?? '',
    warehouseId: map['warehouse_id'] as String?,
    warehouseName: map['warehouse_name'] as String?,
    quantity: map['quantity'] as int? ?? 0,
    type: map['type'] as String? ?? '',
    referenceId: map['reference_id'] as String?,
    referenceNumber: map['reference_number'] as String?,
    notes: map['notes'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String? ?? ''),
  );
}
