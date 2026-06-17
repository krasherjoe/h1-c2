# h-1-core プロジェクトコンテキスト

## プロジェクト情報

- **プロジェクト名**: h-1-core (販売アシスト1号 コア版)
- **言語**: Dart 3.12.0+ / Flutter 3.12.0+
- **目的**: 請求書・領収証発行、顧客・商品マスター管理
- **状態管理**: Provider/Riverpod/Bloc不使用、StatefulWidget + ValueNotifier + シンプルサービスクラス

### 主要パッケージ

| パッケージ | 用途 |
|---|---|
| `sqflite` ^2.3.0 | ローカルSQLite |
| `pdf` ^3.11.3 / `printing` ^5.14.2 | PDF生成・印刷 |
| `crypto` ^3.0.7 / `uuid` ^4.5.1 | ハッシュチェーン・ID生成 |
| `intl` ^0.20.2 | 日本語ロケール |
| `http` ^1.6.0 | Mattermost API |
| `google_sign_in` ^6.1.0 / `googleapis` ^12.0.0 | Google連携 |
| `google_generative_ai` ^0.4.7 | Gemini OCR |
| `fl_chart` ^1.2.0 / `qr_flutter` ^4.1.0 | グラフ・QRコード |
| `shared_preferences` ^2.2.2 | 設定保存 |

## コア設計思想（電帳法 + Hash Chain）

### 設計原則（必読：詳細は `docs/electronic_bookkeeping_hash_chain_justification.md`）

1. **メインDBは自由** — 電帳法の真の要件は「PDF再現可能」であり、DBの不変性ではない
2. **PDF生成JSONにHash Chainを適用** — 電帳法要件を充足する対象はこれだけ
3. **数学的事実は法的解釈に依存しない** — Hash chainの改ざん防止効果は数学的に保証

### DB構成（二層構造）

```
会社DB
├── メインテーブル（自由・変更可能）← 顧客・商品・取引など
└── 電帳法テーブル（PDF再現用）   ← PDF生成JSON + Hash chain
```

### PDF再現フロー

```
生成: メインDB → JSON作成 → Hash chain適用 → PDF生成 → 電帳法テーブル保存
再現: 電帳法テーブル → Hash検証 → PDF再生成
```

### コーディング時の指針

- メインDBは自由に変更・最適化可能
- PDF生成時に必要なデータを電帳法テーブルに保存
- 電帳法テーブルのJSONにHash chainを適用
- PDFはJSONから再現可能

## プロジェクト構造

```
lib/
├── main.dart                          # エントリポイント（全プラグイン登録）
├── constants/screen_ids.dart          # 画面ID定数（Sクラス）
├── models/                            # 共有ドメインモデル (12ファイル)
├── plugin_system/                     # プラグイン基盤 (9ファイル)
├── plugins/                           # プラグイン実装 (28ディレクトリ)
├── screens/                           # トップレベル画面 (2ファイル)
├── services/                          # 共有サービス層 (45ファイル)
│   └── database/
│       ├── database_schema_core.dart  # コアテーブル定義
│       └── database_utils.dart
├── utils/                             # ユーティリティ (3ファイル)
│   ├── app_theme.dart                 # テーマ定義
│   └── theme_utils.dart               # textColorOn()
└── widgets/                           # 共有ウィジェット (20ファイル)
```

> **マニフェスト**: `docs/manifest.yaml` に全プラグイン・コアテーブル・サービスの構造化定義あり（テストでバリデーション済み）

### コアテーブル

- `activity_logs` - 操作ログ
- `hash_chain` - ハッシュチェーン
- `electronic_bookkeeping` - 電帳法対応（PDF生成JSON）
- `sync_log` - 同期ログ
- `pdf_output_history` - PDF出力履歴
- `email_send_history` - メール送信履歴

## プラグインシステム

### アーキテクチャ

プラグインが任意のWidgetをダッシュボードにブロックとして挿入可能。画面ID・ルートの重複はPluginRegistryの登録時にバリデーション。

| ファイル | 責務 |
|---|---|
| `lib/plugin_system/plugin_interface.dart` | H1Plugin抽象クラス |
| `lib/plugin_system/plugin_registry.dart` | プラグイン登録・管理・ルート解決 |
| `lib/plugin_system/plugin_context.dart` | コア機能（DB, Prefs）へのアクセス |
| `lib/plugin_system/plugin_state_service.dart` | 有効/無効状態の永続化 |
| `lib/plugin_system/core_plugin.dart` | CorePlugin（全メニュー一覧） |
| `lib/plugin_system/screen_definition.dart` | 画面定義モデル（id, title, route, builder） |
| `lib/plugin_system/menu_item.dart` | メニュー項目モデル |
| `lib/plugin_system/plugin_widgets.dart` | PluginAppBarTitle等 |

### 仕組み

