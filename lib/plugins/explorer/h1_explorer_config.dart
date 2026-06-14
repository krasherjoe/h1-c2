import 'package:flutter/material.dart';
import 'h1_explorer_item.dart';

class SortOption {
  final String key;
  final String label;

  const SortOption({
    required this.key,
    required this.label,
  });
}

/// A folder entry in the tree view
class TreeFolder {
  final String id;
  final String name;
  final int itemCount;
  final IconData icon;

  const TreeFolder({
    required this.id,
    required this.name,
    this.itemCount = 0,
    this.icon = Icons.folder,
  });
}

abstract class H1ExplorerConfig<T extends H1ExplorerItem> {
  String get explorerTitle;
  String get searchHint;
  bool get showSearch => false;
  bool get defaultTreeView => false;
  IconData get itemIcon;
  String get emptyMessage;

  Future<List<T>> fetchItems(String query);
  Widget buildViewer(BuildContext context, T item);
  Widget buildEditor(BuildContext context, T? item);
  Future<bool> canDelete(T item);
  Future<void> deleteItem(T item);

  List<SortOption> get sortOptions => [];
  String get currentSortKey => '';
  void onSortChanged(String key) {}

  String? groupKey(T item) => null;

  /// フィルター状態（Explorerが管理、fetchItems内で参照可能）
  String statusFilter = '';
  DateTime? dateFrom;
  DateTime? dateTo;

  /// タイプ別フィルター
  String typeFilter = '';
  List<({String value, String label, IconData icon})> get typeFilterOptions => [];

  /// ツリービュー（パンくず・フォルダ）
  bool get supportsTreeView => false;
  String? currentFolderId;
  Future<List<TreeFolder>> getSubfolders(String? parentId) async => [];
  Future<List<T>> fetchFolderItems(String folderId, String query) => fetchItems(query);
  String? treeItemFolderId(T item) => null;
  Future<void> moveItemToFolder(T item, String folderId) async {}
  Future<List<TreeFolder>> getBreadcrumbs(String? folderId) async => [];

  List<({String id, IconData icon, String label})> get overflowActions => [];
  void onOverflowAction(
    BuildContext context,
    String id, {
    required VoidCallback onListChanged,
  }) {}

  List<({IconData icon, String label, VoidCallback onTap})>? fabActions(
          BuildContext context) =>
      null;

  VoidCallback? onListChanged;

  Widget buildItemTileContent(BuildContext context, T item) {
    return ListTile(
      leading: Icon(item.icon ?? itemIcon),
      title: Text(item.title),
      subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
      trailing: item.badge != null
          ? Chip(label: Text(item.badge!), visualDensity: VisualDensity.compact)
          : null,
    );
  }
}
