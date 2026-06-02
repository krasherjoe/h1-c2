class MonthlySummary {
  final int year;
  final int month;
  final int salesAmount;
  final int costAmount;
  final int profitAmount;
  final int orderCount;

  const MonthlySummary({
    required this.year,
    required this.month,
    this.salesAmount = 0,
    this.costAmount = 0,
    this.profitAmount = 0,
    this.orderCount = 0,
  });

  factory MonthlySummary.fromMap(Map<String, dynamic> m) => MonthlySummary(
    year: (m['year'] as num?)?.toInt() ?? 0,
    month: (m['month'] as num?)?.toInt() ?? 0,
    salesAmount: (m['sales_amount'] as num?)?.toInt() ?? 0,
    costAmount: (m['cost_amount'] as num?)?.toInt() ?? 0,
    profitAmount: (m['profit_amount'] as num?)?.toInt() ?? 0,
    orderCount: (m['order_count'] as num?)?.toInt() ?? 0,
  );

  String get label => '$year年$month月';
}

class ProductProfit {
  final String productId;
  final String productName;
  final int quantity;
  final int salesAmount;
  final int costAmount;
  final int profitAmount;
  final double profitRate;

  const ProductProfit({
    required this.productId,
    required this.productName,
    this.quantity = 0,
    this.salesAmount = 0,
    this.costAmount = 0,
    this.profitAmount = 0,
    this.profitRate = 0,
  });

  factory ProductProfit.fromMap(Map<String, dynamic> m) {
    final sales = (m['sales_amount'] as num?)?.toInt() ?? 0;
    final cost = (m['cost_amount'] as num?)?.toInt() ?? 0;
    final profit = sales - cost;
    return ProductProfit(
      productId: m['product_id'] as String? ?? '',
      productName: m['product_name'] as String? ?? '',
      quantity: (m['quantity'] as num?)?.toInt() ?? 0,
      salesAmount: sales,
      costAmount: cost,
      profitAmount: profit > 0 ? profit : 0,
      profitRate: sales > 0 ? (profit / sales) * 100 : 0,
    );
  }
}

class AccountSummary {
  final String accountName;
  final int amount;
  final String type;

  const AccountSummary({
    required this.accountName,
    required this.amount,
    this.type = 'revenue',
  });

  factory AccountSummary.fromMap(Map<String, dynamic> m) => AccountSummary(
    accountName: m['account_name'] as String? ?? m['name'] as String? ?? '',
    amount: (m['amount'] as num?)?.toInt() ?? 0,
    type: m['type'] as String? ?? 'revenue',
  );
}
