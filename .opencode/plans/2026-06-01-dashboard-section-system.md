# ダッシュボードセクションシステム 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** プラグインが任意のウィジェットをダッシュボードにブロックとして挿入できる機構を実装し、画面IDをPluginRegistryで一元管理する。

**Architecture:** PluginRegistry が CorePlugin を自動登録し、全プラグインの `DashboardSection` と `ScreenDefinition` を収集。DashboardScreen は収集したセクションを priority 順にレンダリングする。画面IDとルートの重複は register() 時にバリデーション。

**Tech Stack:** Flutter/Dart, PluginRegistry（既存）, SharedPreferences（クイックアクション保存）

---

## ファイル構成

### 作成ファイル
| # | パス | 責務 |
|---|---|---|
| 1 | `lib/plugin_system/dashboard_section.dart` | DashboardSection データクラス |
| 2 | `lib/plugin_system/screen_definition.dart` | ScreenDefinition データクラス |
| 3 | `lib/plugin_system/core_plugin.dart` | コアプラグイン（メニュー一覧セクション提供） |
| 4 | `lib/plugin_system/plugin_widgets.dart` | `PluginAppBarTitle` ヘルパーウィジェット |

### 修正ファイル
| # | パス | 変更内容 |
|---|---|---|
| 5 | `lib/plugin_system/plugin_interface.dart` | `screens`・`dashboardSection` getter 追加 |
| 6 | `lib/plugin_system/plugin_registry.dart` | 重複バリデーション・自動CorePlugin登録・getScreenByRoute |
| 7 | `lib/plugins/quick_actions/quick_actions_plugin.dart` | ルート削除 → dashboardSection 提供 |
| 8 | `lib/plugins/quick_actions/screens/quick_actions_screen.dart` | 埋め込み用 `QuickActionsPanel` にリファクタ |
| 9 | `lib/screens/dashboard_screen.dart` | セクション収集レンダリングに書き換え |
| 10 | `lib/main.dart` | CorePlugin 自動登録に伴う調整 |

---

### Task 1: DashboardSection モデル作成

**Files:**
- Create: `lib/plugin_system/dashboard_section.dart`

- [ ] **Step 1: DashboardSection クラスを書く**

```dart
import 'package:flutter/material.dart';

class DashboardSection {
  final String id;
  final String title;
  final String? description;
  final int priority;
  final WidgetBuilder builder;
  final bool collapsible;

  const DashboardSection({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.builder,
    this.collapsible = false,
  });
}
```

- [ ] **Step 2: コミット**

```bash
git add lib/plugin_system/dashboard_section.dart
git commit -m "feat: add DashboardSection model"
```

---

### Task 2: ScreenDefinition モデル作成

**Files:**
- Create: `lib/plugin_system/screen_definition.dart`

- [ ] **Step 1: ScreenDefinition クラスを書く**

```dart
import 'package:flutter/material.dart';

class ScreenDefinition {
  final String id;
  final String title;
  final String route;
  final WidgetBuilder builder;

  const ScreenDefinition({
    required this.id,
    required this.title,
    required this.route,
    required this.builder,
  });
}
```

- [ ] **Step 2: コミット**

```bash
git add lib/plugin_system/screen_definition.dart
git commit -m "feat: add ScreenDefinition model"
```

---

### Task 3: PluginAppBarTitle ヘルパー作成

**Files:**
- Create: `lib/plugin_system/plugin_widgets.dart`

- [ ] **Step 1: PluginAppBarTitle を書く**

```dart
import 'package:flutter/material.dart';
import 'plugin_registry.dart';

class PluginAppBarTitle extends StatelessWidget {
  final String fallbackTitle;

  const PluginAppBarTitle({super.key, this.fallbackTitle = ''});

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '/';
    final screen = PluginRegistry.instance.getScreenByRoute(route);
    if (screen != null) {
      return Text('${screen.id}: ${screen.title}');
    }
    return Text(fallbackTitle);
  }
}
```

- [ ] **Step 2: コミット**

```bash
git add lib/plugin_system/plugin_widgets.dart
git commit -m "feat: add PluginAppBarTitle helper widget"
```

---

### Task 4: H1Plugin インターフェース拡張

**Files:**
- Modify: `lib/plugin_system/plugin_interface.dart`

- [ ] **Step 1: plugin_interface.dart に screens と dashboardSection を追加**

編集前:
```dart
abstract class H1Plugin {
  // ... existing getters ...
  List<MenuItem> getMenuItems();
  Map<String, WidgetBuilder> getRoutes();
  Future<void> createTables(Database db);
  Widget? getSettingsScreen() => null;
}
```

編集後:
```dart
import 'dashboard_section.dart';
import 'screen_definition.dart';

abstract class H1Plugin {
  // ... existing getters stay the same ...
  List<MenuItem> getMenuItems();
  Map<String, WidgetBuilder> getRoutes();
  Future<void> createTables(Database db);
  Widget? getSettingsScreen() => null;
  List<ScreenDefinition> get screens => [];
  DashboardSection? get dashboardSection => null;
}
```

既存の import に `dashboard_section.dart` と `screen_definition.dart` を追加する。

