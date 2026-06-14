import 'dart:io';
import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/product_category_repository.dart';
import '../../../models/product_category_model.dart';
import '../../../services/input_style_service.dart';
import '../../../services/error_reporter.dart';
import '../screens/product_editor_screen.dart';
import '../logic/category_tree_utils.dart';

class CategoryExplorerScreen extends StatefulWidget {
  const CategoryExplorerScreen({super.key});
  @override
  State<CategoryExplorerScreen> createState() => _CategoryExplorerScreenState();
}

class _CategoryExplorerScreenState extends State<CategoryExplorerScreen> {
  final _productRepo = ProductRepository();
  final _catRepo = ProductCategoryRepository();

  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  bool _loading = true;
  bool _isTreeView = true;
  int _displaySize = 1; // 0=S, 1=M, 2=L
  String _searchQuery = '';
  String? _selectedCategoryId;

  final _expandedCategories = <String>{};

  // --- 間隔・サイズ定数 ---
  static const _kCardMarginH = 2.0;
  static const _kCardMarginV = 3.0;
  static const _kCardPadH = 8.0;
  static const _kCardPadV = 5.0;
  static const _kItemGap = 6.0;
  static const _kIconTextGap = 8.0;
  static const _kIconSizes = [18.0, 22.0, 26.0];
  static const _kTextSizes = [12.0, 14.0, 15.0];
  static const _kSubTextSizes = [10.0, 11.0, 12.0];
  static const _kPriceSizes = [12.0, 13.0, 14.0];
  static const _kCategoryIconSizes = [16.0, 20.0, 24.0];
  static const _kFolderSizes = [18.0, 22.0, 26.0];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _autoExpandAll() {
    for (final cat in _categories) {
      _expandedCategories.add(cat.id);
    }
    debugPrint('[P1] auto-expanded all: ${_expandedCategories.length} categories');
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final products = await _productRepo.getAllProducts();
    final categories = await _catRepo.getAll();
    if (!mounted) return;
    setState(() {
      _products = products;
      _categories = categories;
      _loading = false;
    });
    final logMsg = 'P1 ログ: products=${_products.length}, categories=${_categories.length}, expanded=$_expandedCategories, showShadows=${inputStyleNotifier.value == "raised"}';
    debugPrint(logMsg);
    ErrorReporter.sendLog(message: logMsg);
    debugPrint('[P1] sample products: ${_products.take(3).map((p) => '${p.name}(${p.categoryId})').join(', ')}');
    _autoExpandAll();
  }

