import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_config.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../screens/product_editor_screen.dart';
import '../logic/product_data_loader.dart';
import '../logic/product_import_export.dart';
import '../models/product_explorer_item.dart';

class ProductExplorerConfig extends H1ExplorerConfig<ProductExplorerItem> {
  String _sortKey = 'name_asc';

  @override
  String get explorerTitle => 'P1:商品マスター';

  @override
  String get searchHint => '商品名・バーコードで検索';

  @override
  IconData get itemIcon => Icons.inventory_2;

  @override
  String get emptyMessage => '商品が登録されていません';

  @override
  List<SortOption> get sortOptions => [
        const SortOption(key: 'name_asc', label: '名前順'),
        const SortOption(key: 'name_desc', label: '名前順（降順）'),
        const SortOption(key: 'category_asc', label: 'カテゴリ順'),
        const SortOption(key: 'price_asc', label: '価格の安い順'),
        const SortOption(key: 'price_desc', label: '価格の高い順'),
      ];

  @override
  String get currentSortKey => _sortKey;

  @override
  void onSortChanged(String key) {
    _sortKey = key;
  }

  @override
  String? groupKey(ProductExplorerItem item) => item.product.category;

  @override
  Future<List<ProductExplorerItem>> fetchItems(String query) async {
    final repo = ProductRepository();
    List<Product> products;
    if (query.isNotEmpty) {
      products = await repo.searchProducts(query);
    } else {
      products = await repo.getAllProducts();
    }
    final list = List<Product>.from(products);
    sortProducts(list, _sortKey);
    return list.map((p) => ProductExplorerItem(p)).toList();
  }

  @override
  Widget buildViewer(BuildContext context, ProductExplorerItem item) {
    return ProductEditorScreen(product: item.product);
  }

  @override
  Widget buildEditor(BuildContext context, ProductExplorerItem? item) {
    return ProductEditorScreen(product: item?.product);
  }

  @override
  Future<bool> canDelete(ProductExplorerItem item) async => true;

  @override
  Future<void> deleteItem(ProductExplorerItem item) async {
    final repo = ProductRepository();
    await repo.deleteProduct(item.product.id);
  }

  @override
  List<({String id, IconData icon, String label})> get overflowActions => [
    (id: 'import', icon: Icons.file_upload, label: 'CSV取込'),
    (id: 'export', icon: Icons.file_download, label: 'CSV出力'),
  ];

  @override
  void onOverflowAction(
    BuildContext context,
    String id, {
    required VoidCallback onListChanged,
  }) async {
    switch (id) {
      case 'import':
        importCsv(context, onListChanged);
      case 'export':
        final repo = ProductRepository();
        final all = await repo.getAllProducts();
        exportCsv(all);
    }
  }
}
