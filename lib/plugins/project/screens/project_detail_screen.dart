import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/project_repository.dart';
import '../../../services/database_helper.dart';
import '../../../models/project_model.dart';
import '../../documents/models/document_model.dart';
import '../../documents/logic/document_converter.dart';
import '../../documents/screens/document_page.dart';
import '../../documents/services/document_repository.dart';
import '../../memorandum/models/memorandum_model.dart';
import '../../memorandum/services/memorandum_repository.dart';
import '../../memorandum/screens/memorandum_input_screen.dart';
import '../../memorandum/screens/memorandum_preview_screen.dart';
import '../../ar/screens/payment_processing_screen.dart';
import '../../../services/sync_service.dart';
import '../../../constants/screen_ids.dart';
import '../../../utils/theme_utils.dart' show cardBoxShadow;
import '../widgets/project_timeline_widget.dart' show TimelineBarPainter;

class ProjectDetailScreen extends StatefulWidget {
  final String? projectId;

  const ProjectDetailScreen({super.key, this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final _repo = ProjectRepository();
  final _docRepo = DocumentRepository();
  final _memoRepo = MemorandumRepository();
  Project? _project;
  List<Map<String, dynamic>> _linkedDocs = [];
  List<Memorandum> _memorandums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) _load();
  }

  Future<void> _load() async {
    if (widget.projectId == null) return;
    setState(() => _loading = true);
    try {
      final project = await _repo.getById(widget.projectId!);
      final docs = await _repo.getLinkedDocuments(widget.projectId!);
      final memos = await _memoRepo.getByProject(widget.projectId!);
      if (!mounted) return;
      setState(() {
        _project = project;
        _linkedDocs = docs;
        _memorandums = memos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('読み込みエラー: $e')),
      );
    }
  }

  Future<void> _changeStage(String stage) async {
    if (_project == null) return;
    try {
      await _repo.updateStage(_project!.id, stage);
      final updated = _project!.copyWith(pipelineStage: stage);
      SyncService.pushChange(
        entityType: 'project',
        entityId: _project!.id,
        action: 'save',
        data: updated.toMap(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ステージ変更エラー: $e')),
      );
    }
  }

  Future<void> _createNewDocument(DocumentType type) async {
    if (_project == null) return;
    final doc = DocumentModel(
      id: const Uuid().v4(),
      documentType: type,
      customerId: _project!.customerId ?? '',
      customerName: _project!.customerName ?? '',
      documentNumber: await _docRepo.generateDocumentNumber(type),
      date: DateTime.now(),
      status: 'draft',
      projectId: _project!.id,
    );
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentPage(document: doc, isEditing: true),
      ),
    );
    if (result == true) {
      try {
        await _repo.linkDocument(
          projectId: _project!.id,
          documentType: type.name,
          documentId: doc.id,
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('リンクエラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('${S.pj2}:案件詳細')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final project = _project;
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('${S.pj2}:案件詳細')),
        body: const Center(child: Text('案件が見つかりません')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${S.pj2}:${project.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '案件を編集',
            onPressed: () => _showEditDialog(project.id),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildInfoCard(project, cs),
          const SizedBox(height: 16),
          _buildStageSection(project, cs),
          const SizedBox(height: 16),
          _buildNextActionGuide(project, cs),
          const SizedBox(height: 16),
          _buildLinkedDocsSection(cs),
          const SizedBox(height: 16),
          _buildMemorandumSection(cs),
          const SizedBox(height: 16),
          _buildStatusActions(project, cs),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Project project, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: cardBoxShadow(cs),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.workspaces, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('案件情報', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          ]),
          const Divider(height: 20),
          _infoRow('案件名', project.name, cs),
          _infoRow('取引先', project.customerName ?? '未設定', cs),
          _infoRow('ステータス', _statusLabel(project.status), cs),
          _infoRow('種別', project.type.displayName, cs),
          _infoRow('ステージ', project.pipelineStage, cs),
          _infoRow('合計金額', '￥${_formatMoney(project.totalAmount)}', cs),
          if (project.startDate != null) ...[
            const SizedBox(height: 8),
            _buildTimeline(project, cs),
          ],
          _infoRow('作成日', _formatDate(project.createdAt), cs),
        ],
      ),
    );
  }

