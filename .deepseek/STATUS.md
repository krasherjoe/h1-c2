# 進捗ステータス

**更新:** 2026-06-01 22:30
**作成者:** OpenCode

---

## 今回の実装（全10タスク完了）

### ダッシュボードセクションシステム

| # | タスク | 状態 |
|---|---|---|
| 1 | DashboardSection モデル | ✅ |
| 2 | ScreenDefinition モデル | ✅ |
| 3 | PluginAppBarTitle ヘルパー | ✅ |
| 4 | H1Plugin インターフェース拡張 | ✅ |
| 5 | PluginRegistry 拡張（重複チェック・ルックアップ） | ✅ |
| 6 | CorePlugin（全メニュー一覧セクション） | ✅ |
| 7 | QuickActionsPlugin 埋め込みパネル化 | ✅ |
| 8 | DashboardScreen セクション収集レンダリング | ✅ |
| 9 | main.dart CorePlugin 登録 | ✅ |
| 10 | ビルド確認・プッシュ | ✅ |

### カラーユーティリティ

- `textColorOn()` / `contrastRatio()` 追加（WCAG AA準拠）
- 3層構造の視覚階層（壁紙→カード→入力フォーム）
- 全シャドウを `cs.shadow` に統一
- デザインルール文書作成（`.deepseek/context/design_rules.md`）

### アーキテクチャ

- プラグインが `DashboardSection` を提供 → ダッシュボードに自動表示
- PluginRegistry が画面ID・ルートの重複を登録時にバリデーション
- AppBar タイトルが PluginAppBarTitle で自動化（`{ID}: {タイトル}`）

### 現在の構成

```
ダッシュボード
├── スライドロック
├── ステータスバー
├── [QuickActionsPlugin] クイックアクション (priority: 0)
└── [CorePlugin] 全メニュー一覧 (priority: 100)
```

---

## 未着手・構想

- 各プラグインの `getRoutes()` → `screens` 移行（画面ID自動化の本格化）
- 案件進捗プラグイン（DashboardSection で挿入）
- 配送状況トラッカープラグイン
- `/invoice/input`, `/invoice/history`, `/plugins` の ScreenDefinition 化
