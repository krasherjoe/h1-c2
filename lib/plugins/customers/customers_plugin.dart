import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../plugin_system/plugin_interface.dart';
import '../../../plugin_system/plugin_context.dart';
import '../../../plugin_system/plugin_permission.dart';
import '../../../plugin_system/menu_item.dart';
import '../../../explorer/h1_explorer.dart';
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
  Future<void> createTables(Database db) async {}
}
