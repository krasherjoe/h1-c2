import 'package:flutter/material.dart';
import '../models/account.dart';
import '../services/account_repository.dart';
import '../../../widgets/h1_text_field.dart';

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});
  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  final _repo = AccountRepository();
  List<Account> _accounts = [];
  Map<int, bool> _canDelete = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await _repo.fetchAll();
    final canDelete = <int, bool>{};
    for (final a in accounts) {
      if (a.id != null) canDelete[a.id!] = await _repo.canDelete(a);
    }
    if (mounted) setState(() { _accounts = accounts; _canDelete = canDelete; _loading = false; });
  }

  String _categoryLabel(String c) => switch (c) {
    'asset' => '資産', 'liability' => '負債', 'equity' => '純資産',
    'revenue' => '収益', 'expense' => '費用', _ => c,
  };

  Color _categoryColor(String c, ColorScheme cs) => switch (c) {
    'asset' => cs.primary, 'liability' => cs.error,
    'equity' => cs.tertiary, 'revenue' => Colors.green,
    'expense' => Colors.orange, _ => cs.onSurface,
  };

  Future<void> _addOrEdit(Account? existing) async {
    final codeCtl = TextEditingController(text: existing?.code ?? '');
    final nameCtl = TextEditingController(text: existing?.name ?? '');
    var category = existing?.category ?? 'expense';
    final edited = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existing != null ? '科目編集' : '科目追加'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              H1TextField(controller: codeCtl, decoration: const InputDecoration(labelText: '科目コード')),
              const SizedBox(height: 8),
              H1TextField(controller: nameCtl, decoration: const InputDecoration(labelText: '科目名')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: category,
                items: const [
                  DropdownMenuItem(value: 'asset', child: Text('資産')),
                  DropdownMenuItem(value: 'liability', child: Text('負債')),
                  DropdownMenuItem(value: 'equity', child: Text('純資産')),
                  DropdownMenuItem(value: 'revenue', child: Text('収益')),
                  DropdownMenuItem(value: 'expense', child: Text('費用')),
                ],
                onChanged: (v) => setDlgState(() => category = v ?? 'expense'),
                decoration: const InputDecoration(labelText: '区分'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            FilledButton(onPressed: () {
              if (codeCtl.text.trim().isEmpty || nameCtl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            }, child: const Text('保存')),
          ],
        ),
      ),
    );
    if (edited != true) { codeCtl.dispose(); nameCtl.dispose(); return; }
    await _repo.save(Account(
      id: existing?.id,
      code: codeCtl.text.trim(),
      name: nameCtl.text.trim(),
      category: category,
      isSystem: existing?.isSystem ?? false,
    ));
    codeCtl.dispose(); nameCtl.dispose();
    await _load();
  }

  Future<void> _confirmDelete(Account a) async {
    final can = await _repo.canDelete(a);
    if (!can) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('使用中の科目は削除できません')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${a.name}」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok == true && a.id != null) {
      await _repo.delete(a.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('勘定科目')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _accounts.length,
              itemBuilder: (ctx, i) {
                final a = _accounts[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: _categoryColor(a.category, cs).withValues(alpha: 0.2),
                      child: Text(a.code, style: TextStyle(fontSize: 10, color: _categoryColor(a.category, cs))),
                    ),
                    title: Text(a.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
                    subtitle: Text(_categoryLabel(a.category), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit, size: 18, color: cs.primary),
                          onPressed: () => _addOrEdit(a),
                        ),
                        if (!a.isSystem)
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                            onPressed: () => _confirmDelete(a),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEdit(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
