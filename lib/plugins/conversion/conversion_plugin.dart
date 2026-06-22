import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import 'services/data_migration_service.dart';

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
  Future<void> initialize(PluginContext context) async {
    debugPrint('[ConversionPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {}

  @override
  Map<String, WidgetBuilder> getRoutes() => {};

  @override
  Future<void> createTables(Database db) async {}

  @override
  Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    if (fromVersion < 2) {
      await DataMigrationService.runConversion(db);
    }
  }
}
