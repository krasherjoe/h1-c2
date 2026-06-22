import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../plugin_system/plugin_interface.dart';
import '../../../plugin_system/plugin_context.dart';
import '../../../plugin_system/screen_definition.dart';
import 'screens/shipping_main_screen.dart';

class ShippingPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.shipping';

  @override
  String get name => '配送管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '追跡番号管理と送り状印刷';

  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'SH',
      title: '配送管理',
      route: '/shipping',
      category: '配送',
      icon: Icons.local_shipping,
      description: '追跡番号管理と送り状印刷',
      builder: (context) => const ShippingMainScreen(),
    ),
  ];

  @override
  Future<void> createTables(Database db) async {
    // テーブルは database_schema_core.dart で作成済み
  }

  @override
  Future<void> migrate(Database db, int fromVersion, int toVersion) async {
    // マイグレーションは不要
  }

  @override
  Future<void> initialize(PluginContext context) async {
    // 初期化処理
  }

  @override
  Future<void> dispose() async {
    // 終了処理
  }

  @override
  Map<String, WidgetBuilder> getRoutes() {
    return {
      '/shipping': (context) => const ShippingMainScreen(),
    };
  }
}
