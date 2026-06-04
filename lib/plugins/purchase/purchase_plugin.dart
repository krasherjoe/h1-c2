import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugins/explorer/h1_explorer.dart';
import 'explorer/purchase_explorer_config.dart';
import '../../services/debug_console.dart';

class PurchasePlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.purchase';

  @override
  String get name => '仕入管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '仕入発注・入荷・返品・支払';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    DebugConsole.register('purchase.stats', (_) async {
      final cnt = await context.database.rawQuery("SELECT purchase_type, COUNT(*) as c FROM purchases GROUP BY purchase_type");
      final lines = cnt.map((r) => '  ${r['purchase_type']}: ${r['c']}件').join('\n');
      final total = cnt.fold(0, (s, r) => s + (r['c'] as int? ?? 0));
      return '購買統計:\n$lines\n  合計: $total件';
    });
    debugPrint('[PurchasePlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[PurchasePlugin] Disposed');
  }

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/purchase': (_) => H1Explorer(
      config: PurchaseExplorerConfig(),
    ),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id TEXT PRIMARY KEY,
        purchase_type TEXT NOT NULL,
        supplier_id TEXT,
        supplier_name TEXT,
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
      CREATE TABLE IF NOT EXISTS purchase_items (
        id TEXT PRIMARY KEY,
        purchase_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        quantity REAL DEFAULT 1,
        unit_price INTEGER DEFAULT 0,
        tax_rate REAL DEFAULT 0.1,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        display_name TEXT NOT NULL,
        formal_name TEXT NOT NULL,
        title TEXT DEFAULT '様',
        department TEXT,
        address TEXT,
        tel TEXT,
        email TEXT,
        contact_person TEXT,
        payment_terms TEXT,
        bank_account TEXT,
        closing_day INTEGER,
        payment_site_days INTEGER DEFAULT 30,
        notes TEXT,
        is_locked INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0,
        head_char1 TEXT,
        head_char2 TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_suppliers_display_name ON suppliers(display_name)',
    );
  }
}
