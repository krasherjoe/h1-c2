import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import '../../services/debug_console.dart';
import 'screens/price_explorer_screen.dart';
import 'commands/pricing_commands.dart';

class PriceListPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.pricelist';

  @override
  String get name => '価格表';

  @override
  String get version => '1.0.0';

  @override
  String get description => '価格表の管理';

  @override
  List<String> get dependencies => ['com.h1.core'];


  @override
  Future<void> initialize(PluginContext context) async {
    DebugConsole.register('pricing.dump', cmdPricingDump);
    debugPrint('[PriceListPlugin] Initialized');
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'PE',
      title: '価格表',
      route: '/pricelist',
      builder: (_) => const PriceExplorerScreen(),
      category: 'マスター',
      icon: Icons.price_change,
      description: '価格表の管理',
    ),
  ];

  @override
  Future<void> dispose() async {
    debugPrint('[PriceListPlugin] Disposed');
  }

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/pricelist': (_) => const PriceExplorerScreen(),
  };

  @override
  Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    if (fromVersion < 2) {
      try {
        await db.execute('ALTER TABLE price_entries ADD COLUMN supplier_id TEXT');
      } catch (_) {}
    }
    if (fromVersion < 3) {
      try {
        await db.execute('ALTER TABLE price_entries ADD COLUMN customer_id TEXT');
      } catch (_) {}
    }
  }

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS price_entries (
        id TEXT PRIMARY KEY,
        year TEXT NOT NULL,
        parent_id TEXT,
        name TEXT NOT NULL,
        unit_price INTEGER,
        product_id TEXT,
        supplier_id TEXT,
        customer_id TEXT,
        notes TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(parent_id) REFERENCES price_entries(id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pe_parent ON price_entries(parent_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pe_year ON price_entries(year)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pe_name ON price_entries(name)');
  }
}
