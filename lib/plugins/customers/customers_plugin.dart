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
  Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    if (fromVersion < 2) {
      final cols = {
        'contact_version_id': 'INTEGER',
        'odoo_id': 'TEXT',
        'kana': 'TEXT',
        'rank_discount_rate': 'REAL',
        'is_synced': 'INTEGER DEFAULT 0',
        'is_current': 'INTEGER DEFAULT 1',
        'version': 'INTEGER DEFAULT 1',
        'content_hash': 'TEXT',
        'previous_hash': 'TEXT',
        'next_version_id': 'TEXT',
        'valid_from': 'TEXT',
        'valid_to': 'TEXT',
      };
      for (final e in cols.entries) {
        try {
          await db.execute('ALTER TABLE customers ADD COLUMN ${e.key} ${e.value}');
        } catch (_) {}
      }
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS customer_contacts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id TEXT NOT NULL,
            contact_version_id INTEGER,
            display_name TEXT,
            formal_name TEXT,
            title INTEGER DEFAULT 1,
            department TEXT,
            address TEXT,
            tel TEXT,
            email TEXT,
            is_active INTEGER DEFAULT 1,
            created_at TEXT NOT NULL,
            FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE customer_contacts ADD COLUMN version INTEGER DEFAULT 1');
      } catch (_) {}
    }
  }

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
        contact_version_id INTEGER,
        odoo_id TEXT,
        kana TEXT,
        head_char1 TEXT,
        head_char2 TEXT,
        closing_day INTEGER,
        payment_day INTEGER,
        rank TEXT DEFAULT 'none',
        rank_discount_rate REAL,
        credit_limit INTEGER DEFAULT 0,
        credit_note TEXT,
        lat REAL,
        lng REAL,
        is_locked INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        is_current INTEGER DEFAULT 1,
        version INTEGER DEFAULT 1,
        content_hash TEXT,
        previous_hash TEXT,
        next_version_id TEXT,
        valid_from TEXT,
        valid_to TEXT,
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
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customer_contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id TEXT NOT NULL,
        contact_version_id INTEGER,
        display_name TEXT,
        formal_name TEXT,
        title INTEGER DEFAULT 1,
        department TEXT,
        address TEXT,
        tel TEXT,
        email TEXT,
        version INTEGER DEFAULT 1,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_contacts_customer ON customer_contacts(customer_id)',
    );
  }
}
