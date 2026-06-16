import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/product_repository.dart';
import '../services/warehouse_stock_repository.dart';
import '../services/warehouse_repository.dart';
import '../models/warehouse_model.dart';
import '../../../constants/screen_ids.dart';

class _ValuationItem {
  final String productId;
  final String productName;
  final String? barcode;
  final int quantity;
  final int unitPrice;
  final String warehouseId;
  final String warehouseName;

  _ValuationItem({
    required this.productId,
    required this.productName,
    this.barcode,
    required this.quantity,
    required this.unitPrice,
    required this.warehouseId,
    required this.warehouseName,
  });

  int get totalValue => quantity * unitPrice;
}

class InventoryValuationScreen extends StatefulWidget {
  const InventoryValuationScreen({super.key});

  @override
  State<InventoryValuationScreen> createState() => _InventoryValuationScreenState();
}

class _InventoryValuationScreenState extends State<InventoryValuationScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final WarehouseStockRepository _warehouseStockRepo = WarehouseStockRepository();
  final WarehouseRepository _warehouseRepo = WarehouseRepository();

  List<_ValuationItem> _items = [];
  bool _isLoading = true;
  String _selectedWarehouseId = 'すべて';
  List<Warehouse> _warehouses = [];

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

      final List<_ValuationItem> items = [];
      for (final p in products) {
        final stocks = await _warehouseStockRepo.fetchByProduct(p.id);
        for (final s in stocks) {
          final wh = warehouses.where((w) => w.id == s.warehouseId).firstOrNull;
          if (s.quantity != 0) {
            items.add(_ValuationItem(
              productId: p.id,
              productName: p.name,
              barcode: p.barcode,
              quantity: s.quantity,
              unitPrice: p.defaultUnitPrice,
              warehouseId: s.warehouseId,
              warehouseName: wh?.name ?? s.warehouseId,
            ));
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _warehouses = warehouses;
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

  List<_ValuationItem> get _filteredItems {
    if (_selectedWarehouseId == 'すべて') return _items;
    return _items.where((item) => item.warehouseId == _selectedWarehouseId).toList();
  }

  int get _totalQuantity {
    return _filteredItems.fold(0, (sum, item) => sum + item.quantity);
  }

  int get _totalValue {
    return _filteredItems.fold(0, (sum, item) => sum + item.totalValue);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('\${S.r4}:在庫評価額一覧'),
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
                _buildSummaryCards(),
                _buildWarehouseFilter(),
                Expanded(child: _buildInventoryList(filtered)),
              ],
            ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).colorScheme.secondaryContainer),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('総数量', '$_totalQuantity個'),
          _summaryItem('評価額合計', '￥${_currencyFormat.format(_totalValue)}'),
          _summaryItem('対象品目', '${_filteredItems.length}件'),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildWarehouseFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('倉庫:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedWarehouseId,
              isExpanded: true,
              underline: const SizedBox(),
              items: [
                const DropdownMenuItem(value: 'すべて', child: Text('すべて')),
                ..._warehouses.map((w) => DropdownMenuItem(
                  value: w.id,
                  child: Text(w.name),
                )),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedWarehouseId = value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList(List<_ValuationItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('在庫データがありません'),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isOutOfStock = item.quantity <= 0;
        final isLowStock = item.quantity <= 5 && item.quantity > 0;

        Color statusColor;
        if (isOutOfStock) {
          statusColor = Theme.of(context).colorScheme.error;
        } else if (isLowStock) {
          statusColor = Theme.of(context).colorScheme.secondary;
        } else {
          statusColor = Theme.of(context).colorScheme.primary;
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: statusColor,
              child: Text(
                '${item.quantity}',
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
            title: Text(
              item.productName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '在庫: ${item.quantity}個 | 評価額: ￥${_currencyFormat.format(item.totalValue)}',
            ),
            trailing: Text(
              '倉庫: ${item.warehouseName}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}