- [ ] **Step 2: コミット**

```bash
git add lib/plugin_system/plugin_interface.dart
git commit -m "feat: add screens and dashboardSection to H1Plugin"
```

---

### Task 5: PluginRegistry 拡張（バリデーション・ルックアップ）

**Files:**
- Modify: `lib/plugin_system/plugin_registry.dart`

- [ ] **Step 1: register() に ScreenDefinition 重複チェックを追加**

編集前:
```dart
// 既存のフィールド
final Map<String, H1Plugin> _plugins = {};
PluginContext? _context;
bool _initialized = false;
```

編集後（フィールド追加 + register メソッド修正）:
```dart
// 既存のフィールド
final Map<String, H1Plugin> _plugins = {};
final Map<String, ScreenDefinition> _screensByRoute = {};
final Map<String, ScreenDefinition> _screensById = {};
PluginContext? _context;
bool _initialized = false;
```

編集前（register メソッド）:
```dart
Future<void> register(H1Plugin plugin) async {
  if (_plugins.containsKey(plugin.id)) {
    throw Exception('Plugin already registered: ${plugin.id}');
  }
  for (final dep in plugin.dependencies) {
    if (!_plugins.containsKey(dep) && dep != 'com.h1.core') {
      throw Exception('Dependency not found: ${plugin.id} requires $dep');
    }
  }
  if (_context != null) {
    await plugin.initialize(_context!);
    try { await plugin.createTables(_context!.database); }
    catch (e) { debugPrint('[PluginRegistry] Table creation error for ${plugin.id}: $e'); }
  }
  _plugins[plugin.id] = plugin;
  debugPrint('[PluginRegistry] Registered: ${plugin.name} v${plugin.version}');
}
```

編集後（register メソッド + 新規メソッド）:
```dart
Future<void> register(H1Plugin plugin) async {
  if (_plugins.containsKey(plugin.id)) {
    throw Exception('Plugin already registered: ${plugin.id}');
  }
  for (final screen in plugin.screens) {
    if (_screensById.containsKey(screen.id)) {
      throw Exception('Screen ID "${screen.id}" already registered');
    }
    if (_screensByRoute.containsKey(screen.route)) {
      throw Exception('Route "${screen.route}" already registered');
    }
  }
  for (final item in plugin.getMenuItems()) {
    if (_screensByRoute.containsKey(item.route)) {
      throw Exception('Route "${item.route}" already registered as a screen');
    }
  }
  for (final dep in plugin.dependencies) {
    if (!_plugins.containsKey(dep) && dep != 'com.h1.core') {
      throw Exception('Dependency not found: ${plugin.id} requires $dep');
    }
  }
  if (_context != null) {
    await plugin.initialize(_context!);
    try { await plugin.createTables(_context!.database); }
    catch (e) { debugPrint('[PluginRegistry] Table creation error for ${plugin.id}: $e'); }
  }
  for (final screen in plugin.screens) {
    _screensByRoute[screen.route] = screen;
    _screensById[screen.id] = screen;
  }
  _plugins[plugin.id] = plugin;
  debugPrint('[PluginRegistry] Registered: ${plugin.name} v${plugin.version}');
}

// 新規メソッド
ScreenDefinition? getScreenByRoute(String route) => _screensByRoute[route];
ScreenDefinition? getScreenById(String id) => _screensById[id];
List<ScreenDefinition> getAllScreenDefinitions() => _screensByRoute.values.toList();
```

> 注: `com.h1.core` は依存関係チェックで特別扱いされる。CorePlugin は main.dart で明示的に最初に登録する（自動登録は行わず、circular import を避ける）。

- [ ] **Step 2: コミット**

```bash
git add lib/plugin_system/plugin_registry.dart
git commit -m "feat: plugin registry validates screens, auto-registers CorePlugin"
```

---

### Task 6: CorePlugin 作成（メニュー一覧セクション提供）

**Files:**
- Create: `lib/plugin_system/core_plugin.dart`

- [ ] **Step 1: CorePlugin クラスを書く**

```dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'plugin_interface.dart';
import 'plugin_context.dart';
import 'plugin_permission.dart';
import 'plugin_registry.dart';
import 'dashboard_section.dart';
import '../widgets/menu_category_header.dart';
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
  @override Future<void> createTables(Database db) async {}
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
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
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
```

- [ ] **Step 2: コミット**

```bash
git add lib/plugin_system/core_plugin.dart
git commit -m "feat: add CorePlugin providing menu listing section"
```

---

### Task 7: QuickActionsPlugin リファクタ（独立画面削除・埋め込みパネル化）

**Files:**
- Modify: `lib/plugins/quick_actions/quick_actions_plugin.dart`
- Modify: `lib/plugins/quick_actions/screens/quick_actions_screen.dart`

- [ ] **Step 1: quick_actions_screen.dart を QuickActionsPanel に書き換え**

ファイル全体を以下の内容に置き換える:

