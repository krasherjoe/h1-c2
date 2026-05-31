# 【設計・実装依頼】プラグインシステムの構築

## プロジェクト情報
- **プロジェクト名**: h-1-core
- **言語**: Dart 3.3.10
- **フレームワーク**: Flutter 3.10.7
- **前提**: コア分離完了済み（118ファイル、約15,000行、エラー0件）

---

## 背景

h-1-coreに機能を動的に追加できるプラグインシステムを実装します。
将来的にはGitHubから最新版をダウンロード・インストールできるようにします。

現在のh-1-coreは以下の機能のみを持つ最小コアです：
- ✅ 請求書入力・編集・削除
- ✅ 領収証発行
- ✅ PDF生成・印刷
- ✅ 顧客マスター（CRUD）
- ✅ 商品マスター（CRUD）
- ✅ 伝票履歴

今後、以下の機能をプラグインとして追加します：
- 見積・受注管理
- 在庫管理
- 会計管理（仕訳・試算表・決算書）
- GPS管理
- メール送信
- 定期請求
- 商品バリエーション

---

## 要件

### 機能要件
- [x] プラグインの登録・登録解除
- [x] プラグイン間の依存関係管理
- [x] プラグイン間通信（イベントバス）
- [x] プラグインからコア機能へのアクセス
- [x] プラグインの権限管理
- [x] ダッシュボードへのメニュー項目動的追加
- [x] ルートの動的追加
- [x] プラグインごとのデータベーステーブル作成

### 非機能要件
- 拡張性: 新規プラグインを容易に追加可能
- 安全性: プラグインの権限を制御
- パフォーマンス: プラグイン読み込みのオーバーヘッド最小化
- 保守性: プラグインの追加・削除が容易

---

## 期待する出力

### 1. プラグインAPI設計

```dart
// lib/plugin_system/plugin_interface.dart
abstract class H1Plugin {
  /// プラグインID（一意、例: com.h1.plugin.quotation）
  String get id;
  
  /// プラグイン名（表示用、例: 見積管理）
  String get name;
  
  /// バージョン（例: 1.0.0）
  String get version;
  
  /// 説明
  String get description;
  
  /// 依存プラグインID（例: ['com.h1.core']）
  List<String> get dependencies => ['com.h1.core'];
  
  /// 必要な権限
  List<PluginPermission> get requiredPermissions;
  
  /// 初期化
  Future<void> initialize(PluginContext context);
  
  /// 終了処理
  Future<void> dispose();
  
  /// ダッシュボードメニュー項目
  List<MenuItem> getMenuItems();
  
  /// ルート定義
  Map<String, WidgetBuilder> getRoutes();
  
  /// データベーステーブル作成
  Future<void> createTables(Database db);
  
  /// 設定画面（オプション）
  Widget? getSettingsScreen() => null;
}
```

### 2. プラグインコンテキスト

```dart
// lib/plugin_system/plugin_context.dart
class PluginContext {
  final Database database;
  final SharedPreferences preferences;
  
  PluginContext({
    required this.database,
    required this.preferences,
  });
  
  /// コアリポジトリへのアクセス
  InvoiceRepository get invoiceRepository => InvoiceRepository();
  CustomerRepository get customerRepository => CustomerRepository();
  ProductRepository get productRepository => ProductRepository();
  
  /// イベントバス
  PluginEventBus get eventBus => PluginEventBus.instance;
  
  /// サービス登録
  void registerService<T>(String name, T service) {
    _services[name] = service;
  }
  
  /// サービス取得
  T getService<T>(String name) {
    final service = _services[name];
    if (service == null) {
      throw Exception('Service not found: $name');
    }
    return service as T;
  }
  
  static final Map<String, dynamic> _services = {};
}
```

### 3. プラグイン権限

```dart
// lib/plugin_system/plugin_permission.dart
enum PluginPermission {
  readDatabase('データベース読み取り'),
  writeDatabase('データベース書き込み'),
  accessLocation('位置情報アクセス'),
  sendEmail('メール送信'),
  accessContacts('連絡先アクセス'),
  useCamera('カメラ使用'),
  accessStorage('ストレージアクセス');
  
  const PluginPermission(this.label);
  final String label;
}
```

### 4. メニュー項目

