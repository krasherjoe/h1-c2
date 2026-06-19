import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../services/case_repository.dart';
import '../widgets/gantt_chart_widget.dart';
import '../../purchase/models/purchase_model.dart';
import '../../../../services/database_helper.dart';
import '../../../../services/tracking_service.dart';
import '../../../../widgets/h1_text_field.dart';

enum TimelineSource { all, cases, purchases }

class CaseDetailScreen extends StatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});
  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _repo = CaseRepository();
  final _db = DatabaseHelper();
  CaseModel? _case;
  List<CaseModel> _allCases = [];
  List<PurchaseModel> _purchases = [];
  bool _loading = true;
  GanttFilter _ganttFilter = GanttFilter.all;
  TimelineSource _source = TimelineSource.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _case = await _repo.fetchById(widget.caseId);
    _allCases = await _repo.fetchAll();
    _purchases = await _fetchPurchases();
    if (mounted) setState(() => _loading = false);
  }

  Future<List<PurchaseModel>> _fetchPurchases() async {
    try {
      final db = await _db.database;
      final maps = await db.query('purchases', orderBy: 'date DESC');
      return maps.map((m) => PurchaseModel.fromMap(m)).toList();
    } catch (_) {
      return [];
    }
  }

  List<GanttChartItem> get _timelineItems {
    final items = <GanttChartItem>[];

    if (_source == TimelineSource.all || _source == TimelineSource.cases) {
      final cases = _filteredCases;
      items.addAll(cases.map(GanttChartItem.fromCase));
    }
    if (_source == TimelineSource.all || _source == TimelineSource.purchases) {
      items.addAll(_purchases
        .where((p) => p.purchaseType == PurchaseType.order || p.purchaseType == PurchaseType.receipt)
        .map(GanttChartItem.fromPurchase));
    }

    items.sort((a, b) => a.startDate.compareTo(b.startDate));
    return items;
  }

  List<CaseModel> get _filteredCases {
    final c = _case;
    if (c == null) return [];
    return switch (_ganttFilter) {
      GanttFilter.all => _allCases,
      GanttFilter.assignee => _allCases.where((i) => i.assignee == c.assignee).toList(),
      GanttFilter.type => _allCases.where((i) => i.type == c.type).toList(),
    };
  }

  Future<void> _resolve() async {
    final noteCtl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('解決メモ'),
        content: H1TextField(controller: noteCtl, decoration: const InputDecoration(labelText: '解決内容'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, noteCtl.text.trim()), child: const Text('解決')),
        ],
      ),
    );
    if (note == null) return;
    await _repo.updateStatus(widget.caseId, 99, notes: note);
    await _load();
  }

  Future<void> _addNote() async {
    final ctl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メモ追加'),
        content: H1TextField(controller: ctl, decoration: const InputDecoration(labelText: 'メモ'), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('追加')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    final existing = _case?.notes ?? '';
    final newNotes = existing.isEmpty ? text : '$existing\n---\n$text';
    await _repo.updateStatus(widget.caseId, _case?.status ?? 0, notes: newNotes);
    await _load();
  }

  Widget _sourceChip(String label, TimelineSource src, IconData icon) {
    final active = _source == src;
    final cs = Theme.of(context).colorScheme;
    final color = switch (src) {
      TimelineSource.all => cs.primary,
      TimelineSource.cases => TimelineEventType.caseEvent.color(Theme.of(context)),
      TimelineSource.purchases => TimelineEventType.purchaseOrder.color(Theme.of(context)),
    };
    return GestureDetector(
      onTap: () => setState(() => _source = src),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.15) : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? color : cs.outlineVariant, width: 0.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: active ? color : cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: active ? color : cs.onSurfaceVariant)),
        ]),
      ),
    );
  }

  void _onTimelineItemTap(String id) async {
    if (id.startsWith('purchase_')) {
      final purchaseId = id.substring(9);
      final purchases = _purchases.where((p) => p.id == purchaseId).toList();
      final purchase = purchases.isNotEmpty ? purchases.first : null;
      if (purchase != null) {
        await _showPurchaseDetail(purchase);
      }
    } else if (id != widget.caseId) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CaseDetailScreen(caseId: id),
      ));
    }
  }

  Future<void> _showPurchaseDetail(PurchaseModel purchase) async {
    final cs = Theme.of(context).colorScheme;
    final trackingSvc = _TrackingInfoWidget(purchase: purchase);
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(purchase.documentNumber.isNotEmpty ? purchase.documentNumber : '伝票なし',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('${purchase.purchaseType.label} / ${purchase.supplierName} / ¥${purchase.total}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          if (purchase.trackingNumber != null) ...[
            const Divider(),
            trackingSvc,
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('案件詳細')), body: const Center(child: CircularProgressIndicator()));
    final c = _case;
    if (c == null) return Scaffold(appBar: AppBar(title: const Text('案件詳細')), body: const Center(child: Text('案件が見つかりません')));
    final timeline = _timelineItems;
    return Scaffold(
      appBar: AppBar(title: Text(c.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.status >= 3 ? cs.errorContainer : cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('${c.typeLabel} / ${c.statusLabel}',
                          style: TextStyle(fontSize: 11, color: c.status >= 3 ? cs.onErrorContainer : cs.onTertiaryContainer, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Text(c.createdAt.toString().substring(0, 16), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 12),
                  if (c.description.isNotEmpty) ...[
                    Text(c.description, style: TextStyle(fontSize: 13, color: cs.onSurface)),
                    const SizedBox(height: 8),
                  ],
                  if (c.amount != null) ...[
                    Text('金額: ¥${c.amount!}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
                    const SizedBox(height: 8),
                  ],
                  Row(children: [
                    if (!c.isResolved) ...[
                      FilledButton.icon(onPressed: _resolve, icon: const Icon(Icons.check, size: 16), label: const Text('解決')),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton.icon(onPressed: _addNote, icon: const Icon(Icons.note_add, size: 16), label: const Text('メモ')),
                  ]),
                ],
              ),
            ),
          ),
          if (c.notes != null && c.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('対応メモ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(c.notes!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ),
            ),
          ],
          // Gantt chart section
          const SizedBox(height: 20),
          Text('タイムライン', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 4),
          Row(children: [
            _sourceChip('すべて', TimelineSource.all, Icons.all_inclusive),
            const SizedBox(width: 6),
            _sourceChip('案件', TimelineSource.cases, TimelineEventType.caseEvent.icon),
            const SizedBox(width: 6),
            _sourceChip('発注入荷', TimelineSource.purchases, TimelineEventType.purchaseOrder.icon),
          ]),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: GanttChartWidget(
                items: timeline,
                highlightId: widget.caseId,
                initialFilter: _ganttFilter,
                onItemTap: _onTimelineItemTap,
                onDueDateChange: (id, date) async {
                  if (!id.startsWith('purchase_')) {
                    await _repo.updateDueDate(id, date);
                  }
                },
              ),
            ),
          ),
          if (c.resolvedAt != null) ...[
            const SizedBox(height: 16),
            Card(
              color: cs.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Icon(Icons.check_circle, color: cs.onTertiaryContainer, size: 18),
                  const SizedBox(width: 8),
                  Text('${c.resolvedAt!.year}/${c.resolvedAt!.month}/${c.resolvedAt!.day} に解決済み',
                      style: TextStyle(fontSize: 12, color: cs.onTertiaryContainer)),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrackingInfoWidget extends StatelessWidget {
  final PurchaseModel purchase;
  const _TrackingInfoWidget({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tn = purchase.trackingNumber ?? '';
    final courier = purchase.courier ?? TrackingService.detectCourier(tn);
    final url = TrackingService.trackingUrl(courier, tn);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.local_shipping, size: 14, color: cs.primary),
        const SizedBox(width: 6),
        Text('配送追跡', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: cs.onSurface)),
      ]),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('運送会社: ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            Text(TrackingService.courierLabel(courier), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('追跡番号: ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            Expanded(child: Text(tn, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary))),
          ]),
          if (url != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {}, // TODO: launch URL
                icon: const Icon(Icons.open_in_new, size: 14),
                label: Text('追跡ページを開く', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }
}
