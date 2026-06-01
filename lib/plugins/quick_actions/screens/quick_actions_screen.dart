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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    if (_pages.isEmpty) return const SizedBox.shrink();
    final actions = _service.allActions;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              const Spacer(),
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
