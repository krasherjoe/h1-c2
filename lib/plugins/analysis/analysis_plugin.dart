import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import 'screens/sales_analysis_screen.dart';
import 'screens/product_profit_screen.dart';
import 'screens/report_dashboard_screen.dart';
import 'screens/monthly_report_screen.dart';
import '../../constants/screen_ids.dart';

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
  Future<void> initialize(PluginContext context) async {
    debugPrint('[AnalysisPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[AnalysisPlugin] Disposed');
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: S.sa, title: '売上分析', route: '/analysis/sales',
      builder: (_) => const SalesAnalysisScreen(),
      category: 'レポート', icon: Icons.bar_chart,
      description: '月別売上・粗利推移',
    ),
    ScreenDefinition(
      id: S.pa, title: '商品別粗利分析', route: '/analysis/profits',
      builder: (_) => const ProductProfitScreen(),
      category: 'レポート', icon: Icons.pie_chart,
      description: '商品別の売上・粗利',
    ),
    ScreenDefinition(
      id: S.rd, title: 'レポートダッシュボード', route: '/analysis/dashboard',
      builder: (_) => const ReportDashboardScreen(),
      category: 'レポート', icon: Icons.dashboard,
      description: 'サマリーカード・月次グラフ',
    ),
    ScreenDefinition(
      id: S.fp1, title: '月次収支', route: '/analysis/monthly',
      builder: (_) => const MonthlyReportScreen(),
      category: 'レポート', icon: Icons.account_balance,
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
