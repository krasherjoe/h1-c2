import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../models/warehouse_model.dart';
import '../models/stock_transfer_models.dart';
import '../services/warehouse_repository.dart';
import '../services/warehouse_stock_repository.dart';
import '../services/stock_transfer_service.dart';

class _TransferLine {
  _TransferLine({required this.product, required this.quantity, this.available});

  final Product product;
  int quantity;
  int? available;
}

class StockTransferScreen extends StatefulWidget {
  const StockTransferScreen({super.key});

  @override
  State<StockTransferScreen> createState() => _StockTransferScreenState();
}

class _StockTransferScreenState extends State<StockTransferScreen> {
  final WarehouseRepository _warehouseRepo = WarehouseRepository();
  final WarehouseStockRepository _warehouseStockRepo = WarehouseStockRepository();
  final StockTransferService _transferService = StockTransferService();

  Warehouse? _fromWarehouse;
  Warehouse? _toWarehouse;
  DateTime _transferDate = DateTime.now();
  final TextEditingController _memoController = TextEditingController();
  final List<_TransferLine> _lines = [];
  bool _loading = true;
  bool _saving = false;
  List<Warehouse> _warehouses = [];
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd');

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    final warehouses = await _warehouseRepo.fetchWarehouses(includeHidden: false);
    if (warehouses.isEmpty) {
      final defaultWarehouse = await _warehouseRepo.ensureDefaultWarehouse();
      warehouses.add(defaultWarehouse);
    }
    final from = warehouses.isNotEmpty ? warehouses.first : null;
    Warehouse? to;
    if (warehouses.length > 1) {
      to = warehouses.firstWhere((w) => w.id != from!.id, orElse: () => warehouses[0]);
    }
    if (!mounted) return;
    setState(() {
      _warehouses = warehouses;
      _fromWarehouse = from;
      _toWarehouse = to;
      _loading = false;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transferDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _transferDate = picked);
    }
  }

  Future<void> _addLine() async {
    if (_fromWarehouse == null || _toWarehouse == null) {
      _showSnack('倉庫を先に選択してください');
      return;
    }

    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const _ProductSelectionScreen()),
    );
    if (product == null || !mounted) return;

    final quantity = await _promptQuantity(product);
    if (quantity == null || !mounted) return;

    final available = await _warehouseStockRepo.getQuantity(product.id, _fromWarehouse!.id);
    if (!mounted) return;
    setState(() {
      _lines.add(_TransferLine(product: product, quantity: quantity, available: available));
    });
  }

  Future<int?> _promptQuantity(Product product, {int? initial}) async {
    final controller = TextEditingController(text: (initial ?? 1).toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${product.name} の数量'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '数量'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              final qty = int.tryParse(controller.text.trim());
              if (qty == null || qty <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正しい数量を入力してください')));
                return;
              }
              Navigator.pop(context, qty);
            },
            child: const Text('決定'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _editLine(int index) async {
    final line = _lines[index];
    final newQty = await _promptQuantity(line.product, initial: line.quantity);
    if (newQty == null || !mounted) return;
    final available = await _warehouseStockRepo.getQuantity(line.product.id, _fromWarehouse!.id);
    if (!mounted) return;
    setState(() {
      line.quantity = newQty;
      line.available = available;
    });
  }

  Future<void> _saveTransfer() async {
    if (_fromWarehouse == null || _toWarehouse == null) {
      _showSnack('倉庫を選択してください');
      return;
    }
    if (_fromWarehouse!.id == _toWarehouse!.id) {
      _showSnack('移動元と移動先は異なる倉庫を選んでください');
      return;
    }
    if (_lines.isEmpty) {
      _showSnack('明細がありません');
      return;
    }
    setState(() => _saving = true);
    try {
      await _transferService.createTransfer(
        fromWarehouseId: _fromWarehouse!.id,
        toWarehouseId: _toWarehouse!.id,
        transferDate: _transferDate,
        memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
        createdByDevice: null,
        lines: _lines
            .map((line) => StockTransferLineInput(
                  productId: line.product.id,
                  quantity: line.quantity,
                ))
            .toList(),
      );
      if (!mounted) return;
      _showSnack('在庫移動を登録しました');
      setState(() {
        _lines.clear();
        _memoController.clear();
        _transferDate = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('保存に失敗しました: $e');
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
        title: const Text('IM:在庫移動'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _saveTransfer,
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save),
            tooltip: '在庫移動を登録',
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
                    children: [
                      Row(
                        children: [
                          Expanded(child: _warehouseDropdown(label: '移動元倉庫', selected: _fromWarehouse, onChanged: (w) => setState(() => _fromWarehouse = w))),
                          const SizedBox(width: 12),
                          Expanded(child: _warehouseDropdown(label: '移動先倉庫', selected: _toWarehouse, onChanged: (w) => setState(() => _toWarehouse = w))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _selectDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(child: Text('移動日: ${_dateFormat.format(_transferDate)}', overflow: TextOverflow.ellipsis)),
                                    const Icon(Icons.calendar_month, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _memoController,
                              decoration: const InputDecoration(labelText: 'メモ (任意)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _lines.isEmpty
                      ? const Center(child: Text('商品を追加してください'))
                      : ListView.builder(
                          itemCount: _lines.length,
                          itemBuilder: (context, index) {
                            final line = _lines[index];
                            final available = line.available;
                            final shortage = available != null && available < line.quantity;
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: ListTile(
                                title: Text(line.product.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('数量: ${line.quantity}'),
                                    if (available != null)
                                      Text(
                                        '移動元の残量: $available',
                                        style: TextStyle(color: shortage ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (v) {
                                    if (v == 'edit') _editLine(index);
                                    if (v == 'delete') setState(() => _lines.removeAt(index));
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('編集'), dense: true)),
                                    PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error), title: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error)), dense: true)),
                                  ],
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
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: const Text('商品を追加'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _warehouseDropdown({required String label, Warehouse? selected, required ValueChanged<Warehouse?> onChanged}) {
    return DropdownButtonFormField<Warehouse>(
      initialValue: selected,
      decoration: InputDecoration(labelText: label),
      items: _warehouses
          .map((w) => DropdownMenuItem(value: w, child: Text(w.name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ProductSelectionScreen extends StatelessWidget {
  const _ProductSelectionScreen();

  @override
  Widget build(BuildContext context) {
    final repo = ProductRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('商品を選択')),
      body: FutureBuilder<List<Product>>(
        future: repo.getAllProducts(includeHidden: false),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snap.data ?? [];
          if (products.isEmpty) return const Center(child: Text('商品が登録されていません'));
          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (_, i) {
              final p = products[i];
              return ListTile(
                leading: CircleAvatar(child: Text('${p.stockQuantity ?? 0}')),
                title: Text(p.name),
                subtitle: Text('¥${NumberFormat('#,###').format(p.defaultUnitPrice)}'),
                onTap: () => Navigator.pop(context, p),
              );
            },
          );
        },
      ),
    );
  }
}