```dart
// lib/plugin_system/menu_item.dart
class MenuItem {
  final String id;
  final String title;
  final String route;
  final String category;
  final IconData icon;
  final String? description;
  
  const MenuItem({
    required this.id,
    required this.title,
    required this.route,
    required this.category,
    required this.icon,
    this.description,
  });
}
```

### 5. プラグインレジストリ

```dart
// lib/plugin_system/plugin_registry.dart
class PluginRegistry {
  static final PluginRegistry instance = PluginRegistry._();
  PluginRegistry._();
  
  final Map<String, H1Plugin> _plugins = {};
  PluginContext? _context;
  
  /// プラグイン登録
  Future<void> register(H1Plugin plugin) async {
    // 依存関係チェック
    for (final dep in plugin.dependencies) {
      if (!_plugins.containsKey(dep) && dep != 'com.h1.core') {
        throw Exception('Dependency not found: $dep');
      }
    }
    
    // 重複チェック
    if (_plugins.containsKey(plugin.id)) {
      throw Exception('Plugin already registered: ${plugin.id}');
    }
    
    // 初期化
    if (_context != null) {
      await plugin.initialize(_context!);
      
      // データベーステーブル作成
      await plugin.createTables(_context!.database);
    }
    
    // 登録
    _plugins[plugin.id] = plugin;
    
    debugPrint('✅ Plugin registered: ${plugin.name} v${plugin.version}');
  }
  
  /// プラグイン登録解除
  Future<void> unregister(String pluginId) async {
    final plugin = _plugins[pluginId];
    if (plugin == null) return;
    
    // 依存チェック（他のプラグインが依存していないか）
    final dependents = _findDependentPlugins(pluginId);
    if (dependents.isNotEmpty) {
      throw Exception(
        'Cannot unregister: ${dependents.join(", ")} depends on this plugin'
      );
    }
    
    // 終了処理
    await plugin.dispose();
    
    // 登録解除
    _plugins.remove(pluginId);
    
    debugPrint('🗑️ Plugin unregistered: ${plugin.name}');
  }
  
  /// コンテキスト設定
  void setContext(PluginContext context) {
    _context = context;
  }
  
  /// 全メニュー項目取得
  List<MenuItem> getAllMenuItems() {
    return _plugins.values
      .expand((p) => p.getMenuItems())
      .toList();
  }
  
  /// カテゴリ別メニュー項目
  Map<String, List<MenuItem>> getMenuItemsByCategory() {
    final items = getAllMenuItems();
    final Map<String, List<MenuItem>> result = {};
    
    for (final item in items) {
      result.putIfAbsent(item.category, () => []).add(item);
    }
    
    return result;
  }
  
  /// 全ルート取得
  Map<String, WidgetBuilder> getAllRoutes() {
    final routes = <String, WidgetBuilder>{};
    for (final plugin in _plugins.values) {
      routes.addAll(plugin.getRoutes());
    }
    return routes;
  }
  
  /// プラグイン取得
  H1Plugin? getPlugin(String pluginId) => _plugins[pluginId];
  
  /// 全プラグイン取得
  List<H1Plugin> get allPlugins => _plugins.values.toList();
  
  /// 依存プラグイン検索
  List<String> _findDependentPlugins(String pluginId) {
    return _plugins.values
      .where((p) => p.dependencies.contains(pluginId))
      .map((p) => p.name)
      .toList();
  }
}
```

### 6. イベントバス

```dart
// lib/plugin_system/plugin_event_bus.dart
class PluginEventBus {
  static final PluginEventBus instance = PluginEventBus._();
  PluginEventBus._();
  
  final Map<String, List<Function(dynamic)>> _listeners = {};
  
  /// イベント発行
  void emit(String eventName, dynamic data) {
    final listeners = _listeners[eventName];
    if (listeners == null) return;
    
    for (final listener in listeners) {
      try {
        listener(data);
      } catch (e) {
        debugPrint('Error in event listener: $e');
      }
    }
  }
  
  /// イベント購読
  void on(String eventName, Function(dynamic) handler) {
    _listeners.putIfAbsent(eventName, () => []).add(handler);
  }
  
  /// イベント購読解除
  void off(String eventName, Function(dynamic) handler) {
    _listeners[eventName]?.remove(handler);
  }
  
  /// 全イベント購読解除
  void clear() {
    _listeners.clear();
  }
}
```

### 7. ダッシュボード更新（プラグイン対応）

既存の `lib/screens/dashboard_screen.dart` を以下のように更新：

