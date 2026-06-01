import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_helper.dart';
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
import 'plugins/audit/audit_plugin.dart';
import 'utils/theme_utils.dart';
import 'screens/dashboard_screen.dart';
import 'screens/invoice_input/invoice_input_form.dart';
import 'screens/invoice_history/invoice_history_screen.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  await registry.register(AccountingPlugin());
  await registry.register(QuickActionsPlugin());
  await registry.register(ExplorerPlugin());
  await registry.register(BackupPlugin());
  await registry.register(ConversionPlugin());
  await registry.register(AuditPlugin());

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
    _check();
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() => _themeMode = themeNotifier.value);
  }

  Future<void> _check() async {
    final needs = await DataMigrationService.needsConversion(widget.db);
    if (!mounted) return;
    setState(() => _needsConversion = needs);
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
    final lightScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
    ).copyWith(
      surfaceContainerLowest: const Color(0xFFE5E5E8),
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    ).copyWith(
      surfaceContainerLowest: const Color(0xFF2C2C2E),
    );
    return MaterialApp(
      title: '販売アシスト1号 コア',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        fontFamily: 'IPAexGothic',
        scaffoldBackgroundColor: lightScheme.surfaceContainerLowest,
        brightness: Brightness.light,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.primary,
          foregroundColor: lightScheme.onPrimary,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFF5F5F7),
          elevation: 1,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        useMaterial3: true,
        fontFamily: 'IPAexGothic',
        scaffoldBackgroundColor: darkScheme.surfaceContainerLowest,
        brightness: Brightness.dark,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.primary,
          foregroundColor: darkScheme.onPrimary,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF3A3A3D),
          elevation: 1,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      themeMode: _themeMode,
      builder: (context, child) => SafeArea(
        top: true,
        bottom: true,
        child: child!,
      ),
      home: _buildHome(),
      routes: {
        '/invoice/input': (_) => const InvoiceInputForm(),
        '/invoice/history': (_) => const InvoiceHistoryScreen(),
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
    return const DashboardScreen();
  }
}
