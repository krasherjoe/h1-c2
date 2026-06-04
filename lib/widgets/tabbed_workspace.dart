import 'package:flutter/material.dart';
import '../plugin_system/plugin_registry.dart';
import '../plugin_system/menu_item.dart';
import 'tab_navigator.dart';

class _TabInfo {
  final String id;
  final String title;
  final String route;
  final GlobalKey<NavigatorState> navigatorKey;
  _TabInfo({required this.id, required this.title, required this.route, required this.navigatorKey});
}

class TabbedWorkspace extends StatefulWidget {
  final Widget dashboard;

  const TabbedWorkspace({super.key, required this.dashboard});

  static TabbedWorkspaceState of(BuildContext context) {
    return context.findAncestorStateOfType<TabbedWorkspaceState>()!;
  }

  @override
  State<TabbedWorkspace> createState() => TabbedWorkspaceState();
}

class TabbedWorkspaceState extends State<TabbedWorkspace> {
  final _tabs = <_TabInfo>[];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs.add(_TabInfo(
      id: '',
      title: 'ダッシュボード',
      route: '__dashboard__',
      navigatorKey: GlobalKey<NavigatorState>(),
    ));
  }

  void openTab(String id, String title, String route) {
    final existing = _tabs.indexWhere((t) => t.route == route);
    if (existing >= 0) {
      setState(() => _currentIndex = existing);
      return;
    }
    setState(() {
      _tabs.add(_TabInfo(id: id, title: title, route: route, navigatorKey: GlobalKey<NavigatorState>()));
      _currentIndex = _tabs.length - 1;
    });
  }

  void closeTab(int index) {
    if (index == 0) return;
    _confirmCloseTab(index);
  }

  void switchToDashboard() {
    setState(() => _currentIndex = 0);
  }

  Future<void> _confirmCloseTab(int index) async {
    final tab = _tabs[index];
    final hasDeepNav = tab.navigatorKey.currentState?.canPop() ?? false;
    if (!hasDeepNav) {
      _doCloseTab(index);
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('タブを閉じる'),
        content: Text('「${tab.title}」には開いている画面があります。閉じますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('閉じる')),
        ],
      ),
    );
    if (ok == true && mounted) _doCloseTab(index);
  }

  void _doCloseTab(int index) {
    setState(() {
      _tabs.removeAt(index);
      if (_currentIndex >= _tabs.length) _currentIndex = _tabs.length - 1;
    });
  }

  Future<void> _confirmCloseAllTabs() async {
    final count = _tabs.length - 1;
    if (count == 0) return;
    final hasDeepNav = _tabs.skip(1).any(
      (t) => t.navigatorKey.currentState?.canPop() ?? false);
    final msg = hasDeepNav
      ? '$count個のタブには開いている画面があります。すべて閉じますか？'
      : '$count個のタブをすべて閉じますか？';
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('すべてのタブを閉じる'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('すべて閉じる')),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _tabs.removeRange(1, _tabs.length);
        _currentIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showBar = _tabs.length > 1;
    final narrow = _tabs.length > 5;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _tabs[_currentIndex].navigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_currentIndex != 0) {
          switchToDashboard();
        }
      },
      child: Column(
        children: [
          if (showBar)
            Container(
              height: 36,
              color: cs.surface,
              child: Row(
                children: [
                  _buildHomeTab(cs),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(right: 4),
                      itemCount: _tabs.length - 1,
                      itemBuilder: (ctx, i) => _buildTab(i + 1, cs, narrow),
                    ),
                  ),
                  _buildAddButton(cs),
                ],
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                widget.dashboard,
                for (final tab in _tabs.skip(1))
                  TabNavigator(
                    navigatorKey: tab.navigatorKey,
                    initialRoute: tab.route,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(ColorScheme cs) {
    final active = _currentIndex == 0;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = 0),
      onLongPress: _confirmCloseAllTabs,
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        width: 36,
        alignment: Alignment.center,
        child: Icon(Icons.home, size: 20,
          color: active ? cs.primary : cs.onSurfaceVariant),
      ),
    );
  }

  Widget _buildTab(int i, ColorScheme cs, bool narrow) {
    final tab = _tabs[i];
    final active = i == _currentIndex;
    final label = _tabLabel(tab, active, narrow);
    final inactiveBg = Color.lerp(cs.primaryContainer, cs.surface, 0.6)!;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = i),
      onLongPress: () => closeTab(i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? Color.lerp(cs.primaryContainer, cs.primary, 0.3)!
              : inactiveBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _tabLabel(_TabInfo tab, bool active, bool narrow) {
    if (active) return tab.title;
    if (narrow) return tab.id;
    return tab.title.length > 4 ? '${tab.title.substring(0, 4)}…' : tab.title;
  }

  Widget _buildAddButton(ColorScheme cs) {
    return GestureDetector(
      onTap: _showPluginPicker,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(Icons.add, size: 18, color: cs.onSurfaceVariant),
      ),
    );
  }

  void _showPluginPicker() {
    final registry = PluginRegistry.instance;
    final menuItems = registry.getAllMenuItems();
    final categories = <String, List<MenuItem>>{};
    for (final item in menuItems) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('開く画面を選択', style: Theme.of(context).textTheme.titleMedium),
            ),
            const Divider(),
            for (final entry in categories.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(entry.key,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
              ),
              for (final item in entry.value)
                ListTile(
                  leading: Icon(item.icon, size: 20),
                  title: Text(item.title, style: const TextStyle(fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    openTab(item.id, item.title, item.route);
                  },
                ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
