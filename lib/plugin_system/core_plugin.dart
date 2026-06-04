import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'plugin_interface.dart';
import 'plugin_context.dart';
import 'plugin_permission.dart';
import 'plugin_registry.dart';
import 'dashboard_section.dart';
import '../widgets/menu_category_header.dart';
import '../widgets/tabbed_workspace.dart';
import 'menu_item.dart';

const List<String> _kCategoryOrder = [
  '販売', 'マスター', '仕入', '在庫', '会計', 'レポート', 'システム',
];

const Map<String, String> _kCategoryDesc = {
  '販売':     '見積〜請求までの販売プロセス',
  'マスター': '商品・顧客など基礎データ',
  '仕入':     '発注・仕入・支払を含む購買プロセス',
  '在庫':     '倉庫在庫の把握と移動・棚卸・調整',
  '会計':     '売掛・支払・資金繰り',
  'レポート': '売上・分析・集計レポート',
  'システム': '設定・ログなど基盤設定',
};

class CorePlugin extends H1Plugin {
  @override String get id => 'com.h1.core';
  @override String get name => 'コアシステム';
  @override String get version => '1.0.0';
  @override String get description => 'h-1-core 基盤システム';
  @override List<String> get dependencies => [];
  @override List<PluginPermission> get requiredPermissions => [];
  @override Future<void> initialize(PluginContext context) async {}
  @override Future<void> dispose() async {}
  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS master_hidden (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        master_type TEXT NOT NULL,
        master_id TEXT NOT NULL,
        is_hidden INTEGER DEFAULT 1,
        hidden_at TEXT NOT NULL,
        UNIQUE(master_type, master_id)
      )
    ''');
  }

  @override
  Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    if (fromVersion < 2) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS master_hidden (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            master_type TEXT NOT NULL,
            master_id TEXT NOT NULL,
            is_hidden INTEGER DEFAULT 1,
            hidden_at TEXT NOT NULL,
            UNIQUE(master_type, master_id)
          )
        ''');
      } catch (_) {}
    }
  }
  @override Widget? getSettingsScreen() => null;
  @override Map<String, WidgetBuilder> getRoutes() => {};

  @override
  DashboardSection? get dashboardSection => DashboardSection(
    id: 'menu_listing',
    title: '全メニュー',
    priority: 100,
    builder: (_) => const _CoreMenuSection(),
    collapsible: false,
  );
}

class _CoreMenuSection extends StatefulWidget {
  const _CoreMenuSection();
  @override
  State<_CoreMenuSection> createState() => _CoreMenuSectionState();
}

class _CoreMenuSectionState extends State<_CoreMenuSection> {
  final Set<String> _collapsedCategories = <String>{};

  void _toggleCategory(String category) {
    setState(() {
      if (_collapsedCategories.contains(category)) {
        _collapsedCategories.remove(category);
      } else {
        _collapsedCategories.add(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final grouped = PluginRegistry.instance.getMenuItemsByCategory();
    if (grouped.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('メニューが未設定です。'),
        ),
      );
    }
    final widgets = <Widget>[];
    final processed = <String>{};
    for (final category in _kCategoryOrder) {
      final items = grouped[category];
      if (items == null || items.isEmpty) continue;
      widgets.add(_buildSection(category, items));
      processed.add(category);
    }
    for (final entry in grouped.entries) {
      if (processed.contains(entry.key)) continue;
      widgets.add(_buildSection(entry.key, entry.value));
      processed.add(entry.key);
    }
    return Column(children: widgets);
  }

  Widget _buildSection(String category, List<MenuItem> items) {
    final collapsed = _collapsedCategories.contains(category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MenuCategoryHeader(
            title: category,
            description: _kCategoryDesc[category],
            collapsible: true,
            collapsed: collapsed,
            onToggle: () => _toggleCategory(category),
          ),
          AnimatedCrossFade(
            firstChild: Column(
              children: items.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _tile(e),
              )).toList(),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: collapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _tile(MenuItem item) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        final tw = context.findAncestorStateOfType<TabbedWorkspaceState>();
        if (tw != null) {
          tw.openTab(item.id, item.title, item.route);
        } else {
          Navigator.pushNamed(context, item.route);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(item.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    '${item.id.toUpperCase()} • ${item.route}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.description!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
