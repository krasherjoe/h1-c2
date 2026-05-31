import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/product_model.dart';
import '../../models/product_category_model.dart';
import '../../services/product_repository.dart';
import '../../services/product_category_repository.dart';
import '../../services/activity_log_repository.dart';
import '../../services/permission_service.dart';
import '../../widgets/screen_id_title.dart';
import '../../widgets/paste_buffer_dialog.dart';
import '../screen_sve_simple_variant_editor.dart';
import '../screen_pv_product_variants.dart';
import '../screen_p1_product_editor.dart';
import 'widgets/product_list_view.dart';
import 'widgets/product_sort_menu.dart';
import 'widgets/product_card.dart';
import 'logic/product_data_loader.dart';
import 'logic/product_undo_manager.dart';
import 'logic/product_import_export.dart';
import 'logic/product_dialogs.dart';
import 'models/product_list_types.dart';

class ProductMasterScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showHidden;

  const ProductMasterScreen({
    super.key,
    this.selectionMode = false,
    this.showHidden = false,
  });

  @override
  State<ProductMasterScreen> createState() => _ProductMasterScreenState();
}

class _ProductMasterScreenState extends State<ProductMasterScreen> {
  final ProductRepository _productRepo = ProductRepository();
  final ProductCategoryRepository _categoryRepo = ProductCategoryRepository();
  final ActivityLogRepository _logRepo = ActivityLogRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<ProductCategory> _categories = [];
  Map<String, List<Product>> _variantsByParent = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortKey = 'name_asc';
  bool _showHidden = false;
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  final Set<String> _selectedCatIds = {};
  final Set<String> _expandedParentIds = {};
  final Set<String> _expandedCatIds = {};
  bool _breadcrumbMode = false;
  String? _currentCategoryId;
  List<BatchUndoEntry> _undoStack = [];
  List<BatchUndoEntry> _redoStack = [];