1. core_plugin.dart が main.dart で最初に登録される
2. PluginRegistry.register() がScreenDefinitionのID・ルート重複をチェック
3. DashboardScreen が全プラグインから dashboardSection を収集
4. priority順にソートしてレンダリング
5. 画面IDは PluginAppBarTitle が自動表示（`{ID}: {タイトル}`形式）

### プラグイン一覧 (26個)

CorePlugin, DocumentsPlugin, CustomersPlugin, ProductsPlugin, CompanyPlugin, SettingsPlugin, InventoryPlugin, PurchasePlugin, AnalysisPlugin, Accounting2Plugin, QuickActionsPlugin, ExplorerPlugin, BackupPlugin, ConversionPlugin, AuditPlugin, DebugPlugin, DriveBackupPlugin, ProjectPlugin, MemorandumPlugin, ArPlugin, DailyPlugin, PriceListPlugin, SuppliersPlugin, SyncPlugin, PrinterPlugin, CasesPlugin

### プラグインID形式

`com.h1.core.{domain}`（例: `com.h1.core.documents`）

### プラグインディレクトリ構造（各プラグイン）

```
{plugin}/
├── {plugin}_plugin.dart       # H1Plugin実装
├── screens/                   # 画面Widget
├── services/                  # サービス
├── models/                    # モデル
├── logic/                     # ビジネスロジック
├── explorer/                  # H1Explorer設定
└── widgets/                   # ウィジェット
```

## コーディング規約

### 命名規則

| 対象 | 規則 | 例 |
|---|---|---|
| クラス | PascalCase | `CustomerRepository` |
| 変数・関数 | camelCase | `fetchCustomerList()` |
| 定数 | UPPER_SNAKE_CASE | `MAX_ITEMS` |
| ファイル | snake_case | `customer_repository.dart` |

### 必須ルール

- null安全性を遵守（`!` の乱用禁止）
- `mounted` チェック必須（StatefulWidgetの非同期処理後）
- インポートは絶対パス（`package:h_1_core/...`）
- try-catch で適切なエラーハンドリング
- コメントは最小限（コードが自己説明的であること）
- constコンストラクタを積極使用
- final の積極的使用
- 早期リターン（ガード節）

### 禁止事項

1. GitHubへのソースコードpush
2. ハードコードされた認証情報
3. null安全性の無視（`!` の乱用）
4. mounted チェックなしの setState
5. 空の catch ブロック
6. 相対パスでのインポート
7. 過度なコメント
8. `Colors.black` / `Colors.white` の直指定（`textColorOn()` 経由以外）
9. `Colors.black26` / `Colors.black38` の直指定（代わりに `cs.shadow`）

## デザインルール

### 3層構造

```
壁紙（surfaceContainerLowest）     #E5E5E8(light) / #2C2C2E(dark)  影なし
  └─ カード（surface）             #F5F5F7(light) / #3A3A3D(dark)  二重影
       └─ 入力フォーム             設定で切替（立体/縁取り）
```

### カードの影

```dart
BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 8, offset: Offset(0, 2)),
BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: Offset(0, 4)),
```

### 文字色

`lib/utils/theme_utils.dart` の `textColorOn(背景色)` を使う（純白・純黒は入力フォーム内部とヘッダーのみ）。

### カラースキーム

`ColorScheme.fromSeed(seedColor: Colors.indigo)` を基準に壁紙色のみ上書き。

| プロパティ | 用途 |
|---|---|
| `primary` | AppBar背景、強調ボタン |
| `surface` | カード背景 |
| `surfaceContainerLowest` | 壁紙 |
| `shadow` | カード影色（alpha調整） |

### テーマ切替

`themeMode` は SharedPreferences の `theme_mode` キーから読む。`system`(default) / `light` / `dark`。

### UX原則（Mobile-First）

1. **選択するだけ**: テキスト入力を避け、タップ/スワイプで操作完了
2. **キーボード排除**: フィルタは任意入力、デフォルトルートではキーボード不要
3. **コンテキスト保持**: BottomSheet/インライン/ダイアログでUI完結
4. **スマホ前提**: タップターゲット44px以上、1アクション=1タップ
5. **即登録**: マスター不在時は簡易入力でその場で登録

### FABルール

H1ExplorerのFABは「種別選択→作成」の2ステップ。選択肢が1つならBottomSheetを表示せず直接実行。

### PDFプレビューボタン配置

AppBarアクションの `[Undo] [Redo] [PDF] [Save]` の位置に統一。アイコンは `Icons.picture_as_pdf`。

## 画面ID一覧

定数定義: `lib/constants/screen_ids.dart` の `S` クラス。

