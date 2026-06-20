import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/warehouse_model.dart';
import '../services/warehouse_repository.dart';
import '../../../widgets/h1_text_field.dart';
import '../../../constants/screen_ids.dart';

class WarehouseListScreen extends StatefulWidget {
  final bool selectionMode;
  final bool showHidden;

  const WarehouseListScreen({
    super.key,
    this.selectionMode = false,
    this.showHidden = false,
  });

  @override
  State<WarehouseListScreen> createState() => _WarehouseListScreenState();
}

class _WarehouseListScreenState extends State<WarehouseListScreen> {
  final WarehouseRepository _repo = WarehouseRepository();
  final TextEditingController _searchController = TextEditingController();

  List<Warehouse> _warehouses = [];
  List<Warehouse> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repo.fetchWarehouses(includeHidden: widget.showHidden);
    if (!mounted) return;
    setState(() {
      _warehouses = data;
      _isLoading = false;
      _applyFilter();
    });
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _warehouses.where((w) {
        return w.name.toLowerCase().contains(query) ||
            (w.location?.toLowerCase().contains(query) ?? false);
      }).toList();
      if (!widget.showHidden) {
        _filtered = _filtered.where((w) => !w.isHidden).toList();
      }
    });
  }

  Future<void> _showEditDialog({Warehouse? warehouse}) async {
    final nameCtrl = TextEditingController(text: warehouse?.name ?? '');
    final locationCtrl = TextEditingController(text: warehouse?.location ?? '');
    final notesCtrl = TextEditingController(text: warehouse?.notes ?? '');
    final isNew = warehouse == null;

    final result = await showDialog<Warehouse>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? '倉庫を新規登録' : '倉庫を編集'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              H1TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: '倉庫名', hintText: '例: 第1倉庫'),
              ),
              const SizedBox(height: 12),
              H1TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(labelText: '所在地', hintText: '例: ○○市△△町1-2-3'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              H1TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: '備考'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx, Warehouse(
                id: warehouse?.id ?? const Uuid().v4(),
                name: name,
                location: locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
                notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                updatedAt: DateTime.now(),
              ));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await _repo.saveWarehouse(result);
      if (widget.selectionMode && mounted) {
        Navigator.pop(context, result);
      } else {
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('${S.wh}:倉庫一覧'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: H1TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '倉庫名・所在地で検索',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => _applyFilter(),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty
                ? const Center(child: Text('倉庫が見つかりません'))
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 80, top: 8),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final w = _filtered[index];
                      return ListTile(
                        tileColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(Icons.warehouse, color: theme.colorScheme.primary),
                        ),
                        title: Text(
                          w.name + (w.isHidden ? ' (非表示)' : ''),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: w.isHidden ? theme.hintColor : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        subtitle: w.location != null ? Text(w.location!) : null,
                        onTap: () {
                          if (widget.selectionMode) {
                            if (w.isHidden) return;
                            Navigator.pop(context, w);
                          } else {
                            _showEditDialog(warehouse: w);
                          }
                        },
                        trailing: widget.selectionMode
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showEditDialog(warehouse: w),
                              ),
                      );
                    },
                  ),
      ),
      floatingActionButton: widget.selectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showEditDialog(),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: theme.cardColor,
              child: const Icon(Icons.add),
            ),
    );
  }
}
