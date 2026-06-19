#!/bin/bash
# ソースコードpush + ローカルAPKビルド + GitHub Release 一発スクリプト
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
echo "✅ タグ $VERSION をpush完了（Forgejo Action も起動するが、ローカルビルドが優先）"

# === 2. README → GitHub ===
echo ""
echo "=== 2/5: README → GitHub ==="
git fetch github --quiet 2>/dev/null || true
if [ -d /tmp/h1-gh-push ]; then
  rm -rf /tmp/h1-gh-push
fi
git worktree add --checkout /tmp/h1-gh-push github/main 2>/dev/null || true
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

# === 3. APKビルド（ローカル） ===
echo ""
echo "=== 3/5: APKビルド（ローカル） ==="
flutter build apk --release --dart-define=APP_VERSION="$VERSION"
echo "✅ APKビルド完了"

# === 4. GitHub Release ===
echo ""
echo "=== 4/5: GitHub Release ==="
APK_NAME="h1-core-$VERSION.apk"
cp build/app/outputs/flutter-apk/app-release.apk "/tmp/$APK_NAME"
LOG=$(git log --oneline --no-decorate "$(git tag --sort=-creatordate | head -1)"..HEAD 2>/dev/null || true)
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
  "/tmp/$APK_NAME#$APK_NAME"
echo "✅ GitHub Release 完了"

# === 5. 古いリリース削除（最新5件のみ保持） ===
echo ""
echo "=== 5/5: 古いリリース削除 ==="
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
