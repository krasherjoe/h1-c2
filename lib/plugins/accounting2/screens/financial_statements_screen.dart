import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/journal_entry.dart';
import '../services/account_repository.dart';
import '../../../services/database_helper.dart';

class FinancialStatementsScreen extends StatefulWidget {
  const FinancialStatementsScreen({super.key});
  @override
  State<FinancialStatementsScreen> createState() => _FinancialStatementsScreenState();
}

class _FinancialStatementsScreenState extends State<FinancialStatementsScreen> {
  final _db = DatabaseHelper();
  final _accRepo = AccountRepository();
  List<Account> _accounts = [];
  List<JournalEntry> _entries = [];
  bool _loading = true;
  int _tab = 0;

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

  int _debitTotal(int accountId) => _entries
    .where((e) => e.debitAccountId == accountId).fold(0, (s, e) => s + e.amount);
  int _creditTotal(int accountId) => _entries
    .where((e) => e.creditAccountId == accountId).fold(0, (s, e) => s + e.amount);

  int _balance(int accountId) => _debitTotal(accountId) - _creditTotal(accountId);

  List<Account> _byCategory(String cat) => _accounts.where((a) => a.category == cat).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('決算書')), body: const Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('決算書')),
      body: Column(
        children: [
          TabBar(
            tabs: const [Tab(text: '貸借対照表'), Tab(text: '損益計算書')],
            onTap: (i) => setState(() => _tab = i),
            indicatorColor: cs.primary,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
          ),
          Expanded(
            child: _tab == 0 ? _buildBS(cs) : _buildPL(cs),
          ),
        ],
      ),
    );
  }

  Widget _buildBS(ColorScheme cs) {
    final assets = _byCategory('asset').where((a) => _balance(a.id!) != 0).toList();
    final liabilities = _byCategory('liability').where((a) => _balance(a.id!) != 0).toList();
    final equities = _byCategory('equity').where((a) => _balance(a.id!) != 0).toList();
    final totalAssets = assets.fold(0, (s, a) => s + _balance(a.id!).abs());
    final totalLiabilities = liabilities.fold(0, (s, a) => s + _balance(a.id!).abs());
    final totalEquities = equities.fold(0, (s, a) => s + _balance(a.id!).abs());
    final totalLiabilityEquity = _entries.isEmpty ? 0 : totalLiabilities + totalEquities;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader('資産の部', cs),
        ...assets.map((a) => _line(a.name, _balance(a.id!).abs(), cs)),
        _totalLine('資産合計', totalAssets, cs),
        const SizedBox(height: 16),
        _sectionHeader('負債の部', cs),
        ...liabilities.map((a) => _line(a.name, _balance(a.id!).abs(), cs)),
        _totalLine('負債合計', totalLiabilities, cs),
        const SizedBox(height: 16),
        _sectionHeader('純資産の部', cs),
        ...equities.map((a) => _line(a.name, _balance(a.id!).abs(), cs)),
        _totalLine('純資産合計', totalEquities, cs),
        const SizedBox(height: 16),
        _totalLine('負債・純資産合計', totalLiabilityEquity, cs, bold: true, color: cs.primary),
      ],
    );
  }

  Widget _buildPL(ColorScheme cs) {
    final revenues = _byCategory('revenue').where((a) => _balance(a.id!) != 0).toList();
    final expenses = _byCategory('expense').where((a) => _balance(a.id!) != 0).toList();
    final totalRevenue = revenues.fold(0, (s, a) => s + _balance(a.id!).abs());
    final totalExpense = expenses.fold(0, (s, a) => s + _balance(a.id!).abs());
    final netIncome = totalRevenue - totalExpense;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _sectionHeader('収益', cs),
        ...revenues.map((a) => _line(a.name, _balance(a.id!).abs(), cs)),
        _totalLine('収益合計', totalRevenue, cs),
        const SizedBox(height: 16),
        _sectionHeader('費用', cs),
        ...expenses.map((a) => _line(a.name, _balance(a.id!).abs(), cs)),
        _totalLine('費用合計', totalExpense, cs),
        const SizedBox(height: 16),
        _totalLine('当期純利益', netIncome >= 0 ? netIncome : 0, cs, bold: true, color: cs.primary),
        if (netIncome < 0)
          _totalLine('当期純損失', netIncome.abs(), cs, bold: true, color: cs.error),
      ],
    );
  }

  Widget _sectionHeader(String title, ColorScheme cs) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
  );

  Widget _line(String label, int amount, ColorScheme cs) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface))),
      Text(_formatMoney(amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface)),
    ]),
  );

  Widget _totalLine(String label, int amount, ColorScheme cs, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color ?? cs.onSurface))),
      Text(_formatMoney(amount), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color ?? cs.primary)),
    ]),
  );

  String _formatMoney(int v) => '¥${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}
