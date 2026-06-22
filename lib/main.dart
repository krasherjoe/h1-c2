import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_helper.dart';
import 'services/db_snapshot_service.dart';
import 'services/company_service.dart';
import 'services/collection_project_service.dart';
import 'services/backup_operation_service.dart';
import 'services/screenshot_service.dart';
import 'services/update_service.dart';
import 'plugins/backup/services/local_backup_service.dart';
import 'services/drive_backup_service.dart';
import 'plugin_system/plugin_registry.dart';
import 'plugin_system/plugin_interface.dart';
import 'plugin_system/plugin_context.dart';
import 'plugin_system/core_plugin.dart';
import 'plugin_system/plugin_state_service.dart';
import 'plugins/documents/documents_plugin.dart';
import 'plugins/customers/customers_plugin.dart';
import 'plugins/products/products_plugin.dart';
import 'plugins/settings/settings_plugin.dart';
import 'plugins/inventory/inventory_plugin.dart';
import 'plugins/purchase/purchase_plugin.dart';
import 'plugins/accounting2/accounting2_plugin.dart';
import 'plugins/drivebackup/drive_backup_plugin.dart';
import 'plugins/sync/sync_plugin.dart';
import 'plugins/printer/printer_plugin.dart';
import 'plugins/cases/cases_plugin.dart';
import 'plugins/quick_actions/quick_actions_plugin.dart';
import 'plugins/company/company_plugin.dart';
import 'plugins/explorer/explorer_plugin.dart';
import 'plugins/backup/backup_plugin.dart';
import 'plugins/conversion/conversion_plugin.dart';
import 'plugins/conversion/services/data_migration_service.dart';
import 'plugins/conversion/screens/conversion_guard_screen.dart';
import 'plugins/analysis/analysis_plugin.dart';
import 'plugins/audit/audit_plugin.dart';
import 'plugins/debug/debug_plugin.dart';
import 'plugins/ice/ice_plugin.dart';
import 'plugins/project/project_plugin.dart';
import 'plugins/memorandum/memorandum_plugin.dart';
import 'plugins/ar/ar_plugin.dart';
import 'plugins/daily/daily_plugin.dart';
import 'plugins/pricelist/price_list_plugin.dart';
import 'plugins/suppliers/suppliers_plugin.dart';
import 'plugins/shipping/shipping_plugin.dart';
import 'constants/env_config.dart';
import 'services/google_auth_service.dart';
import 'utils/app_theme.dart';
import 'services/error_reporter.dart';
import 'services/history_db_service.dart';
import 'services/debug_console.dart';
import 'services/input_style_service.dart';
import 'services/sync_garbage_collector.dart';
import 'services/mattermost_polling_service.dart';
import 'screens/dashboard_screen.dart';
import 'widgets/tabbed_workspace.dart';
import 'screens/plugin_management_screen.dart';

ThemeMode _loadThemeMode(SharedPreferences prefs) {
  final v = prefs.getString('theme_mode') ?? 'system';
  return switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

Future<void> _migrateIfNeeded() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('migrated_v2') == true) return;

  // 1) 旧バージョン: app-private の h1_core.db を移行
  final oldDir = await getApplicationDocumentsDirectory();
  final oldDb = File(p.join(oldDir.path, 'h1_core.db'));
  if (await oldDb.exists()) {
    final newDbPath = await CompanyService.getCurrentDbPath();
    await oldDb.copy(newDbPath);
    await CompanyService.setCurrentCompany('default');
    debugPrint('[Migration] app-private DB移行: $oldDb → $newDbPath');
  }

  // 2) 旧バージョン: public Documents に保存された DB を移行 (v1.2.097〜v1.2.102)
  //    新旧両方のディレクトリ名に対応（販売アシスト1号code → 販売アシスト1号core）
  for (final dirName in ['販売アシスト1号code', '販売アシスト1号core']) {
    try {
      final publicDbDir = Directory('/storage/emulated/0/Documents/$dirName');
      if (await publicDbDir.exists()) {
        final files = publicDbDir.listSync().whereType<File>().where((f) => f.path.endsWith('.db'));
        for (final f in files) {
          final name = p.basenameWithoutExtension(f.path);
          if (name.startsWith('.')) continue;
          final destPath = p.join((await CompanyService.getCompanyDirectory()).path, '$name.db');
          if (!await File(destPath).exists()) {
            await f.copy(destPath);
            debugPrint('[Migration] public DB移行: ${f.path} → $destPath');
          }
        }
      }
    } catch (e) {
      debugPrint('[Migration] public DB移行スキップ(権限なし): $e');
    }
  }

  await prefs.setBool('migrated_v2', true);
}

