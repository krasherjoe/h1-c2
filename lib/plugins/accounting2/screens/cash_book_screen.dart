import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/cash_transaction.dart';
import '../services/account_repository.dart';
import '../services/auto_journal_service.dart';
import '../../../services/database_helper.dart';
import '../../../widgets/h1_text_field.dart';

class CashBookScreen extends StatefulWidget {
  const CashBookScreen({super.key});
  @override
  State<CashBookScreen> createState() => _CashBookScreenState();
}

class _CashBookScreenState extends State<CashBookScreen> {
  final _db = DatabaseHelper();
  List<CashTransaction> _txns = [];
  List<Account> _accounts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await _db.database;
    final txns = await db.query('cash_transactions', orderBy: 'date DESC, created_at DESC');
    final accRepo = AccountRepository();
    final accounts = await accRepo.fetchAll();
    if (mounted) setState(() {
      _txns = txns.map(CashTransaction.fromMap).toList();
      _accounts = accounts;
      _loading = false;
    });
  }

  String accountName(int? id) => _accounts.where((a) => a.id == id).firstOrNull?.name ?? '?';

  String _categoryLabel(String c) => switch (c) {
    'asset' => '資産', 'liability' => '負債', 'equity' => '純資産',
    'revenue' => '収益', 'expense' => '費用', _ => c,
  };

  Future<void> _addTransaction() async {
    final dateCtl = TextEditingController(
      text: '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}');
    final amountCtl = TextEditingController();
    final descCtl = TextEditingController();
    var type = 'outflow';
    var selectedAccount = _accounts.isNotEmpty ? _accounts.first.id! : 0;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('現金出納'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              H1TextField(controller: dateCtl, decoration: const InputDecoration(labelText: '日付')),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'inflow', label: Text('入金')),
                  ButtonSegment(value: 'outflow', label: Text('出金')),
                ],
                selected: {type},
                onSelectionChanged: (s) => setDlgState(() => type = s.first),
              ),
              const SizedBox(height: 8),
              H1TextField(controller: amountCtl, decoration: const InputDecoration(labelText: '金額'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: selectedAccount,
                items: _accounts.map((a) => DropdownMenuItem(value: a.id!, child: Text('${a.name}(${_categoryLabel(a.category)})'))).toList(),
                onChanged: (v) => setDlgState(() => selectedAccount = v ?? 0),
                decoration: const InputDecoration(labelText: '科目'),
              ),
              const SizedBox(height: 8),
              H1TextField(controller: descCtl, decoration: const InputDecoration(labelText: '摘要')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            FilledButton(onPressed: () {
              if (amountCtl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            }, child: const Text('保存')),
          ],
        ),
      ),
    );
    if (saved != true) { dateCtl.dispose(); amountCtl.dispose(); descCtl.dispose(); return; }

    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('cash_transactions', {
      'id': 'cash_${now}_${amountCtl.text}',
      'date': dateCtl.text,
      'type': type,
      'amount': int.tryParse(amountCtl.text) ?? 0,
      'account_id': selectedAccount,
      'description': descCtl.text.trim(),
      'created_at': now,
    });
    try {
      await AutoJournalService().createFromCashTransaction(
        amount: int.tryParse(amountCtl.text) ?? 0,
        type: type,
        accountId: selectedAccount,
        date: DateTime.tryParse(dateCtl.text),
        description: descCtl.text.trim(),
      );
    } catch (_) {}
    dateCtl.dispose(); amountCtl.dispose(); descCtl.dispose();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('現金出納帳')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _txns.isEmpty
              ? Center(child: Text('取引がありません', style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _txns.length,
                  itemBuilder: (ctx, i) {
                    final t = _txns[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          t.type == 'inflow' ? Icons.arrow_downward : Icons.arrow_upward,
                          color: t.type == 'inflow' ? Colors.green : cs.error,
                          size: 20,
                        ),
                        title: Text('${_formatMoney(t.amount)}  ${accountName(t.accountId)}',
                          style: TextStyle(fontSize: 13, color: cs.onSurface)),
                        subtitle: Text('${t.date} ${t.description.isNotEmpty ? "- ${t.description}" : ""}',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                        trailing: Text(t.type == 'inflow' ? '入金' : '出金',
                          style: TextStyle(fontSize: 11, color: t.type == 'inflow' ? Colors.green : cs.error)),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatMoney(int v) => '¥${v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
}
