import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../services/project_repository.dart';
import '../../../models/project_model.dart';
import '../../documents/models/document_model.dart';
import '../../documents/screens/document_page.dart';
import '../../documents/services/document_repository.dart';
import '../../memorandum/models/memorandum_model.dart';
import '../../memorandum/services/memorandum_repository.dart';
import '../../memorandum/screens/memorandum_input_screen.dart';
import '../../memorandum/screens/memorandum_preview_screen.dart';
import '../../../services/sync_service.dart';
import '../../../constants/screen_ids.dart';

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
        appBar: AppBar(title: const Text('\${S.pj2}:案件詳細')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final project = _project;
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('\${S.pj2}:案件詳細')),
        body: const Center(child: Text('案件が見つかりません')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('\${S.pj2}:${project.name}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildInfoCard(project, cs),
          const SizedBox(height: 16),
          _buildStageSection(project, cs),
          const SizedBox(height: 16),
          _buildLinkedDocsSection(cs),
          const SizedBox(height: 16),
          _buildMemorandumSection(cs),
          const SizedBox(height: 16),
          _buildActionsSection(project, cs),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Project project, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
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
          if (project.startDate != null)
            _infoRow('開始日', _formatDate(project.startDate!), cs),
          if (project.endDate != null)
            _infoRow('終了日', _formatDate(project.endDate!), cs),
          if (project.contractMonths != null && project.contractMonths! > 0) ...[
            _infoRow('契約期間', '${project.contractMonths}ヶ月', cs),
            if (project.startDate != null) ...[
              _infoRow('契約期間',
                '${_formatDate(project.startDate!)} → ${_formatDate(_calcEndDate(project))}',
                cs),
            ],
            const SizedBox(height: 8),
            _buildTimeProgress(project, cs),
            if (project.isOverdue) ...[
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
          _infoRow('作成日', _formatDate(project.createdAt), cs),
        ],
      ),
    );
  }

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

  Widget _buildTimeProgress(Project project, ColorScheme cs) {
    final progress = project.timeProgress;
    final overdue = project.isOverdue;
    final barColor = overdue ? Colors.red : (progress >= 1.0 ? Colors.orange : cs.primary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: cs.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(barColor),
          ),
        ),
        const SizedBox(height: 4),
        Text('${(progress * 100).toInt()}% 経過 (${project.elapsedMonths}/${project.contractMonths}ヶ月)',
          style: TextStyle(fontSize: 11, color: barColor, fontWeight: FontWeight.w500)),
      ],
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
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
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
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
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
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
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

  Widget _buildActionsSection(Project project, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.add_circle, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Text('新規伝票作成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
          ]),
          const Divider(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: DocumentType.values.map((type) {
              return ActionChip(
                avatar: Icon(_docTypeIcon(type), size: 16),
                label: Text('${type.label}伝票'),
                onPressed: () => _createNewDocument(type),
              );
            }).toList(),
          ),
        ],
      ),
    );
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
