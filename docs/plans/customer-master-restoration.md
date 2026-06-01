# 顧客マスター本物移植計画

## 問題点

現在の h-1-core の顧客管理は H1Explorer 汎用システムでラップされており、
h-1.flutter.0 の本物の CustomerMasterScreen（295行）と乖離している。

### 現状の構成（問題あり）

```
CustomersPlugin.getRoutes()
  └── '/customers' → H1Explorer(config: CustomerExplorerConfig)
                        ├── viewer: CustomerMasterScreen (本物)
                        └── editor: CustomerEditScreen (15行スタブ)
```

- `CustomerMasterScreen` は既に独立した完全画面なのに H1Explorer で二重ラップ
- `CustomerEditScreen` は 730行→15行に削減され、編集機能が事実上死んでいる
- `CustomerRepository` は 815行から大幅に削減され、検索・履歴・連絡先機能が欠落

### 目指す構成

```
CustomersPlugin.getRoutes()
  ├── '/customers' → CustomerMasterScreen (直ルート)
  └── 編集/追加は CustomerMasterScreen 内から CustomerEditScreen (復元品) へ遷移
```

## 変更ファイル一覧

| # | ファイル | 作業 | 規模 |
|---|---|---|---|
| 1 | `lib/services/customer_repository.dart` | h-1.flutter.0版(815行)で上書き、Gmail同期除去 | 中 |
| 2 | `lib/screens/customer_edit_screen.dart` | h-1.flutter.0版(730行)で上書き、依存切って移植 | 大 |
| 3 | `lib/plugins/customers/customers_plugin.dart` | ルート直結、customer_contacts テーブル追加 | 小 |
| 4 | `lib/plugins/customers/explorer/customer_explorer_config.dart` | 削除 | 小 |
| 5 | `lib/plugins/customers/models/customer_explorer_item.dart` | 削除 | 小 |
| 6 | `lib/plugins/customers/explorer/` | ディレクトリ削除 | 小 |
| 7 | `lib/plugins/customers/models/` | ディレクトリ削除 | 小 |

## 移植方針

### repository (customer_repository.dart)

h-1.flutter.0 の 815行をベースに以下を調整:
- **削除:** `GmailSyncClient` 関連の全コード（gmail_sync_client.dart は h-1-core に未存在）
- **維持:** 全CRUD、getAllCustomers（JOIN含む）、searchCustomers、履歴管理、連絡先管理
- **維持:** `_safeAddColumn()` 動的マイグレーション
- **維持:** `ActivityLogRepository` による操作ログ記録
- **維持:** `hash_utils`, `hash_chain_verify_result` による改ざん検知
- **維持:** `CustomerContact` による連絡先バージョン管理

### edit screen (customer_edit_screen.dart)

h-1.flutter.0 の 730行をベースに以下を調整:
- **削除:** `flutter_contacts` インポート（デバイス連絡先連携不要）
- **削除:** `geolocator` インポート（GPS位置取得は切る。`lat`/`lng`表示は残す）
- **削除:** `contact_picker_sheet.dart` インポート（未移植）
- **削除:** `zoomable_app_bar.dart` インポート → プレーンAppBarに置換
- **削除:** `customer_rank_badge.dart` インポート → インラインWidget化
- **置換:** `sys_logger` → `debugPrint`
- **追加:** `ScreenAppBarTitle(screenId: 'C2', ...)` 採用

### plugin (customers_plugin.dart)

```dart
@override Map<String, WidgetBuilder> getRoutes() => {
  '/customers': (_) => const CustomerMasterScreen(),
};
```

`createTables()` に `customer_contacts` テーブル追加:
```sql
CREATE TABLE IF NOT EXISTS customer_contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  customer_id TEXT NOT NULL,
  address TEXT,
  tel TEXT,
  email TEXT,
  is_active INTEGER DEFAULT 1,
  version INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  FOREIGN KEY(customer_id) REFERENCES customers(id)
)
```

### 影響範囲

- `CustomerMasterScreen`: 変更なし（Viewerとしてそのまま動作）
- `customer_search_filter.dart`: 軽微な修正対応
- その他の customer_master/ サブファイル: 変更不要

## スキップする機能

- Google Drive バックアップ（後続タスク）
- Gmail 同期（後続タスク）
- デバイス連絡先インポート（h-1-coreでは不要）
- GPS 自動位置取得（地図表示がないため）
