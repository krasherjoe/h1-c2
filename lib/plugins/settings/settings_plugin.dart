import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import 'models/company_profile.dart';
import 'services/settings_repository.dart';
import 'screens/settings_screen.dart';

class SettingsPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.settings';

  @override
  String get name => '設定';

  @override
  String get version => '1.0.0';

  @override
  String get description => '会社情報・印刷設定';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    final repo = SettingsRepository(context.preferences);
    final profile = await repo.loadCompanyProfile();
    context.registerService<CompanyProfile>('companyProfile', profile);
    debugPrint('[SettingsPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[SettingsPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'SET',
      title: '設定',
      route: '/settings',
      category: 'システム',
      icon: Icons.settings,
      description: '会社情報・印刷設定',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/settings': (_) => const SettingsScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}
}
