import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import 'services/settings_repository.dart';
import 'screens/settings_screen.dart';

class SettingsPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.settings';

  @override
  String get name => '設定';

  @override
  String get version => '1.0.0';

  @override
  String get description => '印刷設定・伝票番号・税率';

  @override
  List<String> get dependencies => ['com.h1.plugin.company'];


  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[SettingsPlugin] Initialized');
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'SET',
      title: '設定',
      route: '/settings',
      builder: (_) => const SettingsScreen(),
      category: 'システム',
      icon: Icons.settings,
      description: '印刷設定・伝票番号・税率',
    ),
  ];

  @override
  Future<void> dispose() async {
    debugPrint('[SettingsPlugin] Disposed');
  }

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/settings': (_) => const SettingsScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}
}