  bool get _treeMode => _searchQuery.isEmpty && !widget.showHidden;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final data = await loadProducts(
      repo: _productRepo,
      categoryRepo: _categoryRepo,
      mounted: mounted,
    );
    if (!mounted) return;
    if (data != null) {
      _products = data.parents;
      _variantsByParent = data.variantsByParent;
      _categories = data.categories;
      _applyFilter();
      unawaited(_migrateLegacy());
    }
    setState(() => _isLoading = false);
  }

  Future<void> _migrateLegacy() async {
    await migrateLegacyCategoryIds(
      products: _products,
      productRepo: _productRepo,
      categoryRepo: _categoryRepo,
    );
  }

  void _applyFilter() {
    _filteredProducts = applyFilter(
      products: _products,
      searchQuery: _searchQuery,
      showHidden: _showHidden,
      sortKey: _sortKey,
      variantsByParent: _variantsByParent,
    );
    setState(() {});
  }

  void _onSortChanged(String key) {
    setState(() => _sortKey = key);
    _applyFilter();
  }

  void _onSearchChanged(String query) {
    _searchQuery = query;
    _applyFilter();
  }

  void _pushUndo(BatchUndoEntry entry) {
    _undoStack.add(entry);
    _redoStack.clear();
    if (_undoStack.length > 20) _undoStack.removeAt(0);
  }

  void _onUndo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    _redoStack.add(entry);
    performUndo(entry, _logRepo, _loadProducts);
  }

  void _onRedo() {
    if (_redoStack.isEmpty) return;
    final entry = _redoStack.removeLast();
    _undoStack.add(entry);
    performRedo(entry, _loadProducts);
  }

  void _onCategoryTap(String catId) {
    setState(() {
      if (_expandedCatIds.contains(catId)) {
        _expandedCatIds.remove(catId);
      } else {
        _expandedCatIds.add(catId);
      }
    });
  }

  void _onCategoryDrop(String categoryId, Product product) {
    final cat = _categories.where((c) => c.id == categoryId).firstOrNull;
    if (product.parentId != null) return;
    final snapshot = ProductSnapshot(
      before: product.copyWith(),
      after: product.copyWith(category: cat?.name ?? '', categoryId: categoryId),
    );
    _pushUndo(BatchUndoEntry(type: 'move', snapshots: [snapshot]));
    _productRepo.saveProduct(product.copyWith(
      category: cat?.name ?? '',
      categoryId: categoryId,
    ));
    _applyFilter();
  }

  void _onProductTap(Product p) {
    if (_selectMode) {
      setState(() {
        if (_selectedIds.contains(p.id)) _selectedIds.remove(p.id);
        else _selectedIds.add(p.id);
      });
    } else if (widget.selectionMode) {
      if (p.isHidden) return;
      Navigator.pop(context, p);
    } else {
      _showEditDialog(product: p);
    }
  }

  void _onProductLongPress(Product p) {
    _showProductActionSheet(p);
  }

  void _onSelectProduct(Product p) {
    setState(() {
      if (_selectedIds.contains(p.id)) _selectedIds.remove(p.id);
      else _selectedIds.add(p.id);
    });
  }

  void _onDetailProduct(Product p) {
    showDetailPane(
      context: context,
      p: p,
      onEdit: () => _showEditDialog(product: p),
      onOptions: () => _navigateToOptions(p),
      onVariant: () => _showSimpleVariantEditor(p),
    );
  }

  Future<void> _navigateToOptions(Product p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductVariantsScreen(parent: p)),
    );
    _loadProducts();
  }

  Future<void> _showEditDialog({Product? product}) async {
    if (!await guardWrite(context, AppFeature.masterEdit)) return;
    if (!mounted) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductEditorScreen(product: product),
      ),
    );
    if (saved == true && mounted) _loadProducts();
  }

  void _showSimpleVariantEditor(Product parent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SimpleVariantEditorScreen(parent: parent),
      ),
    ).then((_) => _loadProducts());
  }

  void _showProductActionSheet(Product p) {
    final hasVariants = _variantsByParent[p.id]?.isNotEmpty ?? false;
    final expanded = _expandedParentIds.contains(p.id);
    showMenu<String>(
      context: context,
      position: RelativeRect.fill,
      items: buildProductMenuItems(p, hasVariants, expanded, _selectMode, widget.selectionMode),
    ).then((value) {
      if (!mounted || value == null) return;
      _onProductMenuAction(p, value);
    });
  }

  void _onProductMenuAction(Product p, String value) {
    switch (value) {
      case 'expand':
        setState(() {
          if (_expandedParentIds.contains(p.id)) _expandedParentIds.remove(p.id);
          else _expandedParentIds.add(p.id);
        });
      case 'edit':
        _showEditDialog(product: p);
      case 'options':
      case 'customer_price':
        _navigateToOptions(p);
      case 'variant':
        _showSimpleVariantEditor(p);
      case 'detail':
        _onDetailProduct(p);
      case 'select':
        setState(() { _selectMode = true; _selectedIds.add(p.id); });
      case 'delete':
        _confirmDeleteProduct(p);
    }
  }

  Future<void> _confirmDeleteProduct(Product p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('商品を削除'),
        content: Text('「${p.name}」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('削除', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final snapshot = ProductSnapshot(before: p);
    _pushUndo(BatchUndoEntry(type: 'delete', snapshots: [snapshot]));
    await _productRepo.deleteProduct(p.id);
    await _logRepo.logAction(
      action: 'delete', targetType: 'product',
      targetId: p.id, details: p.name, screenId: 'P1',
    );
    _loadProducts();
  }

  Future<void> _importFromPasteBuffer() async {
    if (!await guardWrite(context, AppFeature.masterEdit)) return;
    if (!mounted) return;
    final items = await showPasteBufferScreen(context);
    if (items.isEmpty) return;
    if (!mounted) return;
    for (final item in items) {
      final p = Product(
        id: const Uuid().v4(),
        name: item.name,
        defaultUnitPrice: item.price,
      );
      await _productRepo.saveProduct(p);
    }
    _loadProducts();
  }

  Future<void> _importCsv() async {
    await importCsv(context, _loadProducts);
  }

  void _exportCsv() {
    exportCsv(_products);
  }

  Future<void> _batchDelete() async {
    if (!await guardWrite(context, AppFeature.masterEdit)) return;
    final confirmed = await confirmBatchDelete(
      context: context,
      productCount: _selectedIds.length,
      categoryCount: _selectedCatIds.length,
    );
    if (!confirmed || !mounted) return;
    await productDialogsBatchDelete(
      context: context,
      productRepo: _productRepo,
      selectedIds: _selectedIds,
      selectedCatIds: _selectedCatIds,
      categoryRepo: _categoryRepo,
      onComplete: () {
        setState(() { _selectedIds.clear(); _selectedCatIds.clear(); _selectMode = false; });
        _loadProducts();
      },
    );
  }

  Future<void> _batchMoveCategory() async {
    final catId = await confirmBatchMoveCategory(
      context: context,
      categories: _categories,
    );
    if (catId == null || !mounted) return;
    final cat = _categories.where((c) => c.id == catId).firstOrNull;
    final snapshots = <ProductSnapshot>[];
    for (final id in _selectedIds) {
      final p = _products.firstWhere((p) => p.id == id, orElse: () => _products.first);
      snapshots.add(ProductSnapshot(
        before: p.copyWith(),
        after: p.copyWith(category: cat?.name ?? '', categoryId: catId),
      ));
      await _productRepo.saveProduct(p.copyWith(category: cat?.name ?? '', categoryId: catId));
    }
    _pushUndo(BatchUndoEntry(type: 'move', snapshots: snapshots));
    _loadProducts();
  }

  Future<void> _cleanupDuplicates() async {
    await cleanupDuplicateVersions(
      context: context,
      productRepo: _productRepo,
      onComplete: _loadProducts,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: _selectMode
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _selectMode = false; _selectedIds.clear(); _selectedCatIds.clear(); }))
            : const BackButton(),
        title: _selectMode
            ? Text('${_selectedIds.length}件＋${_selectedCatIds.length}カテゴリ')
            : const ScreenAppBarTitle(screenId: 'P1', title: '商品マスター'),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actionsPadding: const EdgeInsets.only(right: 8),
        actions: _selectMode
            ? <Widget>[
                IconButton(
                  icon: const Icon(Icons.select_all),
                  tooltip: '全選択',
                  onPressed: () => setState(() {
                    final allSelected = _selectedIds.length == _filteredProducts.length;
                    if (allSelected && _selectedCatIds.length == _categories.length) {
                      _selectedIds.clear(); _selectedCatIds.clear();
                    } else {
                      _selectedIds.addAll(_filteredProducts.map((p) => p.id));
                      _selectedCatIds.addAll(_categories.map((c) => c.id));
                    }
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: '選択を削除',
                  onPressed: _batchDelete,
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_move),
                  tooltip: 'カテゴリ移動',
                  onPressed: _selectedIds.isNotEmpty ? _batchMoveCategory : null,
                ),
              ]
            : <Widget>[
          if (_redoStack.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.redo),
              tooltip: 'やり直す（${_redoStack.length}）',
              onPressed: _onRedo,
            ),
          if (_undoStack.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: '操作を取り消す（${_undoStack.length}）',
              onPressed: _onUndo,
            ),
          IconButton(
            icon: const Icon(Icons.content_paste),
            tooltip: 'テキストから取込',
            onPressed: _importFromPasteBuffer,
          ),
          ProductSortMenu(
            currentSortKey: _sortKey,
            onChanged: _onSortChanged,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'その他',
            onSelected: (v) {
              switch (v) {
                case 'import': _importCsv();
                case 'export': _exportCsv();
                case 'cleanup': _cleanupDuplicates();
                case 'hidden' : setState(() => _showHidden = !_showHidden); _applyFilter();
                case 'select': setState(() => _selectMode = true);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.file_upload), title: Text('CSV取込'), dense: true)),
              const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.file_download), title: Text('CSV出力'), dense: true)),
              const PopupMenuItem(value: 'cleanup', child: ListTile(leading: Icon(Icons.cleaning_services), title: Text('重複を整理'), dense: true)),
              PopupMenuItem(value: 'hidden', child: ListTile(
                leading: Icon(_showHidden ? Icons.visibility : Icons.visibility_off),
                title: Text(_showHidden ? '非表示を隠す' : '非表示を表示'),
                dense: true,
              )),
              if (!_selectMode && !widget.selectionMode)
                const PopupMenuItem(value: 'select', child: ListTile(leading: Icon(Icons.checklist), title: Text('複数選択'), dense: true)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              heroTag: 'add_product',
              onPressed: () => _showEditDialog(),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '商品名・バーコード・カテゴリで検索',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        ProductListView(
          filteredProducts: _filteredProducts,
          categories: _categories,
          variantsByParent: _variantsByParent,
          expandedCatIds: _expandedCatIds,
          expandedParentIds: _expandedParentIds,
          breadcrumbMode: _breadcrumbMode,
          treeMode: _treeMode,
          currentCategoryId: _currentCategoryId,
          selectMode: _selectMode,
          selectionMode: widget.selectionMode,
          selectedIds: _selectedIds,
          onCategoryTap: _onCategoryTap,
          onCategoryDrop: _onCategoryDrop,
          onProductTap: _onProductTap,
          onProductLongPress: _onProductLongPress,
          onDetailProduct: _onDetailProduct,
          onSelectProduct: _onSelectProduct,
        ),
        if (_isLoading)
          Container(
            color: Colors.black12,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

Future<void> productDialogsBatchDelete({
  required BuildContext context,
  required ProductRepository productRepo,
  required Set<String> selectedIds,
  required Set<String> selectedCatIds,
  required ProductCategoryRepository categoryRepo,
  required VoidCallback onComplete,
}) async {
  var deleted = 0;
  for (final id in selectedIds) {
    try {
      await productRepo.deleteProduct(id);
      deleted++;
    } catch (e) {
      debugPrint('[P1] batch delete error: $e');
    }
  }
  for (final id in selectedCatIds) {
    try {
      await categoryRepo.deleteCategory(id);
      deleted++;
    } catch (e) {
      debugPrint('[P1] batch category delete error: $e');
    }
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$deleted件を削除しました')));
  onComplete();
}
