#!/bin/bash
# ソースコードpush + ローカルAPKビルド + GitHub Release 一発スクリプト（Action廃止）
# 使い方: ./scripts/push_all.sh <バージョン>
# 例: ./scripts/push_all.sh v1.1.0
set -e

if [ $# -lt 1 ]; then
  echo "使い方: $0 <version>"
  echo "  バージョン例: v1.1.0"
  exit 1
fi

VERSION="$1"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

# === 1. ソースコード + タグ → origin (git.cyberius.biz) ===
BRANCH=$(git branch --show-current)
echo "=== 1/5: ソースコード → origin ($BRANCH) ==="
git push origin "$BRANCH"
echo "✅ origin/${BRANCH} へpush完了"

echo ""
echo "=== タグ $VERSION を origin にpush ==="
git tag -f "$VERSION" 2>/dev/null || git tag "$VERSION"
git push origin "$VERSION" 2>/dev/null || true
echo "✅ タグ $VERSION をpush完了"

# === 2. README → GitHub ===
echo ""
echo "=== 2/5: README → GitHub ==="
git fetch github --quiet 2>/dev/null || true
if git worktree add --checkout /tmp/h1-gh-push github/main 2>/dev/null; then
  cp README.md /tmp/h1-gh-push/README.md
  (
    cd /tmp/h1-gh-push
    git add README.md
    if git diff --cached --quiet; then
      echo "   README 変更なし - skip"
    else
      git commit -m "README ${VERSION} 更新"
      git push github HEAD:main
      echo "✅ GitHub README 更新完了"
    fi
  )
  git worktree remove /tmp/h1-gh-push 2>/dev/null || true
else
  echo "   ⚠️  GitHub worktree checkout 失敗 - README更新をスキップ"
fi

# === 3. pubspec.yaml バージョン更新 ===
echo ""
echo "=== 3/6: pubspec.yaml バージョン更新 ==="
PURE_VERSION="${VERSION#v}"
sed -i "s/^version: .*/version: $PURE_VERSION/" pubspec.yaml
echo "✅ pubspec.yaml → $PURE_VERSION"

# === 4. APKビルド（ローカル） ===
echo ""
echo "=== 4/6: APKビルド（ローカル） ==="
flutter build apk --release --dart-define=APP_VERSION="$VERSION"
echo "✅ APKビルド完了"

# === 5. GitHub Release ===
echo ""
echo "=== 5/6: GitHub Release ==="
APK_NAME="h1-core-$VERSION.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$HOME/$APK_NAME"
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
if [ -n "$PREV_TAG" ]; then
  LOG=$(git log --oneline --no-decorate "$PREV_TAG"..HEAD 2>/dev/null || true)
fi
BODY="## $VERSION"
if [ -n "$LOG" ]; then
  BODY="$BODY"$'\n'"$LOG"
fi
gh release view "$VERSION" --repo krasherjoe/h1-core &>/dev/null \
  && gh release delete "$VERSION" --repo krasherjoe/h1-core --yes
gh release create "$VERSION" \
  --repo krasherjoe/h1-core \
  --title "$VERSION" \
  --notes "$BODY" \
  "$HOME/$APK_NAME#$APK_NAME"
rm -f "$HOME/$APK_NAME"
echo "✅ GitHub Release 完了"

# === 6. 古いリリース削除（最新5件のみ保持） ===
echo ""
echo "=== 6/6: 古いリリース削除 ==="
gh release list --limit 200 --repo krasherjoe/h1-core --json tagName --jq '.[].tagName' \
  | sort -V \
  | head -n -5 \
  | while read tag; do
      echo "   削除: $tag"
      gh release delete "$tag" --repo krasherjoe/h1-core --yes 2>/dev/null || true
    done
echo "✅ クリーンアップ完了"

# === 完了 ===
echo ""
echo "🎉 リリース完了"
echo "   リリースURL: https://github.com/krasherjoe/h1-core/releases/tag/${VERSION}"
