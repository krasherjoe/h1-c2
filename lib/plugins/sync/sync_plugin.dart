import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import '../../services/sync_queue.dart';
import '../../services/company_service.dart';
import '../../services/database_helper.dart';
import 'screens/sync_home_screen.dart';

class SyncPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.sync';
  @override
  String get name => 'グループ同期';
  @override
  String get version => '1.0.0';
  @override
  String get description => 'Gmail経由で端末間データ同期';
  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'SY',
      title: 'グループ同期',
      route: '/sync',
      category: 'システム',
      icon: Icons.sync,
      builder: (_) => const SyncHomeScreen(),
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {};
  @override
  Future<void> dispose() async {}
  @override
  Future<void> createTables(Database db) async {
    await _migrate(db);
  }
  @override
  Future<void> initialize(PluginContext context) async {
    await _migrateSpToDb();
    await SyncQueue.instance.init();
    if (SyncQueue.instance.isParent) SyncQueue.instance.startPolling();
    CompanyService.activeCompanyNotifier.addListener(_onCompanyChanged);
  }

  void _onCompanyChanged() {
    SyncQueue.instance.onCompanySwitch();
  }

  Future<void> _migrate(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''');
    for (final table in ['documents', 'journal_entries', 'cash_transactions']) {
      try { await db.execute("ALTER TABLE $table ADD COLUMN sync_source TEXT DEFAULT ''"); } catch (_) {}
      try { await db.execute("ALTER TABLE $table ADD COLUMN sync_version INTEGER DEFAULT 0"); } catch (_) {}
    }
  }

  Future<void> _migrateSpToDb() async {
    try {
      final db = await DatabaseHelper().database;
      final cnt = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM sync_config')) ?? 0;
      if (cnt > 0) return;
      final prefs = await SharedPreferences.getInstance();
      final parentEmail = prefs.getString('sync_parent_email');
      final lastCheck = prefs.getInt('sync_last_check');
      if (parentEmail != null) {
        await db.insert('sync_config', {'key': 'parent_email', 'value': parentEmail});
      }
      if (lastCheck != null) {
        await db.insert('sync_config', {'key': 'last_check', 'value': lastCheck.toString()});
      }
    } catch (_) {}
  }
}
