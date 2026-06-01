import 'package:flutter/material.dart';
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
import 'screens/dashboard_screen.dart';
import 'screens/invoice_input/invoice_input_form.dart';
import 'screens/invoice_history/invoice_history_screen.dart';
import 'screens/plugin_management_screen.dart';

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
  await registry.register(SettingsPlugin());
  await registry.register(InventoryPlugin());
  await registry.register(PurchasePlugin());
  await registry.register(AnalyticsPlugin());
  await registry.register(AccountingPlugin());
  await registry.register(QuickActionsPlugin());

  final stateService = PluginStateService();
  final states = await stateService.loadAll(
    registry.allPlugins.map((p) => p.id).toList(),
  );
  for (final entry in states.entries) {
    if (!entry.value) {
      registry.setEnabled(entry.key, false);
    }
  }

  runApp(H1CoreApp(registry: registry));
}

class H1CoreApp extends StatelessWidget {
  final PluginRegistry registry;

  const H1CoreApp({super.key, required this.registry});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '販売アシスト1号 コア',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
      routes: {
        '/invoice/input': (_) => const InvoiceInputForm(),
        '/invoice/history': (_) => const InvoiceHistoryScreen(),
        '/plugins': (_) => const PluginManagementScreen(),
        ...registry.getAllRoutes(),
      },
    );
  }
}
