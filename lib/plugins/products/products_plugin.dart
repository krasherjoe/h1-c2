import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../plugin_system/plugin_interface.dart';
import '../../../plugin_system/plugin_context.dart';
import '../../../plugin_system/screen_definition.dart';
import '../../../plugins/explorer/h1_explorer.dart';
import 'explorer/product_explorer_config.dart';
import 'screens/category_explorer_screen.dart';
import '../../../services/debug_console.dart';

class ProductsPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.products';

  @override
  String get name => '商品管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '商品マスターの管理';

  @override
  List<String> get dependencies => ['com.h1.core'];


  @override
  Future<void> initialize(PluginContext context) async {
    DebugConsole.register('products.stats', (_) async {
      final cnt = await context.database.rawQuery('SELECT COUNT(*) as c FROM products');
      return '商品: ${cnt.first['c']}件';
    });
    debugPrint('[ProductsPlugin] Initialized');
  }

  @override
  Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    const missing = <String, String>{
      'wholesale_price_is_tax_inclusive': 'INTEGER DEFAULT 0',
      'odoo_id': 'TEXT',
      'parent_id': 'TEXT',
      'valid_from': 'TEXT',
      'valid_to': 'TEXT',
      'is_current': 'INTEGER DEFAULT 1',
      'version': 'INTEGER DEFAULT 1',
      'content_hash': 'TEXT',
      'previous_hash': 'TEXT',
    };
    for (final e in missing.entries) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN ${e.key} ${e.value}');
      } catch (_) {}
    }
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'P1',
      title: '商品マスター',
      route: '/products',
      builder: (_) => H1Explorer(config: ProductExplorerConfig()),
      category: 'マスター',
      icon: Icons.inventory_2,
      description: '商品の登録・編集',
    ),
    ScreenDefinition(
      id: 'CE',
      title: '商品カテゴリ',
      route: '/products/categories',
      builder: (_) => const CategoryExplorerScreen(),
      category: 'マスター',
      icon: Icons.category,
      description: 'カテゴリの階層管理',
    ),
  ];

  @override
  Future<void> dispose() async {
    debugPrint('[ProductsPlugin] Disposed');
  }

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/products': (_) => H1Explorer(config: ProductExplorerConfig()),
    '/products/categories': (_) => const CategoryExplorerScreen(),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        parent_id TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_categories_name ON product_categories(name)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        default_unit_price INTEGER,
        default_unit_price_is_tax_inclusive INTEGER DEFAULT 0,
        wholesale_price INTEGER DEFAULT 0,
        wholesale_price_is_tax_inclusive INTEGER DEFAULT 0,
        barcode TEXT,
        model_number TEXT,
        manufacturer TEXT,
        category TEXT,
        category_id TEXT,
        stock_quantity INTEGER,
        supplier_id TEXT,
        supplier_name TEXT,
        is_locked INTEGER DEFAULT 0,
        is_hidden INTEGER DEFAULT 0,
        odoo_id TEXT,
        parent_id TEXT,
        valid_from TEXT,
        valid_to TEXT,
        is_current INTEGER DEFAULT 1,
        version INTEGER DEFAULT 1,
        content_hash TEXT,
        previous_hash TEXT,
        description TEXT,
        tags TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(category_id) REFERENCES product_categories(id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_name ON products(name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode)');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_category_id ON products(category_id)',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_option_groups (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        name TEXT NOT NULL,
        price_mode TEXT DEFAULT 'add',
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_option_values (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        value TEXT NOT NULL,
        price_modifier INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY(group_id) REFERENCES product_option_groups(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_variant_options (
        variant_id TEXT NOT NULL,
        option_value_id TEXT NOT NULL,
        PRIMARY KEY(variant_id, option_value_id),
        FOREIGN KEY(variant_id) REFERENCES products(id),
        FOREIGN KEY(option_value_id) REFERENCES product_option_values(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_variant_options_variant ON product_variant_options(variant_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_option_groups_product ON product_option_groups(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_option_values_group ON product_option_values(group_id)',
    );
  }
}
