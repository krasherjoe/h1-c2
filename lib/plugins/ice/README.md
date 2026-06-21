# ICE-API Documentation

ICEデバッグプラグイン（ICE-API）は、AIによるDEBUG操作を可能にするHTTP APIサーバーです。

## 概要

- **目的**: AIによるアプリケーションDEBUG・テスト・監視
- **デフォルトポート**: 8080
- **アクセス方法**: SSHトンネル経由（localhost:8080）
- **認証**: 現在は認証なし（ローカルDEBUG用）

## 設定

### ポート設定
```
!opencode ice.start <port>
```
デフォルト: 8080

### SSHトンネル設定
ICE-APIはSSHトンネル経由でAIがアクセスします。SSH設定は以下の場所に保存されます：
- 設定ファイル: `<会社ディレクトリ>/.ssh/config`
- 秘密鍵: `<会社ディレクトリ>/.ssh/id_ed25519`

## エンドポイント一覧

### 基本エンドポイント

#### GET /health
ヘルスチェック

**レスポンス:**
```json
{
  "status": "ok",
  "service": "h-1-core ICE API",
  "version": "1.0.0"
}
```

#### GET /state
アプリ全体の状態を取得

**レスポンス:**
```json
{
  "workspace": {
    "active_company": "会社名",
    "companies": ["会社1", "会社2"]
  },
  "theme": {
    "mode": "system",
    "input_style": "raised"
  },
  "plugins": [
    {
      "id": "com.h1.core.backup",
      "name": "バックアップ",
      "enabled": true
    }
  ]
}
```

#### GET /errors
エラーログを取得

