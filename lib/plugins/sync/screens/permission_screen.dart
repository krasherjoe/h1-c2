import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../services/permission_service.dart';
import '../../../services/database_helper.dart';
import '../../../constants/screen_ids.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});
  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final _features = PermissionService.allFeatures;
  final Map<String, bool> _childPerms = {};
  List<Map<String, dynamic>> _children = [];
  String? _selectedChild;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    for (final k in _features.keys) { _childPerms[k] = true; }
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseHelper().database;
    final children = await db.query('sync_children', orderBy: 'registered_at DESC');
    if (children.isNotEmpty) {
      final first = children.first['email'] as String? ?? '';
      _selectedChild = first;
      _loadPerms(first);
    }
    if (mounted) setState(() { _children = children; _loaded = true; });
  }

  void _loadPerms(String email) {
    final child = _children.where((c) => c['email'] == email).firstOrNull;
    if (child != null && child['permissions'] != null) {
      try {
        final saved = jsonDecode(child['permissions'] as String) as Map<String, dynamic>;
        for (final k in _features.keys) { _childPerms[k] = saved[k] as bool? ?? true; }
        return;
      } catch (_) {}
    }
    // デフォルト
    for (final k in _features.keys) {
      _childPerms[k] = PermissionService.defaultChildPermissions[k] ?? true;
    }
  }

  Future<void> _save() async {
    if (_selectedChild == null) return;
    final db = await DatabaseHelper().database;
    await db.update('sync_children', {
      'permissions': jsonEncode(Map.from(_childPerms)),
      'last_sync_at': DateTime.now().toIso8601String(),
    }, where: 'email = ?', whereArgs: [_selectedChild]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('\${S.pm}:権限設定')),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: cs.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('子分ごとに機能の権限を設定します', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ),
                ),
                const SizedBox(height: 12),
                if (_children.isEmpty)
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('登録済みの子分がいません', style: TextStyle(color: cs.onSurfaceVariant)),
                  ))
                else ...[
                  DropdownButtonFormField<String>(
                    value: _selectedChild,
                    items: _children.map((c) => DropdownMenuItem(value: c['email'] as String, child: Text(c['email'] as String))).toList(),
                    onChanged: (v) { setState(() { _selectedChild = v; _loadPerms(v!); }); },
                    decoration: const InputDecoration(labelText: '子分選択'),
                  ),
                  const SizedBox(height: 16),
                  ..._buildGroup(cs, '顧客・商品マスター', ['masterEdit', 'masterDelete', 'masterCreate']),
                  ..._buildGroup(cs, '伝票', ['invoiceView', 'invoiceEdit', 'invoiceCreate', 'invoiceDelete', 'invoiceIssue']),
                  ..._buildGroup(cs, '会計', ['accountingView']),
                  ..._buildGroup(cs, 'システム', ['settingEdit', 'backup']),
                  const SizedBox(height: 16),
                  FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save), label: const Text('保存')),
                ],
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  List<Widget> _buildGroup(ColorScheme cs, String title, List<String> keys) {
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
      ),
      Card(
        child: Column(
          children: keys.map((k) => CheckboxListTile(
            dense: true,
            title: Text(_features[k] ?? k, style: TextStyle(fontSize: 13, color: cs.onSurface)),
            value: _childPerms[k] ?? false,
            onChanged: (v) { setState(() => _childPerms[k] = v ?? false); },
          )).toList(),
        ),
      ),
    ];
  }
}
