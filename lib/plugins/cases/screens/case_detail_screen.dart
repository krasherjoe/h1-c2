import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../services/case_repository.dart';
import '../../../../widgets/h1_text_field.dart';

class CaseDetailScreen extends StatefulWidget {
  final String caseId;
  const CaseDetailScreen({super.key, required this.caseId});
  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _repo = CaseRepository();
  CaseModel? _case;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _case = await _repo.fetchById(widget.caseId);
    if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) return Scaffold(appBar: AppBar(title: const Text('案件詳細')), body: const Center(child: CircularProgressIndicator()));
    final c = _case;
    if (c == null) return Scaffold(appBar: AppBar(title: const Text('案件詳細')), body: const Center(child: Text('案件が見つかりません')));
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
