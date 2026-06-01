import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../plugin_system/plugin_interface.dart';
import '../../../plugin_system/plugin_context.dart';
import '../../../plugin_system/plugin_permission.dart';
import '../../../plugin_system/menu_item.dart';
import '../../../plugins/explorer/h1_explorer.dart';
import 'explorer/customer_explorer_config.dart';

class CustomersPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.customers';

  @override
  String get name => '顧客管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '顧客マスターの管理';

  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[CustomersPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[CustomersPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'C1',
      title: '顧客マスター',
      route: '/customers',
      category: 'マスター',
      icon: Icons.people,
      description: '得意先の登録・編集',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/customers': (_) => H1Explorer(config: CustomerExplorerConfig()),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        formal_name TEXT NOT NULL,
        title TEXT DEFAULT '様',
        department TEXT,
        address TEXT,
        tel TEXT,
        email TEXT,
        head_char1 TEXT,
        head_char2 TEXT,
        closing_day INTEGER,
        payment_day INTEGER,
        rank TEXT DEFAULT 'none',
        credit_limit INTEGER DEFAULT 0,
        credit_note TEXT,
        lat REAL,
        lng REAL,
        is_locked INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_product_prices (
        customer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        price INTEGER NOT NULL,
        PRIMARY KEY(customer_id, product_id),
        FOREIGN KEY(customer_id) REFERENCES customers(id),
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_prices_customer ON customer_product_prices(customer_id)',
    );
  }
}
