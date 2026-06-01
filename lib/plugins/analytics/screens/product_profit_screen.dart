import 'package:flutter/material.dart';
import '../../../services/database_helper.dart';

class ProductProfitScreen extends StatefulWidget {
  const ProductProfitScreen({super.key});

  @override
  State<ProductProfitScreen> createState() => _ProductProfitScreenState();
}

class _ProductProfitScreenState extends State<ProductProfitScreen> {
  final _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _profitData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await _dbHelper.database;
    final results = await db.rawQuery('''
      SELECT
        di.product_id,
        di.product_name,
        SUM(di.quantity) as sale_qty,
        SUM(di.quantity * di.unit_price) as sale_amount
      FROM document_items di
      JOIN documents d ON d.id = di.document_id
      WHERE d.document_type IN ('invoice','receipt') AND d.status = 'confirmed'
      GROUP BY di.product_id, di.product_name
      ORDER BY sale_amount DESC
      LIMIT 50
    ''');
    setState(() {
      _profitData = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('商品別利益分析')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profitData.isEmpty
              ? const Center(child: Text('データがありません'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _profitData.length,
                    itemBuilder: (ctx, i) {
                      final row = _profitData[i];
                      final qty = (row['sale_qty'] as num?)?.toDouble() ?? 0;
                      final amount = (row['sale_amount'] as num?)?.toInt() ?? 0;
                      return ListTile(
                        title: Text(row['product_name'] as String),
                        subtitle: Text(
                            '${qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(1)}個'),
                        trailing: Text(
                          '¥${_formatAmount(amount)}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _formatAmount(int amount) =>
    amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
