import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import 'models/memorandum_model.dart';
import 'screens/memorandum_list_screen.dart';
import 'screens/memorandum_input_screen.dart';
import 'screens/memorandum_preview_screen.dart';
import '../../constants/screen_ids.dart';
import '../../services/database/database_utils.dart';

class MemorandumPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.memorandum';

  @override
  String get name => '覚書管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '保守サービス覚書（契約書）の作成・管理';

  @override
  List<String> get dependencies => ['com.h1.core'];


  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[MemorandumPlugin] Initialized');
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: S.memo,
      title: '覚書管理',
      route: '/memorandum',
      builder: (_) => const MemorandumListScreen(),
      category: '販売',
      icon: Icons.description,
      description: '保守サービス覚書の作成・管理',
    ),
  ];

  @override
  Future<void> dispose() async {
    debugPrint('[MemorandumPlugin] Disposed');
  }

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/memorandum': (_) => const MemorandumListScreen(),
    '/memorandum/edit': (_) => const MemorandumInputScreen(),
    '/memorandum/preview': (context) => MemorandumPreviewScreen(
      memorandum: ModalRoute.of(context)!.settings.arguments as Memorandum,
    ),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS memorandums (
        id TEXT PRIMARY KEY,
        document_number TEXT NOT NULL,
        customer_id TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        contract_date TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        contract_months INTEGER NOT NULL,
        monthly_plan TEXT NOT NULL,
        custom_amount INTEGER,
        service_content TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        notes TEXT,
        customer_representative TEXT,
        company_representative TEXT,
        project_id TEXT,
        estimate_id TEXT,
        status TEXT NOT NULL DEFAULT 'draft',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memorandums_customer ON memorandums(customer_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memorandums_status ON memorandums(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_memorandums_project ON memorandums(project_id)',
    );
    await safeAddColumn(db, 'memorandums', 'customer_representative TEXT');
    await safeAddColumn(db, 'memorandums', 'company_representative TEXT');
  }
}
