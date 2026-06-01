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

abstract class H1ExplorerConfig<T extends H1ExplorerItem> {
  String get explorerTitle;
  String get searchHint;
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
}
