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
import 'services/company_service.dart';
import 'plugin_system/plugin_registry.dart';
import 'plugin_system/plugin_context.dart';
import 'plugin_system/core_plugin.dart';
import 'plugin_system/plugin_state_service.dart';
import 'plugins/quotation_plugin.dart';
import 'plugins/documents/documents_plugin.dart';
import 'plugins/customers/customers_plugin.dart';
import 'plugins/products/products_plugin.dart';
import 'plugins/settings/settings_plugin.dart';
import 'plugins/inventory/inventory_plugin.dart';
import 'plugins/purchase/purchase_plugin.dart';
import 'plugins/analytics/analytics_plugin.dart';
import 'plugins/accounting/accounting_plugin.dart';
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
  try {
    final publicDbDir = Directory('/storage/emulated/0/Documents/販売アシスト1号code');
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
  DebugConsole.register('system.status', _cmdStatus);
  DebugConsole.register('system.dump', _cmdDump);
  DebugConsole.register('db.send', _cmdDbSend);

  if (MmCommandService.instance.isEnabled) {
    MmCommandService.instance.start();
  }

  final db = await DatabaseHelper().database;
  final prefs = await SharedPreferences.getInstance();

  final context = PluginContext(database: db, preferences: prefs);

  final registry = PluginRegistry.instance;
  registry.setContext(context);

  // プラグイン登録
  await registry.register(CorePlugin());
  await registry.register(QuotationPlugin());
  await registry.register(DocumentsPlugin());
  await registry.register(CustomersPlugin());
  await registry.register(ProductsPlugin());
  await registry.register(CompanyPlugin());
  await registry.register(SettingsPlugin());
  await registry.register(InventoryPlugin());
  await registry.register(PurchasePlugin());
  await registry.register(AnalyticsPlugin());
  await registry.register(AnalysisPlugin());
  await registry.register(AccountingPlugin());
  await registry.register(QuickActionsPlugin());
  await registry.register(ExplorerPlugin());
  await registry.register(BackupPlugin());
  await registry.register(ConversionPlugin());
  await registry.register(AuditPlugin());
  await registry.register(DebugPlugin());
  await registry.register(ProjectPlugin());
  await registry.register(MemorandumPlugin());
  await registry.register(ArPlugin());
  await registry.register(DailyPlugin());
  await registry.register(PriceListPlugin());
  await registry.register(SuppliersPlugin());

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
      final probe = File('/storage/emulated/0/Documents/販売アシスト1号code/.perm_check');
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
    setState(() => _themeMode = themeNotifier.value);
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
      theme: AppTheme.light(inputStyle: inputStyle),
      darkTheme: AppTheme.dark(inputStyle: inputStyle),
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
}
