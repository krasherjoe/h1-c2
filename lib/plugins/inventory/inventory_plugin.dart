import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import 'screens/inventory_list_screen.dart';
import 'screens/stock_inbound_screen.dart';
import 'screens/stock_outbound_screen.dart';
import 'screens/stocktake_screen.dart';
import 'screens/stock_adjustment_screen.dart';
import 'screens/warehouse_list_screen.dart';
import 'screens/stock_inquiry_screen.dart';

class InventoryPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.inventory';

  @override
  String get name => '在庫管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '在庫入出庫・棚卸・調整・倉庫管理';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[InventoryPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[InventoryPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'WH',
      title: '倉庫一覧',
      route: '/inventory/warehouses',
      category: '在庫',
      icon: Icons.warehouse,
      description: '倉庫マスターの管理',
    ),
    const MenuItem(
      id: 'INV',
      title: '在庫一覧',
      route: '/inventory',
      category: '在庫',
      icon: Icons.inventory,
      description: '商品別在庫一覧',
    ),
    const MenuItem(
      id: 'WHI',
      title: '入庫処理',
      route: '/inventory/inbound',
      category: '在庫',
      icon: Icons.arrow_downward,
      description: '入庫登録',
    ),
    const MenuItem(
      id: 'WHO',
      title: '出庫処理',
      route: '/inventory/outbound',
      category: '在庫',
      icon: Icons.arrow_upward,
      description: '出庫登録',
    ),
    const MenuItem(
      id: 'IQ',
      title: '在庫照会',
      route: '/inventory/inquiry',
      category: '在庫',
      icon: Icons.search,
      description: '商品在庫の照会',
    ),
    const MenuItem(
      id: 'STK',
      title: '棚卸',
      route: '/inventory/stocktake',
      category: '在庫',
      icon: Icons.fact_check,
      description: '棚卸入力',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/inventory': (_) => const InventoryListScreen(),
    '/inventory/inbound': (_) => const StockInboundScreen(),
    '/inventory/outbound': (_) => const StockOutboundScreen(),
    '/inventory/stocktake': (_) => const StocktakeScreen(),
    '/inventory/adjustment': (_) => const StockAdjustmentScreen(),
    '/inventory/warehouses': (_) => const WarehouseListScreen(),
    '/inventory/inquiry': (_) => const StockInquiryScreen(),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        location TEXT,
        notes TEXT,
        is_hidden INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouse_stock (
        product_id TEXT NOT NULL,
        warehouse_id TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (product_id, warehouse_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transactions (
        id TEXT PRIMARY KEY,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        warehouse_id TEXT,
        warehouse_name TEXT,
        quantity INTEGER NOT NULL,
        type TEXT NOT NULL,
        reference_id TEXT,
        reference_number TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_transactions_product ON stock_transactions(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_transactions_created ON stock_transactions(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_warehouse_stock_product ON warehouse_stock(product_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_warehouse_stock_warehouse ON warehouse_stock(warehouse_id)',
    );

    debugPrint('[InventoryPlugin] Tables created');
  }
}
