import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import 'models/company_profile.dart';
import 'services/company_repository.dart';
import 'screens/company_profile_screen.dart';
import 'screens/company_switch_screen.dart';
import '../../services/debug_console.dart';

class CompanyPlugin extends H1Plugin {
  @override String get id => 'com.h1.plugin.company';
  @override String get name => '自社情報';
  @override String get version => '1.0.0';
  @override String get description => '会社情報・印鑑・銀行口座の管理';
  @override List<String> get dependencies => ['com.h1.core'];
  @override List<PluginPermission> get requiredPermissions => [
    PluginPermission.readDatabase,
    PluginPermission.writeDatabase,
  ];

  @override
  Future<void> initialize(PluginContext context) async {
    try {
      final repo = CompanyRepository(context.database);
      final profile = await repo.loadProfile() ?? const CompanyProfile();
      context.registerService<CompanyProfile>('companyProfile', profile);
    } catch (_) {}
    DebugConsole.register('company.info', (_) async {
      try {
        final repo = CompanyRepository(context.database);
        final p = await repo.loadProfile();
        if (p == null) return '自社情報: 未設定';
        return '自社情報:\n  名称: ${p.name}\n  TEL: ${p.tel ?? "なし"}\n  Email: ${p.email ?? "なし"}\n  住所: ${p.address}';
      } catch (e) {
        return '自社情報取得失敗: $e';
      }
    });
    debugPrint('[CompanyPlugin] Initialized');
  }

  @override Future<void> dispose() async {}

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/company': (_) => const CompanyProfileScreen(),
    '/company/switch': (_) => const CompanySwitchScreen(),
  };

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_info (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        zip_code TEXT,
        address TEXT,
        address2 TEXT,
        tel TEXT,
        fax TEXT,
        email TEXT,
        url TEXT,
        default_tax_rate REAL DEFAULT 0.10,
        seal_path TEXT,
        seal_offset_x REAL DEFAULT 10.0,
        seal_offset_y REAL DEFAULT 50.0,
        seal_rotation REAL DEFAULT 0.0,
        tax_display_mode TEXT DEFAULT 'normal',
        registration_number TEXT,
        bank_accounts TEXT,
        default_bank_account_index INTEGER DEFAULT 0,
        fiscal_year_start INTEGER DEFAULT 4,
        closing_day INTEGER DEFAULT 20,
        is_exempt_taxpayer INTEGER DEFAULT 0
      )
    ''');
  }
}
