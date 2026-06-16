import 'package:flutter/material.dart';
import '../../../services/error_reporter.dart';
import '../models/supplier.dart';
import '../services/supplier_repository.dart';
import 'supplier_editor_screen.dart';
import '../../../constants/screen_ids.dart';

class SupplierPickerDialog extends StatefulWidget {
  const SupplierPickerDialog({super.key});

  @override
  State<SupplierPickerDialog> createState() => _SupplierPickerDialogState();
}

class _SupplierPickerDialogState extends State<SupplierPickerDialog> {
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
        screenId: S.sl,
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

  Future<void> _addNew() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SupplierEditorScreen()),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '仕入先を検索...',
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
                    ? const Center(child: Text('該当する仕入先がありません'))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final s = _filtered[i];
                          return ListTile(
                            title: Text(s.displayName),
                            subtitle: Text([
                              s.formalName,
                              if (s.contactPerson != null && s.contactPerson!.isNotEmpty) s.contactPerson,
                            ].join(' | ')),
                            onTap: () => Navigator.pop(context, s),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('新規仕入先を登録'),
                onPressed: _addNew,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<Supplier?> showSupplierPicker(BuildContext context) {
  return showModalBottomSheet<Supplier>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const SupplierPickerDialog(),
  );
}