// バックアップコマンド実装（トップレベル関数）
Future<String> _cmdBackupLocalCreate(List<String> args) async {
  final opService = BackupOperationService();
  final opId = await opService.createOperation(
    operationType: BackupOperationType.create,
    backupType: BackupType.local,
  );
  await opService.updateStatus(opId, BackupStatus.inProgress);

  try {
    final dbPath = await DatabaseHelper().getDatabasePath();
    final localService = LocalBackupService();
    final backupPath = await localService.createAutoBackup(dbPath);

    if (backupPath != null) {
      final file = File(backupPath);
      final size = await file.length();
      await opService.updateFilePath(opId, backupPath, fileSize: size);
      await opService.updateStatus(opId, BackupStatus.completed);
      return 'ローカルバックアップ作成完了: $backupPath (${(size / 1024).toStringAsFixed(1)} KB)';
    } else {
      await opService.updateStatus(opId, BackupStatus.failed, errorMessage: '既に今日のバックアップが存在');
      return '既に今日のバックアップが存在します';
    }
  } catch (e) {
    await opService.updateStatus(opId, BackupStatus.failed, errorMessage: e.toString());
    return 'ローカルバックアップ作成失敗: $e';
  }
}

Future<String> _cmdBackupLocalList(List<String> args) async {
  final localService = LocalBackupService();
  final backups = await localService.listBackups();
  if (backups.isEmpty) return 'ローカルバックアップなし';

  final lines = backups.asMap().entries.map((e) {
    final size = (e.value.sizeBytes / 1024).toStringAsFixed(1);
    final date = e.value.createdAt.toIso8601String().split('T').first;
    return '  ${e.key}: ${e.value.filename} ($size KB, $date)';
  }).join('\n');
  return 'ローカルバックアップ一覧:\n$lines';
}

Future<String> _cmdBackupLocalRestore(List<String> args) async {
  if (args.isEmpty) {
    final backups = await LocalBackupService().listBackups();
    if (backups.isEmpty) return 'ローカルバックアップなし';
    final lines = backups.asMap().entries.map((e) => '  ${e.key}: ${e.value.filename}').join('\n');
    return 'ローカルバックアップ一覧:\n$lines\n\n使用例: !opencode backup.local.restore <index>';
  }

  final opService = BackupOperationService();
  final opId = await opService.createOperation(
    operationType: BackupOperationType.restore,
    backupType: BackupType.local,
  );
  await opService.updateStatus(opId, BackupStatus.inProgress);

  try {
    final index = int.tryParse(args[0]);
    if (index == null) return '数値を指定: !opencode backup.local.restore <index>';

    final backups = await LocalBackupService().listBackups();
    if (index < 0 || index >= backups.length) return '無効なインデックス';

    final backupPath = backups[index].path;
    await opService.updateFilePath(opId, backupPath);

    final localService = LocalBackupService();
    final success = await localService.restoreBackup(backupPath);

    if (success) {
      await opService.updateStatus(opId, BackupStatus.completed);
      return 'ローカルバックアップ復元完了: ${backups[index].filename} (アプリを再起動してください)';
    } else {
      await opService.updateStatus(opId, BackupStatus.failed, errorMessage: '復元失敗');
      return 'ローカルバックアップ復元失敗';
    }
  } catch (e) {
    await opService.updateStatus(opId, BackupStatus.failed, errorMessage: e.toString());
    return 'ローカルバックアップ復元失敗: $e';
  }
}

