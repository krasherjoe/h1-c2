import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/stock_transaction_repository.dart';
import '../services/warehouse_repository.dart';
import '../services/warehouse_stock_repository.dart';
import '../models/warehouse_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/activity_log_repository.dart';
import '../../../models/product_model.dart';
import '../../../constants/screen_ids.dart';

class StockAdjustmentScreen extends StatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  State<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends State<StockAdjustmentScreen> {
  final _productRepo = ProductRepository();
  final _stockRepo = StockTransactionRepository();
  final _warehouseStockRepo = WarehouseStockRepository();
  final _warehouseRepo = WarehouseRepository();
  final _activityLog = ActivityLogRepository();

  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  Map<String, Map<String, int>> _stockMap = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedWarehouseId;

  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _productRepo.getAllProducts();
      final warehouses = await _warehouseRepo.fetchWarehouses();
      final Map<String, Map<String, int>> stockMap = {};
      for (final p in products) {
        final stocks = await _warehouseStockRepo.fetchByProduct(p.id);
        stockMap[p.id] = {for (final s in stocks) s.warehouseId: s.quantity};
      }
      if (!mounted) return;
      setState(() {
        _products = products;
        _warehouses = warehouses;
        _stockMap = stockMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データ読み込みに失敗しました: $e')),
      );
    }
  }

  int _getTotalStock(String productId) {
    final perWarehouse = _stockMap[productId];
    if (perWarehouse == null) return 0;
    return perWarehouse.values.fold(0, (a, b) => a + b);
  }

  int _getWarehouseStock(String productId, String warehouseId) {
    return _stockMap[productId]?[warehouseId] ?? 0;
  }

  List<Product> get _filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (product.barcode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesSearch;
    }).toList();
  }

  Future<void> _showAdjustmentDialog(Product product) async {
    final totalStock = _getTotalStock(product.id);
    final TextEditingController quantityController = TextEditingController(
      text: totalStock.toString(),
    );
    String reason = 'その他';
    String? selectedWarehouseId = _selectedWarehouseId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${product.name} の在庫調整'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: const Text('現在在庫'),
                  trailing: Text('$totalStock個'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: '調整後数量',
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    prefixIcon: Icon(Icons.edit),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedWarehouseId,
                  decoration: const InputDecoration(labelText: '倉庫'),
                  items: _warehouses.map((w) {
                    return DropdownMenuItem(
                      value: w.id,
                      child: Text('${w.name} (在庫: ${_getWarehouseStock(product.id, w.id)})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedWarehouseId = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: reason,
                  decoration: const InputDecoration(labelText: '調整理由'),
                  items: const [
                    DropdownMenuItem(value: '破損', child: Text('破損')),
                    DropdownMenuItem(value: '紛失', child: Text('紛失')),
                    DropdownMenuItem(value: '棚卸差', child: Text('棚卸差額')),
                    DropdownMenuItem(value: '評価替え', child: Text('評価替え')),
                    DropdownMenuItem(value: 'その他', child: Text('その他')),
                  ],
                  onChanged: (value) {
                    setDialogState(() => reason = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'quantity': quantityController.text,
                  'reason': reason,
                  'warehouseId': selectedWarehouseId,
                });
              },
              child: const Text('確定'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final newQuantity = int.tryParse(result['quantity'] as String? ?? '');
      final reason = result['reason'] as String? ?? '';
      final warehouseId = result['warehouseId'] as String?;

      if (newQuantity != null && newQuantity >= 0) {
        await _performAdjustment(
          product: product,
          newQuantity: newQuantity,
          reason: reason,
          warehouseId: warehouseId,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('有効な数量を入力してください')),
        );
      }
    }
  }

  Future<void> _performAdjustment({
    required Product product,
    required int newQuantity,
    required String reason,
    String? warehouseId,
  }) async {
    try {
      final warehouseName = warehouseId != null
          ? _warehouses.where((w) => w.id == warehouseId).firstOrNull?.name ?? ''
          : '';

      if (warehouseId != null) {
        final currentStock = _getWarehouseStock(product.id, warehouseId);
        final delta = newQuantity - currentStock;
        await _warehouseStockRepo.adjustQuantity(product.id, warehouseId, delta);
      }

      await _stockRepo.inbound(
        productId: product.id,
        productName: product.name,
        quantity: newQuantity,
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        type: 'adjustment',
        notes: '調整: $reason',
      );

      final totalBefore = _getTotalStock(product.id);
      final logMessage = '在庫調整: ${product.name} ($totalBefore個 → ${totalBefore + (warehouseId != null ? newQuantity - _getWarehouseStock(product.id, warehouseId) : newQuantity)}個) 理由: $reason 倉庫: $warehouseName';
      await _activityLog.logAction(
        action: 'stock_adjustment',
        targetType: 'inventory',
        targetId: product.id,
        details: logMessage,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} を $newQuantity個に調整しました'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('調整に失敗しました: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filteredProducts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('${S.ia}:在庫調整'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchAndFilter(filteredProducts.length),
                Expanded(child: _buildProductList(filteredProducts)),
              ],
            ),
    );
  }

  Widget _buildSearchAndFilter(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    labelText: '商品名またはバーコード',
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count件登録中',
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList(List<Product> products) {
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('商品データがありません'),
        ),
      );
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final totalStock = _getTotalStock(product.id);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: totalStock <= 0
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              child: Text(
                '$totalStock',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (product.barcode != null)
                  Text('品番: ${product.barcode}'),
                Text('在庫数: $totalStock個'),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '￥${_currencyFormat.format(product.defaultUnitPrice)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('評価額: ￥${_currencyFormat.format(totalStock * product.defaultUnitPrice)}'),
              ],
            ),
            onTap: () => _showAdjustmentDialog(product),
          ),
        );
      },
    );
  }
}
