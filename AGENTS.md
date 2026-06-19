# AI Agents向け開発ガイドライン

このファイルはあらゆるAI（OpenCode, Claude, Devin等）が最初に読むエントリポイント。
補足の参考資料は `.ai/context.md`（技術スタック・設計・規約）。

---

## 🔴 絶対ルール

### バージョン番号
- フォーマット: `v{Major}.{Minor}.{PATCH}` — PATCHは**必ず3桁ゼロ埋め**
- 例: `v1.3.001`, `v1.3.010`, `v1.3.100` （`v1.3.1`や`v1.3.10`は**禁止**）
- 機能追加もバグ修正も PATCH をインクリメント。MINOR は原則変えない
- MINOR を上げるのは DBスキーマ破壊的変更など区切りの良いタイミングのみ
- リリース前に必ず `pubspec.yaml` のバージョンを確認する

### リポジトリ
- **絶対にソースコードをGitHubにpushしてはならない**
- origin: `ssh://git@git.cyberius.biz/joe/h1-core.git`（Forgejo, ソースコード用）
- github: `https://github.com/krasherjoe/h1-core.git`（APK+READMEのみ）
- リリース: `bash scripts/push_all.sh v1.3.010`（一発で全工程＝ソースpush → README更新 → ローカルAPKビルド → GitHub Release）
- Forgejo Action は使用しない（ローカルビルドに統一）

### APK署名
- 鍵: `android/keystore/debug.keystore`（リポジトリ管理の共通鍵）
- パスワードはデフォルトdebug。`key.properties`（gitignore）で上書き可能
- **この鍵が変わると既存ユーザーのデータが全損する**。絶対に別の鍵で署名しない

### Google Client ID
- Android用 Client ID は `android/app/src/main/res/values/strings.xml` の `default_web_client_id` — **絶対に削除しない**
- iOS/Web用は `.env` + `--dart-define-from-file=.env` で注入（`.env` はgit管理外）
- Client Secret は不要（Flutterは公開クライアント）

### APKファイル名
- フォーマット: `h1-core-{version}.apk` — 例: `h1-core-v1.3.023.apk`
- `scripts/push_all.sh` の中で自動的に生成される（61行目）
- GitHub Releaseにアップロードされるファイル名はこのフォーマットに従う

### コード変更時の確認手順
1. 既存パターンを確認してから書く（近隣ファイルを読む）
2. 削除前に全参照を確認する（特に定数・設定値・Client ID）
3. 変更後は必ず `dart analyze` を通す（エラーを0にする）
4. コミット前に `git diff --stat` で意図したファイルだけが変わることを確認
5. ビルド成果物（`build/`, `*.apk`, `problems-report`）が含まれていないか確認

---

## プロジェクト概要

**h-1-core**（販売アシスト1号 コア版）
- 請求書・領収証発行、顧客・商品マスター管理
- Flutter製マルチプラットフォームアプリケーション
- 状態管理: StatefulWidget + ValueNotifier + シンプルサービスクラス

基本設計思想は `docs/electronic_bookkeeping_hash_chain_justification.md` を参照。

---

## コンテキスト管理

OpenCodeセッションへの知識注入は `.ai/context.md` を `.opencode/opencode.json` の `instructions` 経由で直接注入。
`.ai/context.md` を更新すれば即座に全セッションの知識が最新になる。

---

## タスク管理（`.deepseek/`）

タスクはファイルで管理する。OpenCodeがファイルを監視して実装、Cascade（Claude）がレビュー。

```
.deepseek/
├── tasks/
│   ├── inbox/          新規タスク（YYYYMMDD_HHMM_タスク名.md）
│   │   └── TEMPLATE.md  テンプレート
│   ├── in_progress/    OpenCode作業中
│   └── completed/      完了
├── questions/
│   ├── pending/        回答待ち（YYYYMMDD_HHMM_質問.md）
│   └── answered/       回答済み
└── README.md
```

### ワークフロー

Cascade → inbox (タスク投函) → OpenCode → in_progress (実装中) → 不明点は pending → Cascade → answered → 再開 → completed → Cascadeレビュー → マージ

### 質問状ルール

出すべき場面: 要件矛盾、設計確認、複数の実装方法、参照先不明。
質問状は `questions/pending/` に作成。回答は `answered/` に移動されたら確認。

### エージェント役割

- **Cascade (Claude)**: タスク設計・投函・レビュー
- **OpenCode (DeepSeek V4 Flash)**: コーディング・実装・テスト・GitHubリリース

---

## mmcheck 手順

1. `mattermost_get_channel_messages(channel_id: "n6fr87ipuj8epc463o7fu7gdao", limit: 10)`
2. `### ⚠️ h-1-core エラー報告` を含む投稿を探す
3. 内容（version, message, detail, screen, stack）を解析し原因特定・修正
4. ユーザーに日本語で報告する

## MM Command Bridge

Mattermost h1-debug 経由で `!opencode <cmd>` 形式のリモートコマンドを受信・実行（15秒間隔ポーリング、PAT認証）。

### 利用可能コマンド

| コマンド | 説明 |
|---------|------|
| `ping` | 疎通確認 |
| `mmcheck` | Mattermost API疎通診断 |
| `system.status` | システム状態（DBサイズ、登録数等） |
| `system.env` | 環境設定表示 |
| `system.dump` | 全状態ダンプ |
| `google.status` | Google認証状態表示 |
| `db.send` | DBをMMにアップロード |
| `db.snapshot` / `db.restore` | DBスナップショット管理 |
| `documents.stats` | 伝票統計 |

### 設定

1. デバッグ画面（`DB:デバッグ`）を開く
2. 「PAT設定」から Mattermost PAT を入力
3. 「MMポーリング」をONにする
4. h1-debug に `!opencode ping` → `pong` が返れば成功

### 関連ファイル

- `lib/services/mm_command_service.dart` — ポーリング・実行・結果投稿
- `lib/services/debug_console.dart` — コマンドレジストリ
- `lib/plugins/debug/screens/debug_screen.dart` — PAT設定UI

### 注意事項

- 開発専用、PATはSharedPreferencesに平文保存
- ポーリング間隔: 15秒（`mm_command_service.dart:84`）
- コマンドプレフィックス: `!opencode`（`mm_command_service.dart:19`）

---

## 用語

- **oldh1**: 販売アシスト1号の旧バージョン。`lib/screens/` 以下の旧UIコード
- **mm / mmcheck**: Mattermost接続確認。MCP tools または `DebugConsole` の `mmcheck` コマンドで実行