Future<String> _cmdBackupDriveUpload(List<String> args) async {
  final opService = BackupOperationService();
  final opId = await opService.createOperation(
    operationType: BackupOperationType.create,
    backupType: BackupType.drive,
  );
  await opService.updateStatus(opId, BackupStatus.inProgress);

  try {
    final db = await DatabaseHelper().database;
    final dbPath = db.path;
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final baseName = p.basenameWithoutExtension(dbPath);
    final tmpPath = '${dir.path}/backup_${baseName}_$ts.db';
    await File(dbPath).copy(tmpPath);

    final driveService = DriveBackupService();
    final success = await driveService.uploadBackup(tmpPath, companyName: baseName);

    try { await File(tmpPath).delete(); } catch (_) {}

    if (success) {
      await opService.updateStatus(opId, BackupStatus.completed);
      await driveService.cleanOldBackups(keep: 5);
      return 'Driveバックアップアップロード完了';
    } else {
      await opService.updateStatus(opId, BackupStatus.failed, errorMessage: 'アップロード失敗');
      return 'Driveバックアップアップロード失敗';
    }
  } catch (e) {
    await opService.updateStatus(opId, BackupStatus.failed, errorMessage: e.toString());
    return 'Driveバックアップアップロード失敗: $e';
  }
}

Future<String> _cmdBackupDriveList(List<String> args) async {
  final driveService = DriveBackupService();
  final backups = await driveService.listBackups();
  if (backups.isEmpty) return 'Driveバックアップなし';

  final lines = backups.asMap().entries.map((e) {
    final sizeStr = e.value.size != null ? _formatSize(e.value.size!) : '';
    final date = e.value.createdTime != null
        ? '${e.value.createdTime!.year}/${e.value.createdTime!.month.toString().padLeft(2, '0')}/${e.value.createdTime!.day.toString().padLeft(2, '0')}'
        : '';
    return '  ${e.key}: ${e.value.name} ($sizeStr, $date)';
  }).join('\n');
  return 'Driveバックアップ一覧:\n$lines';
}

Future<String> _cmdBackupDriveRestore(List<String> args) async {
  if (args.isEmpty) {
    final backups = await DriveBackupService().listBackups();
    if (backups.isEmpty) return 'Driveバックアップなし';
    final lines = backups.asMap().entries.map((e) => '  ${e.key}: ${e.value.name}').join('\n');
    return 'Driveバックアップ一覧:\n$lines\n\n使用例: !opencode backup.drive.restore <index>';
  }

  final opService = BackupOperationService();
  final opId = await opService.createOperation(
    operationType: BackupOperationType.restore,
    backupType: BackupType.drive,
  );
  await opService.updateStatus(opId, BackupStatus.inProgress);

  try {
    final index = int.tryParse(args[0]);
    if (index == null) return '数値を指定: !opencode backup.drive.restore <index>';

    final backups = await DriveBackupService().listBackups();
    if (index < 0 || index >= backups.length) return '無効なインデックス';

    final file = backups[index];
    if (file.id == null) return 'ファイルIDなし';

    final dbPath = await DatabaseHelper().getDatabasePath();
    final tmpDir = await getApplicationDocumentsDirectory();
    final tmpPath = '${tmpDir.path}/restore_${DateTime.now().millisecondsSinceEpoch}.db';

    await opService.updateFilePath(opId, tmpPath);

    final driveService = DriveBackupService();
    final success = await driveService.downloadBackup(file.id!, tmpPath);

    if (success) {
      await DatabaseHelper.closeAndReset();
      await Future.delayed(const Duration(seconds: 1));
      await File(tmpPath).copy(dbPath);
      try { await File(tmpPath).delete(); } catch (_) {}
      await opService.updateStatus(opId, BackupStatus.completed);
      return 'Driveバックアップ復元完了: ${file.name} (アプリを再起動してください)';
    } else {
      await opService.updateStatus(opId, BackupStatus.failed, errorMessage: 'ダウンロード失敗');
      return 'Driveバックアップ復元失敗: ダウンロードエラー';
    }
  } catch (e) {
    await opService.updateStatus(opId, BackupStatus.failed, errorMessage: e.toString());
    return 'Driveバックアップ復元失敗: $e';
  }
}

