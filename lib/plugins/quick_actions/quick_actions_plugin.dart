import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import '../../plugin_system/dashboard_section.dart';
import 'screens/quick_actions_screen.dart';
import 'screens/quick_action_settings_screen.dart';

class QuickActionsPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.quick_actions';

  @override
  String get name => 'クイックアクション';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'ホーム画面風のショートカット';

  @override

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'QA',
      title: 'クイックアクション',
      route: '/quick_actions/settings',
      builder: (_) => const QuickActionSettingsScreen(),
      category: 'システム',
      icon: Icons.grid_view,
      description: 'ショートカットメニュー設定',
    ),
  ];

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/quick_actions/settings': (_) => const QuickActionSettingsScreen(),
  };

  @override
  DashboardSection? get dashboardSection => DashboardSection(
    id: 'quick_actions',
    title: 'クイックアクション',
    priority: 0,
    builder: (_) => const QuickActionsPanel(),
    collapsible: false,
  );

  @override
  Future<void> createTables(Database db) async {}
}
