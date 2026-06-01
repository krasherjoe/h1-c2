import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import 'screens/analytics_dashboard_screen.dart';

class AnalyticsPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.analytics';

  @override
  String get name => '分析';

  @override
  String get version => '1.0.0';

  @override
  String get description => '売上分析・利益分析・レポート';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[AnalyticsPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[AnalyticsPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'ANL',
      title: '分析',
      route: '/analytics',
      category: 'レポート',
      icon: Icons.bar_chart,
      description: '売上・利益分析',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/analytics': (_) => const AnalyticsDashboardScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}
}
