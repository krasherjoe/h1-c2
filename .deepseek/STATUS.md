# 進捗ステータス

**更新:** 2026-06-02 10:45
**作成者:** OpenCode

---

## 完了タスク一覧（全22タスク）

| # | タスク | 優先度 | 状態 |
|---|---|---|---|
| 1 | H1Explorer コア基盤実装 → プラグイン化 | P1 | ✅ |
| 2 | 顧客プラグイン実装 （CustomerExplorerConfig 再実装） | P1 | ✅ |
| 3 | 商品プラグイン実装 （ProductExplorerConfig 再実装） | P1 | ✅ |
| 4 | 伝票プラグイン実装 | P2 | ✅ |
| 5 | 仕入プラグイン実装 | P2 | ✅ |
| 6 | 在庫管理プラグイン実装 | P2 | ✅ |
| 7 | 分析レポートプラグイン実装 | P3 | ✅ |
| 8 | 会計収支プラグイン実装 | P3 | ✅ |
| 9 | ダッシュボード原型復元 + セクションシステム | P1 | ✅ |
| 10 | QuickActions プラグイン移植 | P1 | ✅ |
| 11 | プラグイン有効/無効制御 | P1 | ✅ |
| 12 | DBスキーマプラグイン分解 + マイグレーション基盤 | P1/P2 | ✅ |
| 13 | 自社情報プラグイン分離 (CompanyPlugin) | P1 | ✅ |
| 14 | バックアッププラグイン実装 | P1 | ✅ |
| 15 | 設定プラグイン + ルート繋ぎ込み | P1 | ✅ |
| 16 | 顧客マスター 直ルート化 → H1Explorer 統一へ回帰 | P1 | ✅ |
| 17 | 商品マスター 直ルート化 → H1Explorer 統一へ回帰 | P1 | ✅ |
| 18 | H1Explorer プラグイン化 (ExplorerPlugin) | P1 | ✅ |
| 19 | エディタ保存ロジック修正 (常にtrue問題) | P1 | ✅ |
| 20 | CustomerMasterScreen / ProductMasterScreen 削除 | P1 | ✅ |
| 21 | ConversionPlugin（V1→V2データ変換 + 起動時ガード） | P1 | ✅ |
| 22 | AuditPlugin（ハッシュチェーン監査画面 + 定期検証） | P1 | ✅ |

---

## アーキテクチャ現状

### 全マスターが H1Explorer に統一
```
H1Explorer（統一シェル）
  ├── CustomerExplorerConfig（顧客マスター）
  ├── ProductExplorerConfig（商品マスター）
  ├── DocumentExplorerConfig（伝票管理）
  └── PurchaseExplorerConfig（仕入管理）
```

### H1ExplorerConfig の拡張機能（全 optional）

| 機能 | 顧客 | 商品 | 伝票 | 仕入 |
|---|---|---|---|---|
| ソートメニュー | ✅ 名前順/降順 | ✅ 名前・カテゴリ・価格 | - | - |
| グループ見出し | ✅ 五十音（あ〜わ） | ✅ カテゴリ別 | - | - |
| FAB ポップアップ | ✅ 手入力/電話帳 | -（直接エディタ） | - | - |
| オーバーフローメニュー | ✅ CSV入出力/敬称 | ✅ CSV入出力 | - | - |
| selectionMode | ✅ 請求書画面で使用 | ✅ 請求書画面で使用 | - | - |

### プラグイン構成（15プラグイン）

| ID | プラグイン | トグル | 役割 |
|---|---|---|---|
| `com.h1.core` | コアシステム | ❌ | 基盤 |
| `com.h1.plugin.explorer` | マスターエクスプローラー | ✅ | 統一シェル |
| `com.h1.plugin.settings` | 設定 | ❌ | 設定管理 |
| `com.h1.plugin.company` | 自社情報 | ✅ | 会社情報 |
| `com.h1.plugin.backup` | バックアップ | ✅ | データ保護 |
| `com.h1.plugin.quick_actions` | クイックアクション | ✅ | ダッシュボード |
| `com.h1.plugin.customers` | 顧客管理 | ✅ | CustomerExplorerConfig |
| `com.h1.plugin.products` | 商品管理 | ✅ | ProductExplorerConfig |
| `com.h1.plugin.documents` | 伝票管理 | ✅ | DocumentExplorerConfig |
| `com.h1.plugin.purchase` | 仕入管理 | ✅ | PurchaseExplorerConfig |
| `com.h1.plugin.inventory` | 在庫管理 | ✅ | - |
| `com.h1.plugin.analytics` | 分析レポート | ✅ | - |
| `com.h1.plugin.accounting` | 会計収支 | ✅ | - |
| `com.h1.plugin.conversion` | データ変換 | ✅ | V1→V2マイグレーション |
| `com.h1.plugin.audit` | ハッシュチェーン監査 | ✅ | 改ざん検出UI |

### 削除したファイル

- `lib/screens/customer_master/customer_master_screen.dart`
- `lib/screens/customer_master/widgets/` （4ファイル: list_view, card, sort_menu, kana_chips）
- `lib/screens/customer_master/models/customer_list_types.dart`
- `lib/screens/product_master/product_master_screen.dart`
- `lib/screens/product_master/widgets/` （3ファイル: list_view, card, sort_menu）
- `lib/plugins/customers/explorer/customer_explorer_config.dart`（旧バージョン）
- `lib/plugins/customers/models/customer_explorer_item.dart`（旧バージョン）
- `lib/plugins/products/explorer/product_explorer_config.dart`（旧バージョン）
- `lib/plugins/products/models/product_explorer_item.dart`（旧バージョン）
- `lib/explorer/` 全ファイル（プラグイン化により移設）

### 残置しているロジックファイル（Config から参照）

- `lib/screens/customer_master/logic/` （5ファイル: search_filter, import_export, dialogs, utils）
- `lib/screens/product_master/logic/` （4ファイル: data_loader, import_export, dialogs, undo_manager）
- `lib/screens/product_master/models/product_list_types.dart`

---

## Next Steps

1. **Google Drive backup integration** — バックアッププラグインの post‑poned 機能
2. **電帳法 定期自動検証** — AuditPlugin の起動時スケジュール検証（現在は手動トリガーのみ）

---

## git.cyberius.biz 最終push
- `HEAD` — ConversionPlugin + AuditPlugin 実装完了