```dart
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _registry = PluginRegistry.instance;
  
  @override
  Widget build(BuildContext context) {
    final menusByCategory = _registry.getMenuItemsByCategory();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('販売アシスト1号 Core'),
        actions: [
          IconButton(
            icon: const Icon(Icons.extension),
            onPressed: () => Navigator.pushNamed(context, '/plugins'),
            tooltip: 'プラグイン管理',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // コア機能
          _buildCategorySection(
            context,
            title: 'コア機能',
            items: _getCoreMenuItems(),
          ),
          
          // プラグイン機能
          ...menusByCategory.entries.map((entry) =>
            _buildCategorySection(
              context,
              title: entry.key,
              items: entry.value,
            ),
          ),
        ],
      ),
    );
  }
  
  List<MenuItem> _getCoreMenuItems() {
    return [
      MenuItem(
        id: 'II',
        title: '請求書入力',
        route: '/invoice/input',
        category: 'コア機能',
        icon: Icons.description,
      ),
      MenuItem(
        id: 'IH',
        title: '請求書履歴',
        route: '/invoice/history',
        category: 'コア機能',
        icon: Icons.history,
      ),
      MenuItem(
        id: 'C1',
        title: '顧客マスター',
        route: '/customer/master',
        category: 'コア機能',
        icon: Icons.people,
      ),
      MenuItem(
        id: 'P1',
        title: '商品マスター',
        route: '/product/master',
        category: 'コア機能',
        icon: Icons.inventory,
      ),
    ];
  }
  
  Widget _buildCategorySection(
    BuildContext context, {
    required String title,
    required List<MenuItem> items,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: items.map((item) => _buildMenuCard(context, item)).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  Widget _buildMenuCard(BuildContext context, MenuItem item) {
    return Card(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 48),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (item.description != null)
              Text(
                item.description!,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
```

### 8. プラグイン管理画面

```dart
// lib/screens/plugin_management_screen.dart
class PluginManagementScreen extends StatefulWidget {
  const PluginManagementScreen({Key? key}) : super(key: key);

  @override
  State<PluginManagementScreen> createState() => _PluginManagementScreenState();
}

class _PluginManagementScreenState extends State<PluginManagementScreen> {
  final _registry = PluginRegistry.instance;
  
  @override
  Widget build(BuildContext context) {
    final plugins = _registry.allPlugins;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('プラグイン管理'),
      ),
      body: plugins.isEmpty
        ? const Center(
            child: Text('インストール済みプラグインはありません'),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plugins.length,
            itemBuilder: (context, index) {
              final plugin = plugins[index];
              return _buildPluginCard(plugin);
            },
          ),
    );
  }
  
  Widget _buildPluginCard(H1Plugin plugin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.extension, size: 40),
        title: Text(plugin.name),
        subtitle: Text('v${plugin.version}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plugin.description),
                const SizedBox(height: 8),
                if (plugin.dependencies.isNotEmpty) ...[
                  const Text(
                    '依存関係:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...plugin.dependencies.map((dep) => Text('  • $dep')),
                  const SizedBox(height: 8),
                ],
                if (plugin.requiredPermissions.isNotEmpty) ...[
                  const Text(
                    '必要な権限:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...plugin.requiredPermissions.map(
                    (perm) => Text('  • ${perm.label}'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

### 9. main.dart更新（プラグイン対応）

既存の `lib/main.dart` を以下のように更新：

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'plugin_system/plugin_registry.dart';
import 'plugin_system/plugin_context.dart';
import 'services/database_helper.dart';
import 'screens/dashboard_screen.dart';
import 'screens/plugin_management_screen.dart';
// 既存のインポート...

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // データベース初期化
  final db = await DatabaseHelper.instance.database;
  final prefs = await SharedPreferences.getInstance();
  
  // プラグインコンテキスト作成
  final context = PluginContext(
    database: db,
    preferences: prefs,
  );
  
  // プラグインレジストリ初期化
  final registry = PluginRegistry.instance;
  registry.setContext(context);
  
  // プラグイン読み込み（将来的にはGitHubから動的ロード）
  // await registry.register(QuotationPlugin());
  // await registry.register(InventoryPlugin());
  
  runApp(H1CoreApp(registry: registry));
}

class H1CoreApp extends StatelessWidget {
  final PluginRegistry registry;
  
  const H1CoreApp({required this.registry, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '販売アシスト1号 Core',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => const DashboardScreen(),
        '/plugins': (_) => const PluginManagementScreen(),
        // 既存のルート...
        '/invoice/input': (_) => InvoiceInputForm(),
        '/invoice/history': (_) => InvoiceHistoryScreen(),
        '/customer/master': (_) => CustomerMasterScreen(),
        '/product/master': (_) => ProductMasterScreen(),
        ...registry.getAllRoutes(), // プラグインルート追加
      },
    );
  }
}
```

