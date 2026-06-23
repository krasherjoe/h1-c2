import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../services/database_helper.dart';
import '../../../services/product_repository.dart';

/// スプレッドシート型の商品一覧画面。
/// 全商品をテーブル形式で表示し、各セルをインライン編集可能。
class SpreadsheetProductScreen extends StatefulWidget {
  const SpreadsheetProductScreen({super.key});

  @override
  State<SpreadsheetProductScreen> createState() =>
      _SpreadsheetProductScreenState();
}

class _SpreadsheetProductScreenState extends State<SpreadsheetProductScreen> {
  final _repo = ProductRepository();
  final _searchController = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _loading = true;
  String _searchQuery = '';

  // Controller maps (productId -> controller)
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _barcodeControllers = {};
  final Map<String, TextEditingController> _modelNumberControllers = {};
  final Map<String, TextEditingController> _manufacturerControllers = {};
  final Map<String, TextEditingController> _supplierControllers = {};
  double _zoomLevel = 1.0;
  static const _zoomLevels = [0.5, 0.7, 1.0, 1.5, 2.0];
  static const _zoomLabels = ['XS', 'S', 'M', 'L', 'XL'];
  static const _baseWidths = [160.0, 100.0, 130.0, 110.0, 120.0, 120.0, 72.0];
  List<double> get _columnWidths => _baseWidths.map((w) => w * _zoomLevel).toList();

