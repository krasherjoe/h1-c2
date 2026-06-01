import 'package:flutter/material.dart';
import 'h1_explorer_item.dart';

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
}
