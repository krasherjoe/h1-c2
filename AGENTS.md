# AI Agents向け開発ガイドライン

## リポジトリ管理の重要なルール

### ⚠️ 絶対に守ること

**GitHubにソースコードをアップロードしてはならない**

- **GitHub (https://github.com/krasherjoe/h1-core)**: APKファイルとREADME.mdの公開専用
- **git.cyberius.biz (ssh://git@git.cyberius.biz/joe/h1-core.git)**: ソースコード管理用の本当のリポジトリ

### リモートリポジトリ設定

```bash
# ソースコード用 (メインリポジトリ)
origin: ssh://git@git.cyberius.biz/joe/h1-core.git

# APK公開用 (ソースコードは絶対にpushしない)
github: https://github.com/krasherjoe/h1-core.git
```

### 運用フロー

1. **ソースコードの変更**: `git push origin <branch>` でgit.cyberius.bizにpush
2. **APKのリリース**: GitHubにはgit pushでソースコードを送らない。以下の手順で行う:

   ```bash
   # 一発スクリプト (推奨)
   ./scripts/push_all.sh v1.1.0

   # 手動の場合:
   flutter build apk --release
   gh release create v1.1.0 \
     --title "v1.1.0" \
     --notes "リリースノート" \
     "build/app/outputs/flutter-apk/app-release.apk#h1-core-v1.1.0.apk"
   ```

3. **README.md**: `gh release create` 時に自動生成される。README.mdに大幅な変更があった場合は `scripts/push_all.sh` 経由でGitHubにpushする（APKと一緒に更新される）。

## プロジェクト概要

**h-1-core** (販売アシスト1号 コア版)
- 請求書・領収証発行
- 顧客・商品マスター管理
- Flutter製マルチプラットフォームアプリケーション

### 技術スタック

- Flutter SDK 3.12.0以上
- sqflite (ローカルデータベース)
- PDF生成 (pdf, printing)
- その他: path_provider, intl, crypto, uuid, shared_preferences

## OpenCode連携システム

### 概要

OpenCode（DeepSeek V4 Flash OpenCode）との連携用に `.deepseek/` ディレクトリを使用します。
タスクをファイルとして配置し、OpenCodeが読んで実装する仕組みです。

### ディレクトリ構造

```
.deepseek/
├── tasks/
│   ├── inbox/          # 新規タスクを置く場所
│   ├── in_progress/    # OpenCodeが作業中のタスク
│   └── completed/      # 完了したタスク
├── context/            # プロジェクトコンテキスト情報
│   ├── project_overview.md
│   ├── coding_rules.md
│   └── architecture.md
└── README.md
```

### タスク作成ルール

1. **ファイル名**: `YYYYMMDD_HHMM_タスク名.md`
   - 例: `20260601_1730_プラグインシステム実装.md`

2. **優先度**: ファイル名の先頭に付与可能
   - `P1_` = 最優先
   - `P2_` = 通常（デフォルト）
   - `P3_` = 低優先

3. **テンプレート**: `.deepseek/tasks/inbox/TEMPLATE.md` を参照

### ワークフロー

```
[あなた] タスク作成
  ↓
.deepseek/tasks/inbox/[タスク].md
  ↓
[OpenCode] タスク発見・作業開始
  ↓
.deepseek/tasks/in_progress/[タスク].md
  ↓ 不明点があれば
.deepseek/questions/pending/[タスク]_質問.md  ← 質問状を出す
  ↓
[あなた] 回答を記入 → answered/ に移動
.deepseek/questions/answered/[タスク]_質問.md
  ↓
[OpenCode] 回答を読んで作業再開
  ↓
[OpenCode] 実装完了
  ↓
.deepseek/tasks/completed/[タスク].md
  ↓
[あなた] レビュー & マージ
```

### 質問状のルール（OpenCode向け）

**質問状を出すべき場面:**
- タスクの要件が矛盾している
- 設計の方向性を確認したい
- 複数の実装方法があり選択が必要
- 参照先ファイルが見つからない

**質問状の作り方:**
1. `questions/pending/` に質問ファイルを作成
2. ファイル名: `YYYYMMDD_HHMM_[タスク名]_質問.md`
3. テンプレート: `.deepseek/questions/pending/TEMPLATE.md` を参照
4. 作業中タスクは `in_progress/` に残したまま待機すること

**回答の確認:**
- `questions/answered/` にファイルが移動していたら回答済み
- 回答欄を読んで作業を再開すること

### エージェントの役割分担

- **Cascade (Claude)**: タスク設計・投函・レビュー
- **OpenCode (DeepSeek V4 Flash)**: コーディング・実装・テスト・GitHubリリース（APK公開）

### タスク作成のコツ

- **具体的に書く**: 曖昧な指示は避ける
- **参考を示す**: 既存コードや設計書を参照
- **制約を明記**: やってはいけないことを書く
- **期待する出力を明示**: どのような実装を期待するか

### 注意事項

⚠️ `.deepseek/` ディレクトリは **git.cyberius.biz にのみpush**  
⚠️ GitHubにはソースコードを含むディレクトリをpushしない

## 用語

- **oldh1**: 販売アシスト1号の旧バージョン（h1-core以前）。`lib/screens/` 以下の旧UIコードを指す。`InvoicePdfPreviewPage` など。
- **mm / mmcheck**: Mattermost の接続状態を確認すること。MCPサーバーの Mattermost tools (`mattermost_get_user_status`, `mattermost_get_channel_messages` 等) を使用してチェックする。コード内の `DebugConsole` にも `mmcheck` コマンドが登録されている。

### mmcheck の正しい使い方

ユーザーから `mmcheck` または `mm` と言われたら以下の手順を実行すること:

1. `mattermost_get_channel_messages` で `channel_id: "n6fr87ipuj8epc463o7fu7gdao"` (h1-debugチャンネル) のメッセージを取得する
2. `limit: 10` 程度で最新のメッセージを取得
3. メッセージの中から `### ⚠️ h-1-core エラー報告` を含む投稿を探す
4. エラーメッセージの内容（version, message, detail, screen, stack）を解析し、問題の原因を特定する
5. 特定した原因をユーザーに日本語で報告する
6. エラーがある場合は、該当するコードを調査して修正する

詳細は `.deepseek/README.md` を参照してください。
