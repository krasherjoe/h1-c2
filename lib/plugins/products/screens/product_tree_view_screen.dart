import 'package:flutter/material.dart';
import 'package:h_1_core/models/product_model.dart';
import 'package:h_1_core/models/product_category_model.dart';
import 'package:h_1_core/services/product_repository.dart';
import 'package:h_1_core/services/product_category_repository.dart';

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

  // D&D状態
  String? _draggingProductId;
  String? _dragSourceCategoryId;

  // 展開状態
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

  // ===== D&D =====

  void _startDrag(String productId, String sourceCategoryId) {
    setState(() {
      _draggingProductId = productId;
      _dragSourceCategoryId = sourceCategoryId;
    });
  }

  Future<void> _onDrop(String productId, String targetCategoryId) async {
    if (_draggingProductId == null) return;

    final originalProduct = _products.firstWhere((p) => p.id == productId);

    setState(() {
      _draggingProductId = null;
      _dragSourceCategoryId = null;
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
      _dragSourceCategoryId = null;
    });
  }

  // ===== カテゴリ CRUD =====

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
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _catRepo.delete(cat.id);
      await _load();
    }
  }

  // ===== フィルタリング =====

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

  // ===== レンダリング =====

  Widget _buildCategoryNode(
      ProductCategory cat, int depth, ColorScheme cs) {
    final children = _categories.where((c) => c.parentId == cat.id).toList();
    final products = _filteredProducts
        .where((p) => p.categoryId == cat.id)
        .toList();
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedCategories.contains(cat.id);
    final isSourceCategory = _draggingProductId != null &&
        _dragSourceCategoryId == cat.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _draggingProductId != null
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
          child: Container(
            padding: EdgeInsets.only(
                left: depth * 20.0, right: 8, top: 4, bottom: 4),
            decoration: isSourceCategory
                ? BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Row(
              children: [
                Icon(
                  hasChildren
                      ? (isExpanded
                          ? Icons.expand_more
                          : Icons.chevron_right)
                      : Icons.label,
                  size: 16,
                  color: const Color(0xFF8D6E63),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.folder,
                    size: 18, color: Color(0xFFFFCA28)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(cat.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500)),
                ),
                Text(
                  '${products.length + children.length}',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant
                          .withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      size: 18, color: cs.onSurfaceVariant),
                  onSelected: (v) {
                    if (v == 'rename') _renameCategory(cat);
                    if (v == 'add_sub') _addSubcategory(cat);
                    if (v == 'delete') _deleteCategory(cat);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'rename', child: Text('名前変更')),
                    const PopupMenuItem(
                        value: 'add_sub', child: Text('サブカテゴリ追加')),
                    const PopupMenuItem(
                        value: 'delete', child: Text('削除')),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          ...products.map((p) => _buildProductItem(p, depth + 1, cs)),
          ...children.map(
              (child) => _buildCategoryNode(child, depth + 1, cs)),
        ],
      ],
    );
  }

  Widget _buildProductItem(
      Product product, int depth, ColorScheme cs) {
    final isDragging = _draggingProductId == product.id;

    return InkWell(
      onLongPress: () =>
          _startDrag(product.id, product.categoryId ?? ''),
      onTap: () {
        // 商品ビューアを開く
      },
      child: Container(
        padding: EdgeInsets.only(
            left: depth * 20.0 + 20, right: 8, top: 4, bottom: 4),
        decoration: isDragging
            ? BoxDecoration(
                color: cs.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Row(
          children: [
            Icon(Icons.inventory_2, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDragging ? cs.primary : null,
                  fontWeight:
                      isDragging ? FontWeight.bold : null,
                ),
              ),
            ),
            if (product.barcode != null)
              Text(product.barcode!,
                  style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant)),
            const SizedBox(width: 8),
            Text(
              '¥${product.defaultUnitPrice.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUncategorizedSection(ColorScheme cs) {
    final uncategorized = _filteredProducts
        .where((p) => p.categoryId == null)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.folder_off,
                  size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text('カテゴリなし',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant)),
              const SizedBox(width: 8),
              Text('${uncategorized.length}',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        ...uncategorized.map(
            (p) => _buildProductItem(p, 1, cs)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // 検索バー
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: '商品名で検索...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        // ドラッグモード中のキャンセルボタン
        if (_draggingProductId != null)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('カテゴリをタップしてドロップ',
                        style: TextStyle(fontSize: 12))),
                TextButton(
                  onPressed: _cancelDrag,
                  child:
                      const Text('キャンセル', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        // ツリー表示
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      ..._categories
                          .where((c) => c.parentId == null)
                          .map((cat) =>
                              _buildCategoryNode(cat, 0, cs)),
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