**レスポンス:**
```json
{
  "errors": [
    {
      "id": 1,
      "message": "エラーメッセージ",
      "stack_trace": "スタックトレース",
      "timestamp": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

#### DELETE /errors
エラーログを削除

**レスポンス:**
```json
{
  "status": "success",
  "deleted_count": 10
}
```

#### POST /command
DebugConsoleコマンドを実行

**リクエスト:**
```json
{
  "command": "backup.local.create",
  "args": []
}
```

**レスポンス:**
```json
{
  "result": "ローカルバックアップ作成完了: /path/to/backup.db (1024 KB)"
}
```

#### POST /db/query
DBクエリを実行

**リクエスト:**
```json
{
  "query": "SELECT * FROM customers LIMIT 10"
}
```

**レスポンス:**
```json
{
  "columns": ["id", "name", "email"],
  "rows": [
    [1, "顧客1", "customer1@example.com"]
  ]
}
```

#### GET /fs/read?path=...
ファイルを読み取り

**クエリパラメータ:**
- `path`: ファイルパス

**レスポンス:**
```json
{
  "path": "/path/to/file.txt",
  "content": "ファイル内容"
}
```

#### POST /fs/write
ファイルを書き込み

**リクエスト:**
```json
{
  "path": "/path/to/file.txt",
  "content": "ファイル内容"
}
```

**レスポンス:**
```json
{
  "status": "success",
  "path": "/path/to/file.txt"
}
```

#### GET /fs/list?path=...
ディレクトリ一覧を取得

**クエリパラメータ:**
- `path`: ディレクトリパス

**レスポンス:**
```json
{
  "path": "/path/to/dir",
  "files": [
    {
      "name": "file.txt",
      "type": "file",
      "size": 1024
    }
  ]
}
```

#### GET /fs/download?path=...
ファイルをダウンロード

**クエリパラメータ:**
- `path`: ファイルパス

**レスポンス:** ファイルのバイナリデータ

### APIエンドポイント

#### GET /api/workspace
ワークスペース情報を取得

**レスポンス:**
```json
{
  "active_company": "会社名",
  "companies": ["会社1", "会社2"]
}
```

#### GET /api/commands
利用可能なコマンド一覧を取得

**レスポンス:**
```json
{
  "commands": [
    {
      "name": "backup.local.create",
      "description": "ローカルバックアップ作成"
    }
  ]
}
```

#### GET /api/db/tables
DBテーブル一覧を取得

**レスポンス:**
```json
{
  "tables": ["customers", "products", "invoices"]
}
```

#### GET /api/preferences?key=...
設定を取得

**クエリパラメータ:**
- `key`: 設定キー（省略時は全設定）

**レスポンス:**
```json
{
  "key": "theme_mode",
  "value": "system"
}
```

#### GET /api/theme
テーマ情報を取得

**レスポンス:**
```json
{
  "mode": "system",
  "input_style": "raised",
  "navbar_style": "primary"
}
```

#### GET /api/projects
プロジェクト一覧を取得

**レスポンス:**
```json
{
  "projects": [
    {
      "id": 1,
      "name": "プロジェクト1",
      "status": "active"
    }
  ]
}
```

#### GET /api/errors
エラーログを取得（API版）

**レスポンス:**
```json
{
  "errors": [
    {
      "id": 1,
      "message": "エラーメッセージ",
      "timestamp": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

#### DELETE /api/errors
エラーログを削除（API版）

**レスポンス:**
```json
{
  "status": "success",
  "deleted_count": 10
}
```

#### GET /api/backup-status
バックアップ状態を取得

**レスポンス:**
```json
{
  "summary": {
    "total_operations": 100,
    "successful": 95,
    "failed": 5,
    "in_progress": 0
  },
  "by_type": {
    "local": {
      "total": 50,
      "successful": 48,
      "failed": 2
    },
    "drive": {
      "total": 50,
      "successful": 47,
      "failed": 3
    }
  }
}
```

#### GET /api/backup-history
バックアップ履歴を取得

**クエリパラメータ:**
- `limit`: 取得数（デフォルト: 10）

**レスポンス:**
```json
{
  "operations": [
    {
      "id": 1,
      "operation_type": "create",
      "backup_type": "local",
      "status": "completed",
      "file_path": "/path/to/backup.db",
      "file_size": 1024000,
      "created_at": "2024-01-01T00:00:00.000Z"
    }
  ]
}
```

#### GET /api/plugins/debug
全プラグインのDEBUG情報を取得

**レスポンス:**
```json
{
  "plugins": [
    {
      "id": "com.h1.core.backup",
      "name": "バックアップ",
      "version": "1.0.0",
      "enabled": true,
      "debug_info": {
        "last_backup": "2024-01-01T00:00:00.000Z",
        "backup_count": 10
      }
    }
  ]
}
```

#### GET /api/plugins/<id>/debug
特定プラグインのDEBUG情報を取得

**パスパラメータ:**
- `id`: プラグインID

**レスポンス:**
```json
{
  "id": "com.h1.core.backup",
  "name": "バックアップ",
  "version": "1.0.0",
  "enabled": true,
  "debug_info": {
    "last_backup": "2024-01-01T00:00:00.000Z",
    "backup_count": 10
  }
}
```

#### GET /api/screenshot
スクリーンショットを取得

**注意:** ICE-APIプラグインが有効な場合のみ使用可能

**レスポンス:**
```json
{
  "format": "png",
  "encoding": "base64",
  "data": "iVBORw0KGgoAAAANSUhEUgAA..."
}
```

#### GET /api/test/list
テストファイル一覧を取得

**レスポンス:**
```json
{
  "test_files": [
    "app_test.dart",
    "customer_test.dart"
  ],
  "count": 2
}
```

#### POST /api/test/run
テストを実行

**リクエスト:**
```json
{
  "test_file": "app_test.dart"
}
```

**レスポンス:**
```json
{
  "status": "success",
  "exit_code": 0,
  "stdout": "テスト出力",
  "stderr": "",
  "timestamp": "2024-01-01T00:00:00.000Z"
}
```

#### GET /api/test/result
最後のテスト結果を取得

**レスポンス:**
```json
{
  "isRunning": false,
  "lastRunTime": "2024-01-01T00:00:00.000Z",
  "lastResult": "テスト結果"
}
```

## DebugConsoleコマンド

ICE-APIに関連するDebugConsoleコマンド:

- `ice.status` - ICE-API状態確認
- `ice.start <port>` - ICE-API起動
- `ice.stop` - ICE-API停止

## バックアップコマンド

- `backup.local.create` - ローカルバックアップ作成
- `backup.local.list` - ローカルバックアップ一覧
- `backup.local.restore <index>` - ローカルバックアップ復元
- `backup.drive.upload` - Driveバックアップアップロード
- `backup.drive.list` - Driveバックアップ一覧
- `backup.drive.restore <index>` - Driveバックアップ復元
- `backup.status` - バックアップ状態
- `backup.history` - バックアップ履歴

## スクリーンショットコマンド

- `screenshot.capture` - スクリーンショットをファイル保存
- `screenshot.base64` - スクリーンショットをBase64で取得

## 注意事項

1. **認証なし**: 現在は認証がないため、ローカルDEBUG用として使用してください
2. **SSHトンネル**: AIはSSHトンネル経由でアクセスします
3. **スクリーンショット**: ICE-APIプラグインが有効な場合のみ使用可能
4. **テスト実行**: Flutterのintegration_testを使用します

## セキュリティ

- 現在は認証なし（ローカルDEBUG用）
- 将来的には認証機能を追加予定
- SSHトンネル経由でのアクセスを推奨

## 開発者向け情報

### プラグインID
- `com.h1.core.ice`

### バージョン
- `1.0.0`

### 依存関係
- `dart:io` - HTTPサーバー
- `sqflite` - DBアクセス
- `shared_preferences` - 設定保存
