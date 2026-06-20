import 'dart:async';
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
import 'constants/env_config.dart';
import 'services/google_auth_service.dart';
import 'utils/app_theme.dart';
import 'services/error_reporter.dart';
import 'services/history_db_service.dart';
import 'services/debug_console.dart';
import 'services/input_style_service.dart';
import 'services/sync_garbage_collector.dart';
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
  }

  Database? db;
  try {
    db = await DatabaseHelper().database;
  } catch (e, st) {
    ErrorReporter.sendError(message: '[Startup] DB接続エラー: $e', stackTrace: st);
  }
  final prefs = await SharedPreferences.getInstance();
  debugPrint('[Startup] DB ready, prefs ready');

  if (db == null) {
    _showFatalError('データベースの初期化に失敗しました');
    return;
  }

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

  final context = PluginContext(database: db, preferences: prefs);

  final registry = PluginRegistry.instance;
  registry.setContext(context);

  // プラグイン登録（各ステップでログ出力）
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

class _H1CoreAppState extends State<H1CoreApp> {
  bool? _needsConversion;
  bool _isConverting = false;
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    inputStyleNotifier.removeListener(_onInputStyleChanged);
    CompanyService.activeCompanyNotifier.removeListener(_onCompanyChanged);
    super.dispose();
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
    await DataMigrationService.runConversion(widget.db, widget.prefs);
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

    return MaterialApp(
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
