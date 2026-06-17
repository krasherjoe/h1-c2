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
  String get explorerTitle => 'PR:${filterType?.label ?? '仕入管理'}';

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
  List<({IconData icon, String label, VoidCallback onTap})>? fabActions(
          BuildContext context) =>
      [
        (icon: Icons.edit_note, label: '手入力で新規作成', onTap: () => _openNewPurchase(context)),
      ];

  void _openNewPurchase(BuildContext context) {
    Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseEditor(purchase: null),
      ),
    ).then((result) {
      if (result != null) onListChanged?.call();
    });
  }

  @override
  Future<bool> canDelete(PurchaseModel item) async => item.isDraft;

  @override
  Future<void> deleteItem(PurchaseModel item) async {
    final repo = PurchaseRepository();
    await repo.delete(item.id);
  }
}
