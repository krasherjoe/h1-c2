import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/screen_definition.dart';
import 'screens/inventory_list_screen.dart';
import 'screens/stock_inbound_screen.dart';
import 'screens/stock_outbound_screen.dart';
import 'screens/stocktake_screen.dart';
import 'screens/stock_adjustment_screen.dart';
import 'screens/stocktake_input_screen.dart';
import 'screens/stock_transfer_screen.dart';
import 'screens/inventory_valuation_screen.dart';
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
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'INV', title: '在庫一覧', route: '/inventory',
      builder: (_) => const InventoryListScreen(),
      category: '在庫', icon: Icons.inventory,
      description: '商品別在庫一覧',
    ),
    ScreenDefinition(
      id: 'WH', title: '倉庫一覧', route: '/inventory/warehouses',
      builder: (_) => const WarehouseListScreen(),
      category: '在庫', icon: Icons.warehouse,
      description: '倉庫マスターの管理',
    ),
    ScreenDefinition(
      id: 'WHI', title: '入庫処理', route: '/inventory/inbound',
      builder: (_) => const StockInboundScreen(),
      category: '在庫', icon: Icons.arrow_downward,
      description: '入庫登録',
    ),
    ScreenDefinition(
      id: 'WHO', title: '出庫処理', route: '/inventory/outbound',
      builder: (_) => const StockOutboundScreen(),
      category: '在庫', icon: Icons.arrow_upward,
      description: '出庫登録',
    ),
    ScreenDefinition(
      id: 'IQ', title: '在庫照会', route: '/inventory/inquiry',
      builder: (_) => const StockInquiryScreen(),
      category: '在庫', icon: Icons.search,
      description: '商品在庫の照会',
    ),
    ScreenDefinition(
      id: 'STK', title: '棚卸', route: '/inventory/stocktake',
      builder: (_) => const StocktakeScreen(),
      category: '在庫', icon: Icons.fact_check,
      description: '棚卸入力',
    ),
    ScreenDefinition(
      id: 'IC', title: '棚卸入力(一括)', route: '/inventory/stocktake_input',
      builder: (_) => const StocktakeInputScreen(),
      category: '在庫', icon: Icons.edit_note,
      description: '一括棚卸入力',
    ),
    ScreenDefinition(
      id: 'IA', title: '在庫調整', route: '/inventory/adjustment',
      builder: (_) => const StockAdjustmentScreen(),
      category: '在庫', icon: Icons.tune,
      description: '在庫調整',
    ),
    ScreenDefinition(
      id: 'IM', title: '在庫移動', route: '/inventory/transfer',
      builder: (_) => const StockTransferScreen(),
      category: '在庫', icon: Icons.swap_horiz,
      description: '倉庫間在庫移動',
    ),
    ScreenDefinition(
      id: 'R4', title: '在庫評価額', route: '/inventory/valuation',
      builder: (_) => const InventoryValuationScreen(),
      category: '在庫', icon: Icons.account_balance,
      description: '在庫評価額一覧',
    ),
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
  Map<String, WidgetBuilder> getRoutes() => {
    '/inventory': (_) => const InventoryListScreen(),
    '/inventory/inbound': (_) => const StockInboundScreen(),
    '/inventory/outbound': (_) => const StockOutboundScreen(),
    '/inventory/stocktake': (_) => const StocktakeScreen(),
    '/inventory/adjustment': (_) => const StockAdjustmentScreen(),
    '/inventory/stocktake_input': (_) => const StocktakeInputScreen(),
    '/inventory/transfer': (_) => const StockTransferScreen(),
    '/inventory/valuation': (_) => const InventoryValuationScreen(),
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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transfers (
        id TEXT PRIMARY KEY,
        document_no TEXT NOT NULL,
        from_warehouse_id TEXT NOT NULL,
        to_warehouse_id TEXT NOT NULL,
        memo TEXT,
        transfer_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by_device TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transfer_items (
        id TEXT PRIMARY KEY,
        transfer_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        notes TEXT,
        FOREIGN KEY (transfer_id) REFERENCES stock_transfers(id)
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
