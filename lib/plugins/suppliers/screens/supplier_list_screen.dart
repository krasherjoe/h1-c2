import 'package:flutter/material.dart';
import '../../../services/error_reporter.dart';
import '../models/supplier.dart';
import '../services/supplier_repository.dart';
import 'supplier_editor_screen.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _repo = SupplierRepository();
  List<Supplier> _suppliers = [];
  List<Supplier> _filtered = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _suppliers = list;
        _filtered = list;
        _isLoading = false;
      });
    } catch (e, st) {
      ErrorReporter.sendError(
        message: '仕入先一覧取得失敗: $e',
        screenId: 'SL',
        stackTrace: st,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = _suppliers;
      } else {
        _filtered = _suppliers.where((s) =>
          s.displayName.toLowerCase().contains(query.toLowerCase()) ||
          s.formalName.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  Future<void> _add() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SupplierEditorScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _edit(Supplier supplier) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SupplierEditorScreen(supplier: supplier)),
    );
    if (result == true) _load();
  }

  Future<void> _delete(Supplier supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${supplier.displayName}」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _repo.delete(supplier.id);
      _load();
    } catch (e, st) {
      ErrorReporter.sendError(
        message: '仕入先削除失敗: $e',
        screenId: 'SL',
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SL:仕入先一覧')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '検索...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('仕入先が登録されていません'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) {
                            final s = _filtered[i];
                            return ListTile(
                              title: Text(s.displayName),
                              subtitle: Text([
                                s.formalName,
                                if (s.tel != null && s.tel!.isNotEmpty) s.tel,
                                if (s.contactPerson != null && s.contactPerson!.isNotEmpty) s.contactPerson,
                              ].join(' | ')),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _edit(s),
                              onLongPress: () => _delete(s),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}
