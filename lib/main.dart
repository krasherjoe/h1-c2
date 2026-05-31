import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/database_helper.dart';
import 'plugin_system/plugin_registry.dart';
import 'plugin_system/plugin_context.dart';
import 'plugins/quotation_plugin.dart';
import 'screens/dashboard_screen.dart';
import 'screens/plugin_management_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await DatabaseHelper().database;
  final prefs = await SharedPreferences.getInstance();

  final context = PluginContext(database: db, preferences: prefs);

  final registry = PluginRegistry.instance;
  registry.setContext(context);

  // プラグイン登録
  await registry.register(QuotationPlugin());

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
        '/plugins': (_) => const PluginManagementScreen(),
        ...registry.getAllRoutes(),
      },
    );
  }
}
