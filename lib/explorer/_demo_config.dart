import 'package:flutter/material.dart';
import 'h1_explorer_item.dart';
import 'h1_explorer_config.dart';

class _DemoItem extends H1ExplorerItem {
  @override
  final String id;
  @override
  final String title;
  @override
  final String? subtitle;
  @override
  final String? badge;
  @override
  final IconData? icon;
  @override
  final DateTime? updatedAt;

  _DemoItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.badge,
    this.updatedAt,
  }) : icon = null;
}

class _DemoConfig extends H1ExplorerConfig<_DemoItem> {
  @override
  String get explorerTitle => 'デモ一覧';

  @override
  String get searchHint => 'デモを検索';

  @override
  IconData get itemIcon => Icons.widgets;

  @override
  String get emptyMessage => 'データがありません';

  @override
  Future<List<_DemoItem>> fetchItems(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final items = [
      _DemoItem(
        id: '1',
        title: 'アイテム1',
        subtitle: 'サブタイトル1',
        badge: 'デモ',
        updatedAt: DateTime.now(),
      ),
      _DemoItem(
        id: '2',
        title: 'アイテム2',
        subtitle: 'サブタイトル2',
        badge: 'テスト',
        updatedAt: DateTime.now(),
      ),
      _DemoItem(
        id: '3',
        title: 'アイテム3',
        badge: 'サンプル',
        updatedAt: DateTime.now(),
      ),
    ];
    if (query.isEmpty) return items;
    return items.where((i) => i.title.contains(query)).toList();
  }

  @override
  Widget buildViewer(BuildContext context, _DemoItem item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
          if (item.subtitle != null) ...[
            const SizedBox(height: 8),
            Text(item.subtitle!),
          ],
          if (item.badge != null) ...[
            const SizedBox(height: 8),
            Chip(label: Text(item.badge!)),
          ],
        ],
      ),
    );
  }

  @override
  Widget buildEditor(BuildContext context, _DemoItem? item) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item == null ? '新規作成モード' : '編集モード: ${item.title}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  @override
  Future<bool> canDelete(_DemoItem item) async => true;

  @override
  Future<void> deleteItem(_DemoItem item) async {}
}
