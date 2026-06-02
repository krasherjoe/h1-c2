import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import 'screens/supplier_list_screen.dart';
import 'screens/supplier_editor_screen.dart';
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
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'SL',
      title: '仕入先マスター',
      route: '/suppliers',
      category: 'マスター',
      icon: Icons.person,
      description: '仕入先の登録・編集',
    ),
    const MenuItem(
      id: 'PE',
      title: '価格表',
      route: '/pricelist',
      category: 'マスター',
      icon: Icons.monetization_on,
      description: '価格表の管理',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/suppliers': (_) => const SupplierListScreen(),
    '/suppliers/edit': (_) => const SupplierEditorScreen(),
    '/pricelist': (_) => const PriceExplorerScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}
}
