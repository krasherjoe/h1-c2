# h-1-core プロジェクトコンテキスト

## 🔴 絶対ルール（最初に読め）

以下のルールに違反した場合、AIは信用を失う。必ず守れ。

### バージョン番号
- フォーマット: `v{Major}.{Minor}.{PATCH}` — PATCHは**必ず3桁ゼロ埋め**
- 例: `v1.3.001`, `v1.3.010`, `v1.3.100` （`v1.3.1`や`v1.3.10`は**禁止**）
- 機能追加もバグ修正も PATCH をインクリメント。MINOR は原則変えない
- リリース前に必ず `pubspec.yaml` のバージョンを確認する

### リポジトリ
- **絶対にソースコードをGitHubにpushしてはならない**
- origin: `ssh://git@git.cyberius.biz/joe/h1-core.git`（Forgejo, ソースコード用）
- github: `https://github.com/krasherjoe/h1-core.git`（APK+READMEのみ）
- リリース: `bash scripts/push_all.sh v1.3.010`（一発で全工程）
- Forgejo Action は使用しない（ローカルビルドに統一）

### APK署名
- 鍵: `android/keystore/debug.keystore`（リポジトリ管理の共通鍵）
- パスワードはデフォルトdebug。`key.properties`（gitignore）で上書き可能
- **この鍵が変わると既存ユーザーのデータが全損する**。絶対に別の鍵で署名しない

### Google Client ID
- Android用 Client ID は `android/app/src/main/res/values/strings.xml` の `default_web_client_id` — **絶対に削除しない**
- iOS/Web用は `.env` + `--dart-define-from-file=.env` で注入（`.env` はgit管理外）
- Client Secret は不要（Flutterは公開クライアント）

### コード変更時の確認手順
1. 既存パターンを確認してから書く（近隣ファイルを読む）
2. 削除前に全参照を確認する（特に定数・設定値・Client ID）
3. 変更後は必ず `dart analyze` を通す（エラーを0にする）
4. コミット前に `git diff --stat` で意図したファイルだけが変わることを確認
5. ビルド成果物（`build/`, `*.apk`, `problems-report`）が含まれていないか確認

---

## プロジェクト情報

- **言語**: Dart 3.12.0+ / Flutter 3.12.0+
- **目的**: 請求書・領収証発行、顧客・商品マスター管理
- **状態管理**: StatefulWidget + ValueNotifier + シンプルサービスクラス（Provider/Riverpod/Bloc不使用）

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

**詳細**: `docs/electronic_bookkeeping_hash_chain_justification.md`（必読）

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

## プロジェクト構造

```
lib/
├── main.dart                          # エントリポイント
├── constants/screen_ids.dart          # 画面ID定数（Sクラス）
├── models/                            # 共有ドメインモデル
├── plugin_system/                     # プラグイン基盤
├── plugins/                           # プラグイン実装 (28)
├── screens/                           # トップレベル画面
├── services/                          # 共有サービス層
├── utils/                             # ユーティリティ
└── widgets/                           # 共有ウィジェット
```

## プラグイン一覧

CorePlugin, DocumentsPlugin, CustomersPlugin, ProductsPlugin, CompanyPlugin, SettingsPlugin, InventoryPlugin, PurchasePlugin, AnalysisPlugin, Accounting2Plugin, QuickActionsPlugin, ExplorerPlugin, BackupPlugin, ConversionPlugin, AuditPlugin, DebugPlugin, DriveBackupPlugin, ProjectPlugin, MemorandumPlugin, ArPlugin, DailyPlugin, PriceListPlugin, SuppliersPlugin, SyncPlugin, PrinterPlugin, CasesPlugin

## コーディング規約

**命名**: クラス=PascalCase / 変数・関数=camelCase / 定数=UPPER_SNAKE_CASE / ファイル=snake_case
**インポート**: 絶対パス（`package:h_1_core/...`）のみ
**必須**: null安全 / `mounted` チェック / try-catch / const優先 / final優先 / 早期リターン

**禁止**: GitHubへのソースpush / ハードコード認証情報 / `!` 乱用 / 空catch / 相対パスimport / `Colors.black`/`Colors.white`直指定

## デザインルール

- **3層**: 壁紙（surfaceContainerLowest）→ カード（surface）→ 入力フォーム
- **文字色**: `textColorOn(背景色)` を使用。純白・純黒は入力フォーム内部とヘッダーのみ
- **テーマ**: `ColorScheme.fromSeed(seedColor: Colors.indigo)`
- **カードの影**:
  ```dart
  BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 8, offset: Offset(0, 2)),
  BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: Offset(0, 4)),
  ```

## 画面ID一覧

`lib/constants/screen_ids.dart` の `S` クラス。全IDはそちらを参照。

主なもの: D1=伝票管理, C1=得意先マスター, P1=商品カテゴリ, CI=自社情報, IS=案件管理, SET=設定

## 伝票ロジック

伝票DBは作業中のメモ（完全性:低）。事実は取引相手に渡したPDF（完全性:高）。ハッシュチェーンがPDFの改ざん検証（最高）。

**あいまいモード**: 確定済み伝票のみPDF末尾にSHA-256ハッシュ+QRコード。下書きには表示されない。

## コマンド（MM Command Bridge / DebugConsole）

| コマンド | 説明 |
|---|---|
| `ping` | 疎通確認 |
| `mmcheck` | Mattermost API疎通診断 |
| `system.status` | システム状態 |
| `system.env` | 環境設定表示 |
| `system.dump` | 全状態ダンプ |
| `google.status` | Google認証状態表示 |
| `db.send` / `db.snapshot` / `db.restore` | DB管理 |
| `documents.stats` | 伝票統計 |

## mmcheck手順

1. `mattermost_get_channel_messages(channel_id: "n6fr87ipuj8epc463o7fu7gdao", limit: 10)`
2. `### ⚠️ h-1-core エラー報告` を含む投稿を探す
3. 内容（version, message, detail, screen, stack）を解析し原因特定・修正

## OpenCode 連携システム

`.deepseek/` ディレクトリでタスク管理。`tasks/inbox/` → `in_progress/` → `completed/`。質問は `questions/pending/` → `answered/`。

- **Cascade (Claude)**: タスク設計・投函・レビュー
- **OpenCode (DeepSeek V4 Flash)**: コーディング・実装・テスト・GitHubリリース
