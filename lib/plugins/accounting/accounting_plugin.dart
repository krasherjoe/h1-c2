import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/screen_definition.dart';
import 'screens/accounts_receivable_screen.dart';
import 'screens/payment_schedule_screen.dart';
import 'screens/payment_register_screen.dart';
import 'screens/cash_flow_screen.dart';

class AccountingPlugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.accounting';

  @override
  String get name => '会計';

  @override
  String get version => '1.0.0';

  @override
  String get description => '売掛管理・支払・資金繰り';

  @override
  List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    debugPrint('[AccountingPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[AccountingPlugin] Disposed');
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: 'RCV', title: '売掛管理', route: '/accounting/receivable',
      builder: (_) => const AccountsReceivableScreen(),
      category: '会計', icon: Icons.account_balance,
    ),
    ScreenDefinition(
      id: 'PS', title: '支払スケジュール', route: '/accounting/schedule',
      builder: (_) => const PaymentScheduleScreen(),
      category: '会計', icon: Icons.calendar_month,
    ),
    ScreenDefinition(
      id: 'PR', title: '入金登録', route: '/accounting/payment',
      builder: (_) => const PaymentRegisterScreen(),
      category: '会計', icon: Icons.payments,
    ),
    ScreenDefinition(
      id: 'CAS', title: '資金繰り', route: '/accounting/cashflow',
      builder: (_) => const CashFlowScreen(),
      category: '会計', icon: Icons.trending_up,
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/accounting/receivable': (_) => const AccountsReceivableScreen(),
    '/accounting/schedule': (_) => const PaymentScheduleScreen(),
    '/accounting/payment': (_) => const PaymentRegisterScreen(),
    '/accounting/cashflow': (_) => const CashFlowScreen(),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        customer_id TEXT,
        supplier_id TEXT,
        document_id TEXT,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT
      )
    ''');
    debugPrint('[AccountingPlugin] Tables created');
  }
}
