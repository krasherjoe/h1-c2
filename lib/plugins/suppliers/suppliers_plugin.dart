import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import 'screens/supplier_list_screen.dart';
import 'screens/supplier_editor_screen.dart';
import 'screens/supplier_products_screen.dart';
import 'services/supplier_product_service.dart';
import '../pricelist/screens/price_explorer_screen.dart';

class SuppliersPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.suppliers';

  @override
  String get name => '仕入先管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '仕入先マスターの管理';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[SuppliersPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[SuppliersPlugin] Disposed');
  }

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/suppliers': (_) => const SupplierListScreen(),
    '/suppliers/edit': (_) => const SupplierEditorScreen(),
    '/pricelist': (_) => const PriceExplorerScreen(),
    '/suppliers/products': (_) => const SupplierProductsScreen(),
  };

  @override
  Future<void> createTables(Database db) async {
    await SupplierProductService().createTable(db);
  }
}
