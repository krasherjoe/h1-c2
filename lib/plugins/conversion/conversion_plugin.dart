import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import 'services/data_migration_service.dart';
import 'screens/conversion_guard_screen.dart';

class ConversionPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.conversion';

  @override
  String get name => 'データ変換';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'V1→V2 データベース変換';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[ConversionPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {}

  @override
  List<MenuItem> getMenuItems() => [];

  @override
  Map<String, WidgetBuilder> getRoutes() => {};

  @override
  Future<void> createTables(Database db) async {}

  @override
  Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    if (fromVersion < 2) {
      final prefs = await SharedPreferences.getInstance();
      await DataMigrationService.runConversion(db, prefs);
    }
  }
}
