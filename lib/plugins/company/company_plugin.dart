import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/plugin_permission.dart';
import '../../plugin_system/menu_item.dart';
import 'models/company_profile.dart';
import 'services/company_repository.dart';
import 'screens/company_profile_screen.dart';
import 'screens/company_switch_screen.dart';

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
    } catch (e) {
      debugPrint('[CompanyPlugin] プロファイル読込スキップ(テーブル未作成): $e');
      context.registerService<CompanyProfile>('companyProfile', const CompanyProfile());
    }
  }

  @override Future<void> dispose() async {}

  @override
  List<MenuItem> getMenuItems() => [
    const MenuItem(
      id: 'CI',
      title: '自社情報',
      route: '/company',
      category: 'システム',
      icon: Icons.business,
      description: '会社名・住所・印鑑・口座',
    ),
    const MenuItem(
      id: 'TM',
      title: '法人切替',
      route: '/company/switch',
      category: 'システム',
      icon: Icons.swap_horiz,
      description: '法人の作成・切替・削除',
    ),
  ];

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
