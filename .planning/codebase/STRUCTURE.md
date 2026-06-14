# Structure: h-1-core

**Date:** 2026-06-14

## Directory Layout

```
h-1-core/
├── lib/
│   ├── main.dart                          # App entry point, plugin registration
│   ├── models/                            # Shared domain models (flat)
│   │   ├── customer_model.dart
│   │   ├── product_model.dart
│   │   ├── invoice_models.dart
│   │   ├── receipt_model.dart
│   │   └── ... (12 files total)
│   ├── plugins/                           # Plugin modules (20+ domains)
│   │   ├── accounting/                    # 会計プラグイン
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── accounting_plugin.dart
│   │   ├── analysis/                      # 分析プラグイン
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── analysis_plugin.dart
│   │   ├── analytics/                     # アナリティクスダッシュボード
│   │   │   └── screens/
│   │   ├── ar/                            # 貸借対照・勘定科目
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── ar_plugin.dart
│   │   ├── audit/                         # 監査ログ
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── audit_plugin.dart
│   │   ├── backup/                        # DBバックアップ
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── backup_plugin.dart
│   │   ├── company/                       # 会社情報・印鑑
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── company_plugin.dart
│   │   ├── communication/                 # 通信（メール等）
│   │   │   └── communication_plugin.dart
│   │   ├── conversion/                    # データマイグレーション
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── conversion_plugin.dart
│   │   ├── customers/                     # 顧客管理
│   │   │   ├── explorer/
│   │   │   ├── logic/
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   └── customers_plugin.dart
│   │   ├── daily/                         # 日報・タスク・タイムログ
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── daily_plugin.dart
│   │   ├── debug/                         # デバッグ画面
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── debug_plugin.dart
│   │   ├── documents/                     # 請求書・領収証
│   │   │   ├── explorer/
│   │   │   ├── logic/
│   │   │   ├── models/
│   │   │   ├── services/
│   │   │   └── documents_plugin.dart
│   │   ├── explorer/                      # エクスプローラー（一覧画面共通）
│   │   │   └── explorer_plugin.dart
│   │   ├── inventory/                     # 在庫管理
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── inventory_plugin.dart
│   │   ├── memorandum/                    #  Memorandum（覚書）
│   │   │   ├── logic/
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── memorandum_plugin.dart
│   │   ├── pricelist/                     # 価格表
│   │   │   ├── commands/
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── price_list_plugin.dart
│   │   ├── products/                      # 商品管理
│   │   │   ├── logic/
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── products_plugin.dart
│   │   ├── project/                       # プロジェクト管理
│   │   │   ├── screens/
│   │   │   └── project_plugin.dart
│   │   ├── purchase/                      # 発注書
│   │   │   ├── explorer/
│   │   │   ├── logic/
│   │   │   ├── models/
│   │   │   ├── services/
│   │   │   └── purchase_plugin.dart
│   │   ├── quick_actions/                 # クイックアクション
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   ├── widgets/
│   │   │   └── quick_actions_plugin.dart
│   │   ├── settings/                      # 設定
│   │   │   ├── models/
│   │   │   ├── screens/
│   │   │   ├── services/
│   │   │   └── settings_plugin.dart
│   │   └── suppliers/                     # 取引先・サプライヤー
│   │       ├── models/
│   │       ├── screens/
│   │       ├── services/
│   │       └── suppliers_plugin.dart
│   ├── plugin_system/                     # Plugin framework core
│   │   ├── core_plugin.dart               # Core plugin (dashboard, menu)
│   │   ├── dashboard_section.dart
│   │   ├── menu_item.dart
│   │   ├── plugin_context.dart            # DB + prefs context for plugins
│   │   ├── plugin_interface.dart          # H1Plugin abstract class
│   │   ├── plugin_registry.dart           # Singleton registry
│   │   ├── plugin_state_service.dart      # Enable/disable persistence
│   │   ├── plugin_widgets.dart
│   │   └── screen_definition.dart         # Screen metadata
│   ├── screens/                           # Top-level screens
│   │   ├── dashboard_screen.dart
│   │   └── plugin_management_screen.dart
│   ├── services/                          # Shared services (flat)
│   │   ├── database/                      # DB schema & utilities
│   │   │   ├── database_schema_core.dart  # Core table definitions
│   │   │   └── database_utils.dart        # Helper functions
│   │   ├── database_helper.dart           # Singleton DB connection manager
│   │   ├── customer_repository.dart       # Customer CRUD
│   │   ├── product_repository.dart        # Product CRUD
│   │   ├── invoice_repository.dart        # Invoice/receipt CRUD
│   │   ├── mm_command_service.dart        # Mattermost command bridge
│   │   ├── error_reporter.dart            # Error reporting
│   │   └── ... (38 service files total)
│   ├── utils/                             # Utilities
│   │   ├── app_theme.dart                 # Theme tokens, light/dark themes
│   │   └── theme_utils.dart               # Theme helpers
│   └── widgets/                           # Reusable UI components
│       ├── tabbed_workspace.dart          # Main shell with tabs
│       ├── tab_navigator.dart             # Tab navigation controller
│       ├── h1_text_field.dart             # Custom text field widget
│       ├── h1_form_field.dart             # Form field wrapper
│       ├── document_card.dart             # Document list item
│       ├── generic_csv_import_screen.dart # CSV import utility
│       └── ... (17 widget files total)
├── test/                                  # Tests
│   ├── widget_test.dart                   # Flutter smoke test
│   └── products/logic/category_tree_utils_test.dart
├── android/, ios/, linux/, macos/, windows/, web/  # Platform directories
├── scripts/                               # Build/release scripts
├── fonts/                                 # IPAexGothic font
└── docs/                                  # Documentation
```

## Key Location Conventions

### Plugin Structure Convention
Each plugin follows this pattern:
- `{plugin}_plugin.dart` — Entry point, implements `H1Plugin` interface
- `screens/` — UI screens (WidgetBuilders for route registration)
- `services/` — Repository and service classes
- `models/` — Domain model classes
- `logic/` — Business logic (converters, generators)
- `explorer/` — Editor/viewer/preview pages (CQRS-lite pattern)
- `widgets/` — Plugin-specific reusable widgets

### Model Organization
- **Shared models** in `lib/models/` (flat, used across plugins): customer, product, invoice, receipt, etc.
- **Plugin-local models** in `lib/plugins/{name}/models/`: domain-specific to that plugin

### Service Organization
- **Shared services** in `lib/services/` (flat): repositories for shared entities, infrastructure services
- **Plugin-local services** in `lib/plugins/{name}/services/`: repository classes specific to that plugin's data

### Naming Conventions
- Classes: `PascalCase` (Flutter/Dart standard)
- Files: `snake_case.dart`
- Private members: `_leadingUnderscore`
- Plugin IDs: `com.h1.core.{domain}` format (e.g., `com.h1.core.documents`)
- Repository classes: `{Entity}Repository` pattern
- Screen files: `{purpose}_screen.dart`, `{entity}_editor.dart`, `{entity}_viewer.dart`

## File Counts

| Area | Approx. Dart files |
|------|-------------------|
| Plugins | ~120 |
| Shared services | 38 |
| Models (shared + plugin-local) | ~50 |
| Widgets | 17 |
| Plugin system core | 9 |
| Screens (top-level) | 2 |
| Tests | 2 |
| **Total** | **~236** |
