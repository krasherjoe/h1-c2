# Concerns: h-1-core

**Date:** 2026-06-14

## Technical Debt

### 1. Minimal Test Coverage (~1%)
Only 2 test files exist for ~236 Dart files. Critical data access paths (repositories) are untested. Any refactoring of SQL queries or migration logic carries high regression risk.

**Impact**: High — changes to customer/product/invoice repositories cannot be verified automatically.

### 2. Direct Repository Instantiation
Repositories are created with `final repo = CustomerRepository()` inside widgets and services, not injected. This creates:
- Tight coupling between UI and data layers
- Inability to mock repositories in tests
- Multiple repository instances per screen (each creates its own `DatabaseHelper()`)

**Affected files**: All screens, all plugins' screens, `lib/plugin_system/plugin_context.dart`

### 3. Hardcoded Japanese Strings
All UI text is hardcoded in Japanese with no i18n framework. While acceptable for a Japan-only product, this means:
- No automated string extraction
- Translation to English requires manual editing of every file
- String duplication across similar screens (editor/viewer patterns repeat)

### 4. Duplicate Explorer Pattern Implementation
The editor/viewer/preview pattern is manually repeated in each plugin that uses it:
- `documents/explorer/` — document_editor.dart, document_viewer.dart, document_preview_page.dart
- `purchase/explorer/` — purchase_editor.dart, purchase_viewer.dart, purchase_preview_page.dart

Each implementation has slight variations, making global UI changes require multi-file edits.

## Known Issues & Fragile Areas

### 5. External Storage Dependency (Android)
The app stores databases on external storage (`/storage/emulated/0/Documents/販売アシスト1号core/`) which requires special Android permissions:
- `MANAGE_EXTERNAL_STORAGE` permission (rarely granted, triggers Play Store review)
- Permission check in `_checkStoragePermission()` shows a blocking dialog
- Fallback to app-private storage exists but may cause data inconsistency

**Risk**: High — if storage permission is revoked or denied, all company data becomes inaccessible.

### 6. Database Migration Hardcoded in database_helper.dart
Migration logic for versions 2-5 is in a single switch statement inside `database_helper.dart:128-165`. Each new version adds another case block. There's no per-migration file or automated migration tracking.

**Affected**: `lib/services/database_helper.dart:_migrateToVersion()`

### 7. Silent Error Suppression in Migrations
Column additions during migrations use bare `catch (_) {}`:
```dart
try { await db.execute('ALTER TABLE ... ADD COLUMN ...'); } catch (_) {}
```
This silently ignores failures that might indicate real schema conflicts.

### 8. PAT Stored in Plain Text
Mattermost Personal Access Token is stored in SharedPreferences without encryption:
```dart
prefs.getString('mattermost_pat')
```
This is acceptable for a personal tool but would be a security finding in any compliance audit.

**File**: `lib/services/mm_command_service.dart`, `lib/plugins/debug/screens/`

### 9. Sync Service — Unimplemented Backend
The sync infrastructure exists (`SyncService`, `sync_log` table, `SyncGarbageCollector`) but there's no backend to sync against. The `http` package calls are prepared but not fully implemented for cross-device sync.

**Risk**: Medium — dead code adds maintenance burden and confusion about data flow.

### 10. 20+ Plugins Registered in main.dart
All plugin registrations are sequential in `main.dart:298-319`. This creates a long initialization sequence with implicit ordering dependencies. Adding a new plugin requires editing this list manually.

**File**: `lib/main.dart:298-319` (22 lines of plugin registration)

## Security Considerations

| Concern | Severity | Notes |
|---------|----------|-------|
| Plain-text PAT storage | Low-Medium | Personal use only, not production-grade |
| No input validation on SQL parameters | Medium | Some raw queries use string interpolation; repositories mostly use parameterized queries |
| No certificate pinning for HTTP | Low | Mattermost API calls use standard HTTPS without pinning |
| File system access to Documents directory | Medium | External storage path is predictable and accessible |
| Hash chain integrity | Good | Document modification detection via SHA-256 hash chain (`hash_chain` table) |

## Performance Considerations

### 11. Raw SQL Queries Throughout
All database operations use `db.rawQuery()` with hand-written SQL. Benefits:
- Full control over query optimization
- No ORM overhead

Risks:
- No compile-time type safety
- Schema changes require manual query updates
- Column name typos cause runtime errors

### 12. N+1 Query Risk in Repository Methods
Some repository methods fetch related data in separate queries rather than JOINs:
```dart
// CustomerRepository queries customers, then contacts separately
SELECT c.* FROM customers c
-- Then for each customer:
SELECT * FROM customer_contacts WHERE customer_id = ?
```

With large datasets (1000+ customers), this could become slow.

## Platform-Specific Concerns

| Platform | Concern |
|----------|---------|
| Android | External storage permission, file path conventions (`/storage/emulated/0/Documents/`) |
| Web | Database throws `UnsupportedError`; app runs but no persistence |
| Desktop | Uses FFI backend; untested on Linux ARM architectures |
| iOS | Supported by Flutter tooling but minimal real-world testing reported |

## Recommendations

### Immediate (Phase 1-2)
1. Add repository unit tests for the most-used entities (Customer, Product, Invoice)
2. Document the migration history in a dedicated file rather than inline switch statement

### Short-term (Phase 3-4)
3. Extract common explorer pattern into a base widget or mixin
4. Add parameterized query audit — find any remaining string-interpolated SQL

### Long-term
5. Evaluate whether `MANAGE_EXTERNAL_STORAGE` permission can be replaced with scoped storage
6. Consider adding an i18n package if English support becomes more than cosmetic
7. Implement actual sync backend or remove dead sync code to reduce confusion
