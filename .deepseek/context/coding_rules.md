# コーディング規約

## 基本原則

1. **シンプルに保つ**: 複雑な実装は避ける
2. **読みやすさ優先**: 他の人が読んでわかるコード
3. **DRY原則**: 同じコードを繰り返さない
4. **YAGNI原則**: 必要になるまで実装しない

## Dart/Flutter固有のルール

### Null安全性

```dart
// ✅ Good
String? nullableString;
String nonNullableString = 'value';

if (nullableString != null) {
  print(nullableString.length);
}

// ❌ Bad
String? value;
print(value!.length); // null チェックなしの強制アンラップ
```

### StatefulWidget

```dart
// ✅ Good
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void dispose() {
    // リソース解放
    super.dispose();
  }
  
  Future<void> _loadData() async {
    final data = await fetchData();
    if (!mounted) return; // 必須チェック
    setState(() {
      // 状態更新
    });
  }
}

// ❌ Bad
Future<void> _loadData() async {
  final data = await fetchData();
  setState(() { // mounted チェックなし
    // 状態更新
  });
}
```

### 非同期処理

```dart
// ✅ Good
Future<void> loadData() async {
  try {
    final data = await repository.fetchData();
    // 処理
  } catch (e) {
    debugPrint('Error: $e');
    // エラーハンドリング
  }
}

// ❌ Bad
Future<void> loadData() async {
  final data = await repository.fetchData(); // エラーハンドリングなし
}
```

## 命名規則

### クラス名

```dart
// ✅ Good
class CustomerRepository {}
class InvoiceInputScreen {}
class H1Plugin {}

// ❌ Bad
class customer_repository {}
class invoiceinputscreen {}
```

### 変数・関数名

```dart
// ✅ Good
final customerName = 'John';
void fetchCustomerList() {}
bool isLoading = false;

// ❌ Bad
final CustomerName = 'John';
void FetchCustomerList() {}
bool loading = false; // 意味が不明確
```

### 定数

```dart
// ✅ Good
const int MAX_ITEMS = 100;
const String DEFAULT_CURRENCY = 'JPY';

// ❌ Bad
const int maxItems = 100;
const String defaultCurrency = 'JPY';
```

### ファイル名

```dart
// ✅ Good
customer_repository.dart
invoice_input_screen.dart
plugin_interface.dart

// ❌ Bad
CustomerRepository.dart
InvoiceInputScreen.dart
pluginInterface.dart
```

## コメント

### 最小限に保つ

```dart
// ✅ Good - コードが自己説明的
final totalAmount = items.fold(0, (sum, item) => sum + item.amount);

// ❌ Bad - 不要なコメント
// 合計金額を計算する
final totalAmount = items.fold(0, (sum, item) => sum + item.amount);
```

### 必要な場合のみ

```dart
// ✅ Good - 複雑なロジックの説明
// 消費税は小数点以下切り捨て（国税庁の規定に準拠）
final tax = (subtotal * 0.1).floor();

// ✅ Good - TODOやFIXME
// TODO: 軽減税率対応
// FIXME: 端数処理のバグ修正
```

## インポート

### 順序

```dart
// 1. Dart標準ライブラリ
import 'dart:async';
import 'dart:convert';

// 2. Flutterパッケージ
import 'package:flutter/material.dart';

// 3. サードパーティパッケージ
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

// 4. プロジェクト内ファイル（絶対パス）
import 'package:h_1_core/models/customer.dart';
import 'package:h_1_core/services/database_helper.dart';
```

### 絶対パス使用

```dart
// ✅ Good
import 'package:h_1_core/models/customer.dart';

// ❌ Bad
import '../models/customer.dart';
import '../../services/database_helper.dart';
```

## エラーハンドリング

### 適切な例外処理

```dart
// ✅ Good
try {
  await database.insert('customers', customer.toMap());
} on DatabaseException catch (e) {
  debugPrint('Database error: $e');
  rethrow;
} catch (e) {
  debugPrint('Unexpected error: $e');
  throw Exception('Failed to save customer');
}

// ❌ Bad
try {
  await database.insert('customers', customer.toMap());
} catch (e) {
  // エラーを無視
}
```

### ユーザーへのフィードバック

```dart
// ✅ Good
try {
  await saveCustomer(customer);
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('保存しました')),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('保存に失敗しました: $e')),
  );
}
```

## ウィジェット構成

### 小さく分割

```dart
// ✅ Good
class CustomerListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }
  
  AppBar _buildAppBar() => AppBar(title: const Text('顧客一覧'));
  
  Widget _buildBody() => ListView.builder(
    itemBuilder: (context, index) => _buildCustomerCard(index),
  );
  
  Widget _buildCustomerCard(int index) => Card(
    child: ListTile(title: Text('Customer $index')),
  );
}

// ❌ Bad - 全部1つのメソッドに
class CustomerListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('顧客一覧')),
      body: ListView.builder(
        itemBuilder: (context, index) => Card(
          child: ListTile(title: Text('Customer $index')),
        ),
      ),
    );
  }
}
```

## データベース

### トランザクション使用

```dart
// ✅ Good
await database.transaction((txn) async {
  await txn.insert('invoices', invoice.toMap());
  for (final item in invoice.items) {
    await txn.insert('invoice_items', item.toMap());
  }
});

// ❌ Bad - トランザクションなし
await database.insert('invoices', invoice.toMap());
for (final item in invoice.items) {
  await database.insert('invoice_items', item.toMap());
}
```

## テスト

### テストの書き方

```dart
// ✅ Good
test('Customer.fromMap should create customer from map', () {
  final map = {
    'id': '123',
    'name': 'John Doe',
    'email': 'john@example.com',
  };
  
  final customer = Customer.fromMap(map);
  
  expect(customer.id, '123');
  expect(customer.name, 'John Doe');
  expect(customer.email, 'john@example.com');
});
```

## パフォーマンス

### 不要な再ビルドを避ける

```dart
// ✅ Good
class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return const Text('Hello');
  }
}

// ❌ Bad - const なし
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text('Hello');
  }
}
```

## プラグイン開発

### H1Plugin実装

```dart
// ✅ Good
class MyPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.my_plugin';
  
  @override
  String get name => 'マイプラグイン';
  
  @override
  Future<void> initialize(PluginContext context) async {
    // 初期化処理
  }
  
  @override
  Future<void> dispose() async {
    // クリーンアップ処理
  }
}
```

## 禁止事項

❌ **絶対にやってはいけないこと**

1. GitHubにソースコードをpush
2. ハードコードされた認証情報
3. null安全性の無視（`!` の乱用）
4. mounted チェックなしの setState
5. エラーの無視（空の catch ブロック）
6. 相対パスでのインポート
7. 過度なコメント
8. グローバル変数の乱用

## 推奨事項

✅ **推奨すること**

1. 早期リターン（ガード節）
2. const コンストラクタの使用
3. final の積極的な使用
4. 型推論の活用
5. 名前付き引数の使用
6. デフォルト値の設定
7. ドキュメンテーションコメント（公開API）
8. テストの作成
