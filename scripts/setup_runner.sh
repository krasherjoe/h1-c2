#!/bin/bash
# PVE Forgejo Runner セットアップスクリプト
# 使い方: このスクリプトをPVEサーバーに転送して実行
# 事前に git.cyberius.biz で以下を用意:
#   1. 管理画面 → サイト管理 → Actions → 有効化
#   2. リポジトリ → Settings → Actions → Runner → 登録トークン発行

set -e

echo "=== Forgejo Runner セットアップ ==="
echo ""

# 引数チェック
if [ $# -lt 2 ]; then
  echo "使い方: $0 <登録トークン> <GitHub PAT>"
  echo "  <登録トークン>: git.cyberius.biz リポジトリ設定で発行"
  echo "  <GitHub PAT>:   GitHub Personal Access Token (repo権限)"
  exit 1
fi

REG_TOKEN="$1"
GH_TOKEN="$2"
INSTANCE="https://git.cyberius.biz"
RUNNER_DIR="/root/runner"

echo "1/5 ディレクトリ作成"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

echo "2/5 runner バイナリダウンロード"
wget -O runner.tar.gz \
  "https://code.forgejo.org/forgejo/runner/releases/download/v12.11.1/forgejo-runner-12.11.1-linux-amd64.tar.gz"
tar xzf runner.tar.gz
rm runner.tar.gz

echo "3/5 登録"
./forgejo-runner register \
  --instance "$INSTANCE" \
  --token "$REG_TOKEN" \
  --name "pve-runner" \
  --labels "ubuntu-latest:docker://node:20-bookworm"

echo "4/5 設定ファイル編集（ラベル調整）"
cat > config.yml << 'CONF'
log:
  level: info

runner:
  file: .runner
  capacity: 2
  envs:
    AUTH_TOKEN: ""
    DOCKER_HOST: ""
    DOCKER_NETWORK: ""
  timeout: 120m

cache:
  enabled: true
  dir: /tmp/cache
CONF

echo "5/5 systemd サービス登録"
cat > /etc/systemd/system/forgejo-runner.service << 'SVC'
[Unit]
Description=Forgejo Runner
After=network.target

[Service]
Type=simple
WorkingDirectory=/root/runner
ExecStart=/root/runner/forgejo-runner daemon
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
echo "次に git.cyberius.biz のリポジトリ設定 → Actions Secrets に"
echo "  GH_TOKEN = $GH_TOKEN"
echo "を追加してください。"
echo ""
echo "あとは git tag v1.x.x && git push --tags で自動ビルド開始"
