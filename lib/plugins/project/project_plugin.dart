import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import 'screens/project_list_screen.dart';
import 'screens/project_detail_screen.dart';

class ProjectPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.project';

  @override
  String get name => '案件管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '案件の作成・進捗管理と伝票紐付け';

  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[ProjectPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[ProjectPlugin] Disposed');
  }

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/projects': (_) => const ProjectListScreen(),
    '/projects/detail': (_) => const ProjectDetailScreen(),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        status TEXT DEFAULT 'active',
        start_date TEXT,
        end_date TEXT,
        notes TEXT,
        total_amount INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        type TEXT DEFAULT 'sales',
        pipeline_stage TEXT DEFAULT '見積',
        progress INTEGER DEFAULT 0,
        scheme_id TEXT,
        current_stage_index INTEGER DEFAULT 0,
        contract_months INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_projects_customer ON projects(customer_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status)',
    );
  }
}
