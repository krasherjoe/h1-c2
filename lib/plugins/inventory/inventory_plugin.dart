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

class InventoryPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.inventory';

  @override
  String get name => '在庫管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '在庫入出庫・棚卸・調整';

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
      id: 'INV',
      title: '在庫管理',
      route: '/inventory',
      category: '在庫',
      icon: Icons.warehouse,
      description: '商品別在庫一覧',
    ),
    const MenuItem(
      id: 'STI',
      title: '入庫',
      route: '/inventory/inbound',
      category: '在庫',
      icon: Icons.arrow_downward,
      description: '入庫登録',
    ),
    const MenuItem(
      id: 'STO',
      title: '出庫',
      route: '/inventory/outbound',
      category: '在庫',
      icon: Icons.arrow_upward,
      description: '出庫登録',
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
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transactions (
        id TEXT PRIMARY KEY,
        transaction_type TEXT NOT NULL,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT
      )
    ''');
    debugPrint('[InventoryPlugin] Tables created');
  }
}
