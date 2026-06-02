import 'package:flutter/material.dart';
import '../models/stock_transaction_model.dart';
import '../services/inventory_repository.dart';
import '../../../services/product_repository.dart';
import '../../../models/product_model.dart';
import '../../../widgets/h1_text_field.dart';

class StocktakeScreen extends StatefulWidget {
  const StocktakeScreen({super.key});

  @override
  State<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends State<StocktakeScreen> {
  final _repo = InventoryRepository();
  final _productRepo = ProductRepository();
  final _entries = <_StocktakeEntry>[];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await _productRepo.getAllProducts();
    final stockMap = await _repo.getAllStockQuantities();
    setState(() {
      _entries.clear();
      for (final p in products) {
        _entries.add(_StocktakeEntry(
          productId: p.id,
          productName: p.name,
          currentStock: stockMap[p.id] ?? 0,
        ));
      }
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    try {
      for (final entry in _entries) {
        if (entry.physicalCount == null) continue;
        final diff = entry.physicalCount! - entry.currentStock;
        if (diff == 0) continue;
        await _repo.save(StockTransaction(
          id: _repo.generateId(),
          type: StockTransactionType.stocktake,
          productId: entry.productId,
          productName: entry.productName,
          quantity: diff,
          date: DateTime.now(),
          note: '棚卸: ${entry.currentStock} → ${entry.physicalCount}',
        ));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('棚卸を保存しました')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存エラー: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('棚卸')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('現在庫を確認し、実在庫数を入力してください',
                    style: Theme.of(context).textTheme.bodySmall),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _entries.length,
                    itemBuilder: (ctx, i) {
                      final entry = _entries[i];
                      return ListTile(
                        dense: true,
                        title: Text(entry.productName),
                        subtitle: Text('現在庫: ${entry.currentStock.toStringAsFixed(0)}'),
                        trailing: SizedBox(
                          width: 100,
                          child: H1TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '実在庫',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                            onChanged: (v) {
                              entry.physicalCount = double.tryParse(v);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('棚卸を保存'),
                      onPressed: _save,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _StocktakeEntry {
  final String productId;
  final String productName;
  final double currentStock;
  double? physicalCount;

  _StocktakeEntry({
    required this.productId,
    required this.productName,
    required this.currentStock,
  });
}