  Widget _buildTimeline(Project project, ColorScheme cs) {
    final start = project.startDate!;
    final end = project.endDate;
    final months = project.contractMonths ?? 1;
    final totalDays = end != null
        ? end.difference(start).inDays
        : months * 30;
    final now = DateTime.now();
    final elapsed = now.difference(start).inDays.clamp(0, totalDays);
    final progress = totalDays > 0 ? elapsed / totalDays : 0.0;
    final overdue = project.isOverdue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          end != null
              ? '${_fmtDate(start)} 〜 ${_fmtDate(end)}'
              : '${_fmtDate(start)} 〜 ${months}ヶ月',
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: CustomPaint(
            size: const Size(double.infinity, 40),
            painter: TimelineBarPainter(
              progress: progress.clamp(0.0, 1.0),
              overdue: overdue,
              primaryColor: cs.primary,
              overdueColor: Colors.red,
              surfaceColor: cs.surfaceContainerHigh,
              monthCount: months,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Text('${(progress * 100).toInt()}% 経過',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: overdue ? Colors.red : cs.onSurface,
            )),
          const Spacer(),
          if (project.contractMonths != null && project.contractMonths! > 0)
            Text('${project.elapsedMonths}/${months}ヶ月',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ]),
        if (overdue) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber, size: 14, color: Colors.red.shade700),
                const SizedBox(width: 4),
                Text('契約期間超過',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _fmtDate(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  DateTime _calcEndDate(Project project) {
    if (project.startDate == null || project.contractMonths == null) {
      return project.endDate ?? DateTime.now();
    }
    return DateTime(
      project.startDate!.year + (project.startDate!.month + project.contractMonths! - 1) ~/ 12,
      (project.startDate!.month + project.contractMonths! - 1) % 12 + 1,
      project.startDate!.day,
    );
  }

  Widget _infoRow(String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSection(Project project, ColorScheme cs) {
    const stages = ['見積', '受注', '発注', '納品', '請求', '入金済'];
    final currentStage = project.pipelineStage;
    final currentIdx = stages.indexOf(currentStage);

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: cardBoxShadow(cs),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.route, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('パイプライン', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          ]),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: stages.asMap().entries.map((entry) {
                final idx = entry.key;
                final stage = entry.value;
                final isCurrent = idx == currentIdx;
                final isPast = idx < currentIdx;
                return GestureDetector(
                  onTap: () => _changeStage(stage),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent ? cs.primary : (isPast ? cs.primaryContainer : cs.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent ? cs.primary : cs.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isCurrent)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.arrow_forward_ios, size: 12, color: cs.onPrimary),
                          ),
                        Text(stage,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? cs.onPrimary : cs.onSurface,
                          )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (project.startDate != null && project.contractMonths != null && project.contractMonths! > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '契約期間: ${_formatDate(project.startDate!)} → ${_formatDate(_calcEndDate(project))} (${project.contractMonths}ヶ月)',
                      style: TextStyle(fontSize: 12, color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkedDocsSection(ColorScheme cs) {
    if (_linkedDocs.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          boxShadow: cardBoxShadow(cs),
        ),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text('紐付いた伝票はありません',
            style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: cardBoxShadow(cs),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.description, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('紐付き伝票 (${_linkedDocs.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          ]),
          const Divider(height: 20),
          ..._linkedDocs.map((doc) {
            final type = documentTypeFromString(doc['document_type'] as String? ?? '');
            final typeLabel = type?.label ?? doc['document_type'] as String? ?? '';
            final docNum = doc['document_number'] as String? ?? '';
            final dateStr = doc['date'] as String? ?? '';
            final total = doc['total'] as int? ?? 0;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.description, color: cs.primary, size: 20),
              title: Text('$typeLabel: $docNum',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
              subtitle: Text('$dateStr  ￥${_formatMoney(total)}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              trailing: Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
              onTap: () async {
                final docModel = await _docRepo.fetchById(doc['id'] as String);
                if (docModel == null || !mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DocumentPage(document: docModel, isEditing: true),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMemorandumSection(ColorScheme cs) {
    if (_memorandums.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          boxShadow: cardBoxShadow(cs),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.description, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text('関連覚書',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            ]),
            const Divider(height: 20),
            Center(
              child: Column(
                children: [
                  Text('関連する覚書はありません',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('新規覚書'),
                    onPressed: _createMemorandum,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: cardBoxShadow(cs),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.description, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('関連覚書 (${_memorandums.length})',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const Spacer(),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add, size: 14),
              label: const Text('新規', style: TextStyle(fontSize: 12)),
              onPressed: _createMemorandum,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
          const Divider(height: 20),
          ..._memorandums.map((memo) {
            final planLabel = memo.monthlyPlan.label(memo.customAmount);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.assignment, color: cs.primary, size: 20),
              title: Text(memo.documentNumber,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface)),
              subtitle: Text('${_formatDate(memo.contractDate)}  月額$planLabel  合計￥${_formatMoney(memo.totalAmount)}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              trailing: Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemorandumPreviewScreen(memorandum: memo),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _createMemorandum() async {
    if (_project == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemorandumInputScreen(
          projectId: _project!.id,
          customerId: _project!.customerId,
          customerName: _project!.customerName,
        ),
      ),
    );
    if (result == true) {
      await _load();
    }
  }

  Future<void> _showEditDialog(String projectId) async {
    final project = await _repo.getById(projectId);
    if (project == null || !mounted) return;

    final startDateCtrl = TextEditingController(
      text: project.startDate != null ? '${project.startDate!.year}/${project.startDate!.month.toString().padLeft(2, '0')}/${project.startDate!.day.toString().padLeft(2, '0')}' : '',
    );
    final endDateCtrl = TextEditingController(
      text: project.endDate != null ? '${project.endDate!.year}/${project.endDate!.month.toString().padLeft(2, '0')}/${project.endDate!.day.toString().padLeft(2, '0')}' : '',
    );
    final contractMonthsCtrl = TextEditingController(text: project.contractMonths?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) =>
            _buildEditDialog(ctx, project, setDialogState, startDateCtrl, endDateCtrl, contractMonthsCtrl),
      ),
    ).then((result) async {
      startDateCtrl.dispose();
      endDateCtrl.dispose();
      contractMonthsCtrl.dispose();

      if (result == null) return;

      final newStartDate = result['startDate'] as DateTime?;
      final newEndDate = result['endDate'] as DateTime?;
      final newContractMonths = result['contractMonths'] as int?;

      if (newStartDate == project.startDate &&
          newEndDate == project.endDate &&
          newContractMonths == project.contractMonths) {
        return;
      }

      try {
        final updated = project.copyWith(
          startDate: newStartDate,
          endDate: newEndDate,
          contractMonths: newContractMonths,
        );
        await _repo.save(updated);
        SyncService.pushChange(
          entityType: 'project',
          entityId: projectId,
          action: 'save',
          data: updated.toMap(),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('案件情報を更新しました')),
        );
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新エラー: $e')),
        );
      }
    });
  }

  Widget _buildEditDialog(
    BuildContext ctx,
    Project project,
    StateSetter setDialogState,
    TextEditingController startDateCtrl,
    TextEditingController endDateCtrl,
    TextEditingController contractMonthsCtrl,
  ) {
    final cs = Theme.of(ctx).colorScheme;

    return AlertDialog(
      title: const Text('案件を編集'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('開始日', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: project.startDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setDialogState(() => startDateCtrl.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}');
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(startDateCtrl.text.isEmpty ? '未設定' : startDateCtrl.text,
                        style: TextStyle(fontSize: 14)),
                    ),
                    if (startDateCtrl.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, size: 16, color: cs.onSurfaceVariant),
                        onPressed: () => setDialogState(() => startDateCtrl.text = ''),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('終了日', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: project.endDate ?? (project.startDate ?? DateTime.now()).add(const Duration(days: 365)),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setDialogState(() => endDateCtrl.text = '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}');
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(endDateCtrl.text.isEmpty ? '未設定' : endDateCtrl.text,
                        style: TextStyle(fontSize: 14)),
                    ),
                    if (endDateCtrl.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, size: 16, color: cs.onSurfaceVariant),
                        onPressed: () => setDialogState(() => endDateCtrl.text = ''),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('契約期間（ヶ月）', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            TextField(
              controller: contractMonthsCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: '例: 12',
                prefixIcon: Icon(Icons.date_range, size: 18, color: cs.onSurfaceVariant),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        FilledButton(
          onPressed: () {
            DateTime? parseYmd(String s) {
              final parts = s.split('/');
              if (parts.length != 3) return null;
              final y = int.tryParse(parts[0]);
              final m = int.tryParse(parts[1]);
              final d = int.tryParse(parts[2]);
              if (y == null || m == null || d == null) return null;
              return DateTime(y, m, d);
            }
            final startDate = parseYmd(startDateCtrl.text);
            final endDate = parseYmd(endDateCtrl.text);
            int? contractMonths;
            if (contractMonthsCtrl.text.isNotEmpty) {
              contractMonths = int.tryParse(contractMonthsCtrl.text);
            }
            Navigator.pop(ctx, {'startDate': startDate, 'endDate': endDate, 'contractMonths': contractMonths});
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildNextActionGuide(Project project, ColorScheme cs) {
    const actions = {
      '見積': _StageAction('見積書を作成して提出しましょう', '見積書を作成', DocumentType.estimation, null),
      '受注': _StageAction('受注内容に基づき納品書を作成しましょう', '納品書を作成', DocumentType.delivery, DocumentType.estimation),
      '発注': _StageAction('発注手配を確認しましょう', null, null, null),
      '納品': _StageAction('納品完了後、請求書を作成しましょう', '請求書を作成', DocumentType.invoice, DocumentType.delivery),
      '請求': _StageAction('入金を確認・登録しましょう', '入金登録へ', null, null),
      '入金済': _StageAction('すべての工程が完了しました', null, null, null),
    };

    final action = actions[project.pipelineStage] ?? actions['見積']!;
    final isTerminal = project.pipelineStage == '入金済';
    final isReceipt = project.pipelineStage == '請求';

    return Container(
      decoration: BoxDecoration(
        color: isTerminal ? cs.primaryContainer.withValues(alpha: 0.3) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: cardBoxShadow(cs),
        border: isTerminal ? Border.all(color: cs.primary.withValues(alpha: 0.3)) : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(isTerminal ? Icons.check_circle : Icons.touch_app, size: 20,
                color: isTerminal ? cs.primary : cs.primary),
            const SizedBox(width: 8),
            Text(isTerminal ? '完了' : '次のアクション',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          ]),
          const Divider(height: 20),
          Text(action.label,
              style: TextStyle(fontSize: 15, color: cs.onSurface)),
          const SizedBox(height: 12),
          if (action.buttonText != null && !isTerminal)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(isReceipt ? Icons.payments : _docTypeIcon(action.createType!), size: 18),
                label: Text(action.buttonText!),
                onPressed: () => _executeNextAction(project, action),
              ),
            ),
          if (!isTerminal) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: Icon(Icons.expand_more, size: 16, color: cs.onSurfaceVariant),
                label: Text('他にも作成する',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                onPressed: () => _showOtherDocTypes(project, cs),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _executeNextAction(Project project, _StageAction action) async {
    if (action.createType != null) {
      await _createNextDocument(project, action.createType!, action.copyFromType);
    } else if (project.pipelineStage == '請求') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaymentProcessingScreen()),
      );
      if (!mounted) return;
      await _load();
    }
  }

  Future<void> _createNextDocument(Project project, DocumentType targetType, DocumentType? copyFromType) async {
    DocumentModel? doc;
    if (copyFromType != null) {
      final source = _linkedDocs.where((d) =>
        d['document_type'] == copyFromType.name && d['status'] == 'confirmed'
      ).toList();
      source.sort((a, b) => ((b['date'] as String?) ?? '').compareTo((a['date'] as String?) ?? ''));
      if (source.isNotEmpty) {
        final srcModel = await _docRepo.fetchById(source.first['id'] as String);
        if (srcModel != null) {
          doc = copyAsDocument(srcModel, targetType);
        }
      }
    }
    doc ??= DocumentModel(
      id: const Uuid().v4(),
      documentType: targetType,
      customerId: project.customerId ?? '',
      customerName: project.customerName ?? '',
      documentNumber: await _docRepo.generateDocumentNumber(targetType),
      date: DateTime.now(),
      status: 'draft',
      projectId: project.id,
    );
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DocumentPage(document: doc, isEditing: true)),
    );
    if (result == true) {
      await _repo.linkDocument(projectId: project.id, documentType: targetType.name, documentId: doc!.id);
      await _load();
    }
  }

  Future<void> _showOtherDocTypes(Project project, ColorScheme cs) async {
    final type = await showModalBottomSheet<DocumentType>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('伝票を作成', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: cs.onSurface)),
          ),
          const Divider(),
          ...DocumentType.values.map((t) => ListTile(
            leading: Icon(_docTypeIcon(t), size: 20, color: cs.primary),
            title: Text('${t.label}伝票'),
            onTap: () => Navigator.pop(ctx, t),
          )),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (type != null) {
      await _createNewDocument(type);
    }
  }

  IconData _docTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.estimation: return Icons.request_quote;
      case DocumentType.order: return Icons.shopping_cart_checkout;
      case DocumentType.delivery: return Icons.local_shipping;
      case DocumentType.invoice: return Icons.receipt_long;
      case DocumentType.receipt: return Icons.receipt;
    }
  }

  Widget _buildStatusActions(Project project, ColorScheme cs) {
    if (project.status == ProjectStatus.lost) {
      return Container(
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.error.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.cancel, size: 20, color: cs.error),
          const SizedBox(width: 8),
          Text('失注案件', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.error)),
          const Spacer(),
          TextButton(
            onPressed: () => _reactivateProject(project),
            child: const Text('再開'),
          ),
        ]),
      );
    }
    if (project.status == ProjectStatus.won) {
      return Container(
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.emoji_events, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text('成約', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: cs.primary)),
        ]),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: cardBoxShadow(cs),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.flag, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('案件ステータス', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          ]),
          const Divider(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('案件を失注にする'),
              style: OutlinedButton.styleFrom(foregroundColor: cs.error),
              onPressed: () => _markAsLost(project),
            ),
          ),
          if (project.pipelineStage == '入金済') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.emoji_events, size: 18),
                label: const Text('案件を成約にする'),
                onPressed: () => _markAsWon(project),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markAsLost(Project project) async {
    int? purchaseCount;
    try {
      final db = await DatabaseHelper().database;
      final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM purchases WHERE status NOT IN ('draft', 'cancelled')",
      );
      purchaseCount = (result.first['c'] as int?) ?? 0;
    } catch (_) {}

    final purchaseWarn = purchaseCount ?? 0;
    if (purchaseWarn > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('失注確認'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('この案件を失注としてマークします。'),
              ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'アクティブな仕入が$purchaseWarn件あります。\n必要に応じてキャンセルしてください。',
                          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('失注にする')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    } else if (project.pipelineStage == '発注' || project.pipelineStage == '納品') {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('失注確認'),
          content: const Text('この案件は発注以降のステージです。関連する仕入がある場合はキャンセルしてください。\n\nそれでも失注にしますか？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('失注にする')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    try {
      final updated = project.copyWith(
        status: ProjectStatus.lost,
        endDate: DateTime.now(),
      );
      await _repo.save(updated);
      SyncService.pushChange(
        entityType: 'project', entityId: project.id, action: 'save', data: updated.toMap(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('失注処理エラー: $e')),
      );
    }
  }

  Future<void> _markAsWon(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('成約確認'),
        content: const Text('この案件を成約としてマークします。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('成約にする')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final updated = project.copyWith(
        status: ProjectStatus.won,
        endDate: DateTime.now(),
      );
      await _repo.save(updated);
      SyncService.pushChange(
        entityType: 'project', entityId: project.id, action: 'save', data: updated.toMap(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('成約処理エラー: $e')),
      );
    }
  }

  Future<void> _reactivateProject(Project project) async {
    try {
      final updated = project.copyWith(status: ProjectStatus.active);
      await _repo.save(updated);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('再開エラー: $e')),
      );
    }
  }

  String _statusLabel(ProjectStatus status) {
    switch (status) {
      case ProjectStatus.active: return '進行中';
      case ProjectStatus.won: return '成約';
      case ProjectStatus.lost: return '失注';
      case ProjectStatus.suspended: return '保留';
    }
  }

  String _formatMoney(int amount) =>
    amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  String _formatDate(DateTime dt) =>
    '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
}

class _StageAction {
  final String label;
  final String? buttonText;
  final DocumentType? createType;
  final DocumentType? copyFromType;
  const _StageAction(this.label, this.buttonText, this.createType, this.copyFromType);
}
