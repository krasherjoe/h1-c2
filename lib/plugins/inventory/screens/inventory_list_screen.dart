import 'package:flutter/material.dart';
import '../../../services/product_repository.dart';
import '../../../models/product_model.dart';
import '../models/stock_transaction_model.dart';
import '../services/inventory_repository.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final _productRepo = ProductRepository();
  final _inventoryRepo = InventoryRepository();
  List<Product> _products = [];
  Map<String, double> _stockMap = {};
  bool _isLoading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productRepo.getAllProducts();
      final stockMap = await _inventoryRepo.getAllStockQuantities();
      setState(() {
        _products = products;
        _stockMap = stockMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Product> get _filtered {
    if (_query.isEmpty) return _products;
    final q = _query.toLowerCase();
    return _products.where((p) =>
      p.name.toLowerCase().contains(q) ||
      (p.barcode?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('在庫一覧')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: '商品名・バーコードで検索',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: _filtered.isEmpty
                        ? const Center(child: Text('該当する商品がありません'))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (ctx, i) {
                              final product = _filtered[i];
                              final stock = _stockMap[product.id] ?? 0;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: stock > 0
                                      ? Colors.green.shade100
                                      : Colors.grey.shade100,
                                  child: Text(
                                    stock == stock.roundToDouble()
                                        ? stock.toInt().toString()
                                        : stock.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: stock > 0
                                          ? Colors.green.shade800
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                title: Text(product.name),
                                subtitle: Text(
                                  '¥${product.defaultUnitPrice}',
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _showHistory(context, product),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showHistory(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StockHistorySheet(
        productId: product.id,
        productName: product.name,
      ),
    );
  }
}

class _StockHistorySheet extends StatefulWidget {
  final String productId;
  final String productName;

  const _StockHistorySheet({required this.productId, required this.productName});

  @override
  State<_StockHistorySheet> createState() => _StockHistorySheetState();
}

class _StockHistorySheetState extends State<_StockHistorySheet> {
  final _repo = InventoryRepository();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return FutureBuilder(
          future: _repo.fetchAll(productId: widget.productId),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final transactions = snapshot.data ?? [];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(widget.productName,
                    style: Theme.of(context).textTheme.titleMedium),
                ),
                if (transactions.isEmpty)
                  const Expanded(child: Center(child: Text('履歴がありません')))
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: transactions.length,
                      itemBuilder: (ctx, i) {
                        final t = transactions[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            t.quantity > 0 ? Icons.add_circle : Icons.remove_circle,
                            color: t.quantity > 0 ? Colors.green : Colors.red,
                          ),
                          title: Text(t.type.label),
                          subtitle: Text(t.date.toIso8601String().substring(0, 10)),
                          trailing: Text(
                            '${t.quantity > 0 ? '+' : ''}${t.quantity}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: t.quantity > 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
