import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../plugin_system/plugin_interface.dart';
import '../../../plugin_system/plugin_context.dart';
import '../../../plugin_system/plugin_permission.dart';
import '../../../plugin_system/menu_item.dart';
import '../../../explorer/h1_explorer.dart';
import 'explorer/product_explorer_config.dart';

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
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[ProductsPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[ProductsPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'P1',
      title: '商品マスター',
      route: '/products',
      category: 'マスター',
      icon: Icons.inventory_2,
      description: '商品の登録・編集',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/products': (_) => H1Explorer(config: ProductExplorerConfig()),
  };

  @override
  Future<void> createTables(Database db) async {}
}
