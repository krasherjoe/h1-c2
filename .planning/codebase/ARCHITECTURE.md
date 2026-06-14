# Architecture: h-1-core (販売アシスト1号 コア版)

**Date:** 2026-06-14

## Pattern: Plugin-Based Modular Monolith

The app follows a **plugin architecture** where each business domain is encapsulated as an independent `H1Plugin`. Plugins register their routes, screens, DB tables, and settings with a central registry at startup.

```
┌─────────────────────────────────────────────────┐
│                  H1CoreApp                       │
│  ┌─────────────┐  ┌──────────────────────────┐  │
│  │ PluginRegistry│  │   TabbedWorkspace       │  │
│  │ (Singleton)  │  │   └─ DashboardScreen    │  │
│  └──────┬──────┘  └──────────────────────────┘  │
│         │                                        │
│  ┌──────┴──────────────────────────────────┐    │
│  │ Registered Plugins (20+)                │    │
│  │ • DocumentsPlugin                       │    │
│  │ • CustomersPlugin                       │    │
│  │ • ProductsPlugin                        │    │
│  │ • ...                                   │    │
│  └─────────────────────────────────────────┘    │
│         │                                        │
│  ┌──────┴──────┐                                │
│  │ PluginContext │ ← Database + SharedPreferences │
│  └──────────────┘                                │
└─────────────────────────────────────────────────┘
         │
┌────────┴────────────────────────────────────────┐
│              Services Layer                      │
│  • Repository classes (CRUD per entity)          │
│  • Shared services (DB, company, sync, etc.)     │
│  • External integrations (Mattermost, Gmail)     │
└─────────────────────────────────────────────────┘
```

## Layers

### 1. Presentation Layer (`lib/screens/`, `lib/plugins/*/screens/`)
- Flutter `StatefulWidget` screens using Material 3
- Navigation via named routes registered by plugins
- `TabbedWorkspace` as the main shell with a dashboard tab
- Explorer pattern: editor/viewer/preview pages for complex entities

### 2. Plugin System (`lib/plugin_system/`)
Custom plugin framework providing:
- **Lifecycle**: `initialize()`, `createTables()`, `migrate()`, `dispose()`
- **Routing**: `getRoutes()` returns `Map<String, WidgetBuilder>`
- **Screen definitions**: `ScreenDefinition` objects with id, route, title, category, icon
- **Dependency management**: Plugins declare dependencies on other plugins
- **Enable/disable state**: Persisted per-plugin via `PluginStateService`
- **Dashboard sections**: Plugins can contribute to the dashboard

### 3. Business Logic Layer (`lib/plugins/*/logic/`, `lib/services/`)
- Repository classes handle data access and business rules
- Converter services (document type conversion between invoice/receipt/etc.)
- PDF generation logic in dedicated service classes
- Sync logic with garbage collection

### 4. Data Layer (`lib/models/`, `lib/services/database/`)
- SQLite via `sqflite` with singleton `DatabaseHelper`
- Model classes with `fromMap()` / `toMap()` serialization
- Schema management: `createCoreSchema()`, versioned migrations
- Hash chain for document integrity verification

## Key Architectural Decisions

### Multi-Company Isolation
Each company has its own database file. `CompanyService` manages the active company context and provides per-company directory paths. This allows a single installation to serve multiple businesses.

### Plugin State Service
Plugins can be enabled/disabled independently. State is persisted in SharedPreferences. Disabled plugins don't register routes or create tables.

### Explorer Pattern (CQRS-lite)
Complex entities use an explorer pattern:
- `*_explorer_config.dart` — Configuration/registration
- `*_editor.dart` — Create/edit view
- `*_viewer.dart` — Read-only detail view
- `*_preview_page.dart` — PDF preview before saving

This separates read and write concerns without full CQRS.

## Data Flow

```
User Action → Screen (StatefulWidget)
              ↓
        Repository (via direct instantiation or PluginContext)
              ↓
        DatabaseHelper (singleton SQLite connection)
              ↓
        SQLite DB ({company_dir}/{name}.db)
              ↑
        ActivityLogRepository (side-effect: audit trail)
```

**Note:** Repositories are instantiated directly (`final repo = CustomerRepository()`) rather than injected. Each repository creates its own `DatabaseHelper()` instance, relying on the singleton pattern for database connection sharing.

## Entry Points

| Entry | File | Purpose |
|-------|------|---------|
| App main | `lib/main.dart` | Bootstraps plugins, DB, routes |
| Plugin registration | `main.dart:298-319` | 20+ plugins registered in startup order |
| Routes | `main.dart:479-483` | Aggregated from all active plugins via `registry.getAllRoutes()` |
| Dashboard | `lib/screens/dashboard_screen.dart` | Main home screen |
| Workspace | `lib/widgets/tabbed_workspace.dart` | Tab-based navigation shell |
