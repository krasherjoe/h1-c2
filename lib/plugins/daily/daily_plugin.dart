import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import 'screens/daily_report_screen.dart';
import 'screens/time_tracking_screen.dart';

class DailyPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.daily';

  @override
  String get name => '日報・工数管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '日報、工数管理、Todo';

  @override
  List<PluginPermission> get requiredPermissions => [
        PluginPermission.readDatabase,
        PluginPermission.writeDatabase,
      ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[DailyPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[DailyPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
        const MenuItem(
          id: 'DR',
          title: 'DR:日報',
          route: '/daily/reports',
          category: '業務',
          icon: Icons.assignment,
          description: '3行日報の作成・管理',
        ),
        const MenuItem(
          id: 'TI',
          title: 'TI:工数管理',
          route: '/daily/time',
          category: '業務',
          icon: Icons.timer,
          description: '工数記録・タイマー',
        ),
      ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
        '/daily/reports': (_) => const DailyReportScreen(),
        '/daily/time': (_) => const TimeTrackingScreen(),
      };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_reports (
        id TEXT PRIMARY KEY,
        report_date TEXT NOT NULL,
        done_text TEXT NOT NULL,
        plan_text TEXT NOT NULL,
        issue_text TEXT,
        tags TEXT,
        project_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS time_logs (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        project_id TEXT NOT NULL,
        date TEXT NOT NULL,
        hours REAL NOT NULL,
        memo TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS todo_tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        priority TEXT NOT NULL DEFAULT 'medium',
        status TEXT NOT NULL DEFAULT 'pending',
        category TEXT,
        reference_id TEXT,
        reference_type TEXT,
        due_date TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        milestone_id TEXT,
        title TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'todo',
        estimated_hours REAL NOT NULL DEFAULT 0,
        due_date TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_reports_date ON daily_reports(report_date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_time_logs_project ON time_logs(project_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_time_logs_task ON time_logs(task_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_todo_tasks_status ON todo_tasks(status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id)');
  }
}
