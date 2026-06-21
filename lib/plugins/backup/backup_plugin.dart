import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import '../../services/database_helper.dart';
import 'screens/backup_screen.dart';
import 'services/local_backup_service.dart';
import '../../constants/screen_ids.dart';

class BackupPlugin extends H1Plugin {
  @override String get id => 'com.h1.plugin.backup';
  @override String get name => 'バックアップ';
  @override String get version => '1.0.0';
  @override String get description => 'ローカル自動バックアップ・リストア（7年保存対応）';

  @override
  Future<void> initialize(PluginContext context) async {
    _runAutoBackup();
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: S.bk,
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

  @override
  Future<Map<String, dynamic>> getDebugInfo() async {
    final localService = LocalBackupService();
    final backups = await localService.listBackups();
    final storageInfo = await localService.getStorageInfo();
    return {
      'backup_count': backups.length,
      'storage_size_bytes': storageInfo['sizeBytes'],
      'storage_size_readable': storageInfo['sizeReadable'],
      'recent_backups': backups.take(5).map((b) => {
        'filename': b.filename,
        'size_bytes': b.sizeBytes,
        'created_at': b.createdAt.toIso8601String(),
        'hash': b.hash,
      }).toList(),
    };
  }

  void _runAutoBackup() async {
    try {
      final dbPath = await DatabaseHelper().getDatabasePath();
      await LocalBackupService().createAutoBackup(dbPath);
    } catch (e) {
      debugPrint('[BackupPlugin] 自動バックアップエラー: $e');
    }
  }
}
