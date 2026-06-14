# Stack: h-1-core (販売アシスト1号 コア版)

**Date:** 2026-06-14
**Version:** 1.2.60+1

## Runtime & SDK

| Item | Value |
|------|-------|
| Framework | Flutter 3.12+ |
| Dart SDK | ^3.12.0 |
| Target platforms | Android, iOS, macOS, Windows, Linux, Web (limited — DB not supported on web) |
| UI toolkit | Material 3 (`useMaterial3: true`) |
| Font | IPAexGothic (bundled as `fonts/ipaex.ttf`) |
| Locale | Japanese primary (`Locale('ja')`), English secondary |

## Core Dependencies

### Data Layer
| Package | Version | Purpose |
|---------|---------|---------|
| `sqflite` | ^2.3.0 | Local SQLite database (primary persistence) |
| `sqflite_common_ffi` | ^2.3.2 | Desktop FFI backend for Linux/Windows/macOS |
| `path_provider` | ^2.1.5 | Platform-specific directories (app docs, external storage) |
| `shared_preferences` | ^2.2.2 | Lightweight key-value config storage |
| `uuid` | ^4.5.1 | UUID generation for entity IDs |

### PDF & Printing
| Package | Version | Purpose |
|---------|---------|---------|
| `pdf` | ^3.11.3 | PDF document generation (invoices, receipts) |
| `printing` | ^5.14.2 | Print/PDF export integration with platform |

### Networking & Communication
| Package | Version | Purpose |
|---------|---------|---------|
| `http` | ^1.6.0 | HTTP client (Mattermost API, future sync backends) |
| `flutter_email_sender` | ^8.0.0 | Native email sending |
| `google_sign_in` | ^6.1.0 | Google Sign-In authentication |
| `googleapis` | ^12.0.0 | Google APIs access (Gmail sender integration) |

### Media & Device
| Package | Version | Purpose |
|---------|---------|---------|
| `camera` | ^0.12.0+1 | Camera access (seal/stamp photography) |
| `image_picker` | ^1.1.2 | Image selection from gallery |

### UI Components
| Package | Version | Purpose |
|---------|---------|---------|
| `fl_chart` | ^1.2.0 | Charts for analytics dashboard |
| `url_launcher` | ^6.3.2 | URL opening (links, phone numbers) |
| `intl` | ^0.20.2 | Date/number formatting (Japanese locale) |
| `crypto` | ^3.0.7 | Hash chain integrity verification |
| `flutter_localizations` | SDK | Japanese/English localization |

## Configuration Files

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Flutter package manifest, dependencies |
| `analysis_options.yaml` | Lint rules (flutter_lints) |
| `.gitignore` / `.gitignore_github` | Git ignore rules (APK vs source separation) |
| `opencode.json` | OpenCode IDE configuration |

## Build & Dev Tools

| Tool | Purpose |
|------|---------|
| `flutter_lints` ^6.0.0 | Standard linting rules |
| `flutter_test` | Widget and unit testing framework |
| `scripts/push_all.sh` | One-shot release script (build APK + push to GitHub) |

## Platform-Specific Notes

- **Android**: External storage access required for multi-company DB isolation (`/storage/emulated/0/Documents/販売アシスト1号core/`)
- **Desktop** (Linux/macOS/Windows): Uses `sqflite_common_ffi` for SQLite FFI binding
- **Web**: Database operations throw `UnsupportedError`; app structure supports web but data layer is Android-first
- **iOS**: Supported via Flutter tooling, untested extensively

## What NOT to Use

- **Firebase / cloud backend**: This is an offline-first, local-database-only app. No cloud sync infrastructure exists beyond optional Mattermost bridge.
- **Provider/Riverpod/Bloc**: State management uses Flutter's built-in `StatefulWidget`, `ValueNotifier`, and simple service classes. Do not introduce a state management library.
- **REST API framework**: The app is client-only with no server component. HTTP is used only for Mattermost API calls.
