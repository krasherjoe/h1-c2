import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import 'screens/printer_settings_screen.dart';
import '../../constants/screen_ids.dart';

class PrinterPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.printer';
  @override
  String get name => 'レシート印刷';
  @override
  String get version => '1.0.0';
  @override
  String get description => 'Bluetoothレシートプリンタ印刷';
  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: S.pt,
      title: 'レシート印刷',
      route: '/printer',
      category: 'システム',
      icon: Icons.print,
      builder: (_) => const PrinterSettingsScreen(),
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/printer': (_) => const PrinterSettingsScreen(),
  };
  @override
  Future<void> dispose() async {}
  @override
  Future<void> createTables(Database db) async {}
  @override
  Future<void> initialize(PluginContext context) async {}
}
