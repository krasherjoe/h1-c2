import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
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
  Map<String, WidgetBuilder> getRoutes() => {
    '/analysis/sales': (_) => const SalesAnalysisScreen(),
    '/analysis/profits': (_) => const ProductProfitScreen(),
    '/analysis/dashboard': (_) => const ReportDashboardScreen(),
    '/analysis/monthly': (_) => const MonthlyReportScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}
}
