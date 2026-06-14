# Conventions: h-1-core

**Date:** 2026-06-14

## Code Style

### Language & Formatting
- **Language**: Dart (Flutter) following standard `flutter_lints` rules
- **File naming**: `snake_case.dart` for all source files
- **Class naming**: `PascalCase` with descriptive nouns
- **Member naming**: camelCase for public, `_camelCase` for private
- **Import ordering**: dart imports first, then package imports, then relative imports
- **Localization**: Japanese is the primary language. All UI strings are hardcoded in Japanese (no i18n framework used). English locale supported but untranslated.

### Plugin Naming Convention
Plugin IDs follow: `com.h1.core.{domain}`
- Example: `com.h1.core.documents`, `com.h1.core.customers`
- Core plugin ID: `com.h1.core`

## Architecture Patterns

### Repository Pattern
All data access goes through repository classes:
```dart
class CustomerRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ActivityLogRepository _logRepo = ActivityLogRepository();

  Future<List<Customer>> getAllCustomers({...}) async { ... }
}
```
- Repositories are **instantiated directly** (`final repo = CustomerRepository()`), not injected
- Each repository creates its own `DatabaseHelper()` instance (singleton)
- Raw SQL queries via `db.rawQuery()`, not an ORM layer

### Singleton Services
- `PluginRegistry.instance` — Central plugin registry
- `DatabaseHelper()` — Singleton database connection manager
- `MmCommandService.instance` — Mattermost command service
- `DebugConsole` — Static command registry

### State Management
- **Primary**: Flutter's built-in `StatefulWidget` with `setState()`
- **Cross-widget notifications**: `ValueNotifier<T>` for simple reactive state
  - Example: `themeNotifier`, `inputStyleNotifier`, `CompanyService.activeCompanyNotifier`
- **No external state management**: No Provider, Riverpod, Bloc, or similar libraries

### Explorer Pattern (CQRS-lite)
For complex entities with multiple views:
```
lib/plugins/{entity}/explorer/
├── {entity}_editor.dart       # Create/Edit form
├── {entity}_viewer.dart       # Read-only detail view
└── {entity}_preview_page.dart # PDF preview before saving
```

## Error Handling

### Standard Pattern
```dart
try {
  // operation
} catch (e) {
  debugPrint('[Component] error message: $e');
  rethrow;  // Always rethrow after logging
}
```

- All errors are logged via `debugPrint()` with a `[ComponentName]` prefix
- Errors in repositories are **always rethrown** — callers handle user-facing feedback
- Flutter error handler (`FlutterError.onError`) sends errors to Mattermost via `ErrorReporter`
- Platform dispatcher error handler (`PlatformDispatcher.instance.onError`) also reports to Mattermost

### Safe Column Addition
Migration-safe column additions use try/catch pattern:
```dart
Future<void> _safeAddColumn(Database db, String table, String columnDefinition) async {
  try {
    final columns = await db.query(table, limit: 1);
    if (!columns.first.containsKey(columnName)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDefinition');
    }
  } catch (_) {}
}
```

## Database Conventions

### Table Naming
- Lowercase with underscores: `customers`, `products`, `activity_logs`, `hash_chain`
- Foreign key references: `{entity}_contacts`, `{entity}_logs`

### ID Convention
- All entity IDs are **UUID strings** (via `uuid` package), not integers
- Primary key column: `id TEXT PRIMARY KEY`
- Auto-increment only for system tables: `sync_log.id INTEGER PRIMARY KEY AUTOINCREMENT`

### Soft Delete Pattern
- `is_hidden` / `is_current` columns for logical deletion
- `valid_to` date column for time-based validity
- Queries filter with `WHERE is_current = 1 AND COALESCE(valid_to, '9999-12-31') > datetime('now')`

### Version Column
Most entities have a `version INTEGER` column for optimistic concurrency control and history tracking.

## UI Conventions

### Theme System
- Centralized in `lib/utils/app_theme.dart`
- Color tokens defined as `static const`: `wallpaperLight`, `cardDark`, accent colors per domain
- Input style configurable: `'raised'` or other styles via SharedPreferences
- Material 3 color scheme derived from indigo seed color

### Screen Registration
Plugins register screens via two mechanisms:
1. **Routes**: `getRoutes()` returns `Map<String, WidgetBuilder>` — standard Flutter named routes
2. **Screen definitions**: `screens` getter returns `List<ScreenDefinition>` — for menu system and navigation

### Menu Categories
Screens are organized into categories matching accent colors:
- Master (deepOrange) → customers, products, suppliers
- Sales (blue) → documents, invoices
- Purchase (green) → purchase orders
- Inventory (purple) → stock management
- Report (blueGrey) → analytics, analysis

## Plugin Lifecycle Convention

```
App Start → DatabaseHelper.init()
            ↓
        PluginRegistry.setContext(context)
            ↓
    For each plugin in order:
      1. createTables(db)     ← During registration
      2. migrate(db, from, to) ← During registration
      3. initialize(context)   ← During registration
      4. StateService.loadAll() ← After all plugins registered
      5. setEnabled(id, state)  ← Apply persisted enable/disable state
```

## Code Not To Write

- **No business logic in widgets** — keep screens thin, push logic to services/repositories
- **No hardcoded strings for user-facing text** — should be localized (currently all Japanese hardcoded is acceptable but new features should consider i18n readiness)
- **No direct `db.execute()` outside migration code** — use repositories
- **No new dependencies without justification** — this is a focused offline app
