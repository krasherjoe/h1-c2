import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/menu_item.dart';
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
  List<PluginPermission> get requiredPermissions => [];

  @override
  Future<void> initialize(PluginContext context) async {}

  @override
  Future<void> dispose() async {}

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'QA',
      title: 'クイックアクション',
      route: '/quick_actions',
      category: 'システム',
      icon: Icons.grid_view,
      description: 'ショートカットメニュー',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/quick_actions': (_) => const QuickActionsScreen(),
    '/quick_actions/settings': (_) => const QuickActionSettingsScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}
}
