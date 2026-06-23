import 'package:flutter/material.dart';
import 'package:h_1_core/models/product_model.dart';
import 'package:h_1_core/models/product_category_model.dart';
import 'package:h_1_core/services/product_repository.dart';
import 'package:h_1_core/services/product_category_repository.dart';
import 'product_editor_screen.dart';

class ProductTreeView extends StatefulWidget {
  const ProductTreeView({super.key});

  @override
  State<ProductTreeView> createState() => _ProductTreeViewState();
}

class _ProductTreeViewState extends State<ProductTreeView> {
  final _productRepo = ProductRepository();
  final _catRepo = ProductCategoryRepository();

  List<Product> _products = [];
  List<ProductCategory> _categories = [];
  bool _loading = true;
  String _searchQuery = '';

  String? _draggingProductId;

  final _expandedCategories = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
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
  }

  List<Product> get _filteredProducts {
    var list = _products;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              (p.barcode?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  void _startDrag(String productId) {
    setState(() {
      _draggingProductId = productId;
    });
  }

  Future<void> _onDrop(String productId, String targetCategoryId) async {
    if (_draggingProductId == null) return;

    final originalProduct = _products.firstWhere((p) => p.id == productId);

    setState(() {
      _draggingProductId = null;
    });

    try {
      final updated = originalProduct.copyWith(categoryId: targetCategoryId);
      await _productRepo.saveProduct(updated);
      await _load();
    } catch (e) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('移動エラー: $e')),
        );
      }
    }
  }

  void _cancelDrag() {
    setState(() {
      _draggingProductId = null;
    });
  }

  Future<void> _renameCategory(ProductCategory cat) async {
    final controller = TextEditingController(text: cat.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カテゴリ名変更'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'カテゴリ名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty && newName != cat.name) {
      await _catRepo.save(cat.copyWith(name: newName));
      await _load();
    }
  }

  Future<void> _addSubcategory(ProductCategory parent) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('サブカテゴリ追加'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'カテゴリ名'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      final newCat = ProductCategory(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        parentId: parent.id,
      );
      await _catRepo.save(newCat);
      await _load();
    }
  }

  Future<void> _deleteCategory(ProductCategory cat) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('カテゴリ削除'),
        content: Text('「${cat.name}」を削除しますか？\nサブカテゴリは親に移動します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('削除', style: TextStyle(color: cs.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _catRepo.delete(cat.id);
      await _load();
    }
  }

  Widget _buildCategoryNode(ProductCategory cat, int depth, ColorScheme cs) {
    final children = _categories.where((c) => c.parentId == cat.id).toList();
    final products =
        _filteredProducts.where((p) => p.categoryId == cat.id).toList();
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedCategories.contains(cat.id);
    final isDragging = _draggingProductId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: isDragging
              ? () => _onDrop(_draggingProductId!, cat.id)
              : hasChildren
                  ? () => setState(() {
                      if (isExpanded) {
                        _expandedCategories.remove(cat.id);
                      } else {
                        _expandedCategories.add(cat.id);
                      }
                    })
                  : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            padding: EdgeInsets.only(left: depth * 24.0, right: 16),
            decoration: isDragging
                ? BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Row(
              children: [
                if (hasChildren)
                  Icon(
                    isExpanded ? Icons.expand_more : Icons.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  )
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.folder_open : Icons.folder,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${products.length + children.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: cs.onSurfaceVariant),
                  onSelected: (v) {
                    if (v == 'rename') _renameCategory(cat);
                    if (v == 'add_sub') _addSubcategory(cat);
                    if (v == 'delete') _deleteCategory(cat);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'rename', child: Text('名前変更')),
                    const PopupMenuItem(
                        value: 'add_sub', child: Text('サブカテゴリ追加')),
                    const PopupMenuItem(value: 'delete', child: Text('削除')),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          ...products.map((p) => _buildProductItem(p, depth + 1, cs)),
          ...children.map((child) => _buildCategoryNode(child, depth + 1, cs)),
        ],
      ],
    );
  }

  Widget _buildProductItem(Product product, int depth, ColorScheme cs) {
    final isDragging = _draggingProductId == product.id;
    final priceStr =
        '¥${product.defaultUnitPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    return InkWell(
      onTap: () async {
        final result = await Navigator.push<Product>(
          context,
          MaterialPageRoute(
            builder: (_) => ProductEditorScreen(product: product),
          ),
        );
        if (result != null) _load();
      },
      onLongPress: () => _startDrag(product.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        padding: EdgeInsets.only(left: depth * 24.0, right: 16),
        decoration: isDragging
            ? BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            const SizedBox(width: 28),
            const SizedBox(width: 8),
            Icon(Icons.inventory_2, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDragging ? cs.primary : cs.onSurface,
                      fontWeight:
                          isDragging ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (product.barcode != null)
                    Text(
                      product.barcode!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              priceStr,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUncategorizedSection(ColorScheme cs) {
    final uncategorized =
        _filteredProducts.where((p) => p.categoryId == null).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(Icons.folder_off, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                'カテゴリなし',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${uncategorized.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...uncategorized.map((p) => _buildProductItem(p, 1, cs)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: '商品名で検索...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        if (_draggingProductId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'カテゴリをタップしてドロップ',
                    style: TextStyle(fontSize: 12, color: cs.primary),
                  ),
                ),
                TextButton(
                  onPressed: _cancelDrag,
                  child: const Text('キャンセル'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._categories
                          .where((c) => c.parentId == null)
                          .map((cat) => _buildCategoryNode(cat, 0, cs)),
                      if (_filteredProducts
                          .any((p) => p.categoryId == null))
                        _buildUncategorizedSection(cs),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
