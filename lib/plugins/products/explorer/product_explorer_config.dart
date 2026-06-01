import 'package:flutter/material.dart';
import '../../../explorer/h1_explorer_config.dart';
import '../../../services/product_repository.dart';
import '../../../screens/product_master/product_master_screen.dart';
import '../../../screens/screen_p1_product_editor.dart';
import '../models/product_explorer_item.dart';

class ProductExplorerConfig extends H1ExplorerConfig<ProductExplorerItem> {
  @override
  String get explorerTitle => '商品マスター';

  @override
  String get searchHint => '商品名で検索';

  @override
  IconData get itemIcon => Icons.inventory_2;

  @override
  String get emptyMessage => '商品が登録されていません';

  @override
  Future<List<ProductExplorerItem>> fetchItems(String query) async {
    final repo = ProductRepository();
    if (query.isNotEmpty) {
      final products = await repo.searchProducts(query);
      return products.map((p) => ProductExplorerItem(p)).toList();
    }
    final products = await repo.getAllProducts();
    return products.map((p) => ProductExplorerItem(p)).toList();
  }

  @override
  Widget buildViewer(BuildContext context, ProductExplorerItem item) {
    return const ProductMasterScreen(selectionMode: false);
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
}
