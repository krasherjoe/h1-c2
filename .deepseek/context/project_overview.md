# h-1-core プロジェクト概要

## プロジェクト情報

- **プロジェクト名**: h-1-core (販売アシスト1号 コア版)
- **言語**: Dart 3.12.0+
- **フレームワーク**: Flutter 3.12.0+
- **目的**: 請求書・領収証発行、顧客・商品マスター管理

## 技術スタック

### 主要パッケージ
- `sqflite` ^2.3.0 - ローカルデータベース
- `path_provider` ^2.1.5 - ファイルパス取得
- `pdf` ^3.11.3 - PDF生成
- `printing` ^5.14.2 - 印刷機能
- `intl` ^0.20.2 - 国際化・日付フォーマット
- `crypto` ^3.0.7 - 暗号化
- `uuid` ^4.5.1 - UUID生成
- `shared_preferences` ^2.2.2 - 設定保存

### 開発パッケージ
- `flutter_test` - テスト
- `sqflite_common_ffi` ^2.3.2 - テスト用DB
- `flutter_lints` ^6.0.0 - Lint

## コア機能

### 実装済み機能
- ✅ 請求書入力・編集・削除
- ✅ 領収証発行
- ✅ PDF生成・印刷
- ✅ 顧客マスター（CRUD）
- ✅ 商品マスター（CRUD）
- ✅ 伝票履歴

### 今後プラグインとして追加予定
- 見積・受注管理
- 在庫管理
- 会計管理（仕訳・試算表・決算書）
- GPS管理
- メール送信
- 定期請求
- 商品バリエーション

## プロジェクト構造

```
lib/
├── main.dart                 # エントリーポイント
├── models/                   # データモデル (13ファイル)
│   ├── customer.dart
│   ├── product.dart
│   ├── invoice.dart
│   └── ...
├── plugin_system/            # プラグインシステム (6ファイル)
│   ├── plugin_interface.dart
│   ├── plugin_registry.dart
│   └── ...
├── plugins/                  # プラグイン実装 (1ファイル)
├── screens/                  # 画面 (76ファイル)
│   ├── dashboard_screen.dart
│   ├── invoice/
│   ├── customer/
│   └── product/
├── services/                 # サービス層 (31ファイル)
│   ├── database_helper.dart
│   ├── pdf_service.dart
│   └── ...
├── utils/                    # ユーティリティ (1ファイル)
└── widgets/                  # 共通ウィジェット (10ファイル)
```

## データベース構造

### 主要テーブル
- `customers` - 顧客マスター
- `products` - 商品マスター
- `invoices` - 請求書ヘッダ
- `invoice_items` - 請求書明細
- `receipts` - 領収証

## プラグインシステム

詳細は `DEEPSEEK_PLUGIN_SYSTEM_REQUEST.md` を参照。

### 設計思想
- コア機能は最小限に保つ
- 機能追加はプラグインで行う
- プラグイン間の依存関係を管理
- 動的なメニュー・ルート追加

### プラグインAPI
- `H1Plugin` インターフェース
- `PluginRegistry` でプラグイン管理
- `PluginContext` でコア機能へアクセス
- `PluginEventBus` でプラグイン間通信

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
