import 'package:flutter/material.dart';
import '../../../plugins/explorer/h1_explorer_config.dart';
import '../models/purchase_model.dart';
import '../services/purchase_repository.dart';
import 'purchase_viewer.dart';
import 'purchase_editor.dart';

class PurchaseExplorerConfig extends H1ExplorerConfig<PurchaseModel> {
  final PurchaseType? filterType;

  PurchaseExplorerConfig({this.filterType});

  @override
  String get explorerTitle => filterType?.label ?? '仕入管理';

  @override
  String get searchHint => '伝票番号・仕入先名で検索';

  @override
  IconData get itemIcon => Icons.shopping_cart;

  @override
  String get emptyMessage => '仕入伝票がありません';

  @override
  Future<List<PurchaseModel>> fetchItems(String query) async {
    final repo = PurchaseRepository();
    return repo.fetchAll(filterType: filterType, query: query);
  }

  @override
  Widget buildViewer(BuildContext context, PurchaseModel item) {
    return PurchaseViewer(purchase: item);
  }

  @override
  Widget buildEditor(BuildContext context, PurchaseModel? item) {
    return PurchaseEditor(purchase: item);
  }

  @override
  Future<bool> canDelete(PurchaseModel item) async => item.isDraft;

  @override
  Future<void> deleteItem(PurchaseModel item) async {
    final repo = PurchaseRepository();
    await repo.delete(item.id);
  }
}
