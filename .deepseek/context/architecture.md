# アーキテクチャ

## ダッシュボードセクションシステム（2026-06-01 実装）

### 概要
プラグインが任意の Widget をダッシュボードにブロックとして挿入できる機構。
画面ID・ルートの重複を PluginRegistry の登録時にバリデーション。

### 構成要素

| ファイル | 責務 |
|---|---|
| `lib/plugin_system/dashboard_section.dart` | DashboardSection モデル（id, title, priority, builder） |
| `lib/plugin_system/screen_definition.dart` | ScreenDefinition モデル（id, title, route, builder） |
| `lib/plugin_system/core_plugin.dart` | CorePlugin（全メニュー一覧セクション, priority:100） |
| `lib/plugin_system/plugin_widgets.dart` | PluginAppBarTitle（画面ID自動表示） |

### 仕組み

1. core_plugin.dart が main.dart で最初に登録される
2. PluginRegistry.register() が ScreenDefinition のID・ルート重複をチェック
3. DashboardScreen が全プラグインから `dashboardSection` を収集
4. priority 順にソートしてレンダリング（QuickActions→CorePlugin→将来のプラグイン）

### 現在のセクション配置

| セクション | 提供元 | priority |
|---|---|---|
| クイックアクション | QuickActionsPlugin | 0 |
| 全メニュー一覧 | CorePlugin | 100 |

### 画面ID自動化
- PluginAppBarTitle が `ModalRoute` からルートを取得
- PluginRegistry.getScreenByRoute() で ScreenDefinition を検索
- `{ID}: {タイトル}` 形式で表示
- 現時点では各プラグインが screens をオーバーライドしていないため fallback 表示
