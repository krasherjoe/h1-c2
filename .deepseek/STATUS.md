# 進捗ステータス

**更新:** 2026-06-01 22:50
**作成者:** OpenCode

---

## 完了タスク一覧（全13タスク）

| # | タスク | 優先度 | 状態 |
|---|---|---|---|
| 1 | H1Explorer コア基盤実装 | P1 | ✅ |
| 2 | 顧客・商品プラグイン実装 | P1 | ✅ |
| 3 | 設定プラグイン実装 | P1 | ✅ |
| 4 | ルート繋ぎ込み修正 | - | ✅ |
| 5 | 伝票プラグイン実装 | P2 | ✅ |
| 6 | 在庫管理プラグイン実装 | P2 | ✅ |
| 7 | 仕入管理プラグイン実装 | P2 | ✅ |
| 8 | 分析レポートプラグイン実装 | P3 | ✅ |
| 9 | 会計収支プラグイン実装 | P3 | ✅ |
| 10 | ダッシュボード原型復元 + セクションシステム | P1 | ✅ |
| 11 | QuickActions プラグイン移植 | P1 | ✅ |
| 12 | **プラグイン有効/無効制御** | **P1** | ✅ |
| 13 | **DBスキーマプラグイン分解 + マイグレーション基盤** | **P1/P2** | ✅ |

---

## 今回の実装詳細

### 12. プラグイン有効/無効制御
- `PluginStateService` — SharedPreferencesで有効/無効状態を永続化
- `PluginRegistry` — `_disabledPlugins` Set、`setEnabled()` / `isEnabled()` / `activePlugins`
- `plugin_management_screen.dart` — SwitchトグルUI、依存関係警告ダイアログ、トグル不可プラグイン
- `dashboard_screen.dart` — `activePlugins` で無効プラグインのセクション除外
- `main.dart` — 起動時に保存済み状態を復元

### 13. DBスキーマプラグイン分解
- `database_schema_core.dart` → `activity_logs` + `hash_chain` のみに縮小
- 各プラグインの `createTables()` に該当テーブルを `IF NOT EXISTS` で移動:
  - CustomersPlugin: `customers`, `customer_product_prices`
  - ProductsPlugin: `products`, `product_categories`, オプションテーブル群
  - DocumentsPlugin: `invoices`, `invoice_items`, `payment_schedules`
  - PurchasePlugin: `suppliers`
  - SettingsPlugin: `company_info`

### 14. DBマイグレーション基盤
- `DatabaseHelper._databaseVersion` 2 にバンプ
- `upgradeDatabase()` にバージョンループ + `_migrateToVersion()` 実装
- `H1Plugin.migrate()` インターフェース追加（プラグイン単位のマイグレーションフック）
- `PluginRegistry.register()` で `createTables` 後に `migrate()` 呼び出し

---

## 待機中

- Cascadeからの新規タスクを `tasks/inbox/` で待機中
- 現在 `inbox/` は空

---

## アーキテクチャ現状

### プラグイン構成（12プラグイン）

| ID | プラグイン | トグル |
|---|---|---|
| `com.h1.core` | コアシステム | ❌ 常時有効 |
| `com.h1.plugin.settings` | 設定 | ❌ 常時有効 |
| `com.h1.plugin.quick_actions` | クイックアクション | ✅ |
| `com.h1.plugin.customers` | 顧客管理 | ✅ |
| `com.h1.plugin.products` | 商品管理 | ✅ |
| `com.h1.plugin.documents` | 伝票管理 | ✅ |
| `com.h1.plugin.purchase` | 仕入管理 | ✅ |
| `com.h1.plugin.inventory` | 在庫管理 | ✅ |
| `com.h1.plugin.analytics` | 分析レポート | ✅ |
| `com.h1.plugin.accounting` | 会計収支 | ✅ |
| (quotation) | 見積書 | ✅ |
| (built-in routes) | 請求書入力/履歴/プラグイン管理 | N/A |

### DBスキーマ配置

```
コアスキーマ (database_schema_core.dart)
├── activity_logs
└── hash_chain

各プラグインの createTables()
├── customers / customer_product_prices
├── products / product_categories / オプション系
├── invoices / invoice_items / payment_schedules
├── purchases / purchase_items / suppliers
├── stock_transactions (inventory)
├── company_info (settings)
├── payments (accounting)
└── (各プラグインの独自テーブル)
```

---

## git.cyberius.biz 最終push
- `e3d9312` — プラグイン有効/無効制御 + DBスキーマ分解 + マイグレーション基盤
