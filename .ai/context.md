# h-1-core プロジェクトコンテキスト

> **絶対ルール（バージョン番号・リポジトリ・APK署名・Google Client ID）は AGENTS.md を参照。**

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

**詳細**: `.ai/design_rules.md` を参照（テーマ配色、AppBar、文字色、入力フォームなどの完全なルール）

- **3層**: 壁紙（surfaceContainerLowest）→ カード（surface）→ 入力フォーム
- **文字色**: `textColorOn(背景色)` を使用。純白・純黒は入力フォーム内部とヘッダーのみ
- **テーマ**: `ColorScheme.fromSeed(seedColor: Colors.indigo)`
- **AppBar**: 必ず `ScreenAppBarTitle` を使用
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
