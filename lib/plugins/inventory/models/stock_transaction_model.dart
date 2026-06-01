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
  final StockTransactionType type;
  final String productId;
  final String productName;
  final double quantity;
  final DateTime date;
  final String? note;

  const StockTransaction({
    required this.id,
    required this.type,
    required this.productId,
    required this.productName,
    this.quantity = 0,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'transaction_type': type.name,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'date': date.toIso8601String().substring(0, 10),
    'note': note,
    'created_at': DateTime.now().toIso8601String(),
  };

  factory StockTransaction.fromMap(Map<String, dynamic> map) {
    return StockTransaction(
      id: map['id'] as String,
      type: StockTransactionType.values.firstWhere(
        (t) => t.name == map['transaction_type'],
        orElse: () => StockTransactionType.inbound,
      ),
      productId: map['product_id'] as String? ?? '',
      productName: map['product_name'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      note: map['note'] as String?,
    );
  }
}
