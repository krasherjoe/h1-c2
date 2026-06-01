#!/bin/bash

# GitHub Release作成スクリプト
# 使い方: ./scripts/create_release.sh

set -e

VERSION="v1.0.0"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
RELEASE_APK="h-1-core-${VERSION}.apk"

echo "🚀 GitHub Release作成: ${VERSION}"

# APKファイル確認
if [ ! -f "$APK_PATH" ]; then
  echo "❌ APKファイルが見つかりません: $APK_PATH"
  echo "flutter build apk --release を実行してください"
  exit 1
fi

# APKファイルをコピー
cp "$APK_PATH" "$RELEASE_APK"
echo "✅ APKファイルをコピー: $RELEASE_APK"

# GitHub CLIで Release作成
gh release create "$VERSION" \
  --title "${VERSION} - 初回リリース（コア版＋プラグインシステム）" \
  --notes "# 販売アシスト1号 コア版 ${VERSION}

## 🎉 初回リリース

請求書・領収証発行をコアとした最小構成版です。

### ✨ 主な機能

**コア機能**:
- 請求書入力・編集・削除
- 領収証発行
- PDF生成・印刷
- 顧客マスター（CRUD）
- 商品マスター（CRUD）
- 伝票履歴

**プラグインシステム**:
- プラグインの動的登録・解除
- 依存関係管理
- イベントバス（プラグイン間通信）
- ダッシュボードへのメニュー自動追加
- プラグイン管理画面

**サンプルプラグイン**:
- 見積管理プラグイン（見積入力・見積履歴）

### 📊 プロジェクト統計

- **ファイル数**: 128ファイル
- **総行数**: 約16,500行
- **APKサイズ**: 46.4MB
- **依存パッケージ**: 9個
- **エラー**: 0件

### 📥 インストール

1. 下記のAPKファイルをダウンロード
2. Android端末にインストール
3. アプリを起動

### ⚠️ 注意事項

- Android 5.0以上が必要
- 初回リリースのため、バグがある可能性があります
- フィードバックをお待ちしています" \
  "$RELEASE_APK"

echo "✅ GitHub Release作成完了: https://github.com/krasherjoe/h-1-core/releases/tag/${VERSION}"
echo "📱 APKダウンロードURL: https://github.com/krasherjoe/h-1-core/releases/download/${VERSION}/${RELEASE_APK}"

# クリーンアップ
rm "$RELEASE_APK"
