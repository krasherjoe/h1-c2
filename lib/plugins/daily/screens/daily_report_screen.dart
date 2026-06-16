import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/daily_models.dart';
import '../services/daily_report_repository.dart';
import '../../../constants/screen_ids.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final _repo = DailyReportRepository();
  final _uuid = const Uuid();
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  List<DailyReport> _reports = [];
  List<String> _allTags = [];
  bool _loading = true;
  String _tagFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final reports = await _repo.getByMonth(_year, _month);
    final tags = await _repo.getAllTags();
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _allTags = tags;
      _loading = false;
    });
  }

  Future<void> _showEditDialog({DailyReport? report}) async {
    final doneCtrl = TextEditingController(text: report?.doneText ?? '');
    final planCtrl = TextEditingController(text: report?.planText ?? '');
    final issueCtrl = TextEditingController(text: report?.issueText ?? '');
    final tagCtrl = TextEditingController(text: report?.tags ?? '');
    final dateStr = report?.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(report != null ? '日報編集' : '3行日報'),
        content: SizedBox(
          width: 500,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: doneCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '今日やったこと', hintText: '1行目'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: planCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '明日やること', hintText: '2行目'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: issueCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '課題・連絡事項', hintText: '3行目（任意）'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (text) =>
                  _allTags.where((t) => t.contains(text.text.toLowerCase())),
              fieldViewBuilder: (ctx, ctrl, focus, submit) => TextField(
                controller: tagCtrl,
                decoration: const InputDecoration(
                    labelText: 'タグ', hintText: 'カンマ区切り（例: 営業, 開発）'),
                onSubmitted: (_) => submit(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () async {
              final now = DateTime.now().toIso8601String();
              await _repo.save(DailyReport(
                id: report?.id ?? _uuid.v4(),
                date: dateStr,
                doneText: doneCtrl.text,
                planText: planCtrl.text,
                issueText: issueCtrl.text.isNotEmpty ? issueCtrl.text : null,
                tags: tagCtrl.text.isNotEmpty ? tagCtrl.text : null,
                projectId: report?.projectId,
                createdAt: report?.createdAt ?? now,
                updatedAt: now,
              ));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _load();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(DailyReport r) async {
    await _repo.delete(r.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = _tagFilter.isEmpty
        ? _reports
        : _reports.where((r) => r.tagList.any((t) => t.contains(_tagFilter))).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('\${S.dr}:日報')),
      body: Column(children: [
        _periodFilter(cs),
        if (_allTags.isNotEmpty) _tagBar(cs),
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _reportCard(filtered[i], cs),
            ),
          ),
      ]),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showEditDialog(),
      ),
    );
  }

  Widget _periodFilter(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _month--;
              if (_month == 0) {
                _month = 12;
                _year--;
              }
            });
            _load();
          },
        ),
        Text('$_year年$_month月',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _month++;
              if (_month == 13) {
                _month = 1;
                _year++;
              }
            });
            _load();
          },
        ),
      ]),
    );
  }

  Widget _tagBar(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          FilterChip(
            label: const Text('all'),
            selected: _tagFilter.isEmpty,
            onSelected: (_) => setState(() => _tagFilter = ''),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          ..._allTags.map((t) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilterChip(
                  label: Text(t),
                  selected: _tagFilter == t,
                  onSelected: (_) =>
                      setState(() => _tagFilter = _tagFilter == t ? '' : t),
                  visualDensity: VisualDensity.compact,
                ),
              )),
        ]),
      ),
    );
  }

  Widget _reportCard(DailyReport r, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showEditDialog(report: r),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(r.date,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer)),
              ),
              if (r.tagList.isNotEmpty) ...[
                const SizedBox(width: 8),
                ...r.tagList.map((t) => Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3)),
                      child: Text(t,
                          style:
                              TextStyle(fontSize: 9, color: cs.onSecondaryContainer)),
                    )),
              ],
              const Spacer(),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error, size: 16),
                  padding: EdgeInsets.zero,
                  onPressed: () => _delete(r),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            _line('✅', r.doneText, cs),
            _line('→', r.planText, cs),
            if (r.issueText != null && r.issueText!.isNotEmpty)
              _line('⚠️', r.issueText!, cs),
          ]),
        ),
      ),
    );
  }

  Widget _line(String prefix, String text, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$prefix ', style: const TextStyle(fontSize: 12)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}
