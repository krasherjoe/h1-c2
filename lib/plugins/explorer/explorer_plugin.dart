import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../plugin_system/plugin_interface.dart';
import '../../../plugin_system/plugin_context.dart';
import '../../../plugin_system/plugin_permission.dart';

class ExplorerPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.explorer';

  @override
  String get name => 'マスターエクスプローラー';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'マスターデータの汎用一覧・閲覧・編集フレームワーク';

  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[ExplorerPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[ExplorerPlugin] Disposed');
  }

  @override
  Future<void> createTables(Database db) async {}

  @override
  Map<String, WidgetBuilder> getRoutes() => {};
}
