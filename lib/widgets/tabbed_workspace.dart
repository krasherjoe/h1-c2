import 'package:flutter/material.dart';
import '../plugin_system/plugin_registry.dart';
import '../plugin_system/menu_item.dart';
import 'tab_navigator.dart';

class _TabInfo {
  final String title;
  final String route;
  final GlobalKey<NavigatorState> navigatorKey;
  _TabInfo({required this.title, required this.route, required this.navigatorKey});
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
      title: 'ダッシュボード',
      route: '__dashboard__',
      navigatorKey: GlobalKey<NavigatorState>(),
    ));
  }

  void openTab(String title, String route) {
    final existing = _tabs.indexWhere((t) => t.route == route);
    if (existing >= 0) {
      setState(() => _currentIndex = existing);
      return;
    }
    setState(() {
      _tabs.add(_TabInfo(title: title, route: route, navigatorKey: GlobalKey<NavigatorState>()));
      _currentIndex = _tabs.length - 1;
    });
  }

  void closeTab(int index) {
    if (index == 0) return;
    setState(() {
      _tabs.removeAt(index);
      if (_currentIndex >= _tabs.length) _currentIndex = _tabs.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final showBar = _tabs.length > 1;

    return Column(
      children: [
        if (showBar)
          SizedBox(
            height: 38,
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    itemCount: _tabs.length,
                    itemBuilder: (ctx, i) => _buildTabChip(i, cs),
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
    );
  }

  Widget _buildTabChip(int i, ColorScheme cs) {
    final tab = _tabs[i];
    final active = i == _currentIndex;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = i),
      onLongPress: i == 0 ? null : () => closeTab(i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? cs.primaryContainer : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              i == 0 ? Icons.home : Icons.insert_drive_file,
              size: 14,
              color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              tab.title,
              style: TextStyle(
                fontSize: 13,
                color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant.withValues(alpha: 0.6),
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(ColorScheme cs) {
    return GestureDetector(
      onTap: _showPluginPicker,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Icon(Icons.add, size: 16, color: cs.onSurfaceVariant),
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
                    openTab(item.title, item.route);
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
