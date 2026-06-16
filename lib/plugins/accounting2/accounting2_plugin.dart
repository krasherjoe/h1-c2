import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import '../../plugin_system/dashboard_section.dart';
import 'screens/accounting2_main_screen.dart';
import 'screens/receipt_photo_screen.dart';
import '../../constants/screen_ids.dart';

const _kAccountsTable = '''
CREATE TABLE IF NOT EXISTS accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  is_system INTEGER DEFAULT 0,
  created_at TEXT,
  updated_at TEXT
)''';

const _kJournalTable = '''
CREATE TABLE IF NOT EXISTS journal_entries (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  debit_account_id INTEGER NOT NULL,
  credit_account_id INTEGER NOT NULL,
  amount INTEGER NOT NULL,
  description TEXT,
  document_id TEXT,
  entry_type TEXT DEFAULT 'manual',
  created_at TEXT
)''';

const _kCashTable = '''
CREATE TABLE IF NOT EXISTS cash_transactions (
  id TEXT PRIMARY KEY,
  date TEXT NOT NULL,
  type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  account_id INTEGER NOT NULL,
  description TEXT,
  created_at TEXT
)''';

const _kAuditLogTable = '''
CREATE TABLE IF NOT EXISTS audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  action TEXT NOT NULL,
  old_values TEXT,
  new_values TEXT,
  created_at TEXT NOT NULL
)''';

const _kTemplateAccounts = [
  {'code': '101', 'name': '現金', 'category': 'asset'},
  {'code': '102', 'name': '普通預金', 'category': 'asset'},
  {'code': '103', 'name': '売掛金', 'category': 'asset'},
  {'code': '104', 'name': '商品', 'category': 'asset'},
  {'code': '105', 'name': '仮払金', 'category': 'asset'},
  {'code': '201', 'name': '買掛金', 'category': 'liability'},
  {'code': '202', 'name': '借入金', 'category': 'liability'},
  {'code': '203', 'name': '預り金', 'category': 'liability'},
  {'code': '204', 'name': '仮受金', 'category': 'liability'},
  {'code': '301', 'name': '資本金', 'category': 'equity'},
  {'code': '302', 'name': '繰越利益剰余金', 'category': 'equity'},
  {'code': '401', 'name': '売上高', 'category': 'revenue'},
  {'code': '402', 'name': '受取利息', 'category': 'revenue'},
  {'code': '403', 'name': '雑収入', 'category': 'revenue'},
  {'code': '501', 'name': '仕入高', 'category': 'expense'},
  {'code': '502', 'name': '消耗品費', 'category': 'expense'},
  {'code': '503', 'name': '旅費交通費', 'category': 'expense'},
  {'code': '504', 'name': '通信費', 'category': 'expense'},
  {'code': '505', 'name': '水道光熱費', 'category': 'expense'},
  {'code': '506', 'name': '地代家賃', 'category': 'expense'},
  {'code': '507', 'name': '給料賃金', 'category': 'expense'},
  {'code': '508', 'name': '支払利息', 'category': 'expense'},
  {'code': '509', 'name': '広告宣伝費', 'category': 'expense'},
  {'code': '510', 'name': '保険料', 'category': 'expense'},
  {'code': '511', 'name': '租税公課', 'category': 'expense'},
  {'code': '512', 'name': '修繕費', 'category': 'expense'},
  {'code': '513', 'name': '車両費', 'category': 'expense'},
  {'code': '514', 'name': '会議費', 'category': 'expense'},
  {'code': '515', 'name': '福利厚生費', 'category': 'expense'},
  {'code': '516', 'name': '雑費', 'category': 'expense'},
];

class Accounting2Plugin extends H1Plugin {
  @override
  String get id => 'com.h1.plugin.accounting2';
  @override
  String get name => '会計';
  @override
  String get version => '1.0.0';
  @override
  String get description => '複式簿記・決算書作成';
  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: S.kj,
      title: '会計',
      route: '/accounting2',
      category: '業務',
      icon: Icons.account_balance,
      builder: (_) => const Accounting2MainScreen(),
    ),
    ScreenDefinition(
      id: S.rc,
      title: 'レシート読取',
      route: '/receipt_photo',
      category: '会計',
      icon: Icons.receipt_long,
      builder: (_) => const ReceiptPhotoScreen(),
    ),
  ];

  @override
  DashboardSection? get dashboardSection => null;

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/receipt_photo': (_) => const ReceiptPhotoScreen(),
  };

  @override
  Future<void> dispose() async {}

  @override
  Future<void> createTables(Database db) async {}

  @override
  Future<void> initialize(PluginContext context) async {
    await _initTables(context.database);
    await _seedTemplateAccounts(context.database);
  }

  Future<void> _initTables(Database db) async {
    await db.execute(_kAccountsTable);
    await db.execute(_kJournalTable);
    await db.execute(_kCashTable);
    await db.execute(_kAuditLogTable);
  }

  Future<void> _seedTemplateAccounts(Database db) async {
    final count = (await db.rawQuery('SELECT COUNT(*) as c FROM accounts')).first['c'] as int;
    if (count > 0) return;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final a in _kTemplateAccounts) {
      batch.insert('accounts', {
        'code': a['code'],
        'name': a['name'],
        'category': a['category'],
        'is_system': 1,
        'created_at': now,
        'updated_at': now,
      });
    }
    await batch.commit(noResult: true);
  }
}
