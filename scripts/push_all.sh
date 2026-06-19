#!/bin/bash
# ソースコードpush + README更新 一発スクリプト
# APKビルド・リリースは Forgejo Action が自動実行
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
echo "=== 1/3: ソースコード → origin ($BRANCH) ==="
git push origin "$BRANCH"
echo "✅ origin/${BRANCH} へpush完了"

echo ""
echo "=== タグ $VERSION を origin にpush ==="
git tag -f "$VERSION" 2>/dev/null || git tag "$VERSION"
git push origin "$VERSION" 2>/dev/null || true
echo "✅ タグ $VERSION をpush完了（Forgejo Action が起動）"

# === 2. README → GitHub ===
echo ""
echo "=== 2/3: README → GitHub ==="
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

# === 3. 完了 ===
echo ""
echo "=== 3/3: 完了 ==="
echo "🎉 Forgejo Action が APK ビルド + GitHub Release を実行中"
echo "   リリースURL: https://github.com/krasherjoe/h1-core/releases/tag/${VERSION}"
echo "   Action 実行状況: https://git.cyberius.biz/joe/h1-core/actions"