Future<String> _cmdBackupStatus(List<String> args) async {
  final opService = BackupOperationService();
  final summary = await opService.getSummary();
  return jsonEncode(summary);
}

Future<String> _cmdBackupHistory(List<String> args) async {
  final opService = BackupOperationService();
  final operations = await opService.getRecentOperations(limit: 50);
  final lines = operations.map((op) {
    return '${op.createdAt} ${op.operationType.name}/${op.backupType.name} ${op.status.name} ${op.filePath ?? ''}';
  }).join('\n');
  return lines;
}

String _formatSize(String sizeStr) {
  final bytes = int.tryParse(sizeStr);
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// スクリーンショットコマンド実装
Future<String> _cmdScreenshotCapture(List<String> args) async {
  try {
    final screenshotService = ScreenshotService();
    if (!screenshotService.isEnabled) {
      return 'スクリーンショット機能はICE-APIプラグインが有効な場合のみ使用可能です';
    }
    final filePath = await screenshotService.captureToFile();
    final file = File(filePath);
    final size = await file.length();
    return 'スクリーンショット保存完了: $filePath (${(size / 1024).toStringAsFixed(1)} KB)';
  } catch (e) {
    return 'スクリーンショット取得失敗: $e';
  }
}

// Mattermostコマンド実装
Future<String> _cmdMmSetPat(List<String> args) async {
  if (args.isEmpty) {
    return 'PATを指定: !opencode mm.setpat <pat>';
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('mattermost_pat', args[0]);
  return 'PAT設定完了';
}

Future<String> _cmdMmSetChannel(List<String> args) async {
  if (args.isEmpty) {
    return 'チャンネルIDを指定: !opencode mm.setchannel <channel_id>';
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('mattermost_channel_id', args[0]);
  return 'チャンネルID設定完了';
}

Future<String> _cmdMmSetBaseUrl(List<String> args) async {
  if (args.isEmpty) {
    return 'Base URLを指定: !opencode mm.setbaseurl <base_url>';
  }
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('mattermost_base_url', args[0]);
  return 'Base URL設定完了';
}

Future<String> _cmdMmStatus(List<String> args) async {
  final mmService = MattermostPollingService();
  await mmService.initialize();
  final configured = mmService.isConfigured;
  return 'Mattermostポーリング: ${configured ? "✅ 設定済み" : "❌ 未設定"}';
}

Future<String> _cmdMmStart(List<String> args) async {
  final mmService = MattermostPollingService();
  await mmService.initialize();
  if (!mmService.isConfigured) {
    return '❌ 設定されていません。mm.setpat, mm.setchannel, mm.setbaseurlで設定してください';
  }
  mmService.startForegroundPolling();
  return '✅ Mattermostポーリング開始';
}

Future<String> _cmdMmStop(List<String> args) async {
  final mmService = MattermostPollingService();
  mmService.stopForegroundPolling();
  return '✅ Mattermostポーリング停止';
}

Future<String> _cmdScreenshotBase64(List<String> args) async {
  try {
    final screenshotService = ScreenshotService();
    if (!screenshotService.isEnabled) {
      return 'スクリーンショット機能はICE-APIプラグインが有効な場合のみ使用可能です';
    }
    final base64 = await screenshotService.captureToBase64();
    return base64;
  } catch (e) {
    return 'スクリーンショット取得失敗: $e';
  }
}

Future<String> _cmdStatus(List<String> _) async {
  try {
    final db = await DatabaseHelper().database;
    final file = File(db.path);
    final size = await file.length();
    return '✅ 稼働中 | DB: ${(size / 1024).round()}KB';
  } catch (e) {
    return 'ステータス取得失敗: $e';
  }
}

Future<String> _cmdEnv(List<String> _) async {
  final buf = StringBuffer();
  buf.writeln('```');
  buf.writeln('環境設定');
  buf.writeln('  GOOGLE_CLIENT_ID(dart-define): '
      '${EnvConfig.googleClientId.isNotEmpty ? "✅ ${EnvConfig.googleClientId}" : "❌ 未設定"}');
  buf.writeln('  Android default_web_client_id: '
      '${EnvConfig.googleClientIdOrDefault.isNotEmpty ? "✅ ${EnvConfig.googleClientIdOrDefault}" : "❌ 未設定"}');
  if (Platform.isAndroid) {
    buf.writeln('');
    buf.writeln('  ※ Android は AndroidManifest.xml の default_web_client_id を使用');
    buf.writeln('    (strings.xml に定義)');
  }
  buf.writeln('```');
  return buf.toString();
}

Future<String> _cmdGoogleStatus(List<String> _) async {
  try {
    GoogleAuthService.instance.init();
    final signedIn = await GoogleAuthService.instance.isSignedIn();
    final buf = StringBuffer();
    buf.writeln('```');
    buf.writeln('Google 認証状態');
    buf.writeln('  ログイン: ${signedIn ? "✅ 済" : "❌ 未"}');
    if (signedIn) {
      final email = await GoogleAuthService.instance.getEmail();
      buf.writeln('  アカウント: $email');
      final token = await GoogleAuthService.instance.getAccessToken();
      buf.writeln('  トークン: ${token != null ? "✅ 有効" : "❌ 取得失敗"}');
    }
    buf.writeln('  起動時ClientID: ${EnvConfig.googleClientIdOrDefault.isNotEmpty ? EnvConfig.googleClientIdOrDefault : "未設定"}');
    buf.writeln('```');
    return buf.toString();
  } catch (e) {
    return 'Google状態取得失敗: $e';
  }
}

Future<String> _cmdDump(List<String> _) async {
  try {
    final buf = StringBuffer();
    buf.writeln('```');
    buf.writeln('h-1-core 状態ダンプ');
    final db = await DatabaseHelper().database;
    final file = File(db.path);
    final size = await file.length();
    buf.writeln('DB: ${file.path} (${(size / 1024).round()}KB)');
    try {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
      for (final t in tables) {
        final name = t['name'] as String;
        final cnt = await db.rawQuery('SELECT COUNT(*) as c FROM "$name"');
        buf.writeln('  $name: ${cnt.first['c']}行');
      }
    } catch (_) {}
    buf.writeln('```');
    return buf.toString();
  } catch (e) {
    return 'ダンプ失敗: $e';
  }
}

const _includeDebug = bool.fromEnvironment('INCLUDE_DEBUG', defaultValue: true);

void _checkExpiryOrExit() {
  final buildDateStr = EnvConfig.appBuildDate;
  if (buildDateStr.isEmpty) return;
  if (buildDateStr.length != 8) return;
  final year = int.tryParse(buildDateStr.substring(0, 4));
  final month = int.tryParse(buildDateStr.substring(4, 6));
  final day = int.tryParse(buildDateStr.substring(6, 8));
  if (year == null || month == null || day == null) return;
  final buildDate = DateTime(year, month, day);
  final expiry = buildDate.add(const Duration(days: 90));
  if (DateTime.now().isAfter(expiry)) {
    _showFatalError('このバージョンの有効期限が切れています。\n新しいバージョンをインストールしてください。\n\n'
        'ビルド日付: $buildDateStr\n'
        '有効期限: ${expiry.toIso8601String().substring(0, 10)}');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ビルド日付チェック（90日経過で起動不可）
  _checkExpiryOrExit();

  runZonedGuarded(() async {
    try {
      await ErrorReporter.initVersion();
    } catch (_) {}

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      ErrorReporter.sendError(
        message: '${details.exceptionAsString()} | ${details.library}',
        detail: details.toString(),
        stackTrace: details.stack,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReporter.sendError(
        message: error.toString(),
        stackTrace: stack,
      );
      return true;
    };

    try {
      await _migrateIfNeeded();
    } catch (e, st) {
      ErrorReporter.sendError(
        message: '[Startup] DB初期化エラー: $e',
        stackTrace: st,
      );
    }

  DebugConsole.register('ping', (_) async => 'pong');
  DebugConsole.register('system.status', _cmdStatus);
  DebugConsole.register('system.env', _cmdEnv);
  DebugConsole.register('google.status', _cmdGoogleStatus);
  if (_includeDebug) {
    DebugConsole.register('system.dump', _cmdDump);
    DebugConsole.register('db.snapshot', (_) async {
      final path = await DbSnapshotService.snapshot();
      return path != null ? 'スナップショット作成完了' : 'スナップショット失敗';
    });
    DebugConsole.register('db.restore', (args) async {
      if (args.isEmpty) {
        final snaps = await DbSnapshotService.list();
        if (snaps.isEmpty) return 'スナップショットなし';
        final lines = snaps.asMap().entries.map((e) => '  ${e.key}: ${e.value.split('/').last}').join('\n');
        return 'スナップショット一覧:\n$lines\n\n⚠️ 復元すると現在のデータが失われます。\n使用例: !opencode db.restore 0 --force';
      }
      final hasForce = args.contains('--force');
      if (!hasForce) {
        final db = await DatabaseHelper().database;
        final docCount = await db.rawQuery("SELECT COUNT(*) as c FROM documents WHERE is_current = 1");
        final invCount = await db.rawQuery("SELECT COUNT(*) as c FROM invoices WHERE is_current = 1");
        final docTotal = (docCount.first['c'] as int? ?? 0) + (invCount.first['c'] as int? ?? 0);
        return '⚠️ 復元すると現在のデータ($docTotal件の伝票)が失われます。\n'
               '続行する場合は --force を付けて再実行:\n'
               '!opencode db.restore ${args[0]} --force';
      }
      final index = int.tryParse(args[0]);
      if (index == null) return '数値を指定: !opencode db.restore <index> --force';
      await DbSnapshotService.restore(index);
      return '復元完了、アプリを再起動してください';
    });

    // バックアップコマンド
    DebugConsole.register('backup.local.create', _cmdBackupLocalCreate);
    DebugConsole.register('backup.local.list', _cmdBackupLocalList);
    DebugConsole.register('backup.local.restore', _cmdBackupLocalRestore);
    DebugConsole.register('backup.drive.upload', _cmdBackupDriveUpload);
    DebugConsole.register('backup.drive.list', _cmdBackupDriveList);
    DebugConsole.register('backup.drive.restore', _cmdBackupDriveRestore);
    DebugConsole.register('backup.status', _cmdBackupStatus);
    DebugConsole.register('backup.history', _cmdBackupHistory);

    // スクリーンショットコマンド
    DebugConsole.register('screenshot.capture', _cmdScreenshotCapture);
    DebugConsole.register('screenshot.base64', _cmdScreenshotBase64);

    // Mattermostコマンド
    DebugConsole.register('mm.setpat', _cmdMmSetPat);
    DebugConsole.register('mm.setchannel', _cmdMmSetChannel);
    DebugConsole.register('mm.setbaseurl', _cmdMmSetBaseUrl);
    DebugConsole.register('mm.status', _cmdMmStatus);
    DebugConsole.register('mm.start', _cmdMmStart);
    DebugConsole.register('mm.stop', _cmdMmStop);
  }

  Database? db;
  try {
    db = await DatabaseHelper().database;
  } catch (e) {
    ErrorReporter.sendError(message: '[Startup] DB接続エラー: $e');
  }
  final prefs = await SharedPreferences.getInstance();
  debugPrint('[Startup] DB ready, prefs ready');

  if (db == null) {
    _showFatalError('データベースの初期化に失敗しました');
    return;
  }

  final context = PluginContext(database: db, preferences: prefs);
  final registry = PluginRegistry.instance;
  registry.setContext(context);

  // 履歴DBから伝票テーブルの整合性チェック＋自動リペア
  {
    // deleted_atカラムを確保（documentsテーブルが存在しない場合は何もしない）
    try {
      await safeAddColumn(db, 'documents', "deleted_at TEXT DEFAULT NULL");
      // リペア
      final restored = await HistoryDbService().repairDocumentsTable(db);
      if (restored > 0) {
        debugPrint('[Startup] 🔧 自動リペア完了: $restored件の伝票を復元');
      }
      // 30日以上前のhistoryエントリをパージ
      await HistoryDbService().purgeOldEntries();
      // ソフトデリートから30日経過したレコードを完全削除
      final cutoff = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final purgeTargets = await db.query('documents',
        columns: ['id'],
        where: 'deleted_at IS NOT NULL AND deleted_at < ?',
        whereArgs: [cutoff],
      );
      if (purgeTargets.isNotEmpty) {
        await db.transaction((txn) async {
          for (final t in purgeTargets) {
            final id = t['id'] as String;
            await txn.delete('document_items', where: 'document_id = ?', whereArgs: [id]);
            await txn.delete('documents', where: 'id = ?', whereArgs: [id]);
          }
        });
        debugPrint('[Startup] 🧹 古いソフトデリートデータをパージ: ${purgeTargets.length}件');
      }
    } catch (_) {
      // documentsテーブル未作成（初回起動時など）の場合は静かにスキップ
    }
  }

  // プラグイン登録
  final plugins = <H1Plugin>[
    CorePlugin(), DocumentsPlugin(), CustomersPlugin(),
    ProductsPlugin(), CompanyPlugin(), SettingsPlugin(),
    InventoryPlugin(), PurchasePlugin(),
    AnalysisPlugin(), Accounting2Plugin(),
    QuickActionsPlugin(), ExplorerPlugin(), BackupPlugin(),
    ConversionPlugin(), AuditPlugin(), if (_includeDebug) DebugPlugin(),
    DriveBackupPlugin(), ProjectPlugin(), MemorandumPlugin(),
    ArPlugin(), DailyPlugin(), PriceListPlugin(), SuppliersPlugin(),
    SyncPlugin(), PrinterPlugin(), CasesPlugin(), IcePlugin(),
    ShippingPlugin(),
  ];
  for (final plugin in plugins) {
    try {
      await registry.register(plugin);
      debugPrint('[Startup] ✅ ${plugin.id}');
    } catch (e, st) {
      debugPrint('[Startup] ❌ ${plugin.id}: $e');
      debugPrint('[Startup] Stack: $st');
      try {
        ErrorReporter.sendError(message: 'プラグイン初期化失敗: ${plugin.id}: $e', screenId: 'startup', stackTrace: st);
      } catch (_) {}
    }
  }

  final stateService = PluginStateService();
  final states = await stateService.loadAll(
    registry.allPlugins.map((p) => p.id).toList(),
  );
  for (final entry in states.entries) {
    if (!entry.value) {
      registry.setEnabled(entry.key, false);
    }
  }

  final collectionCount = await CollectionProjectService.autoCreateCollectionProjects();
  if (collectionCount > 0) {
    debugPrint('[Startup] ✅ 回収案件を $collectionCount 件作成');
  }

  runApp(H1CoreApp(registry: registry, db: db, prefs: prefs));
  }, (error, stack) {
    ErrorReporter.sendError(message: error.toString(), stackTrace: stack);
  });
}

class H1CoreApp extends StatefulWidget {
  final PluginRegistry registry;
  final Database db;
  final SharedPreferences prefs;

  const H1CoreApp({
    super.key,
    required this.registry,
    required this.db,
    required this.prefs,
  });

  @override
  State<H1CoreApp> createState() => _H1CoreAppState();
}

class _H1CoreAppState extends State<H1CoreApp> with WidgetsBindingObserver {
  bool? _needsConversion;
  bool _isConverting = false;
  late ThemeMode _themeMode;
  final GlobalKey _screenshotKey = GlobalKey();
  final MattermostPollingService _mmService = MattermostPollingService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _themeMode = _loadThemeMode(widget.prefs);
    themeNotifier.value = _themeMode;
    WidgetsBinding.instance.addPostFrameCallback((_) => _applySystemNavBar(_themeMode));
    themeNotifier.addListener(_onThemeChanged);
    inputStyleNotifier.addListener(_onInputStyleChanged);
    CompanyService.activeCompanyNotifier.addListener(_onCompanyChanged);
    CompanyService.getCurrentCompany().then((name) {
      if (name != null && mounted) {
        CompanyService.activeCompanyNotifier.value = name;
      }
    });
    _scheduleGarbageCollection();
    _check();
    _checkStoragePermission();
    
    // ICE-APIプラグインが有効な場合のみスクリーンショット機能を有効化
    final iceEnabled = widget.registry.isEnabled('com.h1.core.ice');
    if (iceEnabled) {
      ScreenshotService().setGlobalKey(_screenshotKey);
    }
    
    // 自動アップデートチェック
    _checkAutoUpdate();
    
    // Mattermostポーリング初期化
    _mmService.initialize();
  }

  Future<void> _checkAutoUpdate() async {
    final updateService = UpdateService();
    final needsUpdate = await updateService.performAutoCheck();
    if (needsUpdate && mounted) {
      // 更新がある場合は通知などを表示（将来的に実装）
      debugPrint('[AutoUpdate] Update available');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    themeNotifier.removeListener(_onThemeChanged);
    inputStyleNotifier.removeListener(_onInputStyleChanged);
    CompanyService.activeCompanyNotifier.removeListener(_onCompanyChanged);
    _mmService.stopForegroundPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // フォアグラウンドに戻った時点でポーリング開始
        _mmService.startForegroundPolling();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // バックグラウンドに入った時点でポーリング停止
        _mmService.stopForegroundPolling();
        break;
    }
  }

  Future<void> _checkStoragePermission() async {
    if (!Platform.isAndroid) return;
    try {
      final probe = File('/storage/emulated/0/Documents/販売アシスト1号core/.perm_check');
      await probe.parent.create(recursive: true);
      await probe.writeAsString('');
      await probe.delete();
      return;
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final granted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('ストレージ権限が必要です'),
          content: const Text('データを端末に安全に保存するため、ファイル管理へのアクセス権限が必要です。設定画面で許可してください。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('後で'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('設定を開く'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (granted == true) {
        const channel = MethodChannel('com.h1.core/settings');
        await channel.invokeMethod('openManageStorage');
      }
    });
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {
      _themeMode = themeNotifier.value;
      _applySystemNavBar(_themeMode);
    });
  }

  void _onInputStyleChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onCompanyChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _check() async {
    final needs = await DataMigrationService.needsConversion(widget.db);
    if (!mounted) return;
    setState(() => _needsConversion = needs);
  }

  void _scheduleGarbageCollection() {
    Future.delayed(const Duration(seconds: 10), () {
      SyncGarbageCollector.runAll();
    });
  }

  Future<void> _runConversion() async {
    setState(() => _isConverting = true);
    await DataMigrationService.runConversion(widget.db);
    if (!mounted) return;
    setState(() {
      _needsConversion = false;
      _isConverting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = widget.prefs.getString('input_field_style') ?? 'raised';
    final navbarStyle = widget.prefs.getString('navbar_style') ?? 'primary';
    final iceEnabled = widget.registry.isEnabled('com.h1.plugin.ice');

    final app = MaterialApp(
      title: '販売アシスト1号 コア',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja'),
      supportedLocales: const [Locale('ja'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(inputStyle: inputStyle, navbarStyle: navbarStyle),
      darkTheme: AppTheme.dark(inputStyle: inputStyle, navbarStyle: navbarStyle),
      themeMode: _themeMode,
      builder: (context, child) => SafeArea(
        top: true,
        bottom: true,
        child: child!,
      ),
      home: _buildHome(),
      routes: {

        '/plugins': (_) => const PluginManagementScreen(),
        ...widget.registry.getAllRoutes(),
      },
    );

    // ICE-APIプラグインが有効な場合のみRenderRepaintBoundaryでラップ
    if (iceEnabled) {
      return RepaintBoundary(
        key: _screenshotKey,
        child: app,
      );
    }
    return app;
  }

  Widget _buildHome() {
    if (_needsConversion == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_needsConversion!) {
      return ConversionGuardScreen(
        onConvert: _runConversion,
        isConverting: _isConverting,
      );
    }
    return TabbedWorkspace(dashboard: const DashboardScreen());
  }

  void _applySystemNavBar(ThemeMode mode) {
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system &&
        PlatformDispatcher.instance.platformBrightness == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
  }
}

Never _showFatalError(String message) {
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('アプリを起動できませんでした',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  ));
  throw UnsupportedError('Fatal: $message');
}
