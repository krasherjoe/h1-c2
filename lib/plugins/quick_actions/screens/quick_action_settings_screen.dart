import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quick_action_page.dart';
import '../services/quick_action_service.dart';

class QuickActionSettingsScreen extends StatefulWidget {
  const QuickActionSettingsScreen({super.key});

  @override
  State<QuickActionSettingsScreen> createState() => _QuickActionSettingsScreenState();
}

class _QuickActionSettingsScreenState extends State<QuickActionSettingsScreen> {
  final _service = QuickActionService();
  List<QuickActionPage> _pages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pages = await _service.loadPages();
    if (!mounted) return;
    setState(() {
      _pages = pages;
      _loading = false;
    });
  }

  Future<void> _save() => _service.savePages(_pages);

  void _addPage() {
    setState(() {
      _pages.add(QuickActionPage(
        id: 'page_${DateTime.now().millisecondsSinceEpoch}',
        name: '新規ページ ${_pages.length + 1}',
        sortOrder: _pages.length,
        actionIds: [],
      ));
    });
    _save();
  }

  void _editPage(int index) {
    final page = _pages[index];
    final nameCtrl = TextEditingController(text: page.name);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ページ名',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          _pages[index].name = v;
                          _save();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _load();
                      },
                      child: const Text('完了'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deletePage(index);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('アクション', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ReorderableListView(
                    children: _service.allActions.entries.map((entry) {
                      final route = entry.key;
                      final item = entry.value;
                      final enabled = page.actionIds.contains(route);
                      return ListTile(
                        key: ValueKey(route),
                        leading: Icon(item.icon),
                        title: Text(item.title),
                        subtitle: Text(route, style: const TextStyle(fontSize: 11)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (enabled)
                              ReorderableDragStartListener(
                                index: page.actionIds.indexOf(route),
                                child: const Icon(Icons.drag_handle),
                              ),
                            Switch(
                              value: enabled,
                              onChanged: (v) {
                                setSheetState(() {
                                  if (v) {
                                    page.actionIds.add(route);
                                  } else {
                                    page.actionIds.remove(route);
                                  }
                                  _save();
                                });
                              },
                            ),
                          ],
                        ),
                        onTap: () {
                          setSheetState(() {
                            if (enabled) {
                              page.actionIds.remove(route);
                            } else {
                              page.actionIds.add(route);
                            }
                            _save();
                          });
                        },
                      );
                    }).toList(),
                    onReorder: (oldI, newI) {
                      setSheetState(() {
                        if (oldI < newI) newI--;
                        final item = page.actionIds.removeAt(oldI);
                        page.actionIds.insert(newI, item);
                        _save();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deletePage(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ページ削除'),
        content: Text('「${_pages[index].name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _pages.removeAt(index));
              _save();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('QA1: クイックアクション設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'ページ追加',
            onPressed: _addPage,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.widgets, size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text('ページがありません', style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _addPage,
                        icon: const Icon(Icons.add),
                        label: const Text('ページを追加'),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: EdgeInsets.only(
                    left: 12, right: 12, top: 12,
                    bottom: MediaQuery.of(context).padding.bottom + 12,
                  ),
                  itemCount: _pages.length,
                  onReorder: (oldI, newI) {
                    setState(() {
                      if (newI > oldI) newI--;
                      final item = _pages.removeAt(oldI);
                      _pages.insert(newI, item);
                    });
                    _save();
                  },
                  itemBuilder: (ctx, i) {
                    final page = _pages[i];
                    final actions = _service.allActions;
                    final actionNames = page.actionIds
                        .map((route) => actions[route]?.title ?? route)
                        .join(', ');
                    return Card(
                      key: ValueKey(page.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(page.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: actionNames.isNotEmpty
                            ? Text(actionNames, maxLines: 1, overflow: TextOverflow.ellipsis)
                            : Text('アクションなし', style: TextStyle(color: cs.onSurfaceVariant)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${page.actionIds.length}個', style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _editPage(i),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPage,
        child: const Icon(Icons.add),
      ),
    );
  }
}
