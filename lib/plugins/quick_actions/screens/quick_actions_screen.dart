import 'package:flutter/material.dart';
import '../services/quick_action_service.dart';
import '../models/quick_action_page.dart';
import '../widgets/quick_action_button.dart';

class QuickActionsPanel extends StatefulWidget {
  const QuickActionsPanel({super.key});
  @override
  State<QuickActionsPanel> createState() => _QuickActionsPanelState();
}

class _QuickActionsPanelState extends State<QuickActionsPanel> {
  final _service = QuickActionService();
  final _pageCtrl = PageController();
  List<QuickActionPage> _pages = [];
  int _currentPage = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pages = await _service.loadPages();
    if (!mounted) return;
    setState(() { _pages = pages; _loading = false; });
  }

  double _calcHeight() {
    if (_pages.isEmpty) return 120;
    final screenW = MediaQuery.of(context).size.width - 64;
    final btnW = 72.0;
    final gap = 4.0;
    final perRow = ((screenW + gap) / (btnW + gap)).floor().clamp(1, 10);
    final maxRows = _pages.fold(1, (max, page) {
      final rows = ((page.actionIds.length - 1) ~/ perRow) + 1;
      return rows > max ? rows : max;
    });
    return 8.0 + (maxRows * 72.0) + ((maxRows - 1) * 6.0) + 4.0;
  }

  void _openReorderSheet() {
    final page = _pages[_currentPage];
    final actions = _service.allActions;
    final ids = List<String>.from(page.actionIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Text('並び替え: ${page.name}',
                      style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: () {
                        page.actionIds = ids;
                        _service.savePages(_pages);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: (ids.length * 56.0).clamp(0, MediaQuery.of(ctx).size.height * 0.55),
                child: ReorderableListView.builder(
                  itemCount: ids.length,
                  onReorder: (oldI, newI) {
                    setSheetState(() {
                      if (newI > oldI) newI--;
                      final item = ids.removeAt(oldI);
                      ids.insert(newI, item);
                    });
                  },
                  itemBuilder: (ctx, i) {
                    final route = ids[i];
                    final item = actions[route];
                    return ListTile(
                      key: ValueKey(route),
                      leading: Icon(item?.icon ?? Icons.help_outline,
                        color: item != null
                          ? QuickActionService.accentFor(item)
                          : null),
                      title: Text(item?.title ?? route),
                      subtitle: Text(route, style: const TextStyle(fontSize: 11)),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    if (_pages.isEmpty) return const SizedBox.shrink();
    final actions = _service.allActions;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    Text(
                      'クイックアクション  ',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _pages[_currentPage].name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.reorder, size: 20, color: cs.onSurfaceVariant),
                tooltip: '並び替え',
                onPressed: _openReorderSheet,
              ),
              IconButton(
                icon: Icon(Icons.settings, size: 20, color: cs.onSurfaceVariant),
                tooltip: 'クイックアクション設定',
                onPressed: () => Navigator.pushNamed(context, '/quick_actions/settings'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: _calcHeight(),
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: _pages.map((page) {
              final gap = 4.0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: gap,
                    runSpacing: 6,
                    children: page.actionIds.map((route) {
                      final item = actions[route];
                      if (item == null) return const SizedBox.shrink();
                      return SizedBox(
                        width: 72,
                        child: QuickActionButton(
                          icon: item.icon,
                          label: item.title,
                          accentColor: QuickActionService.accentFor(item),
                          onTap: () => Navigator.pushNamed(context, route),
                          onLongPress: _openReorderSheet,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_pages.length > 1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
