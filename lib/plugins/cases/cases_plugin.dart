import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../plugin_system/plugin_interface.dart';
import '../../plugin_system/plugin_context.dart';
import '../../plugin_system/screen_definition.dart';
import '../../plugin_system/dashboard_section.dart';
import '../../services/database_helper.dart';
import 'services/case_repository.dart';
import 'screens/case_list_screen.dart';
import '../../constants/screen_ids.dart';

class CasesPlugin extends H1Plugin {
  Timer? _overdueTimer;

  @override
  String get id => 'com.h1.plugin.cases';
  @override
  String get name => '案件管理';
  @override
  String get version => '1.0.0';
  @override
  String get description => '滞留/破損/盗難/紛失の案件管理';
  @override
  List<String> get dependencies => ['com.h1.core'];

  @override
  List<ScreenDefinition> get screens => [
    ScreenDefinition(
      id: S.is_,
      title: '案件管理',
      route: '/cases',
      category: '業務',
      icon: Icons.assignment,
      builder: (_) => const CaseListScreen(),
    ),
  ];

  @override
  Map<String, WidgetBuilder> getRoutes() => {
    '/cases': (_) => const CaseListScreen(),
  };

  @override
  DashboardSection? get dashboardSection => DashboardSection(
    id: 'overdue_summary',
    title: '延滞請求書',
    priority: 5,
    builder: (_) => _OverdueSummaryCard(),
  );

  @override
  Future<void> dispose() async {
    _overdueTimer?.cancel();
  }

  @override
  Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cases (
        id TEXT PRIMARY KEY, type TEXT NOT NULL, status INTEGER DEFAULT 0,
        priority INTEGER DEFAULT 0, reference_type TEXT, reference_id TEXT,
        title TEXT NOT NULL, amount INTEGER, description TEXT,
        assignee TEXT, due_date TEXT,
        created_at TEXT NOT NULL, escalated_at TEXT, resolved_at TEXT, notes TEXT
      )''');
  }

  @override
  Future<void> initialize(PluginContext context) async {
    // 既存テーブルに足りないカラムを追加（互換性）
    try { await context.database.execute('ALTER TABLE cases ADD COLUMN assignee TEXT'); } catch (_) {}
    try { await context.database.execute('ALTER TABLE cases ADD COLUMN due_date TEXT'); } catch (_) {}

    final repo = CaseRepository();
    await repo.escalateAll();
    try {
      final created = await repo.autoCreateFromOverdueInvoices();
      if (created > 0) {
        debugPrint('[CasesPlugin] ${created}件の延滞案件を自動作成');
      }
    } catch (e) {
      debugPrint('[CasesPlugin] 延滞案件作成エラー: $e');
    }
    _overdueTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      try {
        await repo.autoCreateFromOverdueInvoices();
      } catch (_) {}
    });
  }
}

class _OverdueSummaryCard extends StatefulWidget {
  @override
  State<_OverdueSummaryCard> createState() => _OverdueSummaryCardState();
}

class _OverdueSummaryCardState extends State<_OverdueSummaryCard> {
  int _overdueCount = 0;
  int _activeCaseCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = CaseRepository();
    final overdue = await repo.getOverdueInvoiceCount();
    final activeCases = await repo.fetchAll();
    if (mounted) setState(() {
      _overdueCount = overdue;
      _activeCaseCount = activeCases.length;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/cases'),
          child: Row(children: [
            Icon(Icons.warning_amber_rounded, color: cs.error, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('延滞請求書 $_overdueCount件',
                  style: TextStyle(fontWeight: FontWeight.bold, color: cs.error)),
                const SizedBox(height: 2),
                Text('アクティブ案件 $_activeCaseCount件',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            )),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}
