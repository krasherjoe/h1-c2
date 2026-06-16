import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart' show ScreenDefinition;
import 'screens/debug_screen.dart';
import '../../constants/screen_ids.dart';

class DebugPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.debug';

  @override
  String get name => 'デバッグ';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Mattermost連携デバッグ・診断';


  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: S.db,
      title: 'デバッグ',
      route: '/debug',
      builder: (_) => const DebugScreen(),
      category: 'システム',
      icon: Icons.bug_report,
      description: 'Mattermost診断・DB送信',
    ),
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[DebugPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {}

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/debug': (_) => const DebugScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}
}
