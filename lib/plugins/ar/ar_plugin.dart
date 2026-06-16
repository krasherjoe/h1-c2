import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import 'screens/ar_dashboard_screen.dart';
import 'screens/cash_flow_screen.dart';
import 'screens/payment_processing_screen.dart';
import 'screens/payment_schedule_screen.dart';
import 'screens/payment_register_screen.dart';
import 'screens/ledger_screen.dart';
import 'screens/tax_report_screen.dart';
import '../../constants/screen_ids.dart';

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
  Future<void> initialize(PluginContext context) async {
    debugPrint('[ArPlugin] Initialized');
  }

  @override
  Future<void> dispose() async {
    debugPrint('[ArPlugin] Disposed');
  }

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: S.ar, title: '売掛金管理', route: '/ar',
      builder: (_) => const ArDashboardScreen(),
      category: '売掛・支払', icon: Icons.account_balance,
      description: '顧客別未回収額',
    ),
    ScreenDefinition(
      id: S.rp, title: '入金処理', route: '/ar/receipt',
      builder: (_) => const PaymentProcessingScreen(),
      category: '売掛・支払', icon: Icons.payments,
      description: '入金登録',
    ),
    ScreenDefinition(
      id: S.py, title: '支払予定', route: '/ar/schedules',
      builder: (_) => const PaymentScheduleScreen(),
      category: '売掛・支払', icon: Icons.calendar_month,
      description: '支払予定一覧',
    ),
    ScreenDefinition(
      id: S.pg, title: '支払登録', route: '/ar/payment',
      builder: (_) => const PaymentRegisterScreen(),
      category: '売掛・支払', icon: Icons.check_circle,
      description: '支払実績登録',
    ),
    ScreenDefinition(
      id: S.cf, title: '資金繰り', route: '/ar/cashflow',
      builder: (_) => const CashFlowScreen(),
      category: '売掛・支払', icon: Icons.account_balance,
      description: '資金繰り表',
    ),
    ScreenDefinition(
      id: S.lr, title: '台帳', route: '/ar/ledger',
      builder: (_) => const LedgerScreen(),
      category: '売掛・支払', icon: Icons.book,
      description: '売掛台帳・買掛台帳',
    ),
    ScreenDefinition(
      id: S.tx, title: '税務レポート', route: '/ar/tax',
      builder: (_) => const TaxReportScreen(),
      category: '売掛・支払', icon: Icons.calculate,
      description: '消費税納付額計算',
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/ar': (_) => const ArDashboardScreen(),
    '/ar/receipt': (_) => const PaymentProcessingScreen(),
    '/ar/schedules': (_) => const PaymentScheduleScreen(),
    '/ar/payment': (_) => const PaymentRegisterScreen(),
    '/ar/cashflow': (_) => const CashFlowScreen(),
    '/ar/ledger': (_) => const LedgerScreen(),
    '/ar/tax': (_) => const TaxReportScreen(),
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