| ID | タイトル | ルート |
|---|---|---|
| D1 | 伝票管理 | `/documents` |
| C1 | 得意先マスター | `/customers` |
| P1 | 商品カテゴリ | `/products` |
| CI | 自社情報 | `/company` |
| TM | 法人切替 | `/company/switch` |
| SET | 設定 | `/settings` |
| INV | 在庫一覧 | `/inventory` |
| PUR | 仕入管理 | `/purchase` |
| SL | 仕入先一覧 | `/suppliers` |
| KJ | 会計 | `/accounting2` |
| RC | レシート読取 | `/receipt_photo` |
| IS | 案件管理 | `/cases` |
| SY | グループ同期 | `/sync` |
| PT | レシート印刷 | `/printer` |
| QA | クイックアクション | `/quick_actions/settings` |
| BK | バックアップ管理 | `/backup` |
| SA | 売上分析 | `/analysis/sales` |
| AD | ハッシュチェーン監査 | `/audit` |
| DB | デバッグ | `/debug` |
| PRJ | プロジェクト | `/projects` |
| MEMO | 覚書管理 | `/memorandum` |
| AR | 売掛金管理 | `/ar` |
| DR | 日報 | `/daily/reports` |
| PE | 価格表 | `/pricelist` |
| DK | Driveバックアップ | `/drivebackup` |

## 伝票ロジック

### あいまいモード

伝票DBは作業中のメモ。事実は取引相手に渡したPDF。

| 層 | 役割 | 完全性 |
|---|---|---|
| 伝票DB | 作業中メモ | 低い |
| PDF | 取引相手に渡した最終形 | 高い |
| ハッシュチェーン | PDFの改ざん検証 | 最も高い |

### 伝票種別

| 種別 | 厳格さ | 備考 |
|---|---|---|
| 見積 | 低い | 金額メモ |
| 納品 | 低い | 金額メモ |
| 請求 | 低い | 金額メモ＋振込先表示 |
| 領収 | 高い | 法的効力あり |
| 受注 | 高い | DBモード、productId参照 |

### 編集履歴

`document_edit_logs` テーブル、14日間保持、自動クリーンアップ。

### ハッシュ+QRコード

確定済み伝票のPDF末尾にSHA-256ハッシュとQRコードを追加。未発行（下書き）には表示されない。

## DV/DE レイアウトルール

### subject（件名）のデータ構造

DBカラム: `subject`（TEXT）1つ。保存時: `${title}\n${memo}`。読込時: `split('\n')` で分割（1行目→タイトル、2行目以降→メモ）。

- 改行コード: `\n`（LF）固定
- 件名が空でも保存可能（メモだけでも可）

## Google Sheets AI統合（=AI() 関数）

`SheetsSyncService` が分析スプレッドシートを作成。`=AI("プロンプト", セル範囲)` カスタム関数でGemini APIを呼び出すGASコードあり。

詳細は `.deepseek/context/google_sheets_ai_integration.md` 参照。

## MM Command Bridge

Mattermost h1-debugチャンネル経由で `!opencode <cmd>` 形式のコマンドを受信・実行。15秒間隔ポーリング、PAT認証。

### 利用可能コマンド

| コマンド | 説明 |
|---|---|
| `ping` | 疎通確認 |
| `mmcheck` | Mattermost API疎通診断 |
| `system.status` | システム状態 |
| `system.dump` | 全状態ダンプ |
| `db.send` | DBをMMにアップロード |
| `db.snapshot` / `db.restore` | DBスナップショット |
| `documents.stats` | 伝票統計 |

### 関連ファイル

- `lib/services/mm_command_service.dart` - ポーリング・実行・結果投稿
- `lib/services/debug_console.dart` - コマンドレジストリ
- `lib/plugins/debug/screens/debug_screen.dart` - PAT設定UI

## リポジトリ管理（重要）

- **origin**: `ssh://git@git.cyberius.biz/joe/h1-core.git`（ソースコード用）
- **github**: `https://github.com/krasherjoe/h1-core.git`（APK+READMEのみ公開）
- **絶対にGitHubにソースコードをpushしない**
- リリース: `scripts/push_all.sh v1.x.x`（APKビルド→GitHub Release→README自動更新）
- GitHubリリースは最新5件のみ保持

## mmcheck 手順

1. `mattermost_get_channel_messages` で `channel_id: "n6fr87ipuj8epc463o7fu7gdao"` (h1-debug) のメッセージを取得（limit: 10）
2. `### ⚠️ h-1-core エラー報告` を含む投稿を探す
3. エラー内容（version, message, detail, screen, stack）を解析し原因特定
4. ユーザーに日本語で報告、該当コードを調査して修正

## OpenCode 連携システム

`.deepseek/` ディレクトリでタスク管理。詳細は `.deepseek/README.md` 参照。

### ディレクトリ構造

```
.deepseek/
├── tasks/inbox/        # 新規タスク
├── tasks/in_progress/  # 作業中タスク
├── tasks/completed/    # 完了タスク
├── questions/pending/  # 回答待ち質問
├── questions/answered/ # 回答済み質問
├── context/            # プロジェクトコンテキスト
└── README.md
```

### 質問状ルール

質問状を出すべき場面: 要件矛盾、設計確認、複数の実装方法、参照先不明。

### エージェント役割

- **Cascade (Claude)**: タスク設計・投函・レビュー
- **OpenCode (DeepSeek V4 Flash)**: コーディング・実装・テスト・GitHubリリース
