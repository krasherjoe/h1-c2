import 'package:flutter/material.dart';
import '../services/quick_action_service.dart';
import '../models/quick_action_page.dart';
import '../widgets/quick_action_button.dart';

class QuickActionsScreen extends StatefulWidget {
  const QuickActionsScreen({super.key});

  @override
  State<QuickActionsScreen> createState() => _QuickActionsScreenState();
}

class _QuickActionsScreenState extends State<QuickActionsScreen> {
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
    setState(() {
      _pages = pages;
      _loading = false;
    });
  }

  void _navigate(String route) {
    Navigator.pushNamed(context, route);
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

  List<Widget> _buildPages() {
    final actions = _service.allActions;
    return _pages.map((page) {
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
                  onTap: () => _navigate(route),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QA: クイックアクション'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, '/quick_actions/settings');
              if (!mounted) return;
              await _load();
            },
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
                      Icon(Icons.widgets, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text('アクションがありません', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/quick_actions/settings'),
                        icon: const Icon(Icons.add),
                        label: const Text('アクションを追加'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: _calcHeight(),
                      child: PageView(
                        controller: _pageCtrl,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        children: _buildPages(),
                      ),
                    ),
                    if (_pages.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
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
                ),
    );
  }
}
