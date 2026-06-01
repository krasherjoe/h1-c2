import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import '../../explorer/h1_explorer.dart';
import 'explorer/document_explorer_config.dart';

class DocumentsPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.documents';

  @override
  String get name => '伝票管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '見積・受注・納品・請求・領収の一元管理';

  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[DocumentsPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[DocumentsPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'DOC',
      title: '伝票管理',
      route: '/documents',
      category: '販売',
      icon: Icons.folder_open,
      description: '見積・納品・請求・領収',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/documents': (_) => H1Explorer(
      config: DocumentExplorerConfig(),
    ),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS documents (
        id TEXT PRIMARY KEY,
        document_type TEXT NOT NULL,
        customer_id TEXT,
        customer_name TEXT,
        document_number TEXT,
        date TEXT,
        total INTEGER DEFAULT 0,
        status TEXT DEFAULT 'draft',
        linked_document_id TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS document_items (
        id TEXT PRIMARY KEY,
        document_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        unit_price INTEGER DEFAULT 0,
        tax_rate REAL DEFAULT 0.1,
        FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');
    debugPrint('[DocumentsPlugin] Tables created');
  }
}