  // Modified & new row tracking
  final Set<String> _modifiedIds = {};
  final Set<String> _newRowIds = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    for (final c in _nameControllers.values) {
      c.dispose();
    }
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final c in _barcodeControllers.values) {
      c.dispose();
    }
    for (final c in _modelNumberControllers.values) {
      c.dispose();
    }
    for (final c in _manufacturerControllers.values) {
      c.dispose();
    }
    for (final c in _supplierControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilter();
    });
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      // New rows first, then existing
      _filteredProducts = [
        ..._allProducts.where((p) => _newRowIds.contains(p.id)),
        ..._allProducts.where((p) => !_newRowIds.contains(p.id)),
      ];
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredProducts = _allProducts.where((p) {
        return p.name.toLowerCase().contains(q) ||
            (p.barcode?.toLowerCase().contains(q) ?? false) ||
            (p.modelNumber?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final products = await _repo.getAllProducts();
      if (!mounted) return;
      setState(() {
        _allProducts = products;
        _createAllControllers();
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      debugPrint('[Spreadsheet] load error: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _createAllControllers() {
    for (final p in _allProducts) {
      _nameControllers.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.name),
      );
      _priceControllers.putIfAbsent(
        p.id,
        () => TextEditingController(
          text: p.defaultUnitPrice > 0 ? p.defaultUnitPrice.toString() : '',
        ),
      );
      _barcodeControllers.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.barcode ?? ''),
      );
      _modelNumberControllers.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.modelNumber ?? ''),
      );
      _manufacturerControllers.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.manufacturer ?? ''),
      );
      _supplierControllers.putIfAbsent(
        p.id,
        () => TextEditingController(text: p.supplierName ?? ''),
      );
    }
  }

  void _markModified(String productId) {
    if (!_modifiedIds.contains(productId)) {
      setState(() => _modifiedIds.add(productId));
    }
  }

  void _addNewRow() {
    final now = DateTime.now();
    final newId =
        'new_${now.millisecondsSinceEpoch}_${now.microsecondsSinceEpoch}';
    final newProduct = Product(id: newId, name: '');
    setState(() {
      _allProducts.insert(0, newProduct);
      _newRowIds.add(newId);
      _modifiedIds.add(newId);
      _nameControllers[newId] = TextEditingController(text: '');
      _priceControllers[newId] = TextEditingController(text: '');
      _barcodeControllers[newId] = TextEditingController(text: '');
      _modelNumberControllers[newId] = TextEditingController(text: '');
      _manufacturerControllers[newId] = TextEditingController(text: '');
      _supplierControllers[newId] = TextEditingController(text: '');
      _applyFilter();
    });
  }

  Future<void> _saveProduct(String productId) async {
    final nameCtrl = _nameControllers[productId];
    if (nameCtrl == null || nameCtrl.text.trim().isEmpty) {
      _showSnackBar('商品名は必須です');
      return;
    }

    Product product;
    try {
      product = _allProducts.firstWhere((p) => p.id == productId);
    } catch (_) {
      return;
    }

    final updated = product.copyWith(
      name: nameCtrl.text.trim(),
      defaultUnitPrice: int.tryParse(
            _priceControllers[productId]?.text.replaceAll(',', '') ?? '',
          ) ??
          0,
      barcode: _barcodeControllers[productId]?.text.trim().isEmpty ?? true
          ? null
          : _barcodeControllers[productId]!.text.trim(),
      modelNumber: _modelNumberControllers[productId]?.text.trim().isEmpty ??
          true
          ? null
          : _modelNumberControllers[productId]!.text.trim(),
      manufacturer: _manufacturerControllers[productId]?.text.trim().isEmpty ??
          true
          ? null
          : _manufacturerControllers[productId]!.text.trim(),
      supplierName: _supplierControllers[productId]?.text.trim().isEmpty ?? true
          ? null
          : _supplierControllers[productId]!.text.trim(),
    );

    try {
      await _repo.saveProduct(updated);
      if (!mounted) return;
      setState(() {
        _modifiedIds.remove(productId);
        _newRowIds.remove(productId);
        // Update the product in _allProducts
        final idx = _allProducts.indexWhere((p) => p.id == productId);
        if (idx >= 0) _allProducts[idx] = updated;
      });
      _showSnackBar('✅ 保存しました');
    } catch (e) {
      _showSnackBar('❌ 保存エラー: $e');
    }
  }

  Future<void> _deleteProduct(String productId) async {
    Product product;
    try {
      product = _allProducts.firstWhere((p) => p.id == productId);
    } catch (_) {
      return;
    }

    final name = product.name.isEmpty ? '未保存の行' : product.name;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「$name」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (_newRowIds.contains(productId)) {
      // New, unsaved row — just remove locally
      setState(() {
        _disposeProductControllers(productId);
        _allProducts.removeWhere((p) => p.id == productId);
        _newRowIds.remove(productId);
        _modifiedIds.remove(productId);
        _applyFilter();
      });
      return;
    }

    try {
      await _repo.deleteProduct(productId);
      if (!mounted) return;
      setState(() {
        _disposeProductControllers(productId);
        _allProducts.removeWhere((p) => p.id == productId);
        _modifiedIds.remove(productId);
        _applyFilter();
      });
      _showSnackBar('✅ 削除しました');
    } catch (e) {
      _showSnackBar('❌ 削除エラー: $e');
    }
  }

  void _disposeProductControllers(String productId) {
    _nameControllers.remove(productId)?.dispose();
    _priceControllers.remove(productId)?.dispose();
    _barcodeControllers.remove(productId)?.dispose();
    _modelNumberControllers.remove(productId)?.dispose();
    _manufacturerControllers.remove(productId)?.dispose();
    _supplierControllers.remove(productId)?.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ===== Build =====

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _filteredProducts.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? '検索結果がありません'
                        : '商品がありません',
                  ),
                )
              : _buildTable(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: '商品名で検索...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ズームアイコン（タップで段階切替）
          GestureDetector(
            onTap: () {
              final currentIdx = _zoomLevels.indexOf(_zoomLevel);
              final nextIdx = (currentIdx + 1) % _zoomLevels.length;
              setState(() => _zoomLevel = _zoomLevels[nextIdx]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.zoom_out_map, size: 16, color: cs.onPrimaryContainer),
                  const SizedBox(width: 4),
                  Text(
                    _zoomLabels[_zoomLevels.indexOf(_zoomLevel)],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addNewRow,
            tooltip: '行を追加',
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 40,
              dataRowMinHeight: 40,
              dataRowMaxHeight: 52,
              columnSpacing: 12,
              horizontalMargin: 12,
              columns: [
                DataColumn(label: SizedBox(width: _columnWidths[0], child: const Text('商品名', style: TextStyle(fontWeight: FontWeight.w600)))),
                DataColumn(label: SizedBox(width: _columnWidths[1], child: const Text('単価', style: TextStyle(fontWeight: FontWeight.w600)))),
                DataColumn(label: SizedBox(width: _columnWidths[2], child: const Text('バーコード', style: TextStyle(fontWeight: FontWeight.w600)))),
                DataColumn(label: SizedBox(width: _columnWidths[3], child: const Text('型番', style: TextStyle(fontWeight: FontWeight.w600)))),
                DataColumn(label: SizedBox(width: _columnWidths[4], child: const Text('メーカー', style: TextStyle(fontWeight: FontWeight.w600)))),
                DataColumn(label: SizedBox(width: _columnWidths[5], child: const Text('仕入先', style: TextStyle(fontWeight: FontWeight.w600)))),
                DataColumn(label: SizedBox(width: _columnWidths[6], child: const Text('操作', style: TextStyle(fontWeight: FontWeight.w600)))),
              ],
              rows: _filteredProducts.map((product) {
                return _buildRow(product);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildRow(Product product) {
    final cs = Theme.of(context).colorScheme;
    final isNew = _newRowIds.contains(product.id);
    final isModified = _modifiedIds.contains(product.id);
    final needsSave = isNew || isModified;

    Color? rowColor;
    if (isNew) {
      rowColor = Colors.green.withValues(alpha: 0.06);
    } else if (isModified) {
      rowColor = Colors.orange.withValues(alpha: 0.06);
    }

    return DataRow(
      color:
          rowColor != null ? WidgetStatePropertyAll(rowColor) : null,
      cells: [
        _textCell(
          _nameControllers[product.id], _columnWidths[0],
          onChanged: () => _markModified(product.id),
        ),
        _textCell(
          _priceControllers[product.id], _columnWidths[1],
          onChanged: () => _markModified(product.id),
          prefix: '¥',
          keyboardType: TextInputType.number,
        ),
        _textCell(
          _barcodeControllers[product.id], _columnWidths[2],
          onChanged: () => _markModified(product.id),
        ),
        _textCell(
          _modelNumberControllers[product.id], _columnWidths[3],
          onChanged: () => _markModified(product.id),
        ),
        DataCell(
          SizedBox(
            width: _columnWidths[4],
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                try {
                  final db = await DatabaseHelper().database;
                  final rows = await db.rawQuery(
                    "SELECT DISTINCT manufacturer FROM products WHERE manufacturer IS NOT NULL AND manufacturer LIKE ? AND is_current = 1 LIMIT 10",
                    ['%${textEditingValue.text}%'],
                  );
                  return rows.map((r) => r['manufacturer'] as String).where((s) => s.isNotEmpty);
                } catch (_) {
                  return const Iterable<String>.empty();
                }
              },
              onSelected: (String selection) {
                _manufacturerControllers[product.id]?.text = selection;
                _markModified(product.id);
              },
              initialValue: TextEditingValue(text: _manufacturerControllers[product.id]?.text ?? ''),
              fieldViewBuilder: (context, textEditingController, focusNode, onSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) {
                    _manufacturerControllers[product.id]?.text = v;
                    _markModified(product.id);
                  },
                  onSubmitted: (_) => onSubmitted(),
                );
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: _columnWidths[5],
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                try {
                  final db = await DatabaseHelper().database;
                  final rows = await db.rawQuery(
                    "SELECT DISTINCT supplier_name FROM products WHERE supplier_name IS NOT NULL AND supplier_name LIKE ? AND is_current = 1 LIMIT 10",
                    ['%${textEditingValue.text}%'],
                  );
                  return rows.map((r) => r['supplier_name'] as String).where((s) => s.isNotEmpty);
                } catch (_) {
                  return const Iterable<String>.empty();
                }
              },
              onSelected: (String selection) {
                _supplierControllers[product.id]?.text = selection;
                _markModified(product.id);
              },
              initialValue: TextEditingValue(text: _supplierControllers[product.id]?.text ?? ''),
              fieldViewBuilder: (context, textEditingController, focusNode, onSubmitted) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) {
                    _supplierControllers[product.id]?.text = v;
                    _markModified(product.id);
                  },
                  onSubmitted: (_) => onSubmitted(),
                );
              },
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: _columnWidths[6],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.save,
                    size: 18,
                    color: needsSave ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  onPressed: needsSave ? () => _saveProduct(product.id) : null,
                  tooltip: '保存',
                ),
                IconButton(
                  icon: Icon(Icons.delete, size: 18, color: cs.error),
                  onPressed: () => _deleteProduct(product.id),
                  tooltip: '削除',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DataCell _textCell(
    TextEditingController? controller,
    double width, {
    VoidCallback? onChanged,
    String? prefix,
    TextInputType? keyboardType,
  }) {
    return DataCell(
      SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            prefixText: prefix,
          ),
          style: const TextStyle(fontSize: 13),
          keyboardType: keyboardType,
          onChanged: (_) => onChanged?.call(),
        ),
      ),
    );
  }
}
