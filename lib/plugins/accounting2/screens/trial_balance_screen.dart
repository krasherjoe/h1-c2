import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/journal_entry.dart';
import '../services/account_repository.dart';
import '../services/export_service.dart';
import '../../../services/database_helper.dart';

class TrialBalanceScreen extends StatefulWidget {
  const TrialBalanceScreen({super.key});
  @override
  State<TrialBalanceScreen> createState() => _TrialBalanceScreenState();
}

class _TrialBalanceScreenState extends State<TrialBalanceScreen> {
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

  String _categoryLabel(String c) => switch (c) {
    'asset' => '資産', 'liability' => '負債', 'equity' => '純資産',
    'revenue' => '収益', 'expense' => '費用', _ => c,
  };

  int _debitTotal(int accountId) => _entries
    .where((e) => e.debitAccountId == accountId).fold(0, (s, e) => s + e.amount);
  int _creditTotal(int accountId) => _entries
    .where((e) => e.creditAccountId == accountId).fold(0, (s, e) => s + e.amount);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('試算表')), body: const Center(child: CircularProgressIndicator()));
    int totalDebit = 0, totalCredit = 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('試算表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () async {
              final now = DateTime.now();
              final dateLabel = '${now.year}/${now.month}/${now.day}';
              await ExportService().exportTrialBalance(
                accounts: _accounts,
                entries: _entries,
                totalDebit: totalDebit,
                totalCredit: totalCredit,
                dateLabel: dateLabel,
              );
            },
          ),
        ],
      ),
      body: _entries.isEmpty
          ? Center(child: Text('仕訳データがありません', style: TextStyle(color: cs.onSurfaceVariant)))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: cs.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      SizedBox(width: 60, child: Text('区分', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurface))),
                      Expanded(child: Text('科目', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurface))),
                      SizedBox(width: 90, child: Text('借方合計', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurface), textAlign: TextAlign.right)),
                      SizedBox(width: 90, child: Text('貸方合計', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurface), textAlign: TextAlign.right)),
                    ]),
                  ),
                ),
                ..._accounts.map((a) {
                  final d = _debitTotal(a.id!);
                  final c = _creditTotal(a.id!);
                  if (d == 0 && c == 0) return const SizedBox.shrink();
                  totalDebit += d; totalCredit += c;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    child: Row(children: [
                      SizedBox(width: 60, child: Text(_categoryLabel(a.category), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))),
                      Expanded(child: Text(a.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface))),
                      SizedBox(width: 90, child: Text(d > 0 ? _formatMoney(d) : '', style: TextStyle(fontSize: 12, color: cs.onSurface), textAlign: TextAlign.right)),
                      SizedBox(width: 90, child: Text(c > 0 ? _formatMoney(c) : '', style: TextStyle(fontSize: 12, color: cs.onSurface), textAlign: TextAlign.right)),
                    ]),
                  );
                }),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: [
                    SizedBox(width: 60, child: Text('', style: TextStyle(fontSize: 10))),
                    Expanded(child: Text('合計', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary))),
                    SizedBox(width: 90, child: Text(_formatMoney(totalDebit), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary), textAlign: TextAlign.right)),
                    SizedBox(width: 90, child: Text(_formatMoney(totalCredit), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary), textAlign: TextAlign.right)),
                  ]),
                ),
                if (totalDebit != totalCredit)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
                      color: cs.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Icon(Icons.warning, color: cs.onErrorContainer, size: 20),
                          const SizedBox(width: 8),
                          Text('借方合計と貸方合計が一致しません', style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _formatMoney(int v) => '¥${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}
