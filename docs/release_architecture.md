# リリースアーキテクチャ

## バージョン番号ルール

```
v{MAJOR}.{MINOR}.{PATCH}
```

| パラメータ | 桁数 | 説明 |
|-----------|------|------|
| MAJOR | 任意 | 原則 1。大きな設計変更時にインクリメント |
| MINOR | 任意 | 原則 3。大きな区切りのタイミングでインクリメント |
| PATCH | **3桁** | リリースごとに +1。ゼロ埋め（001, 002, ..., 010, 099, 100） |

**ルール:**
- 機能追加でもバグ修正でも PATCH をインクリメント（基本的に MINOR のまま）
- MINOR を上げるのは「DBスキーマ破壊的変更」や「大きな設計変更」など、区切りの良いタイミングのみ
- PATCH は常に3桁で表記。例: `v1.3.008`、`v1.3.010`、`v1.4.001`

## 全体像

```
[開発環境]
  push_all.sh v1.3.010
       │
       ├── ① ソースコード + タグ → git.cyberius.biz (Forgejo)
       │
       ├── ② README → GitHub (gh worktree push)
       │
       ├── ③ flutter build apk --release (ローカル)
       │    android/keystore/debug.keystore で署名
       │
       ├── ④ gh release create → GitHub Releases
       │    https://github.com/.../releases/tag/v1.3.010
       │
       └── ⑤ 古いリリース削除（最新5件のみ保持）
```

**全てローカルで完結**。Forgejo Action は使用しない。

## コンポーネント

### git.cyberius.biz（Forgejo）

- **役割**: ソースコード管理
- **URL**: `ssh://git@git.cyberius.biz/joe/h1-core.git`
- **認証**: SSH (公開鍵)
- **実体**: `www.cyberius.biz:5000` 上のコンテナ（osa ユーザーの環境）

### GitHub（krasherjoe/h1-core）

- **公開内容**: APK ファイル + README.md のみ
- **Release URL**: `https://github.com/krasherjoe/h1-core/releases`
- **認証**: gh CLI（GITHUB_TOKEN 環境変数、開発マシン上で `gh auth login` 済み）

### 開発環境（ローカルマシン）

- **物理**: PVE 上の別コンテナ
- **OS**: Linux
- **ツール**: Flutter SDK, Android SDK, gh CLI, OpenCode
- **リリーススクリプト**: `scripts/push_all.sh`（一発で全工程を実行）

## リリースフロー

```
./scripts/push_all.sh v1.3.010
```

| ステップ | 処理 |
|---------|------|
| 1/5 | git push origin (ソースコード + タグ) |
| 2/5 | README 更新（GitHub worktree push） |
| 3/5 | flutter build apk --release（ローカルビルド） |
| 4/5 | gh release create（GitHub Release 作成） |
| 5/5 | 古いリリース削除（最新5件のみ保持） |

**注意:** 鍵は `android/keystore/debug.keystore`（リポジトリ管理）。パスワードはデフォルトの debug 用。`key.properties`（gitignore）はローカルでパスワード上書きが必要な場合のみ使用。

## SSH 接続設定

`~/.ssh/config`:

```
host cyb0
  hostname www.cyberius.biz
  port 5000
  user osa

host git.cyberius.biz
  IdentityFile ~/.ssh/id_ed25519
  ProxyJump cyb0
  StrictHostKeyChecking no
  UserKnownHostsFile=/dev/null

host git
  hostname 192.168.99.120
  port 22
  user root
```

| エイリアス | 接続先 | 用途 |
|-----------|--------|------|
| `ssh git.cyberius.biz` | Forgejo (gitサーバー) | git push / pull |
| `ssh git` | Runner コンテナ | メンテナンス・監査 |
| `ssh cyb0` | PVE ホスト | インフラ管理 |

## Runner 管理コマンド

```bash
# 状態確認
systemctl status forgejo-runner

# ログ監視
journalctl -u forgejo-runner -f

# 設定再読込（config.yml 編集後）
systemctl restart forgejo-runner

# 紐付け情報
cat /root/runner/.runner

# ディスク容量
docker system df

# 利用可能な Docker イメージ一覧
docker images
```
