// AUTO GENERATED from plugins-manifest.json
// DO NOT EDIT MANUALLY
// 生成コマンド: dart run scripts/generate_manifest.dart

import 'package:flutter/material.dart';
import 'menu_item.dart';

/// plugins-manifest.json から自動生成された全MenuItem
class GeneratedManifest {
  GeneratedManifest._();

  static List<MenuItem> getAll() => _items;

  static MenuItem? byRoute(String route) {
    for (final item in _items) {
      if (item.route == route) return item;
    }
    return null;
  }

  static MenuItem? byId(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  static List<MenuItem> byCategory(String category) {
    return _items.where((item) => item.category == category).toList();
  }

  static List<String> getCategories() {
    final set = <String>{};
    for (final item in _items) {
      set.add(item.category);
    }
    return set.toList();
  }

  static final List<MenuItem> _items = <MenuItem>[
    // --- ProductsPlugin (com.h1.plugin.products) ---
    MenuItem(
      id: 'P1',
      title: '商品マスター',
      route: '/products',
      category: 'マスター',
      icon: Icons.inventory_2,
      description: '商品の登録・編集',
    ),
    MenuItem(
      id: 'CE',
      title: '商品カテゴリ',
      route: '/products/categories',
      category: 'マスター',
      icon: Icons.category,
      description: 'カテゴリの階層管理',
    ),
    // --- CustomersPlugin (com.h1.plugin.customers) ---
    MenuItem(
      id: 'C1',
      title: '顧客マスター',
      route: '/customers',
      category: 'マスター',
      icon: Icons.people,
      description: '得意先の登録・編集',
    ),
    // --- PriceListPlugin (com.h1.plugin.pricelist) ---
    MenuItem(
      id: 'PE',
      title: '価格表',
      route: '/pricelist',
      category: 'マスター',
      icon: Icons.price_change,
      description: '価格表の管理',
    ),
    // --- SuppliersPlugin (com.h1.plugin.suppliers) ---
    MenuItem(
      id: 'SU',
      title: '仕入先台帳',
      route: '/suppliers/ledger',
      category: '在庫・仕入',
      icon: Icons.inventory_2,
    ),
    MenuItem(
      id: 'RE',
      title: '仕入先レポート',
      route: '/suppliers/report',
      category: '在庫・仕入',
      icon: Icons.assessment,
    ),
    // --- DocumentsPlugin (com.h1.plugin.documents) ---
    MenuItem(
      id: 'DOC',
      title: '伝票管理',
      route: '/documents',
      category: '販売',
      icon: Icons.folder_open,
      description: '見積・納品・請求・領収',
    ),
    // --- QuotationPlugin (com.h1.plugin.quotation) ---
    MenuItem(
      id: 'Q1',
      title: '見積入力',
      route: '/quotation/input',
      category: '販売管理',
      icon: Icons.description,
      description: '見積書を作成',
    ),
    MenuItem(
      id: 'QH',
      title: '見積履歴',
      route: '/quotation/history',
      category: '販売管理',
      icon: Icons.history,
      description: '過去の見積を確認',
    ),
    // --- MemorandumPlugin (com.h1.plugin.memorandum) ---
    MenuItem(
      id: 'MEMO',
      title: '覚書管理',
      route: '/memorandum',
      category: '販売',
      icon: Icons.description,
      description: '保守サービス覚書の作成・管理',
    ),
    // --- ProjectPlugin (com.h1.plugin.project) ---
    MenuItem(
      id: 'PRJ',
      title: '案件管理',
      route: '/projects',
      category: '販売',
      icon: Icons.workspaces,
      description: '案件の作成・進捗管理',
    ),
    // --- PurchasePlugin (com.h1.plugin.purchase) ---
    MenuItem(
      id: 'PUR',
      title: '仕入管理',
      route: '/purchase',
      category: '仕入',
      icon: Icons.shopping_cart,
      description: '発注・入荷・返品・支払',
    ),
    // --- InventoryPlugin (com.h1.plugin.inventory) ---
    MenuItem(
      id: 'WH',
      title: '倉庫一覧',
      route: '/inventory/warehouses',
      category: '在庫',
      icon: Icons.warehouse,
      description: '倉庫マスターの管理',
    ),
    MenuItem(
      id: 'INV',
      title: '在庫一覧',
      route: '/inventory',
      category: '在庫',
      icon: Icons.inventory,
      description: '商品別在庫一覧',
    ),
    MenuItem(
      id: 'WHI',
      title: '入庫処理',
      route: '/inventory/inbound',
      category: '在庫',
      icon: Icons.arrow_downward,
      description: '入庫登録',
    ),
    MenuItem(
      id: 'WHO',
      title: '出庫処理',
      route: '/inventory/outbound',
      category: '在庫',
      icon: Icons.arrow_upward,
      description: '出庫登録',
    ),
    MenuItem(
      id: 'IQ',
      title: '在庫照会',
      route: '/inventory/inquiry',
      category: '在庫',
      icon: Icons.search,
      description: '商品在庫の照会',
    ),
    MenuItem(
      id: 'STK',
      title: '棚卸',
      route: '/inventory/stocktake',
      category: '在庫',
      icon: Icons.fact_check,
      description: '棚卸入力',
    ),
    MenuItem(
      id: 'IC',
      title: '棚卸入力(一括)',
      route: '/inventory/stocktake_input',
      category: '在庫',
      icon: Icons.edit_note,
      description: '一括棚卸入力',
    ),
    MenuItem(
      id: 'IA',
      title: '在庫調整',
      route: '/inventory/adjustment',
      category: '在庫',
      icon: Icons.tune,
      description: '在庫調整',
    ),
    MenuItem(
      id: 'IM',
      title: '在庫移動',
      route: '/inventory/transfer',
      category: '在庫',
      icon: Icons.swap_horiz,
      description: '倉庫間在庫移動',
    ),
    MenuItem(
      id: 'R4',
      title: '在庫評価額',
      route: '/inventory/valuation',
      category: '在庫',
      icon: Icons.account_balance,
      description: '在庫評価額一覧',
    ),
    // --- ArPlugin (com.h1.plugin.ar) ---
    MenuItem(
      id: 'AR',
      title: '売掛金管理',
      route: '/ar',
      category: '売掛・支払',
      icon: Icons.account_balance,
      description: '顧客別未回収額',
    ),
    MenuItem(
      id: 'RP',
      title: '入金処理',
      route: '/ar/receipt',
      category: '売掛・支払',
      icon: Icons.payments,
      description: '入金登録',
    ),
    MenuItem(
      id: 'PY',
      title: '支払予定',
      route: '/ar/schedules',
      category: '売掛・支払',
      icon: Icons.calendar_month,
      description: '支払予定一覧',
    ),
    MenuItem(
      id: 'PG',
      title: '支払登録',
      route: '/ar/payment',
      category: '売掛・支払',
      icon: Icons.check_circle,
      description: '支払実績登録',
    ),
    MenuItem(
      id: 'CF',
      title: '資金繰り',
      route: '/ar/cashflow',
      category: '売掛・支払',
      icon: Icons.account_balance,
      description: '資金繰り表',
    ),
    MenuItem(
      id: 'LR',
      title: '台帳',
      route: '/ar/ledger',
      category: '売掛・支払',
      icon: Icons.book,
      description: '売掛台帳・買掛台帳',
    ),
    MenuItem(
      id: 'TX',
      title: '税務レポート',
      route: '/ar/tax',
      category: '売掛・支払',
      icon: Icons.calculate,
      description: '消費税納付額計算',
    ),
    // --- AccountingPlugin (com.h1.plugin.accounting) ---
    MenuItem(
      id: 'RCV',
      title: '売掛管理',
      route: '/accounting/receivable',
      category: '会計',
      icon: Icons.account_balance,
    ),
    MenuItem(
      id: 'PS',
      title: '支払スケジュール',
      route: '/accounting/schedule',
      category: '会計',
      icon: Icons.calendar_month,
    ),
    MenuItem(
      id: 'PR',
      title: '入金登録',
      route: '/accounting/payment',
      category: '会計',
      icon: Icons.payments,
    ),
    MenuItem(
      id: 'CAS',
      title: '資金繰り',
      route: '/accounting/cashflow',
      category: '会計',
      icon: Icons.trending_up,
    ),
    // --- CompanyPlugin (com.h1.plugin.company) ---
    MenuItem(
      id: 'CI',
      title: '自社情報',
      route: '/company',
      category: 'システム',
      icon: Icons.business,
      description: '会社名・住所・印鑑・口座',
    ),
    MenuItem(
      id: 'TM',
      title: '法人切替',
      route: '/company/switch',
      category: 'システム',
      icon: Icons.swap_horiz,
      description: '法人の作成・切替・削除',
    ),
    // --- SettingsPlugin (com.h1.plugin.settings) ---
    MenuItem(
      id: 'SET',
      title: '設定',
      route: '/settings',
      category: 'システム',
      icon: Icons.settings,
      description: '印刷設定・伝票番号・税率',
    ),
    // --- BackupPlugin (com.h1.plugin.backup) ---
    MenuItem(
      id: 'BK',
      title: 'バックアップ管理',
      route: '/backup',
      category: 'システム',
      icon: Icons.backup,
      description: 'DB自動バックアップ・リストア',
    ),
    // --- QuickActionsPlugin (com.h1.plugin.quick_actions) ---
    MenuItem(
      id: 'QA',
      title: 'クイックアクション',
      route: '/quick_actions/settings',
      category: 'システム',
      icon: Icons.grid_view,
      description: 'ショートカットメニュー設定',
    ),
    // --- DebugPlugin (com.h1.plugin.debug) ---
    MenuItem(
      id: 'DB',
      title: 'デバッグ',
      route: '/debug',
      category: 'システム',
      icon: Icons.bug_report,
      description: 'Mattermost診断・DB送信',
    ),
    // --- AuditPlugin (com.h1.plugin.audit) ---
    MenuItem(
      id: 'AD',
      title: 'ハッシュチェーン監査',
      route: '/audit',
      category: 'tools',
      icon: Icons.verified_rounded,
    ),
    // --- DailyPlugin (com.h1.plugin.daily) ---
    MenuItem(
      id: 'DR',
      title: '日報',
      route: '/daily/reports',
      category: '業務',
      icon: Icons.assignment,
      description: '3行日報の作成・管理',
    ),
    MenuItem(
      id: 'TI',
      title: '工数管理',
      route: '/daily/time',
      category: '業務',
      icon: Icons.timer,
      description: '工数記録・タイマー',
    ),
    // --- AnalysisPlugin (com.h1.plugin.analysis) ---
    MenuItem(
      id: 'SA',
      title: '売上分析',
      route: '/analysis/sales',
      category: 'レポート',
      icon: Icons.bar_chart,
      description: '月別売上・粗利推移',
    ),
    MenuItem(
      id: 'PA',
      title: '商品別粗利分析',
      route: '/analysis/profits',
      category: 'レポート',
      icon: Icons.pie_chart,
      description: '商品別の売上・粗利',
    ),
    MenuItem(
      id: 'RD',
      title: 'レポートダッシュボード',
      route: '/analysis/dashboard',
      category: 'レポート',
      icon: Icons.dashboard,
      description: 'サマリーカード・月次グラフ',
    ),
    MenuItem(
      id: 'FP1',
      title: '月次収支',
      route: '/analysis/monthly',
      category: 'レポート',
      icon: Icons.account_balance,
      description: '月別売上・仕入・粗利・利益',
    ),
    // --- AnalyticsPlugin (com.h1.plugin.analytics) ---
    MenuItem(
      id: 'ANL',
      title: '分析',
      route: '/analytics',
      category: 'レポート',
      icon: Icons.bar_chart,
      description: '売上・利益分析',
    ),
  ];
}
