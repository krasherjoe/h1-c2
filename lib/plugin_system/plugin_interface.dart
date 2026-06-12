import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'plugin_context.dart';
import 'dashboard_section.dart';
import 'screen_definition.dart';

abstract class H1Plugin {
  String get id;
  String get name;
  String get version;
  String get description;
  List<String> get dependencies => ['com.h1.core'];
  Future<void> initialize(PluginContext context);
  Future<void> dispose();
  Map<String, WidgetBuilder> getRoutes();
  Future<void> createTables(Database db);
  Future<void> migrate(Database db, int fromVersion, int toVersion) async {}
  Widget? getSettingsScreen() => null;
  List<ScreenDefinition> get screens => [];
  DashboardSection? get dashboardSection => null;
}
