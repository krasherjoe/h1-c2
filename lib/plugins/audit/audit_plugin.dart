import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import '../../plugin_system/screen_definition.dart';
import 'screens/audit_screen.dart';

class AuditPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.audit';

  @override
  String get name => 'ハッシュチェーン監査';

  @override
  String get version => '1.0.0';

  @override
  String get description => '改ざん検出・ハッシュチェーン検証';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[AuditPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {}

  @override
  List<MenuItem> getMenuItems() => [
    MenuItem(
      id: 'audit',
      title: 'ハッシュチェーン監査',
      route: '/audit',
      category: 'tools',
      icon: Icons.verified_rounded,
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/audit': (_) => const AuditScreen(),
  };

  @override
  Future<void> createTables(Database db) async {}

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'audit_screen',
      title: 'ハッシュチェーン監査',
      route: '/audit',
      builder: (_) => const AuditScreen(),
    ),
  ];
}
