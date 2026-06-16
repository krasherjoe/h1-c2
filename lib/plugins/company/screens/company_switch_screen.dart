import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../services/company_service.dart';
import '../../../constants/screen_ids.dart';

class CompanySwitchScreen extends StatefulWidget {
  const CompanySwitchScreen({super.key});
  @override
  State<CompanySwitchScreen> createState() => _CompanySwitchScreenState();
}

class _CompanySwitchScreenState extends State<CompanySwitchScreen> {
  String _currentCompany = '';
  List<String> _companies = [];
  Map<String, int> _fileSizes = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final current = await CompanyService.getCurrentCompany() ?? '';
    final list = await CompanyService.getCompanyList();
    final dir = await CompanyService.getCompanyDirectory();
    final sizes = <String, int>{};
    for (final name in list) {
      final file = File(p.join(dir.path, '$name.db'));
      if (await file.exists()) {
        sizes[name] = await file.length();
      }
    }
    if (!mounted) return;
    setState(() {
      _currentCompany = current;
      _companies = list;
      _fileSizes = sizes;
      _loading = false;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _switch(String name) async {
    await CompanyService.switchCompany(name);
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「$name」に切り替えました')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('\${S.tm}:法人切替')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _companies.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('法人が登録されていません', style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _createCompany,
                        icon: const Icon(Icons.add_business),
                        label: const Text('新規法人を作成'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('現在の法人', style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text(
                      _currentCompany.isNotEmpty ? _currentCompany : '（なし）',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: cs.primary),
                    ),
                    const SizedBox(height: 24),
                    Text('法人一覧', style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    ..._companies.map((name) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          name == _currentCompany ? Icons.business : Icons.business_outlined,
                          color: name == _currentCompany ? cs.primary : null,
                        ),
                        title: Text(name),
                        subtitle: Text(
                          name == _currentCompany ? '現在使用中' : 'タップして切替',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_fileSizes.containsKey(name))
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  _formatFileSize(_fileSizes[name]!),
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                              ),
                            if (name == _currentCompany)
                              Icon(Icons.check_circle, color: cs.primary)
                            else
                              const Icon(Icons.chevron_right),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                              onPressed: () => _deleteCompany(name),
                              tooltip: '削除',
                            ),
                          ],
                        ),
                        onTap: name == _currentCompany ? null : () => _switch(name),
                      ),
                    )),
                    const SizedBox(height: 24),
                    Center(
                      child: FilledButton.icon(
                        onPressed: _createCompany,
                        icon: const Icon(Icons.add_business),
                        label: const Text('新規法人を作成'),
                      ),
                    ),
                  ],
                ),
    );
  }

  Future<void> _createCompany() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規法人を作成'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: '法人名'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('作成')),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    if (_companies.contains(name)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$name」は既に存在します'), backgroundColor: Colors.red),
      );
      return;
    }
    try {
      await CompanyService.createCompany(name);
      await CompanyService.switchCompany(name);
      await _load();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('作成エラー: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteCompany(String name) async {
    if (_companies.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最後の法人は削除できません'), backgroundColor: Colors.red),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('法人を削除'),
        content: Text('「$name」を削除してもよろしいですか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await CompanyService.deleteCompany(name);
      if (name == _currentCompany) {
        final remaining = _companies.where((c) => c != name).toList()..sort();
        if (remaining.isNotEmpty) {
          await CompanyService.switchCompany(remaining.first);
        }
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$name」を削除しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除エラー: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
