# アーキテクチャ

## プラグインシステム

### 概要
プラグインが任意の Widget をダッシュボードにブロックとして挿入できる機構。
画面ID・ルートの重複を PluginRegistry の登録時にバリデーション。

### 構成要素

| ファイル | 責務 |
|---|---|
| `lib/plugin_system/plugin_interface.dart` | H1Plugin インターフェース |
| `lib/plugin_system/plugin_registry.dart` | プラグイン登録・管理・ルート解決 |
| `lib/plugin_system/plugin_context.dart` | コア機能 (DB, SharedPreferences) へのアクセス |
| `lib/plugin_system/plugin_state_service.dart` | プラグイン有効/無効状態の永続化 |
| `lib/plugin_system/dashboard_section.dart` | DashboardSection モデル（id, title, priority, builder） |
| `lib/plugin_system/screen_definition.dart` | ScreenDefinition モデル（id, title, route, builder） |
| `lib/plugin_system/core_plugin.dart` | CorePlugin（全メニュー一覧セクション, priority:100） |
| `lib/plugin_system/plugin_widgets.dart` | PluginAppBarTitle（画面ID自動表示） |
| `lib/plugin_system/menu_item.dart` | MenuItem モデル |

### 仕組み

1. core_plugin.dart が main.dart で最初に登録される
2. PluginRegistry.register() が ScreenDefinition のID・ルート重複をチェック
3. DashboardScreen が全プラグインから `dashboardSection` を収集
4. priority 順にソートしてレンダリング
5. PluginStateService が有効/無効状態を SharedPreferences に保存

### 現在のセクション配置

| セクション | 提供元 | priority |
|---|---|---|
| クイックアクション | QuickActionsPlugin | 0 |
| 全メニュー一覧 | CorePlugin | 100 |

### 画面ID自動化
- PluginAppBarTitle が `ModalRoute` からルートを取得
- PluginRegistry.getScreenByRoute() で ScreenDefinition を検索
- `{ID}: {タイトル}` 形式で表示
- 定数は `lib/constants/screen_ids.dart` の `S` クラスで一元管理

## プラグイン一覧 (28ディレクトリ)

| プラグイン | 説明 | テーブル |
|---|---|---|
| accounting2 | 会計 (仕訳・試算表・財務諸表) | accounts, journal_entries, cash_transactions |
| analysis | 売上分析・レポート | - |
| analytics | アナリティクス | - |
| ar | 売掛金管理 | - |
| audit | ハッシュチェーン監査 | audit_logs |
| backup | ローカルバックアップ | - |
| cases | 案件管理 | cases, case_notes |
| communication | 通信 | - |
| company | 自社情報・法人切替 | company_info |
| conversion | 旧DB→新DB変換 | - |
| customers | 顧客マスター | customers |
| daily | 日報・工数管理 | daily_reports, time_logs, todo_tasks, tasks |
| debug | デバッグ (MMコマンド等) | - |
| documents | 伝票管理 (見積/受注/納品/請求/領収) | documents, document_items, document_edit_logs, invoices, invoice_items, payment_schedules |
| drivebackup | Google Drive バックアップ | - |
| explorer | H1Explorer コア | - |
| inventory | 在庫管理 | - |
| memorandum | 覚書管理 | memorandums, memorandum_items |
| pricelist | 価格表 | - |
| printer | レシート印刷 | - |
| products | 商品マスター | products, product_categories |
| project | プロジェクト管理 | projects |
| purchase | 仕入管理 | purchases, purchase_items, suppliers |
| quick_actions | クイックアクション | - |
| settings | 設定 | - |
| suppliers | 仕入先マスター | suppliers |
| sync | グループ同期 | sync_config, permissions, sync_children, sync_notifications |

## DBアーキテクチャ

### コアテーブル (database_schema_core.dart)
- `activity_logs` - 操作ログ
- `hash_chain` - ハッシュチェーン
- `electronic_bookkeeping` - 電子帳簿保存法対応 (PDF生成JSON)
- `sync_log` - 同期ログ
- `pdf_output_history` - PDF出力履歴
- `email_send_history` - メール送信履歴

### 設計思想
- メインDBは自由 (電帳法の真要件は「PDF再現可能」)
- PDF生成JSONにHash Chainを適用
- 数学的事実は法的解釈に依存しない

詳細は `docs/electronic_bookkeeping_hash_chain_justification.md` を参照。
