import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/journal_entry.dart';
import '../services/account_repository.dart';
import '../../../services/database_helper.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});
  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  final _db = DatabaseHelper();
  final _accRepo = AccountRepository();
  List<Account> _accounts = [];
  List<JournalEntry> _allEntries = [];
  int? _selectedAccountId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await _accRepo.fetchAll();
    final db = await _db.database;
    final entries = await db.query('journal_entries', orderBy: 'date ASC, created_at ASC');
    if (mounted) setState(() {
      _accounts = accounts;
      _allEntries = entries.map(JournalEntry.fromMap).toList();
      if (_selectedAccountId == null && accounts.isNotEmpty) _selectedAccountId = accounts.first.id;
      _loading = false;
    });
  }

  List<JournalEntry> _filtered() => _allEntries.where((e) =>
    e.debitAccountId == _selectedAccountId || e.creditAccountId == _selectedAccountId).toList();

  String accountName(int? id) => _accounts.where((a) => a.id == id).firstOrNull?.name ?? '?';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = _accounts.where((a) => a.id == _selectedAccountId).firstOrNull;
    final entries = _filtered();
    int balance = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('総勘定元帳')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButtonFormField<int>(
              value: _selectedAccountId,
              items: _accounts.map((a) => DropdownMenuItem(value: a.id!, child: Text('${a.code} ${a.name}'))).toList(),
              onChanged: (v) => setState(() => _selectedAccountId = v),
              decoration: const InputDecoration(labelText: '科目', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            ),
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text('${selected.name} (${selected.code})',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            ),
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text('取引がありません', style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == 0) {
                        return Card(
                          color: cs.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(children: [
                              SizedBox(width: 80, child: Text('日付', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface))),
                              Expanded(child: Text('借方', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface))),
                              SizedBox(width: 20, child: Text('', style: TextStyle(fontSize: 11))),
                              Expanded(child: Text('貸方', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface))),
                              SizedBox(width: 80, child: Text('残高', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface), textAlign: TextAlign.right)),
                            ]),
                          ),
                        );
                      }
                      final e = entries[i - 1];
                      if (e.debitAccountId == _selectedAccountId) balance += e.amount;
                      if (e.creditAccountId == _selectedAccountId) balance -= e.amount;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                        child: Row(children: [
                          SizedBox(width: 80, child: Text(e.date.toString().substring(0, 10), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))),
                          Expanded(child: Text(e.debitAccountId == _selectedAccountId ? _formatMoney(e.amount) : '',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface))),
                          SizedBox(width: 20, child: Text(e.debitAccountId == _selectedAccountId ? '借' : '貸', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))),
                          Expanded(child: Text(e.creditAccountId == _selectedAccountId ? _formatMoney(e.amount) : '',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface))),
                          SizedBox(width: 80, child: Text(_formatMoney(balance.abs()), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary), textAlign: TextAlign.right)),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatMoney(int v) => '¥${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}
