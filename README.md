# 販売アシスト1号 コア (h-1-core)

請求書・領収証発行、顧客・商品マスター管理に対応した Flutter 製マルチプラットフォームアプリケーション。

## 機能

- **伝票管理**: 見積書・受注・納品書・請求書・領収証・売上伝票の発行・管理
- **顧客マスター**: 五十音グループ・敬称自動付与・重複チェック・CSV入出力
- **商品マスター**: カテゴリ別管理・価格表（PE）統合・価格帯ソート・バリアント生成
- **仕入管理**: 仕入先管理・発注・入荷
- **在庫管理**: 入庫・出庫・在庫照会・移動
- **案件管理**: 案件作成・進捗管理・ガントチャート・売掛管理（AR/LR）
- **帳票出力**: PDF生成（清水印刷対応）・サーマルレシート印刷
- **ハッシュチェーン**: SHA-256による改ざん検出・電帳法対応
- **Google連携**: ログイン・Driveバックアップ・Gmail送信・Gemini OCR
- **Mattermost連携**: エラー報告・リモートコマンド
- **ICE-API**: HTTP経由のデバッグ・操作API
- **データ変換**: V1→V2データ移行
- **自動バックアップ**: ローカル保存（7年保存）
- **プラグインシステム**: 28プラグインの有効/無効制御
- **テーマ**: ライト/ダークモード対応
- **レシート印刷**: 会社情報・合計金額強調表示

## 技術スタック

- **言語/フレームワーク**: Dart 3.12+ / Flutter 3.12+
- **データベース**: sqflite（ローカルSQLite）
- **状態管理**: StatefulWidget + ValueNotifier + シンプルサービスクラス
- **PDF生成**: pdf / printing
- **認証**: google_sign_in
- **API連携**: http（Mattermost）, googleapis（Google Drive/Gmail）
- **OCR**: google_generative_ai（Gemini）, google_mlkit_text_recognition
- **暗号化**: crypto（SHA-256 ハッシュチェーン）
- **テスト**: flutter_test（1,169 tests）, mocktail, sqflite_common_ffi

## プロジェクト構造

```
lib/
├── main.dart                         # エントリポイント（42行）
├── constants/screen_ids.dart         # 画面ID定数
├── models/                           # 共有ドメインモデル（14ファイル）
├── plugin_system/                    # プラグイン基盤
├── plugins/                          # 28プラグイン
│   ├── documents/                    # 伝票管理（中核）
│   ├── products/                     # 商品マスター + 価格表
│   ├── customers/                    # 顧客マスター
│   ├── cases/                        # 案件管理
│   ├── project/                      # プロジェクト管理
│   ├── shipping/                     # 配送管理
│   ├── ice/                          # ICE-API
│   ├── backup/                       # バックアップ
│   └── ...                           # その他20プラグイン
├── services/                         # 共有サービス（30+ファイル）
├── utils/                            # ユーティリティ
└── widgets/                          # 共有ウィジェット

test/
├── models/                           # モデルテスト（230 tests）
├── plugins/                          # プラグイン別テスト
├── services/                         # サービス層テスト（45+ファイル）
└── widgets/                          # ウィジェットテスト
```

## 開発

```bash
# 依存関係取得
flutter pub get

# 静的解析
dart analyze lib/

# テスト実行
flutter test

# APKビルド
flutter build apk --release

# リリース（ソースpush + APKビルド + GitHub Release）
bash scripts/push_all.sh v1.4.260
```

## ダウンロード

最新のAPKは [Releases](https://github.com/krasherjoe/h1-c2/releases) からダウンロードしてください。

## 設計思想

詳細は [docs/electronic_bookkeeping_hash_chain_justification.md](docs/electronic_bookkeeping_hash_chain_justification.md) を参照。
- メインDBは自由に変更可能（PDF再現性が電帳法の真の要件）
- PDF生成JSONにHash Chainを適用して改ざん検証
- 二層構造DB（メインテーブル + 電帳法テーブル）

## ライセンス

All Rights Reserved.
