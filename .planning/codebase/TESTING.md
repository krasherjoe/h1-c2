# Testing: h-1-core

**Date:** 2026-06-14

## Current Test State

### Coverage: Minimal
The codebase has **2 test files**:

| File | Type | Description |
|------|------|-------------|
| `test/widget_test.dart` | Widget smoke test | Default Flutter counter app test (not updated for actual app) |
| `test/products/logic/category_tree_utils_test.dart` | Unit test | Tests product category tree utilities |

**Total tests**: ~3-5 assertions across both files. This represents <1% of the codebase coverage.

## Testing Framework

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | SDK | Widget testing, mock BuildContext |
| `sqflite_common_ffi` | ^2.3.2 | Desktop SQLite backend; also used for in-memory DB testing (`DatabaseHelper.testDatabase`) |

### Test Infrastructure Present but Unused
- `DatabaseHelper.testDatabase` — Static field for injecting a test database instance (defined but rarely used)
- No mocking framework (mockito, mocktail) is configured
- No test coverage tooling in dev_dependencies

## Testing Patterns Found

### Unit Tests (Example: category_tree_utils_test.dart)
```dart
void main() {
  group('CategoryTreeUtils', () {
    test('buildTree groups flat list into hierarchy', () { ... });
    test('getDescendants returns children recursively', () => ...);
  });
}
```
- Uses standard `group()`/`test()` pattern from `flutter_test`
- Pure function testing — no Flutter widget dependencies
- Direct instantiation of utility classes

### Database Testing Pattern (in repositories)
Repositories reference `DatabaseHelper.testDatabase`:
```dart
// In CustomerRepository and similar
static Database? testDatabase;
```
This allows in-memory SQLite testing but is not wired up in any test runner.

## What's Missing

### No Widget Tests
Despite 20+ screens, there are **zero widget tests**. Key screens that need coverage:
- `DashboardScreen` — Main entry point
- Document editor/viewer screens
- Customer/Product CRUD screens
- Plugin management screen

### No Integration Tests
- No end-to-end flow tests (e.g., create customer → create invoice → view analytics)
- No plugin lifecycle integration tests
- No DB migration tests

### No Service Tests
Repositories handle the most complex logic but have no tests:
- `CustomerRepository.getAllCustomers()` — Complex SQL with joins and filters
- `InvoiceRepository` — Document type conversion logic
- `SyncService` — Multi-device sync logic
- `DataMigrationService` — Version migration logic

### No Error Path Testing
Error handling is present throughout (`catch` + `debugPrint` + `rethrow`) but never tested:
- Network failures in Mattermost bridge
- DB corruption/fallback scenarios
- Permission denied flows

## Recommended Test Strategy

### Priority 1: Repository Unit Tests
Test repository methods with in-memory SQLite:
```dart
// Pattern using testDatabase
late Database db;

setUp(() async {
  db = await openDatabase(inMemoryDatabasePath, version: 1,
    onCreate: (db, version) => createCoreSchema(db));
  DatabaseHelper.testDatabase = db;
});
```

### Priority 2: Plugin Lifecycle Tests
Verify plugin registration, dependency resolution, and enable/disable state.

### Priority 3: Widget Tests for Core Flows
Test the most-used screens: document creation, customer editing, dashboard navigation.

### Priority 4: Migration Tests
Verify each database migration (v1→v2→...→v5) preserves data correctly.

## Test Conventions (When Written)

Based on existing test patterns:
- File location mirrors source: `lib/plugins/products/logic/` → `test/products/logic/`
- Test file naming: `{source_file}_test.dart`
- Group by class/utility
- Use `setUp()` / `tearDown()` for DB setup
- No page objects or complex test abstractions needed — keep tests simple and direct
