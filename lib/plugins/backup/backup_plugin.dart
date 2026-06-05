import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/screen_definition.dart';
import '../../services/database_helper.dart';
import 'screens/backup_screen.dart';
import 'services/local_backup_service.dart';

class BackupPlugin extends H1Plugin {
  @override String get id => 'com.h1.plugin.backup';
  @override String get name => 'バックアップ';
  @override String get version => '1.0.0';
  @override String get description => 'ローカル自動バックアップ・リストア（7年保存対応）';
  @override List<String> get dependencies => ['com.h1.core'];
  @override List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    _runAutoBackup();
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'BK',
      title: 'バックアップ管理',
      route: '/backup',
      builder: (_) => const BackupScreen(),
      category: 'システム',
      icon: Icons.backup,
      description: 'DB自動バックアップ・リストア',
    ),
  ];

  @override Future<void> dispose() async {}

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/backup': (_) => const BackupScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}

  void _runAutoBackup() async {
    try {
      final dbPath = await DatabaseHelper().getDatabasePath();
      await LocalBackupService().createAutoBackup(dbPath);
    } catch (e) {
      debugPrint('[BackupPlugin] 自動バックアップエラー: $e');
    }
  }
}
