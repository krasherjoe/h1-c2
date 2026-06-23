import 'package:flutter/material.dart';
import '../../explorer/h1_explorer_config.dart';
import '../models/project_explorer_item.dart';
import '../screens/project_detail_screen.dart';
import '../widgets/project_timeline_widget.dart' show TimelineBarPainter;
import '../../../services/project_repository.dart';
import '../../../models/project_model.dart';
import '../../../utils/app_theme.dart';

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
    (value: 'sales', label: '販売', icon: Icons.trending_up),
    (value: 'development', label: '開発', icon: Icons.code),
    (value: 'collection', label: '回収', icon: Icons.payments),
    (value: 'other', label: 'その他', icon: Icons.more_horiz),
  ];

  @override
  List<({String value, String label, IconData icon})> get typeFilterOptions => _pipelineOptions;

  @override
  String? groupKey(ProjectExplorerItem item) {
    // collection はタイプ別、それ以外はパイプライン
    if (item.project.type == ProjectType.collection) return '回収';
    return item.project.pipelineStage;
  }

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
      filtered = filtered.where((p) => p.type == ProjectType.values.firstWhere(
        (t) => t.name == typeFilter, orElse: () => ProjectType.sales,
      )).toList();
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
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規案件'),
        content: TextField(
          controller: nameCtl,
          decoration: const InputDecoration(
            labelText: '案件名',
            hintText: '例: ○○株式会社 リニューアル',
          ),
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
    if (name == null) return;
    try {
      await ProjectRepository().createProject(
        name: name,
        customerId: '',
        customerName: '',
      );
      onListChanged?.call();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('作成エラー: $e')),
      );
    }
  }

  @override
  Widget buildItemTileContent(BuildContext context, ProjectExplorerItem item) {
    final cs = Theme.of(context).colorScheme;
    final project = item.project;
    final isDark = cs.brightness == Brightness.dark;
    final isLost = project.status == ProjectStatus.lost;
    final isWon = project.status == ProjectStatus.won;
    final cardBg = isLost
        ? (isDark ? AppTheme.cardLostDark : AppTheme.cardLostLight)
        : (Theme.of(context).cardTheme.color ?? cs.surface);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cardBg,
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
            if (project.startDate != null) ...[
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: 3,
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, 3),
                      painter: TimelineBarPainter(
                        progress: project.timeProgress.clamp(0.0, 1.0),
                        overdue: project.isOverdue,
                        barColor: project.isOverdue ? cs.error : cs.primary,
                        overdueColor: cs.error,
                        surfaceColor: cs.surfaceContainerHighest,
                        markerColor: cs.error,
                        monthCount: project.contractMonths ?? 12,
                      ),
                    ),
                  );
                },
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
