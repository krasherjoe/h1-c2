import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../plugin_system/plugin_registry.dart';
import '../plugin_system/menu_item.dart';
import '../widgets/slide_to_unlock.dart';
import '../widgets/menu_category_header.dart';

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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _registry = PluginRegistry.instance;
  bool _loading = true;
  bool _statusEnabled = true;
  String _statusText = '販売アシスト1号 - 準備中';
  bool _historyUnlocked = false;
  final Set<String> _collapsedCategories = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_collapsedCategories.contains(category)) {
        _collapsedCategories.remove(category);
      } else {
        _collapsedCategories.add(category);
      }
    });
  }

  bool _isCategoryCollapsed(String category) => _collapsedCategories.contains(category);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _statusEnabled = prefs.getBool('dashboard_status_enabled') ?? true;
      _statusText = prefs.getString('dashboard_status_text') ?? '販売アシスト1号 - 準備中';
      _historyUnlocked = prefs.getBool('dashboard_history_unlocked') ?? false;
      _loading = false;
    });
  }

  void _navigate(BuildContext context, MenuItem item) {
    if (item.route == '/documents' && !_historyUnlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スライドでロックを解除してください')),
      );
      return;
    }
    Navigator.pushNamed(context, item.route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('D1:ダッシュボード'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              await _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSlideUnlock(),
                  if (_statusEnabled) _buildStatusBar(),
                  ..._buildMenuSections(),
                ],
              ),
            ),
    );
  }

  Widget _buildSlideUnlock() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _historyUnlocked
          ? Row(
              children: [
                Icon(Icons.lock_open, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('A2 ロック解除済')),
                OutlinedButton.icon(
                  onPressed: () async {
                    setState(() => _historyUnlocked = false);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('dashboard_history_unlocked', false);
                  },
                  icon: const Icon(Icons.lock),
                  label: const Text('再ロック'),
                ),
              ],
            )
          : SlideToUnlock(
              isLocked: !_historyUnlocked,
              lockedText: 'スライドでロック解除 (A2)',
              unlockedText: 'A2 解除済',
              onUnlocked: () async {
                setState(() => _historyUnlocked = true);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('dashboard_history_unlocked', true);
              },
            ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.secondary),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  List<Widget> _buildMenuSections() {
    final grouped = _registry.getMenuItemsByCategory();
    if (grouped.isEmpty) return const [];

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

    if (widgets.isEmpty) {
      widgets.add(const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('メニューが未設定です。'),
        ),
      ));
    }

    return widgets;
  }

  Widget _buildSection(String category, List<MenuItem> items) {
    final collapsed = _isCategoryCollapsed(category);
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
    return GestureDetector(
      onTap: () => _navigate(context, item),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12)),
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
