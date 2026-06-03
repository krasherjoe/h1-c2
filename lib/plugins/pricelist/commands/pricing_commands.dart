import '../../../services/database_helper.dart';

Future<String> cmdPricingDump(List<String> args) async {
  final db = await DatabaseHelper().database;
  final isCsv = args.contains('--csv');
  var customerFilter = '';
  var categoryFilter = '';
  for (final arg in args) {
    if (arg == '--csv') continue;
    if (arg.startsWith('customer=')) customerFilter = arg.substring(9);
    if (arg.startsWith('category=')) categoryFilter = arg.substring(9);
  }

  final conditions = <String>[];
  final params = <dynamic>[];
  if (customerFilter.isNotEmpty) {
    conditions.add('c.name LIKE ?');
    params.add('%$customerFilter%');
  }
  if (categoryFilter.isNotEmpty) {
    conditions.add('p.category LIKE ?');
    params.add('%$categoryFilter%');
  }
  final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

  final rows = await db.rawQuery('''
    SELECT c.name AS customer, p.name AS product, p.category, cpp.price
    FROM customer_product_prices cpp
    JOIN customers c ON c.id = cpp.customer_id
    JOIN products p ON p.id = cpp.product_id
    $where
    ORDER BY customer, p.category, product
  ''', params);

  if (rows.isEmpty) return '該当する納入価格データがありません。';

  if (isCsv) {
    final buf = StringBuffer();
    buf.writeln('顧客名,商品名,カテゴリ,単価');
    for (final r in rows) {
      buf.writeln('${r['customer']},${r['product']},${r['category'] ?? ""},${r['price']}');
    }
    return buf.toString();
  }

  final buf = StringBuffer();
  buf.writeln('📋 **納入価格リスト** (${rows.length}件)');
  if (customerFilter.isNotEmpty) buf.writeln('  顧客絞込: $customerFilter');
  if (categoryFilter.isNotEmpty) buf.writeln('  カテゴリ絞込: $categoryFilter');
  buf.writeln('');

  String? lastCustomer;
  for (final r in rows) {
    final customer = r['customer'] as String? ?? '';
    if (customer != lastCustomer) {
      if (lastCustomer != null) buf.writeln('');
      buf.writeln('**【$customer】**');
      lastCustomer = customer;
    }
    final name = r['product'] as String? ?? '';
    final cat = r['category'] as String? ?? '';
    final price = r['price'] as int? ?? 0;
    final priceStr = '¥${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    buf.writeln('  $name${cat.isNotEmpty ? "($cat)" : ""}  $priceStr');
  }

  return buf.toString();
}
