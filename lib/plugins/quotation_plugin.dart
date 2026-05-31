import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../plugin_system/plugin_interface.dart';
import '../plugin_system/plugin_context.dart';
import '../plugin_system/plugin_permission.dart';
import '../plugin_system/menu_item.dart';

class QuotationPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.quotation';

  @override
  String get name => '見積管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '見積書の作成・編集・PDF出力機能を提供';

  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<PluginPermission> get requiredPermissions => [
        PluginPermission.readDatabase,
        PluginPermission.writeDatabase,
      ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[QuotationPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[QuotationPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() {
    return [
      const MenuItem(
        id: 'Q1',
        title: '見積入力',
        route: '/quotation/input',
        category: '販売管理',
        icon: Icons.description,
        description: '見積書を作成',
      ),
      const MenuItem(
        id: 'QH',
        title: '見積履歴',
        route: '/quotation/history',
        category: '販売管理',
        icon: Icons.history,
        description: '過去の見積を確認',
      ),
    ];
  }

  @override
  Map<String, WidgetBuilder> getRoutes() {
    return {
      '/quotation/input': (_) => const _QuotationInputScreen(),
      '/quotation/history': (_) => const _QuotationHistoryScreen(),
    };
  }

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotations (
        id TEXT PRIMARY KEY,
        customer_id TEXT,
        document_number TEXT,
        issue_date TEXT,
        total INTEGER,
        status TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quotation_items (
        id TEXT PRIMARY KEY,
        quotation_id TEXT,
        product_id TEXT,
        quantity REAL,
        unit_price INTEGER,
        amount INTEGER
      )
    ''');
    debugPrint('[QuotationPlugin] Tables created');
  }
}

class _QuotationInputScreen extends StatelessWidget {
  const _QuotationInputScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見積入力')),
      body: const Center(child: Text('見積入力画面（プラグイン）')),
    );
  }
}

class _QuotationHistoryScreen extends StatelessWidget {
  const _QuotationHistoryScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('見積履歴')),
      body: const Center(child: Text('見積履歴画面（プラグイン）')),
    );
  }
}
