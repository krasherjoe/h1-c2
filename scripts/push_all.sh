#!/bin/bash
# 両リモートpush + GitHub Release作成 一発スクリプト
# 使い方: ./scripts/push_all.sh <バージョン> [リリースノート.md]
# 例: ./scripts/push_all.sh v1.1.0
# 例: ./scripts/push_all.sh v1.1.0 ./docs/release_notes.md
set -e

if [ $# -lt 1 ]; then
  echo "使い方: $0 <version> [リリースノート.md]"
  echo "  バージョン例: v1.1.0"
  exit 1
fi

VERSION="$1"
NOTES_FILE="${2:-}"
NOTES_ARG=()
APK_NAME="h1-core-${VERSION}.apk"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT_DIR"

# === 1. ソースコード → origin (git.cyberius.biz) ===
BRANCH=$(git branch --show-current)
echo "=== 1/4: ソースコード → origin ($BRANCH) ==="
git push origin "$BRANCH"
echo "✅ origin/${BRANCH} へpush完了"

# === 2. APK ビルド ===
echo ""
echo "=== 2/4: APK ビルド ==="
flutter build apk --release --dart-define=APP_VERSION="$VERSION"
cp "$APK_PATH" "/tmp/$APK_NAME"
echo "✅ APK: /tmp/$APK_NAME ($(wc -c < "/tmp/$APK_NAME") bytes)"

# === 3. README → GitHub ===
echo ""
echo "=== 3/4: README → GitHub ==="
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

# === 4. GitHub Release ===
echo ""
echo "=== 4/4: GitHub Release 作成 ==="
if [ -n "$NOTES_FILE" ] && [ -f "$NOTES_FILE" ]; then
  NOTES_ARG=(--notes-file "$NOTES_FILE")
else
  LOG=$(git log --oneline --no-decorate "$(git tag --sort=-creatordate | head -1)..HEAD" 2>/dev/null || true)
  BODY="## ${VERSION} 変更点"
  if [ -n "$LOG" ]; then
    BODY="$BODY"$'\n'"$LOG"
  fi
  NOTES_ARG=(--notes "$BODY")
fi

# tag を origin にも打つ
git tag -f "$VERSION" 2>/dev/null || git tag "$VERSION"
git push origin "$VERSION" 2>/dev/null || true

# gh はリモートに同じ tag が無いと怒るので一旦消して任せる
git tag -d "$VERSION" 2>/dev/null || true
gh release create "$VERSION" \
  --title "$VERSION" \
  "${NOTES_ARG[@]}" \
  "/tmp/$APK_NAME#$APK_NAME"
# 再度 local tag を打って origin と同期
git tag "$VERSION"

rm -f "/tmp/$APK_NAME"
echo ""
echo "🎉 完了: https://github.com/krasherjoe/h1-core/releases/tag/${VERSION}"
echo "   リリースURL: https://github.com/krasherjoe/h1-core/releases/tag/${VERSION}"
