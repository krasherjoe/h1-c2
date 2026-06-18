#!/bin/bash
# PVE Forgejo Runner セットアップスクリプト
# 使い方: このスクリプトをPVEサーバーに転送して実行
# 事前に git.cyberius.biz で以下を用意:
#   1. 管理画面 → サイト管理 → Actions → 有効化
#   2. リポジトリ → Settings → Actions Secrets → GH_TOKEN 追加（GitHub PAT）

set -e

echo "=== Forgejo Runner セットアップ ==="
echo ""

if [ $# -lt 2 ]; then
  echo "使い方: $0 <インスタンスURL> <登録トークン>"
  echo "  <インスタンスURL>: https://git.cyberius.biz"
  echo "  <登録トークン>:    Forgejo管理画面 → Actions → 登録トークン"
  exit 1
fi

INSTANCE="$1"
REG_TOKEN="$2"
RUNNER_DIR="/root/runner"

echo "1/4 ディレクトリ作成"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

echo "2/4 runner バイナリダウンロード"
wget -q -O forgejo-runner \
  "https://code.forgejo.org/forgejo/runner/releases/download/v12.11.1/forgejo-runner-12.11.1-linux-amd64"
chmod +x forgejo-runner
./forgejo-runner --version

echo "3/4 設定ファイル作成"
cat > config.yml << CONF
log:
  level: info

cache:
  enabled: true
  dir: /tmp/cache

container:
  network: host

connection:
  - address: $INSTANCE
    token: $REG_TOKEN
CONF

# Dockerイメージ事前pull（初回ジョブ高速化）
echo "Dockerイメージ事前pull..."
docker pull node:20-bookworm 2>&1 | tail -1

echo "4/4 systemd サービス登録"
cat > /etc/systemd/system/forgejo-runner.service << SVC
[Unit]
Description=Forgejo Runner
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=$RUNNER_DIR
ExecStart=$RUNNER_DIR/forgejo-runner daemon --config $RUNNER_DIR/config.yml
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable forgejo-runner
systemctl start forgejo-runner

echo ""
echo "=== 完了 ==="
echo "状態確認: systemctl status forgejo-runner"
echo "ログ確認: journalctl -u forgejo-runner -f"
echo ""
echo "次に Forgejo リポジトリ設定 → Actions Secrets に"
echo "  GH_TOKEN = <GitHub PAT>"
echo "を追加してください。PATは https://github.com/settings/tokens で repo権限付きで作成"
echo ""
echo "あとは git tag v1.x.x && git push origin --tags で自動ビルド開始"
