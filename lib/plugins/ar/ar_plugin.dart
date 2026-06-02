import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import 'screens/ar_dashboard_screen.dart';
import 'screens/payment_processing_screen.dart';
import 'screens/payment_schedule_screen.dart';
import 'screens/payment_register_screen.dart';
import 'models/ar_models.dart';

class ArPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.ar';

  @override
  String get name => '売掛・支払管理';

  @override
  String get version => '1.0.0';

  @override
  String get description => '売掛金管理・入金処理・支払予定・支払登録';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[ArPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[ArPlugin] Disposed');
  }

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'AR',
      title: '売掛金管理',
      route: '/ar',
      category: '売掛・支払',
      icon: Icons.account_balance,
      description: '顧客別未回収額',
    ),
    const MenuItem(
      id: 'RP',
      title: '入金処理',
      route: '/ar/receipt',
      category: '売掛・支払',
      icon: Icons.payments,
      description: '入金登録',
    ),
    const MenuItem(
      id: 'PY',
      title: '支払予定',
      route: '/ar/schedules',
      category: '売掛・支払',
      icon: Icons.calendar_month,
      description: '支払予定一覧',
    ),
    const MenuItem(
      id: 'PG',
      title: '支払登録',
      route: '/ar/payment',
      category: '売掛・支払',
      icon: Icons.check_circle,
      description: '支払実績登録',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/ar': (_) => const ArDashboardScreen(),
    '/ar/receipt': (_) => const PaymentProcessingScreen(),
    '/ar/schedules': (_) => const PaymentScheduleScreen(),
    '/ar/payment': (_) => const PaymentRegisterScreen(),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_schedules (
        id TEXT PRIMARY KEY,
        purchase_id TEXT,
        document_number TEXT,
        supplier_name TEXT,
        due_date TEXT,
        amount INTEGER,
        status TEXT DEFAULT 'unpaid',
        paid_date TEXT,
        payment_id TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        payment_number TEXT,
        payment_date TEXT,
        supplier_id TEXT,
        supplier_name TEXT,
        amount INTEGER,
        payment_method TEXT,
        bank_account TEXT,
        purchase_ids TEXT,
        notes TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payment_schedules_status ON payment_schedules(status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payment_schedules_due_date ON payment_schedules(due_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date)',
    );

    debugPrint('[ArPlugin] Tables created');
  }
}
