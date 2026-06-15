import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_helper.dart';
import 'services/db_snapshot_service.dart';
import 'services/company_service.dart';
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
import 'plugins/analytics/analytics_plugin.dart';
import 'plugins/accounting/accounting_plugin.dart';
import 'plugins/accounting2/accounting2_plugin.dart';
import 'plugins/drivebackup/drive_backup_plugin.dart';
import 'plugins/sync/sync_plugin.dart';
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
import 'plugins/project/project_plugin.dart';
import 'plugins/memorandum/memorandum_plugin.dart';
import 'plugins/ar/ar_plugin.dart';
import 'plugins/daily/daily_plugin.dart';
import 'plugins/pricelist/price_list_plugin.dart';
import 'plugins/suppliers/suppliers_plugin.dart';
import 'utils/theme_utils.dart';
import 'utils/app_theme.dart';
import 'services/error_reporter.dart';
import 'services/mm_command_service.dart';
import 'services/debug_console.dart';
import 'services/log_dispatcher.dart';
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

Future<String> _cmdMmCheck(List<String> _) async {
  try {
    final buf = StringBuffer();
    final prefs = await SharedPreferences.getInstance();
    final pat = prefs.getString('mattermost_pat');
    final baseUrl = prefs.getString('mattermost_base_url') ?? 'https://mm.ka.sugeee.com';
    final teamName = prefs.getString('mattermost_team_name') ?? 'cyb';
    final webhookUrl = prefs.getString('mattermost_webhook_url');

    buf.writeln('📡 Mattermost 診断');
    buf.writeln('  URL: $baseUrl');
    buf.writeln('  チーム: $teamName');
    buf.writeln('  PAT: ${pat != null ? '✅ 設定済み (${pat.substring(0, 4)}...)': '❌ 未設定'}');
    buf.writeln('  Webhook: ${webhookUrl != null ? '✅ 設定済み' : '❌ 未設定'}');

    if (pat == null) {
      buf.writeln('\n❌ PAT未設定のため接続テストをスキップ');
      return buf.toString();
    }

    final headers = {'Authorization': 'Bearer $pat', 'Content-Type': 'application/json'};

    buf.writeln('\n--- 接続テスト ---');
    try {
      final pingRes = await http.get(Uri.parse('$baseUrl/api/v4/system/ping'), headers: headers);
      if (pingRes.statusCode == 200) {
        buf.writeln('  Ping: ✅ ${pingRes.body}');
      } else {
        buf.writeln('  Ping: ❌ (${pingRes.statusCode})');
      }
    } catch (e) {
      buf.writeln('  Ping: ❌ $e');
      buf.writeln('\n❌ サーバーに到達できません');
      return buf.toString();
    }

    try {
      final teamRes = await http.get(Uri.parse('$baseUrl/api/v4/teams/name/$teamName'), headers: headers);
      if (teamRes.statusCode == 200) {
        final team = jsonDecode(teamRes.body);
        buf.writeln('  チーム: ✅ ${team['display_name']} (${team['id']})');
        final teamId = team['id'] as String;

        final chRes = await http.get(
          Uri.parse('$baseUrl/api/v4/teams/$teamId/channels/name/h1-debug'),
          headers: headers,
        );
        if (chRes.statusCode == 200) {
          final ch = jsonDecode(chRes.body);
          buf.writeln('  チャンネル(h1-debug): ✅ ${ch['display_name']} (${ch['id']})');
        } else {
          buf.writeln('  チャンネル(h1-debug): ❌ (${chRes.statusCode})');
        }
      } else {
        buf.writeln('  チーム: ❌ (${teamRes.statusCode})');
      }
    } catch (e) {
      buf.writeln('  チーム/チャンネル取得: ❌ $e');
    }

    buf.writeln('\n✅ 診断完了');
    return buf.toString();
  } catch (e) {
    return 'mmcheck 失敗: $e';
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

Future<String> _cmdDbSend(List<String> _) async {
  try {
    final db = await DatabaseHelper().database;
    final file = File(db.path);
    if (!await file.exists()) return 'DBファイルなし';
    final bytes = await file.readAsBytes();
    final svc = MmCommandService.instance;
    final channelId = await svc.channelId;
    if (channelId == null) return 'チャンネル取得失敗';
    if (svc.pat == null || svc.baseUrl == null) return 'PAT未設定';

    final uploadReq = http.MultipartRequest(
      'POST', Uri.parse('${svc.baseUrl}/api/v4/files'),
    );
    uploadReq.headers['Authorization'] = 'Bearer ${svc.pat}';
    uploadReq.fields['channel_id'] = channelId;
    uploadReq.files.add(await http.MultipartFile.fromBytes('files', bytes, filename: 'h1-core_db_cmd.db'));
    final uploadRes = await uploadReq.send();
    final uploadBody = await uploadRes.stream.bytesToString();
    if (uploadRes.statusCode != 201) return 'アップロード失敗(${uploadRes.statusCode})';
    final data = jsonDecode(uploadBody);
    final fileIds = (data['file_infos'] as List).map<String>((f) => f['id'] as String).toList();
    await http.post(
      Uri.parse('${svc.baseUrl}/api/v4/posts'),
      headers: {'Authorization': 'Bearer ${svc.pat}', 'Content-Type': 'application/json'},
      body: jsonEncode({'channel_id': channelId, 'message': ':floppy_disk: **コマンド経由DB送信**', 'file_ids': fileIds}),
    );
    return 'DB送信完了';
  } catch (e) {
    return 'DB送信失敗: $e';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _migrateIfNeeded();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorReporter.sendError(
      message: '${details.exceptionAsString()} | ${details.library}',
      detail: details.context?.toString(),
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

  await MmCommandService.instance.loadConfig();
  await LogDispatcher.loadConfig();

  DebugConsole.register('ping', (_) async => 'pong');
  DebugConsole.register('mmcheck', _cmdMmCheck);
  DebugConsole.register('system.status', _cmdStatus);
  DebugConsole.register('system.dump', _cmdDump);
  DebugConsole.register('db.send', _cmdDbSend);
  DebugConsole.register('db.snapshot', (_) async {
    final path = await DbSnapshotService.snapshot();
    return path != null ? 'スナップショット作成完了' : 'スナップショット失敗';
  });
  DebugConsole.register('db.restore', (args) async {
    if (args.isEmpty) {
      final snaps = await DbSnapshotService.list();
      if (snaps.isEmpty) return 'スナップショットなし';
      final lines = snaps.asMap().entries.map((e) => '  ${e.key}: ${e.value.split('/').last}').join('\n');
      return 'スナップショット一覧:\n$lines\n\n使用例: !opencode db.restore 0';
    }
    final index = int.tryParse(args[0]);
    if (index == null) return '数値を指定: !opencode db.restore 0';
    await DbSnapshotService.restore(index);
    return '復元完了、アプリを再起動してください';
  });

  if (MmCommandService.instance.isEnabled) {
    MmCommandService.instance.start();
  }

  final db = await DatabaseHelper().database;
  final prefs = await SharedPreferences.getInstance();
  debugPrint('[Startup] DB ready, prefs ready');

  final context = PluginContext(database: db, preferences: prefs);

  final registry = PluginRegistry.instance;
  registry.setContext(context);

  // プラグイン登録（各ステップでログ出力）
  final plugins = <H1Plugin>[
    CorePlugin(), DocumentsPlugin(), CustomersPlugin(),
    ProductsPlugin(), CompanyPlugin(), SettingsPlugin(),
    InventoryPlugin(), PurchasePlugin(), AnalyticsPlugin(),
    AnalysisPlugin(), AccountingPlugin(), Accounting2Plugin(),
    QuickActionsPlugin(), ExplorerPlugin(), BackupPlugin(),
    ConversionPlugin(), AuditPlugin(), DebugPlugin(),
    DriveBackupPlugin(), ProjectPlugin(), MemorandumPlugin(),
    ArPlugin(), DailyPlugin(), PriceListPlugin(), SuppliersPlugin(),
    SyncPlugin(),
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

  runApp(H1CoreApp(registry: registry, db: db, prefs: prefs));
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
    _applySystemNavBar(_themeMode);
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
    _applyNavBarColor(mode, widget.prefs);
  }
}

void applyNavBarColor() {
  try {
    SharedPreferences.getInstance().then((prefs) {
      final mode = themeNotifier.value;
      _applyNavBarColor(mode, prefs);
    });
  } catch (_) {}
}

void _applyNavBarColor(ThemeMode mode, SharedPreferences prefs) {
  final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);
  final navbarStyle = prefs.getString('navbar_style') ?? 'primary';
  final cs = isDark ? AppTheme.dark() : AppTheme.light();
  final navBarColor = switch (navbarStyle) {
    'primary' => cs.colorScheme.primary,
    'black' => Colors.black,
    _ => isDark ? const Color(0xFF2C2C2E) : const Color(0xFF2E2E2E),
  };
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    systemNavigationBarColor: navBarColor,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}