```dart
import 'package:flutter/material.dart';
import '../services/quick_action_service.dart';
import '../models/quick_action_page.dart';
import '../widgets/quick_action_button.dart';

class QuickActionsPanel extends StatefulWidget {
  const QuickActionsPanel({super.key});
  @override
  State<QuickActionsPanel> createState() => _QuickActionsPanelState();
}

class _QuickActionsPanelState extends State<QuickActionsPanel> {
  final _service = QuickActionService();
  final _pageCtrl = PageController();
  List<QuickActionPage> _pages = [];
  int _currentPage = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pages = await _service.loadPages();
    if (!mounted) return;
    setState(() { _pages = pages; _loading = false; });
  }

  double _calcHeight() {
    if (_pages.isEmpty) return 120;
    final screenW = MediaQuery.of(context).size.width - 64;
    final btnW = 72.0;
    final gap = 4.0;
    final perRow = ((screenW + gap) / (btnW + gap)).floor().clamp(1, 10);
    final maxRows = _pages.fold(1, (max, page) {
      final rows = ((page.actionIds.length - 1) ~/ perRow) + 1;
      return rows > max ? rows : max;
    });
    return 8.0 + (maxRows * 72.0) + ((maxRows - 1) * 6.0) + 4.0;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    if (_pages.isEmpty) return const SizedBox.shrink();
    final actions = _service.allActions;
    return Column(
      children: [
        SizedBox(
          height: _calcHeight(),
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: _pages.map((page) {
              final gap = 4.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: gap,
                    runSpacing: 6,
                    children: page.actionIds.map((route) {
                      final item = actions[route];
                      if (item == null) return const SizedBox.shrink();
                      return SizedBox(
                        width: 72,
                        child: QuickActionButton(
                          icon: item.icon,
                          label: item.title,
                          accentColor: QuickActionService.accentFor(item),
                          onTap: () => Navigator.pushNamed(context, route),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_pages.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 2: quick_actions_plugin.dart を修正**

```dart
// import 追加
import '../../plugin_system/dashboard_section.dart';

class QuickActionsPlugin extends H1Plugin {
  // ... 既存の getter はそのまま ...

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/quick_actions/settings': (_) => const QuickActionSettingsScreen(),
  };

  @override
  DashboardSection? get dashboardSection => DashboardSection(
    id: 'quick_actions',
    title: 'クイックアクション',
    priority: 0,
    builder: (_) => const QuickActionsPanel(),
    collapsible: false,
  );
}
```

- [ ] **Step 3: コミット**

```bash
git add lib/plugins/quick_actions/
git commit -m "refactor: QuickActionsPlugin provides dashboard section instead of standalone route"
```

---

### Task 8: DashboardScreen 書き換え

**Files:**
- Modify: `lib/screens/dashboard_screen.dart`

- [ ] **Step 1: ダッシュボード全体を PluginRegistry のセクション収集に書き換え**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../plugin_system/plugin_registry.dart';
import '../plugin_system/dashboard_section.dart';
import '../plugin_system/plugin_widgets.dart';
import '../widgets/slide_to_unlock.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _statusEnabled = prefs.getBool('dashboard_status_enabled') ?? true;
      _statusText = prefs.getString('dashboard_status_text') ?? '販売アシスト1号 - 準備中';
      _historyUnlocked = prefs.getBool('dashboard_history_unlocked') ?? false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sections = _registry.allPlugins
      .map((p) => p.dashboardSection)
      .whereType<DashboardSection>()
      .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const PluginAppBarTitle(fallbackTitle: 'ダッシュボード'),
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
                  ...sections.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: s.builder(context),
                  )),
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
}
```

- [ ] **Step 2: コミット**

```bash
git add lib/screens/dashboard_screen.dart
git commit -m "refactor: DashboardScreen renders sections from plugin registry"
```

---

### Task 9: main.dart 整理

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: CorePlugin を最初に登録 + QuickActionsPlugin は維持**

CorePlugin の import を追加し、最初に登録:

```dart
// 追加
import 'plugin_system/core_plugin.dart';

// QuickActionsPlugin の import は維持
import 'plugins/quick_actions/quick_actions_plugin.dart';

// 登録部分（CorePlugin を最初に）
await registry.register(CorePlugin());
await registry.register(QuotationPlugin());
await registry.register(DocumentsPlugin());
// ... 残りはそのまま ...
await registry.register(AccountingPlugin());
await registry.register(QuickActionsPlugin());
```

- [ ] **Step 2: コミット**

```bash
git add lib/main.dart
git commit -m "chore: CorePlugin auto-registration, no manual import needed"
```

---

### Task 10: ビルド確認

- [ ] **Step 1: ビルド実行**

```bash
flutter build apk --debug 2>&1 | tail -20
```

Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 2: エラーがあれば修正して再ビルド**

よくある修正ポイント:
- import パス（plugin_system からの相対パス）
- `ScreenDefinition` / `DashboardSection` の import 漏れ
- `PluginRegistry` の `_registerCorePlugin` が `CorePlugin` を参照できるか（import と circular dependency に注意）
- `quick_actions_plugin.dart` に必要な import 追加

- [ ] **Step 3: プッシュ**

```bash
git add -A && git commit -m "fix: build errors after dashboard section refactor"
git push origin main
```
