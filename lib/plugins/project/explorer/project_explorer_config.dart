import 'package:flutter/material.dart';
import '../../explorer/h1_explorer_config.dart';
import '../models/project_explorer_item.dart';
import '../screens/project_detail_screen.dart';
import '../../../services/project_repository.dart';
import '../../../models/project_model.dart';

class ProjectExplorerConfig extends H1ExplorerConfig<ProjectExplorerItem> {
  String _projectStatusFilter = '';

  @override
  String get explorerTitle => 'PRJ:案件管理';

  @override
  String get searchHint => '案件名・顧客名で検索';

  @override
  bool get showSearch => true;

  @override
  bool get showStatusFilter => false;

  @override
  IconData get itemIcon => Icons.workspaces;

  @override
  String get emptyMessage => '案件がありません';

  @override
  bool get supportsEdit => false;

  @override
  bool get viewerHasOwnScaffold => true;

  static const _pipelineOptions = [
    (value: '', label: 'すべて', icon: Icons.all_inbox),
    (value: '見積', label: '見積', icon: Icons.request_quote),
    (value: '受注', label: '受注', icon: Icons.shopping_cart_checkout),
    (value: '発注', label: '発注', icon: Icons.local_shipping),
    (value: '納品', label: '納品', icon: Icons.local_shipping),
    (value: '請求', label: '請求', icon: Icons.receipt_long),
    (value: '入金済', label: '入金済', icon: Icons.check_circle),
  ];

  @override
  List<({String value, String label, IconData icon})> get typeFilterOptions => _pipelineOptions;

  @override
  String? groupKey(ProjectExplorerItem item) => item.project.pipelineStage;

  @override
  Future<List<ProjectExplorerItem>> fetchItems(String query) async {
    final repo = ProjectRepository();
    final all = await repo.getAll();
    var filtered = all;

    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered.where((p) =>
        p.name.toLowerCase().contains(q) ||
        (p.customerName?.toLowerCase().contains(q) ?? false)
      ).toList();
    }

    if (typeFilter.isNotEmpty) {
      filtered = filtered.where((p) => p.pipelineStage == typeFilter).toList();
    }

    if (_projectStatusFilter.isNotEmpty) {
      filtered = filtered.where((p) {
        if (_projectStatusFilter == 'active') {
          return p.status == ProjectStatus.active || p.status == ProjectStatus.suspended;
        }
        return p.status.name == _projectStatusFilter;
      }).toList();
    }

    return filtered.map((p) => ProjectExplorerItem(p)).toList();
  }

  @override
  Widget buildViewer(BuildContext context, ProjectExplorerItem item) {
    return ProjectDetailScreen(projectId: item.project.id);
  }

  @override
  Widget buildEditor(BuildContext context, ProjectExplorerItem? item) {
    return ProjectDetailScreen(projectId: item?.project.id);
  }

  @override
  Future<bool> canDelete(ProjectExplorerItem item) async => false;

  @override
  Future<void> deleteItem(ProjectExplorerItem item) async {}

  @override
  List<({String id, IconData icon, String label})> get overflowActions => [
    (id: 'filter_active', icon: Icons.play_circle, label: '進行中'),
    (id: 'filter_lost', icon: Icons.cancel_outlined, label: '失注'),
    (id: 'filter_won', icon: Icons.check_circle, label: '成約'),
    (id: 'filter_all', icon: Icons.all_inclusive, label: 'すべて解除'),
  ];

  @override
  void onOverflowAction(BuildContext context, String id, {required VoidCallback onListChanged}) {
    switch (id) {
      case 'filter_active':
        _projectStatusFilter = 'active';
      case 'filter_lost':
        _projectStatusFilter = 'lost';
      case 'filter_won':
        _projectStatusFilter = 'won';
      case 'filter_all':
        _projectStatusFilter = '';
    }
    onListChanged();
  }

  @override
  List<({IconData icon, String label, Future<void> Function() onTap})>? fabActions(
          BuildContext context) =>
      [
        (
          icon: Icons.add,
          label: '新規案件',
          onTap: () => _createProject(context),
        ),
      ];

  Future<void> _createProject(BuildContext context) async {
    final nameCtl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規案件'),
        content: TextField(
          controller: nameCtl,
          decoration: const InputDecoration(labelText: '案件名'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () {
              if (nameCtl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, nameCtl.text.trim());
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      await ProjectRepository().createProject(name: result, customerId: '', customerName: '');
      onListChanged?.call();
    }
  }

  @override
  Widget buildItemTileContent(BuildContext context, ProjectExplorerItem item) {
    final cs = Theme.of(context).colorScheme;
    final project = item.project;
    final isLost = project.status == ProjectStatus.lost;
    final isWon = project.status == ProjectStatus.won;

    return Container(
      decoration: BoxDecoration(
        color: isLost ? cs.surfaceContainerHighest.withValues(alpha: 0.5) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          isLost ? Icons.cancel_outlined : (isWon ? Icons.check_circle : Icons.workspaces),
          color: isLost ? cs.error : (isWon ? cs.primary : cs.primary),
          size: 24,
        ),
        title: Text(project.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isLost ? cs.onSurfaceVariant : cs.onSurface,
          )),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (project.customerName != null && project.customerName!.isNotEmpty)
              Text(project.customerName!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _stageColor(project.pipelineStage, cs).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(project.pipelineStage,
                  style: TextStyle(fontSize: 10, color: _stageColor(project.pipelineStage, cs), fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              if (project.status == ProjectStatus.lost)
                Text('失注', style: TextStyle(fontSize: 10, color: cs.error)),
              if (project.status == ProjectStatus.won)
                Text('成約', style: TextStyle(fontSize: 10, color: cs.primary)),
              const Spacer(),
              Text('￥${_fmt(project.totalAmount)}',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary)),
            ]),
            if (project.contractMonths != null && project.contractMonths! > 0) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: project.timeProgress.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    project.isOverdue ? cs.error : cs.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _stageColor(String stage, ColorScheme cs) {
    switch (stage) {
      case '見積': return cs.secondary;
      case '受注': return cs.tertiary;
      case '発注': return cs.error;
      case '納品': return cs.primaryContainer;
      case '請求': return cs.secondaryContainer;
      case '入金済': return cs.primary;
      default: return cs.onSurfaceVariant;
    }
  }

  String _fmt(int n) =>
    n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
