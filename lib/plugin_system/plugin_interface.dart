import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'plugin_permission.dart';
import 'menu_item.dart';
import 'plugin_context.dart';

abstract class H1Plugin {
  String get id;
  String get name;
  String get version;
  String get description;
  List<String> get dependencies => ['com.h1.core'];
  List<PluginPermission> get requiredPermissions;
  Future<void> initialize(PluginContext context);
  Future<void> dispose();
  List<MenuItem> getMenuItems();
  Map<String, WidgetBuilder> getRoutes();
  Future<void> createTables(Database db);
  Widget? getSettingsScreen() => null;
}
