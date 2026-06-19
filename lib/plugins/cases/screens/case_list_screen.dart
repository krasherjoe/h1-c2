import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../services/case_repository.dart';
import '../widgets/case_progress_bar.dart';
import '../widgets/gantt_chart_widget.dart';
import '../../purchase/models/purchase_model.dart';
import '../../../services/database_helper.dart';
import 'case_detail_screen.dart';
import '../../../constants/screen_ids.dart';

class CaseListScreen extends StatefulWidget {
  const CaseListScreen({super.key});
  @override
  State<CaseListScreen> createState() => _CaseListScreenState();
}

class _CaseListScreenState extends State<CaseListScreen> {
  final _repo = CaseRepository();
  List<CaseModel> _cases = [];
  bool _loading = true;
  late final PageController _pageController;
  int _currentPage = 0;
  String _typeFilter = 'all';

  static const _statusTabs = ['すべて', '発見', '注意', '警告', '重大'];
  static const _statusValues = [-1, 0, 1, 2, 3];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await _repo.escalateAll();
      _cases = await _repo.fetchAll();
    } catch (_) {
      _cases = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<CaseModel> _filteredForTab(int tabIndex) {
    var list = _cases.where((c) => !c.isResolved).toList();
    if (_typeFilter != 'all') list = list.where((c) => c.type == _typeFilter).toList();
    final sv = _statusValues[tabIndex];
    if (sv >= 0) list = list.where((c) => c.status == sv).toList();
    list.sort((a, b) => b.status.compareTo(a.status));
    return list;
  }

  void _goToPage(int i) {
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Color _statusColor(int s, ColorScheme cs) => switch (s) { 0 => cs.tertiaryContainer, 1 => Colors.orange.shade100, 2 => Colors.deepOrange.shade100, 3 => cs.errorContainer, _ => cs.surface };
  Color _statusTextColor(int s, ColorScheme cs) => switch (s) { 0 => cs.onTertiaryContainer, 1 => Colors.orange.shade800, 2 => Colors.deepOrange.shade800, 3 => cs.onErrorContainer, _ => cs.onSurface };
  IconData _statusIcon(int s) => [Icons.fiber_new, Icons.info_outline, Icons.warning_amber, Icons.gavel][s.clamp(0, 3)];

  String _daysText(int d) => d == 0 ? '本日' : '${d}日';

  Future<void> _createManually() async {
    final type = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
      title: const Text('種別選択'),
      children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'overdue'), child: const Text('💰 滞留')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'damage'), child: const Text('🔧 破損')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'theft'), child: const Text('🚨 盗難')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'loss'), child: const Text('🔍 紛失')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'bug'), child: const Text('🐛 バグ')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'feature'), child: const Text('✨ 機能')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'task'), child: const Text('📋 タスク')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'web'), child: const Text('🌐 Web制作')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'illust'), child: const Text('🎨 イラスト制作')),
        SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'other'), child: const Text('📌 その他')),
      ],
    ));
    if (type == null) return;
    final ctl = TextEditingController();
    if (!mounted) return;
    final title = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('件名'), content: TextField(controller: ctl, autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('作成'))],
    ));
    if (title == null || title.isEmpty) return;
    await _repo.create(type: type, title: title);
    await _load();
  }

  Future<void> _quickStatus(CaseModel c, int newStatus) async {
    await _repo.updateStatus(c.id, newStatus);
    await _load();
  }

  void _showGanttChart(BuildContext context) async {
    final db = DatabaseHelper();
    List<PurchaseModel> purchases = [];
    try {
      final d = await db.database;
      final maps = await d.query('purchases', orderBy: 'date DESC');
      purchases = maps.map((m) => PurchaseModel.fromMap(m)).toList();
    } catch (_) {}

    final nonResolved = _cases.where((c) => c.status < 99).toList();
    final items = <GanttChartItem>[
      ...nonResolved.map(GanttChartItem.fromCase),
      ...purchases
          .where((p) => p.purchaseType == PurchaseType.order || p.purchaseType == PurchaseType.receipt)
          .map(GanttChartItem.fromPurchase),
    ];
    items.sort((a, b) => a.startDate.compareTo(b.startDate));

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _GanttFullScreen(items: items),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final counts = [0, 0, 0, 0];
    for (final c in _cases.where((c) => !c.isResolved)) {
      if (c.status >= 0 && c.status <= 3) counts[c.status]++;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('${S.is_}:案件管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timeline),
            tooltip: 'ガントチャート',
            onPressed: () => _showGanttChart(context),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // ステータスサマリー
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(children: [
                ...[0, 1, 2, 3].map((i) => Expanded(child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(i, cs).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(children: [
                    Icon(_statusIcon(i), size: 16, color: _statusTextColor(i, cs)),
                    Text('${counts[i]}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _statusTextColor(i, cs))),
                    Text(_statusTabs[i + 1], style: TextStyle(fontSize: 9, color: _statusTextColor(i, cs))),
                  ]),
                ))),
              ]),
            ),
            const SizedBox(height: 8),
            // 種別フィルター
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _typeChip('all', '全部', cs),
                _typeChip('overdue', '滞留', cs),
                _typeChip('damage', '破損', cs),
                _typeChip('theft', '盗難', cs),
                _typeChip('loss', '紛失', cs),
                _typeChip('bug', 'バグ', cs),
                _typeChip('feature', '機能', cs),
                _typeChip('task', 'タスク', cs),
                _typeChip('web', 'Web', cs),
                _typeChip('illust', 'イラスト', cs),
                _typeChip('other', '他', cs),
              ]),
            ),
            const SizedBox(height: 4),
            // タブバー（タップでも切替可能）
            Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: _statusTabs.asMap().entries.map((e) {
                final i = e.key;
                final selected = _currentPage == i;
                return Expanded(child: GestureDetector(
                  onTap: () => _goToPage(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: selected ? cs.surface : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_statusTabs[i],
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: selected ? cs.primary : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ));
              }).toList()),
            ),
            const SizedBox(height: 4),
            // PageView（1本指横スワイプでタブ切替）
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _statusTabs.length,
                itemBuilder: (context, index) {
                  final filtered = _filteredForTab(index);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text('案件がありません',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                      children: filtered.map((c) => _buildCaseCard(c, cs)).toList(),
                    ),
                  );
                },
              ),
            ),
          ]),
      floatingActionButton: FloatingActionButton(
        onPressed: _createManually,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCaseCard(CaseModel c, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => CaseDetailScreen(caseId: c.id))
        ).then((_) => _load()),
        onLongPress: () => _showStatusMenu(c),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 4,
              height: 62,
              decoration: BoxDecoration(
                color: _statusTextColor(c.status, cs),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _statusColor(c.status, cs).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(c.typeLabel, style: TextStyle(fontSize: 9, color: _statusTextColor(c.status, cs))),
                ),
                const SizedBox(width: 4),
                Expanded(child: Text(c.title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface),
                  overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.schedule, size: 12, color: cs.onSurfaceVariant),
                const SizedBox(width: 2),
                Text(_daysText(c.elapsedDays), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                if (c.amount != null) ...[
                  const SizedBox(width: 8),
                  Text('¥${c.amount!}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary)),
                ],
                if (c.assignee != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.person, size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Text(c.assignee!, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ],
              ]),
              const SizedBox(height: 6),
              CaseProgressBar(
                status: c.status,
                elapsedDays: c.elapsedDays,
                isResolved: c.isResolved,
              ),
            ])),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(c.status, cs),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(c.statusLabel,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _statusTextColor(c.status, cs))),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _typeChip(String value, String label, ColorScheme cs) {
    final active = _typeFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: active ? cs.onPrimary : cs.onSurfaceVariant)),
        selected: active,
        onSelected: (_) => setState(() => _typeFilter = value),
        visualDensity: VisualDensity.compact,
        selectedColor: cs.primary,
        checkmarkColor: cs.onPrimary,
      ),
    );
  }

  void _showStatusMenu(CaseModel c) {
    showModalBottomSheet(context: context, builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (c.status < 3) ListTile(
          leading: const Icon(Icons.arrow_upward),
          title: Text('${c.statusLabel}→${['発見', '注意', '警告', '重大'][c.status + 1]}に昇格'),
          onTap: () { Navigator.pop(ctx); _quickStatus(c, c.status + 1); },
        ),
        if (c.status > 0) ListTile(
          leading: const Icon(Icons.arrow_downward),
          title: Text('${c.statusLabel}→${['発見', '注意', '警告', '重大'][c.status - 1]}に降格'),
          onTap: () { Navigator.pop(ctx); _quickStatus(c, c.status - 1); },
        ),
        if (!c.isResolved) ListTile(
          leading: const Icon(Icons.check_circle, color: Colors.green),
          title: const Text('解決'),
          onTap: () { Navigator.pop(ctx); _quickStatus(c, 99); },
        ),
      ]),
    ));
  }
}

class _GanttFullScreen extends StatelessWidget {
  final List<GanttChartItem> items;
  const _GanttFullScreen({required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ガントチャート')),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: GanttChartWidget(items: items),
          ),
        ),
      ),
    );
  }
}
