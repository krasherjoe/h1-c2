import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/memorandum_model.dart';
import '../services/memorandum_repository.dart';
import 'memorandum_input_screen.dart';
import '../../../constants/screen_ids.dart';

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
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('削除', style: TextStyle(color: Theme.of(context).colorScheme.error))),
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
        title: const Text('${S.mn1}:覚書一覧'),
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
                      final dateStr = '${m.contractDate.year}/${m.contractDate.month.toString().padLeft(2, '0')}/${m.contractDate.day.toString().padLeft(2, '0')}';
                      return GestureDetector(
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
                        child: Card(
                          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Text(dateStr, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                        const SizedBox(width: 8),
                                        Text(m.customerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      ]),
                                      const SizedBox(height: 2),
                                      Text('${m.monthlyPlan.label(m.customAmount)} × ${m.contractMonths}ヶ月  ${NumberFormat('#,###').format(m.totalAmount)}円',
                                          style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      if (m.serviceContent.isNotEmpty)
                                        Text(m.serviceContent, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                                            maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                if (m.status == MemorandumStatus.draft)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.secondaryContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('下書き', style: TextStyle(fontSize: 10)),
                                  ),
                              ],
                            ),
                          ),
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
