# h-1-core プロジェクト概要

> **マニフェスト**: `docs/manifest.yaml` に全プラグイン・コアテーブル・サービスの最新定義あり

## プロジェクト情報

- **プロジェクト名**: h-1-core (販売アシスト1号 コア版)
- **言語**: Dart 3.12.0+
- **フレームワーク**: Flutter 3.12.0+
- **目的**: 請求書・領収証発行、顧客・商品マスター管理

## 技術スタック

### 主要パッケージ
- `sqflite` ^2.3.0 - ローカルデータベース
- `path_provider` ^2.1.5 - ファイルパス取得
- `path` ^1.9.0 - パス操作
- `pdf` ^3.11.3 - PDF生成
- `printing` ^5.14.2 - 印刷機能
- `intl` ^0.20.2 - 国際化・日付フォーマット
- `crypto` ^3.0.7 - 暗号化
- `uuid` ^4.5.1 - UUID生成
- `shared_preferences` ^2.2.2 - 設定保存
- `http` ^1.6.0 - HTTP通信
- `url_launcher` ^6.3.2 - URL起動
- `flutter_email_sender` ^8.0.0 - メール送信
- `google_sign_in` ^6.1.0 - Google認証
- `googleapis` ^12.0.0 - Google API
- `camera` ^0.12.0+1 - カメラ
- `image_picker` ^1.1.2 - 画像選択
- `fl_chart` ^1.2.0 - チャート描画
- `qr_flutter` ^4.1.0 - QRコード生成
- `mobile_scanner` ^6.0.0 - QR/バーコードスキャン
- `geolocator` ^13.0.0 - GPS
- `flutter_contacts` ^1.1.0 - 連絡先
- `permission_handler` ^11.3.0 - 権限管理
- `google_generative_ai` ^0.4.7 - Gemini OCR

### 開発パッケージ
- `flutter_test` - テスト
- `sqflite_common_ffi` ^2.3.2 - テスト用DB
- `flutter_lints` ^6.0.0 - Lint

## プロジェクト構造

```
lib/
├── main.dart                    # エントリーポイント
├── constants/                   # 定数 (1ファイル)
│   └── screen_ids.dart          # 画面ID定数 (Sクラス)
├── models/                      # データモデル (12ファイル)
│   ├── customer_model.dart
│   ├── product_model.dart
│   ├── invoice_models.dart
│   ├── company_info.dart
│   ├── receipt_model.dart
│   ├── project_model.dart
│   ├── custom_field_model.dart
│   ├── customer_contact.dart
│   ├── document_type_colors.dart
│   ├── payment_schedule_model.dart
│   ├── product_category_model.dart
│   └── sync_log_entry.dart
├── plugin_system/               # プラグイン基盤 (9ファイル)
│   ├── plugin_interface.dart    # H1Plugin インターフェース
│   ├── plugin_registry.dart     # プラグイン登録・管理
│   ├── plugin_context.dart      # コア機能へのアクセス
│   ├── plugin_state_service.dart # プラグイン有効/無効状態
│   ├── core_plugin.dart         # コアプラグイン (メニュー一覧)
│   ├── dashboard_section.dart   # ダッシュボードセクションモデル
│   ├── screen_definition.dart   # 画面定義モデル
│   ├── menu_item.dart           # メニュー項目モデル
│   └── plugin_widgets.dart      # PluginAppBarTitle等
├── plugins/                     # プラグイン実装 (28ディレクトリ, 183ファイル)
│   ├── accounting/              # 旧会計 (非推奨)
│   ├── accounting2/             # 新会計 (仕訳・試算表・財務諸表)
│   ├── analysis/                # 売上分析・レポート
│   ├── analytics/               # アナリティクス
│   ├── ar/                      # 売掛金管理
│   ├── audit/                   # ハッシュチェーン監査
│   ├── backup/                  # ローカルバックアップ
│   ├── cases/                   # 案件管理
│   ├── communication/           # 通信プラグイン
│   ├── company/                 # 自社情報・法人切替
│   ├── conversion/              # 旧DB→新DB変換
│   ├── customers/               # 顧客マスター
│   ├── daily/                   # 日報・工数管理
│   ├── debug/                   # デバッグ (MMコマンド等)
│   ├── documents/               # 伝票管理 (見積/受注/納品/請求/領収)
│   ├── drivebackup/             # Google Drive バックアップ
│   ├── explorer/                # H1Explorer コア
│   ├── inventory/               # 在庫管理
│   ├── memorandum/              # 覚書管理
│   ├── pricelist/               # 価格表
│   ├── printer/                 # レシート印刷
│   ├── products/                # 商品マスター
│   ├── project/                 # プロジェクト管理
│   ├── purchase/                # 仕入管理
│   ├── quick_actions/           # クイックアクション
│   ├── settings/                # 設定
│   ├── suppliers/               # 仕入先マスター
│   └── sync/                    # グループ同期
├── screens/                     # 画面 (2ファイル)
│   ├── dashboard_screen.dart
│   └── plugin_management_screen.dart
├── services/                    # サービス層 (45ファイル)
│   ├── database/
│   │   ├── database_schema_core.dart  # コアDBスキーマ
│   │   └── database_utils.dart
│   ├── database_helper.dart     # DB初期化・マイグレーション
│   ├── customer_repository.dart # 顧客リポジトリ
│   ├── product_repository.dart  # 商品リポジトリ
│   ├── invoice_repository.dart  # 請求書リポジトリ
│   ├── history_repository.dart  # 履歴リポジトリ
│   ├── hash_utils.dart          # ハッシュチェーン
│   ├── error_reporter.dart      # エラー報告 (MM送信)
│   ├── mm_command_service.dart  # MMコマンドブリッジ
│   ├── sync_service.dart        # 同期サービス
│   ├── sync_queue.dart          # 同期キュー
│   └── ... (他35ファイル)
├── utils/                       # ユーティリティ (3ファイル)
│   ├── app_theme.dart           # テーマ定義
│   ├── theme_utils.dart         # textColorOn()等
│   └── font_cache.dart          # フォントキャッシュ
└── widgets/                     # 共通ウィジェット (20ファイル)
    ├── document_card.dart
    ├── document_item_card.dart
    ├── h1_form_field.dart
    ├── h1_text_field.dart
    ├── tabbed_workspace.dart
    └── ... (他15ファイル)
```

