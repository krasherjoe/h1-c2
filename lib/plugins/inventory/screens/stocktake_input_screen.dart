import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../services/warehouse_stock_repository.dart';
import '../services/stock_transaction_repository.dart';
import '../../../constants/screen_ids.dart';

class StocktakeInputScreen extends StatefulWidget {
  const StocktakeInputScreen({super.key});

  @override
  State<StocktakeInputScreen> createState() => _StocktakeInputScreenState();
}

class _StocktakeInputScreenState extends State<StocktakeInputScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final WarehouseStockRepository _warehouseStockRepo = WarehouseStockRepository();
  final StockTransactionRepository _stockRepo = StockTransactionRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Product> _filtered = [];
  final Map<String, TextEditingController> _stockControllers = {};
  bool _loading = true;
  bool _saving = false;
  String _sortMode = 'name_asc';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final ctrl in _stockControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final items = await _productRepo.getAllProducts(includeHidden: false);
    if (!mounted) return;
    setState(() {
      _products = items;
      _filtered = items;
      _loading = false;
    });
    for (final product in items) {
      final total = await _warehouseStockRepo.getTotalQuantity(product.id);
      if (!mounted) return;
      _stockControllers.putIfAbsent(
        product.id,
        () => TextEditingController(text: total.toString()),
      );
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _products.where((p) {
        final name = p.name.toLowerCase();
        final category = p.category?.toLowerCase() ?? '';
        final barcode = p.barcode?.toLowerCase() ?? '';
        return name.contains(q) || category.contains(q) || barcode.contains(q);
      }).toList();

      switch (_sortMode) {
        case 'stock_desc':
          _filtered.sort((a, b) => _getCurrentStock(b.id).compareTo(_getCurrentStock(a.id)));
          break;
        case 'stock_asc':
          _filtered.sort((a, b) => _getCurrentStock(a.id).compareTo(_getCurrentStock(b.id)));
          break;
        case 'name_desc':
          _filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
          break;
        case 'name_asc':
        default:
          _filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          break;
      }
    });
  }

  int _getCurrentStock(String productId) {
    final ctrl = _stockControllers[productId];
    if (ctrl == null) return 0;
    final parsed = int.tryParse(ctrl.text);
    final product = _products.where((p) => p.id == productId).firstOrNull;
    return parsed ?? (product?.stockQuantity ?? 0);
  }

  int _getOriginalStock(String productId) {
    final product = _products.where((p) => p.id == productId).firstOrNull;
    return product?.stockQuantity ?? 0;
  }

  Future<void> _saveStocktake() async {
    setState(() => _saving = true);
    try {
      final Map<String, int> updates = {};
      for (final product in _products) {
        final controller = _stockControllers[product.id];
        if (controller == null) continue;
        final parsed = int.tryParse(controller.text);
        if (parsed == null) continue;
        final original = _getOriginalStock(product.id);
        if (parsed != original) {
          updates[product.id] = parsed;
        }
      }
      if (updates.isEmpty) {
        _showSnack('変更はありません');
        return;
      }

      await _productRepo.updateStockQuantities(updates);

      for (final entry in updates.entries) {
        final product = _products.where((p) => p.id == entry.key).firstOrNull;
        if (product == null) continue;
        final delta = entry.value - _getOriginalStock(entry.key);
        if (delta != 0) {
          await _stockRepo.inbound(
            productId: product.id,
            productName: product.name,
            quantity: delta.abs(),
            warehouseId: null,
            warehouseName: null,
            type: 'stocktake',
            notes: '棚卸: ${delta > 0 ? "増" : "減"} ($delta)',
          );
        }
      }

      if (!mounted) return;
      _showSnack('棚卸結果を反映しました');
      await _loadProducts();
    } catch (e) {
      if (!mounted) return;
      _showSnack('棚卸の保存に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('${S.ic}:棚卸入力'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _saveStocktake,
            icon: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary),
                  )
                : const Icon(Icons.save),
            tooltip: '棚卸結果を保存',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: '商品名・カテゴリ・バーコードで検索',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (_) => _applyFilter(),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('名前昇順'),
                            selected: _sortMode == 'name_asc',
                            onSelected: (_) {
                              setState(() => _sortMode = 'name_asc');
                              _applyFilter();
                            },
                          ),
                          ChoiceChip(
                            label: const Text('名前降順'),
                            selected: _sortMode == 'name_desc',
                            onSelected: (_) {
                              setState(() => _sortMode = 'name_desc');
                              _applyFilter();
                            },
                          ),
                          ChoiceChip(
                            label: const Text('在庫 少→多'),
                            selected: _sortMode == 'stock_asc',
                            onSelected: (_) {
                              setState(() => _sortMode = 'stock_asc');
                              _applyFilter();
                            },
                          ),
                          ChoiceChip(
                            label: const Text('在庫 多→少'),
                            selected: _sortMode == 'stock_desc',
                            onSelected: (_) {
                              setState(() => _sortMode = 'stock_desc');
                              _applyFilter();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const Center(child: Text('該当する商品がありません'))
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final product = _filtered[index];
                            final controller = _stockControllers[product.id]!;
                            final currentStock = _getOriginalStock(product.id);
                            final enteredStock = int.tryParse(controller.text) ?? currentStock;
                            final diff = enteredStock - currentStock;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'カテゴリ: ${product.category ?? '未分類'}',
                                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                          ),
                                          if (product.barcode != null)
                                            Text(
                                              'バーコード: ${product.barcode}',
                                              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 110,
                                      child: TextField(
                                        controller: controller,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: '棚卸数',
                                          helperText: '現在: $currentStock',
                                        ),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    if (diff != 0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          '${diff > 0 ? '+' : ''}$diff',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: diff > 0 ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.error,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  child: IconButton(
                    onPressed: _saving ? null : _saveStocktake,
                    icon: _saving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    tooltip: _saving ? '保存中...' : '棚卸結果を反映',
                  ),
                ),
              ],
            ),
    );
  }
}
