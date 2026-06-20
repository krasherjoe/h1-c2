import 'package:flutter/material.dart';
import '../../../services/project_repository.dart';
import '../../../services/database_helper.dart';
import '../../../models/project_model.dart';
import '../../../utils/app_theme.dart';
import '../../../widgets/h1_text_field.dart';
import 'project_detail_screen.dart';

class ProjectListScreen extends StatefulWidget {
  final bool selectionMode;
  const ProjectListScreen({super.key, this.selectionMode = false});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  final _repo = ProjectRepository();
  List<Project> _projects = [];
  bool _loading = true;
  bool _kanbanMode = false;

  static const _stages = ['見積', '受注', '発注', '納品', '請求', '入金済'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final projects = await _repo.getAll();
      if (!mounted) return;
      setState(() {
        _projects = projects;
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

  Future<void> _createProject() async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新規案件'),
        content: H1TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '案件名',
            hintText: '例: ○○株式会社 HPリニューアル',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, nameController.text.trim());
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _repo.createProject(
        name: result,
        customerId: '',
        customerName: '',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('作成エラー: $e')),
      );
    }
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

  Color _statusColor(ProjectStatus status, ColorScheme cs) {
    switch (status) {
      case ProjectStatus.active: return cs.tertiary;
      case ProjectStatus.won: return cs.primary;
      case ProjectStatus.lost: return cs.error;
      case ProjectStatus.suspended: return cs.secondary;
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

  Future<void> _changeStage(Project project, String stage) async {
    try {
      await _repo.updateStage(project.id, stage);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ステージ変更エラー: $e')),
      );
    }
  }

  void _showStageSheet(Project project) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('ステージ変更: ${project.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const Divider(),
            ..._stages.map((stage) => ListTile(
              leading: Icon(Icons.circle, size: 12, color: _stageColor(stage, Theme.of(context).colorScheme)),
              title: Text(stage),
              trailing: project.pipelineStage == stage ? const Icon(Icons.check, size: 18) : null,
              onTap: () {
                Navigator.pop(ctx);
                _changeStage(project, stage);
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showProjectMenu(Project project) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(project.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('ステージ変更'),
              onTap: () {
                Navigator.pop(ctx);
                _showStageSheet(project);
              },
            ),
            if (project.status == ProjectStatus.active) ...[
              ListTile(
                leading: Icon(Icons.cancel_outlined, color: cs.error),
                title: Text('失注にする', style: TextStyle(color: cs.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _markAsLost(project);
                },
              ),
            ],
            if (project.status == ProjectStatus.lost) ...[
              ListTile(
                leading: Icon(Icons.refresh, color: cs.primary),
                title: Text('再開', style: TextStyle(color: cs.primary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _reactivateProject(project);
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.delete, color: cs.error),
              title: Text('削除', style: TextStyle(color: cs.error)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(project);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
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
    } else {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('失注確認'),
          content: const Text('この案件を失注としてマークします。よろしいですか？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('失注にする')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    try {
      final updated = project.copyWith(status: ProjectStatus.lost, endDate: DateTime.now());
      await _repo.save(updated);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('失注処理エラー: $e')),
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

  Future<void> _confirmDelete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${project.name}」を削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _repo.delete(project.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.selectionMode ? '案件を選択' : 'PJ1:案件一覧')),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _projects.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspaces, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('案件がありません',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('最初の案件を作成'),
                    onPressed: _createProject,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                _buildViewToggle(cs),
                Expanded(
                  child: _kanbanMode ? _buildKanbanView(cs) : _buildListView(cs),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildViewToggle(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('表示切替:', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(width: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.list), label: Text('リスト')),
              ButtonSegment(value: true, icon: Icon(Icons.view_column), label: Text('カンバン')),
            ],
            selected: {_kanbanMode},
            onSelectionChanged: (v) => setState(() => _kanbanMode = v.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(ColorScheme cs) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
        itemCount: _projects.length,
        onReorder: (oldI, newI) {
          setState(() {
            if (newI > oldI) newI--;
            final item = _projects.removeAt(oldI);
            _projects.insert(newI, item);
          });
          for (int i = 0; i < _projects.length; i++) {
            _repo.updateOrder(_projects[i].id, i);
          }
        },
        itemBuilder: (ctx, i) => Padding(
          key: ValueKey(_projects[i].id),
          padding: EdgeInsets.zero,
          child: _buildProjectCard(_projects[i], cs),
        ),
      ),
    );
  }

  Widget _buildKanbanView(ColorScheme cs) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _stages.map((stage) {
            final stageProjects = _projects.where((p) => p.pipelineStage == stage).toList();
            return _buildKanbanColumn(stage, stageProjects, cs);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(String stage, List<Project> projects, ColorScheme cs) {
    final color = _stageColor(stage, cs);
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        final project = _projects.firstWhere((p) => p.id == details.data);
        _changeStage(project, stage);
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          width: 240,
          margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
          decoration: BoxDecoration(
            color: isHovering ? color.withValues(alpha: 0.08) : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: isHovering ? Border.all(color: color, width: 2) : null,
            boxShadow: [
              BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 2)),
              BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(stage, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${projects.length}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: projects.isEmpty
                  ? Center(
                      child: Text('なし', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(6),
                      itemCount: projects.length,
                      itemBuilder: (ctx, i) => _buildKanbanCard(projects[i], cs),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanCard(Project project, ColorScheme cs) {
    return LongPressDraggable<String>(
      data: project.id,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 220,
          child: _buildKanbanCardContent(project, cs),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Text(project.name, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ),
      child: _buildKanbanCardContent(project, cs),
    );
  }

  Widget _buildKanbanCardContent(Project project, ColorScheme cs) {
    final isLost = project.status == ProjectStatus.lost;
    final isWon = project.status == ProjectStatus.won;
    final hasBar = project.startDate != null;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      clipBehavior: Clip.antiAlias,
      color: isLost ? (cs.brightness == Brightness.dark ? AppTheme.cardLostDark : AppTheme.cardLostLight) : null,
      child: Stack(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            onTap: widget.selectionMode
              ? () => Navigator.pop(context, project.id)
              : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(projectId: project.id),
                  ),
                ).then((_) => _load());
              },
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, 10, 36, hasBar ? 12 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(project.name,
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                          color: isLost ? cs.onSurfaceVariant : cs.onSurface)),
                    ),
                    if (isLost)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.cancel, size: 14, color: cs.error),
                      ),
                    if (isWon)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.check_circle, size: 14, color: cs.primary),
                      ),
                  ]),
                  if (project.customerName != null && project.customerName!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(project.customerName!,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _statusColor(project.status, cs).withValues(alpha: 0.15),
                        ),
                        child: Text(_statusLabel(project.status),
                          style: TextStyle(fontSize: 9, color: _statusColor(project.status, cs), fontWeight: FontWeight.w500)),
                      ),
                      const Spacer(),
                      Text('￥${_formatMoney(project.totalAmount)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 2, right: 2,
            child: SizedBox(
              width: 28, height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz, size: 16, color: cs.onSurfaceVariant),
                onPressed: () => _showProjectMenu(project),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          if (hasBar)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildTimeProgressBar(project, cs),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeProgressBar(Project project, ColorScheme cs) {
    final start = project.startDate;
    if (start == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final elapsedDays = now.difference(start).inDays;
    final overdue = project.isOverdue;
    final hasContract = project.contractMonths != null && project.contractMonths! > 0;
    final totalDays = hasContract && project.contractMonths != null
        ? project.contractMonths! * 30
        : 365;
    final progress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    final barColor = overdue ? cs.error : (progress >= 1.0 ? cs.secondary : cs.primary);
    return ClipRRect(
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: 2,
        backgroundColor: cs.brightness == Brightness.dark ? AppTheme.cardProgressBgDark : AppTheme.cardProgressBgLight,
        valueColor: AlwaysStoppedAnimation(barColor.withValues(alpha: 0.5)),
      ),
    );
  }

  Widget _buildProjectCard(Project project, ColorScheme cs) {
    final hasBar = project.startDate != null;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: widget.selectionMode
              ? () => Navigator.pop(context, project.id)
              : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(projectId: project.id),
                  ),
                ).then((_) => _load());
              },
            onLongPress: () => _showProjectMenu(project),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, hasBar ? 18 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(project.name,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _statusColor(project.status, cs).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_statusLabel(project.status),
                          style: TextStyle(fontSize: 11, color: _statusColor(project.status, cs), fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  if (project.customerName != null && project.customerName!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      Icon(Icons.business, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(project.customerName!,
                        style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                    ]),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _stageColor(project.pipelineStage, cs).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(project.pipelineStage,
                          style: TextStyle(fontSize: 12, color: _stageColor(project.pipelineStage, cs), fontWeight: FontWeight.w500)),
                      ),
                      const Spacer(),
                      Text('￥${_formatMoney(project.totalAmount)}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (hasBar)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildTimeProgressBar(project, cs),
            ),
        ],
      ),
    );
  }

  String _formatMoney(int amount) =>
    amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
