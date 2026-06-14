# Integrations: h-1-core

**Date:** 2026-06-14

## External Services

### Mattermost (Primary Integration)
| Aspect | Detail |
|--------|--------|
| Type | Incoming/outgoing webhook + REST API |
| Purpose | Remote debugging commands, error reporting, DB snapshot sharing |
| Auth | Personal Access Token (PAT) stored in `SharedPreferences` as `mattermost_pat` |
| Base URL | Configurable via `mattermost_base_url` (default: `https://mm.ka.sugeee.com`) |
| Team | `cyb` (configurable via `mattermost_team_name`) |
| Channel | `h1-debug` for command bridge |

**Key files:**
- `lib/services/mm_command_service.dart` — Polling loop (15s interval), command execution, result posting
- `lib/services/mattermost_bridge.dart` — Generic Mattermost API client
- `lib/services/error_reporter.dart` — Error reporting to Mattermost
- `lib/services/debug_console.dart` — Debug command registry (`ping`, `mmcheck`, `system.status`, `db.send`, etc.)
- `lib/plugins/debug/screens/` — Debug screen UI with PAT input and toggle switches

**Command prefix:** `!opencode <cmd>` in h1-debug channel triggers remote execution.

### Google Services
| Service | Purpose | Auth Method |
|---------|---------|-------------|
| Google Sign-In | User authentication (optional) | `google_sign_in` package |
| Gmail API | Email sending from within app | OAuth2 via `googleapis` + `flutter_email_sender` |
| Google Account Service | Account management on device | `google_account_service.dart` |

**Key files:**
- `lib/services/google_auth_service.dart` — Google auth flow
- `lib/services/google_account_service.dart` — Device Google account detection
- `lib/services/gmail_sender.dart` — Gmail API email sender

### No Other External Services

The app is **offline-first by design**. There are no:
- Backend APIs
- Push notification services
- Cloud storage (beyond Mattermost file upload as ad-hoc backup)
- Analytics/telemetry providers (self-hosted Mattermost only)

## Local Integrations

### SQLite Database
- Primary persistence layer via `sqflite`
- Multi-company support: each company has its own `.db` file in a dedicated directory
- Version: 5, with migration path defined in `database_helper.dart:_migrateToVersion()`
- Schema core: `lib/services/database/database_schema_core.dart`

### File System
- Company directories: `{app_docs}/販売アシスト1号core/{company_name}/` or external storage `/storage/emulated/0/Documents/販売アシスト1号core/`
- DB snapshot service: creates timestamped copies for backup/restore (`lib/services/db_snapshot_service.dart`)

## Integration Patterns

1. **Repository pattern**: Each domain entity has a repository class that encapsulates SQLite operations
2. **Plugin system**: Internal integration via `H1Plugin` interface — plugins register routes, screens, and DB tables
3. **Service layer**: Shared services (DB helper, company service) are accessed directly, not through DI container
4. **SharedPreferences**: Lightweight config persistence for app settings, PAT tokens, theme mode
