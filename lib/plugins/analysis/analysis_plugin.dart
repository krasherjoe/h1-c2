import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import 'screens/sales_analysis_screen.dart';
import 'screens/product_profit_screen.dart';
import 'screens/report_dashboard_screen.dart';
import 'screens/monthly_report_screen.dart';

class AnalysisPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.analysis';

  @override
  String get name => '分析レポート';

  @override
  String get version => '1.0.0';

  @override
  String get description => '売上分析・商品別粗利分析・レポートダッシュボード';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[AnalysisPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[AnalysisPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'SA',
      title: '売上分析',
      route: '/analysis/sales',
      category: 'レポート',
      icon: Icons.bar_chart,
      description: '月別売上・粗利推移',
    ),
    const MenuItem(
      id: 'PA',
      title: '商品別粗利分析',
      route: '/analysis/profits',
      category: 'レポート',
      icon: Icons.pie_chart,
      description: '商品別の売上・粗利',
    ),
    const MenuItem(
      id: 'RD',
      title: 'レポートダッシュボード',
      route: '/analysis/dashboard',
      category: 'レポート',
      icon: Icons.dashboard,
      description: 'サマリーカード・月次グラフ',
    ),
    const MenuItem(
      id: 'FP1',
      title: '月次収支',
      route: '/analysis/monthly',
      category: 'レポート',
      icon: Icons.account_balance,
      description: '月別売上・仕入・粗利・利益',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/analysis/sales': (_) => const SalesAnalysisScreen(),
    '/analysis/profits': (_) => const ProductProfitScreen(),
    '/analysis/dashboard': (_) => const ReportDashboardScreen(),
    '/analysis/monthly': (_) => const MonthlyReportScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}
}
