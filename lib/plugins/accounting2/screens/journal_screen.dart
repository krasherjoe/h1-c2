import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../models/account.dart';
import '../services/account_repository.dart';
import '../../../services/database_helper.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _db = DatabaseHelper();
  final _accRepo = AccountRepository();
  List<JournalEntry> _entries = [];
  List<Account> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await _db.database;
    final entries = await db.query('journal_entries', orderBy: 'date DESC, created_at DESC');
    final accounts = await _accRepo.fetchAll();
    if (mounted) setState(() {
      _entries = entries.map(JournalEntry.fromMap).toList();
      _accounts = accounts;
      _loading = false;
    });
  }

  String accountName(int? id) => _accounts.where((a) => a.id == id).firstOrNull?.name ?? '?';

  String entryTypeLabel(String t) => switch (t) {
    'auto' => '自動', 'manual' => '手動', 'import' => '取込', _ => t,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('仕訳帳')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(child: Text('仕訳がありません', style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _entries.length,
                  itemBuilder: (ctx, i) {
                    final e = _entries[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 3),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${e.date}  ${accountName(e.debitAccountId)} / ${accountName(e.creditAccountId)}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface)),
                                  const SizedBox(height: 2),
                                  Text('${_formatMoney(e.amount)}  ${e.description}',
                                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: e.entryType == 'auto' ? cs.tertiaryContainer : cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(entryTypeLabel(e.entryType),
                                style: TextStyle(fontSize: 9, color: e.entryType == 'auto' ? cs.onTertiaryContainer : cs.onSurfaceVariant)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _formatMoney(int v) => '¥${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}