## データベース構造

### コアテーブル (database_schema_core.dart)
- `activity_logs` - 操作ログ
- `hash_chain` - ハッシュチェーン
- `electronic_bookkeeping` - 電子帳簿保存法対応 (PDF生成JSON)
- `sync_log` - 同期ログ
- `pdf_output_history` - PDF出力履歴
- `email_send_history` - メール送信履歴

### プラグイン別テーブル
- `documents` / `document_items` / `document_edit_logs` (documents)
- `invoices` / `invoice_items` / `payment_schedules` (documents - 旧互換)
- `customers` (customers)
- `products` / `product_categories` (products)
- `company_info` (company)
- `purchases` / `purchase_items` / `suppliers` (purchase)
- `daily_reports` / `time_logs` / `todo_tasks` / `tasks` (daily)
- `projects` (project)
- `cases` / `case_notes` (cases)
- `memorandums` / `memorandum_items` (memorandum)
- `audit_logs` (audit)
- `master_hidden` (core_plugin)
- `sync_config` / `permissions` / `sync_children` / `sync_notifications` (sync)
- `edit_logs` (edit_log_repository)
- `accounts` / `journal_entries` / `cash_transactions` (accounting2)

## プラグインシステム

### 設計思想
- コア機能は最小限に保つ
- 機能追加はプラグインで行う
- プラグイン間の依存関係を管理
- 動的なメニュー・ルート追加

### プラグインAPI
- `H1Plugin` インターフェース
- `PluginRegistry` でプラグイン管理
- `PluginContext` でコア機能へアクセス
- `PluginStateService` で有効/無効状態を永続化

### 登録プラグイン一覧 (26個)
CorePlugin, DocumentsPlugin, CustomersPlugin, ProductsPlugin, CompanyPlugin, SettingsPlugin, InventoryPlugin, PurchasePlugin, AnalysisPlugin, Accounting2Plugin, QuickActionsPlugin, ExplorerPlugin, BackupPlugin, ConversionPlugin, AuditPlugin, DebugPlugin, DriveBackupPlugin, ProjectPlugin, MemorandumPlugin, ArPlugin, DailyPlugin, PriceListPlugin, SuppliersPlugin, SyncPlugin, PrinterPlugin, CasesPlugin

## リポジトリ管理

⚠️ **重要**: GitHubにソースコードをアップロードしない

- **origin** (git.cyberius.biz): ソースコード管理用
- **github** (GitHub): APKとREADME.mdの公開専用

詳細は `AGENTS.md` を参照。

## 開発ガイドライン

### コーディング規約
- null安全性を遵守
- `mounted` チェック必須（StatefulWidget）
- コメントは最小限
- 絶対パス使用
- Material Design 3準拠

### 命名規則
- クラス: PascalCase
- 変数・関数: camelCase
- 定数: UPPER_SNAKE_CASE
- ファイル: snake_case.dart

### エラーハンドリング
- try-catch で適切にエラーをキャッチ
- ユーザーにわかりやすいエラーメッセージ
- debugPrint でログ出力

## ビルド・実行

### 開発環境
```bash
flutter run
```

### リリースビルド（Android）
```bash
flutter build apk --release
```

### テスト
```bash
flutter test
```

## 連絡先

プロジェクトオーナー: joe@cyberius.biz