### 10. サンプルプラグイン（見積管理）

```dart
// lib/plugins/quotation_plugin.dart
class QuotationPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.quotation';
  
  @override
  String get name => '見積管理';
  
  @override
  String get version => '1.0.0';
  
  @override
  String get description => '見積書の作成・編集・PDF出力機能を提供';
  
  @override
  List<String> get dependencies => ['com.h1.core'];
  
  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];
  
  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('Initializing Quotation Plugin...');
    // 初期化処理
  }
  
  @override
  Future<void> dispose() async {
    debugPrint('Disposing Quotation Plugin...');
    // 終了処理
  }
  
  @override
  List<MenuItem> getMenuItems() {
    return [
      MenuItem(
        id: 'Q1',
        title: '見積入力',
        route: '/quotation/input',
        category: '販売管理',
        icon: Icons.description,
        description: '見積書を作成',
      ),
      MenuItem(
        id: 'QH',
        title: '見積履歴',
        route: '/quotation/history',
        category: '販売管理',
        icon: Icons.history,
        description: '過去の見積を確認',
      ),
    ];
  }
  
  @override
  Map<String, WidgetBuilder> getRoutes() {
    return {
      '/quotation/input': (_) => const QuotationInputScreen(),
      '/quotation/history': (_) => const QuotationHistoryScreen(),
    };
  }
  
  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotations (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        document_number TEXT,
        issue_date TEXT,
        total INTEGER,
        status TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotation_items (
        id TEXT PRIMARY KEY,
        quotation_id TEXT,
        product_id TEXT,
        quantity REAL,
        unit_price INTEGER,
        amount INTEGER,
        FOREIGN KEY (quotation_id) REFERENCES quotations (id)
      )
    ''');
  }
}

// 簡易画面（スタブ）
class QuotationInputScreen extends StatelessWidget {
  const QuotationInputScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見積入力')),
      body: const Center(
        child: Text('見積入力画面（プラグイン）'),
      ),
    );
  }
}

class QuotationHistoryScreen extends StatelessWidget {
  const QuotationHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見積履歴')),
      body: const Center(
        child: Text('見積履歴画面（プラグイン）'),
      ),
    );
  }
}
```

---

## 出力形式

各ファイルごとに以下の形式で出力してください：

```
ファイル名: lib/[パス]/[ファイル名].dart
説明: [このファイルの役割]
---
[完全なコード]
---
```

---

## 制約・注意事項

1. **既存コードへの影響最小化**
   - 既存のコア機能に影響を与えない
   - main.dartとdashboard_screen.dartのみ更新

2. **型安全性**
   - null安全性を遵守
   - 適切な型定義

3. **エラーハンドリング**
   - プラグイン登録失敗時の適切なエラーメッセージ
   - 依存関係エラーの明確な表示

4. **パフォーマンス**
   - プラグイン読み込みのオーバーヘッド最小化
   - 遅延初期化の活用

5. **コーディング規約**
   - mounted チェック必須（StatefulWidget）
   - コメントは最小限
   - 絶対パス使用

---

## 実装手順（参考）

1. プラグインシステムディレクトリ作成
2. プラグインAPI実装（interface, context, permission, menu_item）
3. プラグインレジストリ実装
4. イベントバス実装
5. ダッシュボード更新
6. プラグイン管理画面作成
7. main.dart更新
8. サンプルプラグイン作成
9. 動作確認

---

## 質問・確認事項

1. プラグインAPIの設計は適切ですか？
2. イベントバスの実装方法は適切ですか？
3. プラグインの権限管理は十分ですか？
4. 他に必要な機能はありますか？

---

## 参考資料

- 既存プロジェクト: `/home/user/code/h-1-core/`
- プラグインシステム設計: `docs/planning/plugin_system_guide.md`（元プロジェクト）
- Flutter プラグインシステムのベストプラクティス

---

**この依頼書に従って、h-1-coreのプラグインシステムを完全に実装してください。**
