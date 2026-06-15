import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/journal_entry.dart';
import '../services/account_repository.dart';
import '../../../services/database_helper.dart';
import '../../../services/sheets_sync_service.dart';
import 'account_list_screen.dart';
import 'cash_book_screen.dart';
import 'journal_screen.dart';
import 'ledger_screen.dart';
import 'trial_balance_screen.dart';
import 'financial_statements_screen.dart';

class Accounting2MainScreen extends StatefulWidget {
  const Accounting2MainScreen({super.key});
  @override
  State<Accounting2MainScreen> createState() => _Accounting2MainScreenState();
}

class _Accounting2MainScreenState extends State<Accounting2MainScreen> {
  final _db = DatabaseHelper();
  final _accRepo = AccountRepository();
  List<Account> _accounts = [];
  List<JournalEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await _accRepo.fetchAll();
    final db = await _db.database;
    final entries = await db.query('journal_entries', orderBy: 'date ASC');
    if (mounted) setState(() {
      _accounts = accounts;
      _entries = entries.map(JournalEntry.fromMap).toList();
      _loading = false;
    });
  }

  int _debitTotal(int accountId) =>
    _entries.where((e) => e.debitAccountId == accountId).fold(0, (s, e) => s + e.amount);
  int _creditTotal(int accountId) =>
    _entries.where((e) => e.creditAccountId == accountId).fold(0, (s, e) => s + e.amount);
  int _balance(int accountId) => _debitTotal(accountId) - _creditTotal(accountId);

  int _categoryTotal(String cat) =>
    _accounts.where((a) => a.category == cat).fold(0, (s, a) => s + _balance(a.id!).abs());

  String _fmt(int v) => '¥${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final revenue = _categoryTotal('revenue');
    final expense = _categoryTotal('expense');
    final profit = revenue - expense;

    return Scaffold(
      appBar: AppBar(title: const Text('KJ:会計')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_entries.isNotEmpty) ...[
                    Card(
                      color: profit > 0 ? cs.errorContainer : cs.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(profit > 0 ? Icons.warning_amber : Icons.check_circle,
                                  color: profit > 0 ? cs.onErrorContainer : cs.onTertiaryContainer, size: 18),
                              const SizedBox(width: 6),
                              Text('決算サマリー',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                                      color: profit > 0 ? cs.onErrorContainer : cs.onTertiaryContainer)),
                            ]),
                            const SizedBox(height: 8),
                            _summaryRow('収益合計', _fmt(revenue), profit > 0 ? cs.onErrorContainer : cs.onTertiaryContainer),
                            _summaryRow('費用合計', _fmt(expense), profit > 0 ? cs.onErrorContainer : cs.onTertiaryContainer),
                            Divider(height: 12, color: profit > 0 ? cs.onErrorContainer : cs.onTertiaryContainer),
                            _summaryRow('課税対象利益', _fmt(profit), profit > 0 ? cs.onErrorContainer : cs.onTertiaryContainer, bold: true),
                            if (profit > 0) ...[
                              const SizedBox(height: 6),
                              Row(children: [
                                Icon(Icons.info_outline, size: 14, color: cs.onErrorContainer),
                                const SizedBox(width: 4),
                                Expanded(child: Text('経費の計上漏れがあるかもしれません（知らんけど）',
                                    style: TextStyle(fontSize: 11, color: cs.onErrorContainer))),
                              ]),
                              const SizedBox(height: 2),
                              Text('最終的な判断は税理士等の専門家にご相談ください',
                                  style: TextStyle(fontSize: 9, color: cs.onErrorContainer.withValues(alpha: 0.7))),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (profit > 0) ...[
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('よく使われる経費科目',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6, runSpacing: 6,
                                children: ['旅費交通費', '消耗品費', '通信費', '水道光熱費', '地代家賃', '車両費', '会議費', '雑費']
                                    .map((n) => ActionChip(
                                          label: Text(n, style: const TextStyle(fontSize: 11)),
                                          onPressed: () => Navigator.push(context,
                                              MaterialPageRoute(builder: (_) => const CashBookScreen())),
                                          visualDensity: VisualDensity.compact,
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                  _menuCard(cs, Icons.account_balance, '勘定科目', '科目の追加・編集・削除', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountListScreen()));
                  }),
                  const SizedBox(height: 8),
                  _menuCard(cs, Icons.monetization_on, '現金出納帳', '日々の現金入出金を記録', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CashBookScreen()));
                  }),
                  const SizedBox(height: 8),
                  _menuCard(cs, Icons.book, '仕訳帳', '全仕訳の確認・手動編集', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalScreen()));
                  }),
                  const SizedBox(height: 8),
                  _menuCard(cs, Icons.view_list, '総勘定元帳', '科目別取引一覧', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LedgerScreen()));
                  }),
                  const SizedBox(height: 8),
                  _menuCard(cs, Icons.table_chart, '試算表', '合計残高試算表', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TrialBalanceScreen()));
                  }),
                  const SizedBox(height: 8),
                  _menuCard(cs, Icons.description, '決算書', '貸借対照表・損益計算書', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialStatementsScreen()));
                  }),
                  const SizedBox(height: 8),
                  _menuCard(cs, Icons.analytics, '分析シート', 'Google Sheetsで売上分析', () async {
                    final url = await SheetsSyncService.instance.ensureAnalysisSpreadsheet();
                    if (url == null) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('作成失敗（ログインしてください）')));
                      return;
                    }
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('📊 $url'),
                      duration: const Duration(seconds: 10),
                      action: SnackBarAction(label: '開く', onPressed: () => SheetsSyncService.instance.openUrl(url)),
                    ));
                  }),
                ],
              ),
            ),
    );
  }

  Widget _summaryRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.w500, color: color)),
      ]),
    );
  }

  Widget _menuCard(ColorScheme cs, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: cs.primary),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
