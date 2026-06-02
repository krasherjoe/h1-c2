import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/memorandum_model.dart';
import '../services/memorandum_repository.dart';
import 'memorandum_input_screen.dart';

class MemorandumListScreen extends StatefulWidget {
  const MemorandumListScreen({super.key});
  @override
  State<MemorandumListScreen> createState() => _MemorandumListScreenState();
}

class _MemorandumListScreenState extends State<MemorandumListScreen> {
  final _repo = MemorandumRepository();
  final _df = DateFormat('yyyy/M/d');
  bool _loading = true;
  List<Memorandum> _items = [];
  MemorandumStatus? _filterStatus;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.getAll(status: _filterStatus);
    if (!mounted) return;
    setState(() { _items = items; _loading = false; });
  }

  Future<void> _delete(Memorandum m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('覚書 ${m.documentNumber}（${m.customerName}）を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await _repo.delete(m.id);
      if (!mounted) return;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('覚書 一覧'),
        actions: [
          IconButton(
            icon: Icon(_filterStatus == null ? Icons.filter_list : Icons.filter_list_off),
            onPressed: () => _toggleFilter(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text('覚書はありません',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final m = _items[i];
                      return Card(
                        child: ListTile(
                          title: Text('${m.documentNumber} ${m.customerName}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${m.monthlyPlan.label(m.customAmount)} × ${m.contractMonths}ヶ月 = ${NumberFormat('#,###').format(m.totalAmount)}円'),
                              Text('${_df.format(m.startDate)} ~ ${_df.format(m.endDate)}'),
                              if (m.serviceContent.isNotEmpty) Text(m.serviceContent, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                          trailing: Chip(
                            label: Text(m.status == MemorandumStatus.draft ? '下書き' : '確定',
                              style: const TextStyle(fontSize: 12)),
                            backgroundColor: m.status == MemorandumStatus.draft ? cs.secondaryContainer : cs.tertiaryContainer,
                          ),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => MemorandumInputScreen(memorandum: m),
                            ));
                            if (!mounted) return;
                            _load();
                          },
                          onLongPress: () async {
                            final result = await showMenu<String>(
                              context: context,
                              position: RelativeRect.fromLTRB(100, 100, 100, 100),
                              items: const [
                                PopupMenuItem(value: 'delete', child: Text('削除')),
                              ],
                            );
                            if (result == 'delete') {
                              await _delete(m);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const MemorandumInputScreen(),
          ));
          if (!mounted) return;
          _load();
        },
      ),
    );
  }

  void _toggleFilter() {
    setState(() {
      if (_filterStatus == null) {
        _filterStatus = MemorandumStatus.draft;
      } else if (_filterStatus == MemorandumStatus.draft) {
        _filterStatus = MemorandumStatus.confirmed;
      } else {
        _filterStatus = null;
      }
    });
    _load();
  }
}