  List<Product> get _filteredProducts {
    var list = _products;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) =>
        p.name.toLowerCase().contains(q) ||
        (p.barcode?.toLowerCase().contains(q) ?? false) ||
        (p.modelNumber?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    if (_selectedCategoryId != null) {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('P1:商品マスター'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isTreeView ? Icons.view_list : Icons.account_tree),
            tooltip: _isTreeView ? 'リスト表示' : 'ツリー表示',
            onPressed: () => setState(() => _isTreeView = !_isTreeView),
          ),
          IconButton(
            icon: Icon(_displaySize == 0 ? Icons.view_list : _displaySize == 1 ? Icons.view_module : Icons.view_day),
            tooltip: _displaySize == 0 ? 'S表示' : _displaySize == 1 ? 'M表示' : 'L表示',
            onPressed: () => setState(() => _displaySize = (_displaySize + 1) % 3),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(cs),
          if (!_isTreeView) _buildCategoryFilter(cs),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _isTreeView
                    ? _buildTreeView(cs)
                    : _buildListView(cs),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProduct,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        decoration: InputDecoration(
          hintText: '商品名で検索...',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildCategoryFilter(ColorScheme cs) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          FilterChip(
            label: const Text('すべて'),
            selected: _selectedCategoryId == null,
            onSelected: (_) => setState(() => _selectedCategoryId = null),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          ..._categories.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(cat.name),
              selected: _selectedCategoryId == cat.id,
              onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
              visualDensity: VisualDensity.compact,
            ),
          )),
        ],
      ),
    );
  }

  // --- ツリー表示 ---
  Widget _buildTreeView(ColorScheme cs) {
    return ValueListenableBuilder<String>(
      valueListenable: inputStyleNotifier,
      builder: (context, inputStyle, _) {
        final showShadows = inputStyle == 'raised';
        final rootCategories = _categories.where((c) => c.parentId == null).toList();
        final uncategorizedProducts = _products.where((p) => p.categoryId == null).toList();
        final treeLog = 'P1 ツリー: rootCategories=${rootCategories.length}, uncategorized=${uncategorizedProducts.length}, showShadows=$showShadows, expanded=$_expandedCategories';
        debugPrint(treeLog);
        ErrorReporter.sendLog(message: treeLog);
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ...rootCategories.map((cat) =>
                _buildCategoryTreeItem(cat, 0, cs, showShadows)),
              if (uncategorizedProducts.isNotEmpty)
                _buildUncategorizedSection(cs, showShadows),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTreeItem(ProductCategory cat, int depth, ColorScheme cs, bool showShadows) {
    final children = _categories.where((c) => c.parentId == cat.id).toList();
    final products = _products.where((p) => p.categoryId == cat.id).toList();
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedCategories.contains(cat.id);
    final spacing = _kItemGap;
    debugPrint('[P1] treeItem: ${cat.name}(id=${cat.id}) products=${products.length} expanded=$isExpanded');

    return DragTarget<Product>(
      onWillAcceptWithDetails: (details) => details.data.categoryId != cat.id,
      onAcceptWithDetails: (details) async {
        try {
          final updated = details.data.copyWith(categoryId: cat.id);
          await _productRepo.saveProduct(updated);
          setState(() => _expandedCategories.add(cat.id));
          await _load();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('商品移動エラー: $e')),
            );
          }
        }
      },
      builder: (ctx, candidates, rejected) {
        final isHighlighted = candidates.isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: hasChildren ? () => setState(() {
                if (isExpanded) _expandedCategories.remove(cat.id);
                else _expandedCategories.add(cat.id);
              }) : null,
              child: Container(
                padding: EdgeInsets.only(left: depth * 20.0, right: 8, top: spacing, bottom: spacing),
                decoration: isHighlighted ? BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ) : null,
                child: Row(
                  children: [
                Icon(
                  hasChildren ? (isExpanded ? Icons.expand_more : Icons.chevron_right) : Icons.label,
                  size: [16, 20, 24][_displaySize].toDouble(),
                  color: isHighlighted ? cs.primary : const Color(0xFF8D6E63),
                  shadows: showShadows ? [Shadow(blurRadius: 2, color: cs.shadow.withValues(alpha: 0.35))] : null,
                ),
                const SizedBox(width: 8),
                Icon(Icons.folder, size: [18, 22, 26][_displaySize].toDouble(),
                    color: isHighlighted ? cs.primary : const Color(0xFFFFCA28),
                    shadows: showShadows ? [Shadow(blurRadius: 2, color: cs.shadow.withValues(alpha: 0.35))] : null),
                const SizedBox(width: 8),
                    Expanded(
                      child: Text(cat.name,
                        style: TextStyle(
                          fontSize: [12, 14, 16][_displaySize].toDouble(),
                          fontWeight: FontWeight.w500,
                          color: isHighlighted ? cs.primary : null,
                          shadows: showShadows ? [Shadow(blurRadius: 1, color: cs.shadow.withValues(alpha: 0.3))] : null,
                        )),
                    ),
                    Text('${products.length + children.length}',
                      style: TextStyle(fontSize: [10, 12, 13][_displaySize].toDouble(),
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          shadows: showShadows ? [Shadow(blurRadius: 1, color: cs.shadow.withValues(alpha: 0.25))] : null)),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: cs.onSurfaceVariant),
                      onSelected: (v) => _handleCategoryAction(v, cat),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'rename', child: Text('名前変更')),
                        const PopupMenuItem(value: 'add_sub', child: Text('サブカテゴリ追加')),
                        const PopupMenuItem(value: 'delete', child: Text('削除')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
          ...products.map((p) => _buildProductCard(p, depth + 1, cs, showShadows: showShadows)),
          ...children.map((child) => _buildCategoryTreeItem(child, depth + 1, cs, showShadows)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUncategorizedSection(ColorScheme cs, bool showShadows) {
    final uncategorized = _products.where((p) => p.categoryId == null).toList();
    final spacing = _kItemGap;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: spacing),
          child: Row(
            children: [
              Icon(Icons.label, size: [18, 22, 26][_displaySize].toDouble(), color: cs.onSurfaceVariant,
                  shadows: showShadows ? [Shadow(blurRadius: 2, color: cs.shadow.withValues(alpha: 0.35))] : null),
              const SizedBox(width: 8),
              Text('未分類',
                style: TextStyle(
                  fontSize: [12, 14, 16][_displaySize].toDouble(),
                  fontWeight: FontWeight.w500,
                  shadows: showShadows ? [Shadow(blurRadius: 1, color: cs.shadow.withValues(alpha: 0.3))] : null,
                )),
              const SizedBox(width: 8),
              Text('${uncategorized.length}',
                style: TextStyle(fontSize: [10, 12, 13][_displaySize].toDouble(), color: cs.onSurfaceVariant,
                    shadows: showShadows ? [Shadow(blurRadius: 1, color: cs.shadow.withValues(alpha: 0.25))] : null)),
            ],
          ),
        ),
        ...uncategorized.map((p) => _buildProductCard(p, 0, cs, showShadows: showShadows)),
      ],
    );
  }

  Widget _buildProductCard(Product product, int depth, ColorScheme cs, {bool showShadows = true}) {
    return LongPressDraggable<Product>(
      data: product,
      feedback: Material(
        elevation: 8,
        color: Colors.transparent,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(blurRadius: 8, color: cs.shadow.withValues(alpha: 0.3))],
          ),
          child: Icon(Icons.inventory_2, size: 24, color: cs.primary),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _buildProductCardContent(product, depth, cs, showShadows),
      ),
      child: _buildProductCardContent(product, depth, cs, showShadows),
    );
  }

  Widget _buildProductCardContent(Product product, int depth, ColorScheme cs, bool showShadows) {
    final priceStr = '¥${product.defaultUnitPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    final iconSize = _kIconSizes[_displaySize];
    final textS = _kTextSizes[_displaySize];
    final subS = _kSubTextSizes[_displaySize];
    final priceS = _kPriceSizes[_displaySize];
    return Card(
      margin: EdgeInsets.only(
        left: (depth > 0 ? depth * 16.0 : 0) + _kCardMarginH,
        right: _kCardMarginH,
        top: _kCardMarginV,
      ),
      elevation: showShadows ? 2 : 0,
      shadowColor: showShadows ? cs.shadow.withValues(alpha: 0.3) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openProductViewer(product),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _kCardPadH, vertical: _kCardPadV),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2, size: iconSize, color: cs.primary,
                  shadows: showShadows ? [Shadow(blurRadius: 2, color: cs.shadow.withValues(alpha: 0.35))] : null),
              SizedBox(width: _kIconTextGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: textS, fontWeight: FontWeight.w500)),
                    if (product.barcode != null)
                      Text('バーコード: ${product.barcode}',
                        style: TextStyle(fontSize: subS, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Text(priceStr, style: TextStyle(
                fontSize: priceS, fontWeight: FontWeight.bold, color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }

  // --- リスト表示 ---
  Widget _buildListView(ColorScheme cs) {
    final products = _filteredProducts;
    return ValueListenableBuilder<String>(
      valueListenable: inputStyleNotifier,
      builder: (context, inputStyle, _) {
        final showShadows = inputStyle == 'raised';
        return RefreshIndicator(
          onRefresh: _load,
          child: products.isEmpty
              ? Center(child: Text(_searchQuery.isNotEmpty ? '検索結果がありません' : '商品がありません'))
              : ListView.builder(
                  key: ValueKey('list_${products.length}_$_searchQuery'),
                  padding: const EdgeInsets.all(12),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) => _buildProductCard(products[i], 0, cs, showShadows: showShadows),
                ),
        );
      },
    );
  }

  // --- 操作 ---
  void _createProduct() async {
    final result = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductEditorScreen()),
    );
    if (result != null) _load();
  }

  void _openProductViewer(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProductViewer(
          product: product,
          onEdit: (p) async {
            final result = await Navigator.push<Product>(
              context,
              MaterialPageRoute(builder: (_) => ProductEditorScreen(product: p)),
            );
            if (result != null) _load();
          },
          onDelete: () async {
            await _productRepo.deleteProduct(product.id);
            _load();
          },
        ),
      ),
    ).then((_) => _load());
  }

  void _handleCategoryAction(String action, ProductCategory cat) async {
    switch (action) {
      case 'rename':
        final controller = TextEditingController(text: cat.name);
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('カテゴリ名変更'),
            content: TextField(controller: controller, autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
              FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('保存')),
            ],
          ),
        );
        if (name != null && name.isNotEmpty) {
          await _catRepo.save(cat.copyWith(name: name));
          _load();
        }
        break;
      case 'add_sub':
        final controller = TextEditingController();
        final name = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('サブカテゴリ追加'),
            content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: 'カテゴリ名')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
              FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('追加')),
            ],
          ),
        );
        if (name != null && name.isNotEmpty) {
          await _catRepo.save(ProductCategory(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, parentId: cat.id));
          _load();
        }
        break;
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('カテゴリ削除'),
            content: Text('「${cat.name}」を削除しますか？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
            ],
          ),
        );
        if (confirm == true) {
          await _catRepo.delete(cat.id);
          _load();
        }
        break;
    }
  }
}

// --- ビューアー画面 ---
class _ProductViewer extends StatelessWidget {
  final Product product;
  final Future<void> Function(Product) onEdit;
  final VoidCallback onDelete;

  const _ProductViewer({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final priceStr = '¥${product.defaultUnitPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: '削除',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('削除確認'),
                  content: Text('「${product.name}」を削除しますか？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
                  ],
                ),
              );
              if (confirm == true) {
                onDelete();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編集',
            onPressed: () => onEdit(product),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoRow('商品名', product.name, cs),
          _infoRow('単価', priceStr, cs),
          if (product.barcode != null) _infoRow('バーコード', product.barcode!, cs),
          if (product.modelNumber != null) _infoRow('型番', product.modelNumber!, cs),
          if (product.manufacturer != null) _infoRow('メーカー', product.manufacturer!, cs),
          if (product.category != null) _infoRow('カテゴリ', product.category!, cs),
          if (product.supplierName != null) _infoRow('仕入先', product.supplierName!, cs),
          if (product.stockQuantity != null) _infoRow('在庫数', '${product.stockQuantity}', cs),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
