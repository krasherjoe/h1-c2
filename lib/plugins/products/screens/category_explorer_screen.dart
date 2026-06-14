import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../services/product_category_repository.dart';
import '../../../models/product_category_model.dart';
import '../logic/category_tree_utils.dart';

class CategoryExplorerScreen extends StatefulWidget {
  const CategoryExplorerScreen({super.key});
  @override
  State<CategoryExplorerScreen> createState() => _CategoryExplorerScreenState();
}

class _CategoryExplorerScreenState extends State<CategoryExplorerScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ProductCategoryRepository();
  List<ProductCategory> _all = [];
  bool _loading = true;
  String? _currentParentId; // 現在地。null=ルート
  bool _editMode = false;
  late final AnimationController _wiggle;

  @override
  void initState() {
    super.initState();
    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _load();
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await _repo.getAll();
    if (!mounted) return;
    setState(() {
      _all = all;
      _loading = false;
      if (_currentParentId != null && !_all.any((c) => c.id == _currentParentId)) {
        _currentParentId = null;
      }
    });
  }

  // 移動後の軽量リロード(_loading を立てずちらつきを防ぐ。編集モードは維持)
  Future<void> _reloadKeepingState() async {
    final all = await _repo.getAll();
    if (!mounted) return;
    setState(() {
      _all = all;
      if (_currentParentId != null && !_all.any((c) => c.id == _currentParentId)) {
        _currentParentId = null;
      }
    });
  }

  Map<String, ProductCategory> _indexById() {
    final m = <String, ProductCategory>{};
    for (final c in _all) {
      m[c.id] = c;
    }
    return m;
  }

  Map<String, String?> _parentOf() {
    final m = <String, String?>{};
    for (final c in _all) {
      m[c.id] = c.parentId;
    }
    return m;
  }

  List<ProductCategory> get _currentChildren =>
      _all.where((c) => c.parentId == _currentParentId).toList();

  String? _upParentId() => _indexById()[_currentParentId]?.parentId;

  List<ProductCategory> _breadcrumbChain() {
    final byId = _indexById();
    final chain = <ProductCategory>[];
    final visited = <String>{};
    String? cur = _currentParentId;
    while (cur != null) {
      final c = byId[cur];
      if (c == null) break;
      if (!visited.add(cur)) break;
      chain.add(c);
      cur = c.parentId;
    }
    return chain.reversed.toList();
  }

  void _enter(ProductCategory c) {
    setState(() => _currentParentId = c.id);
  }

  void _goUp() {
    setState(() => _currentParentId = _upParentId());
  }

  void _jumpTo(String? parentId) {
    setState(() => _currentParentId = parentId);
  }

  void _enterEditMode() {
    if (_editMode) return;
    setState(() => _editMode = true);
    _wiggle.repeat();
  }

  void _exitEditMode() {
    if (!_editMode) return;
    setState(() => _editMode = false);
    _wiggle.stop();
    _wiggle.value = 0;
  }

  // 【層1 + no-op】ドロップ可否(視覚フィードバックにも使用)
  bool _canDrop(ProductCategory moving, String? newParentId) {
    if (moving.parentId == newParentId) return false; // no-op
    if (wouldCreateCycle(
          movingId: moving.id,
          newParentId: newParentId,
          parentOf: _parentOf(),
        )) {
      return false; // 自分自身/子孫への移動は拒否
    }
    return true;
  }

  // 【層2/3/4】実行(保存直前に再チェック)
  Future<void> _move(ProductCategory moving, String? newParentId) async {
    if (moving.parentId == newParentId) return; // 層4: no-op
    if (wouldCreateCycle(
          movingId: moving.id,
          newParentId: newParentId,
          parentOf: _parentOf(),
        )) {
      return; // 層2/3: 念のため拒否
    }
    await _repo.moveNode(moving.id, newParentId);
    await _reloadKeepingState();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildBreadcrumb(),
        const Divider(height: 1),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _editMode ? _exitEditMode : null, // 空白タップで解除
            child: _buildGrid(),
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    final chain = _breadcrumbChain();
    final items = <Widget>[
      _crumb('ルート', () => _jumpTo(null), isLast: chain.isEmpty),
    ];
    for (var i = 0; i < chain.length; i++) {
      items.add(const Icon(Icons.chevron_right, size: 18, color: Colors.grey));
      final c = chain[i];
      items.add(_crumb(c.name, () => _jumpTo(c.id), isLast: i == chain.length - 1));
    }
    return Row(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: items),
            ),
          ),
        ),
        if (_editMode)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(onPressed: _exitEditMode, child: const Text('完了')),
          ),
      ],
    );
  }

  Widget _crumb(String label, VoidCallback onTap, {required bool isLast}) {
    return InkWell(
      onTap: isLast ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
            color: isLast ? null : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final children = _currentChildren;
    final showUp = _currentParentId != null;
    final itemCount = children.length + (showUp ? 1 : 0);

    if (itemCount == 0) {
      return const Center(child: Text('カテゴリがありません'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showUp && index == 0) {
          return _editMode ? _buildUpDropTarget() : _UpCell(onTap: _goUp);
        }
        final i = index - (showUp ? 1 : 0);
        final c = children[i];
        final cell = _Wiggle(
          animation: _wiggle,
          enabled: _editMode,
          phase: i.isEven ? 0.0 : math.pi,
          child: _FolderCell(
            category: c,
            onTap: () => _enter(c),
            onLongPress: _enterEditMode,
          ),
        );
        if (!_editMode) return cell;
        return _buildFolderDropDrag(c, cell);
      },
    );
  }

  // フォルダ: ドロップ先(DragTarget) かつ ドラッグ元(Draggable)
  Widget _buildFolderDropDrag(ProductCategory c, Widget cell) {
    return DragTarget<ProductCategory>(
      onWillAcceptWithDetails: (d) => _canDrop(d.data, c.id),
      onAcceptWithDetails: (d) {
        _move(d.data, c.id);
      },
      builder: (context, candidate, rejected) {
        return _dropHighlight(
          active: candidate.isNotEmpty,
          child: Draggable<ProductCategory>(
            data: c,
            feedback: _dragFeedback(c.name),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _FolderCell(category: c, onTap: () {}, onLongPress: () {}),
            ),
            child: cell,
          ),
        );
      },
    );
  }

  // 「..」: ドロップ先のみ(親階層へ戻す)
  Widget _buildUpDropTarget() {
    final up = _upParentId();
    return DragTarget<ProductCategory>(
      onWillAcceptWithDetails: (d) => _canDrop(d.data, up),
      onAcceptWithDetails: (d) {
        _move(d.data, up);
      },
      builder: (context, candidate, rejected) {
        return _dropHighlight(
          active: candidate.isNotEmpty,
          child: _UpCell(onTap: _goUp),
        );
      },
    );
  }

  Widget _dropHighlight({required bool active, required Widget child}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: active ? Theme.of(context).colorScheme.primary : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _dragFeedback(String name) {
    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.9,
        child: SizedBox(
          width: 96,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.folder, size: 56, color: Color(0xFFFFCA28)),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wiggle extends StatelessWidget {
  final Animation<double> animation; // 0..1 を繰り返す
  final bool enabled;
  final double phase;
  final Widget child;
  const _Wiggle({
    required this.animation,
    required this.enabled,
    required this.phase,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final angle = math.sin(animation.value * math.pi * 2 + phase) * 0.045; // ±約2.6度
        return Transform.rotate(angle: angle, child: child);
      },
    );
  }
}

class _UpCell extends StatelessWidget {
  final VoidCallback onTap;
  const _UpCell({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const <Widget>[
          Icon(Icons.drive_folder_upload, size: 56, color: Colors.blueGrey),
          SizedBox(height: 8),
          Text('..', style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

class _FolderCell extends StatelessWidget {
  final ProductCategory category;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _FolderCell({
    required this.category,
    required this.onTap,
    required this.onLongPress,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.folder, size: 56, color: Color(0xFFFFCA28)),
          const SizedBox(height: 8),
          Text(
            category.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
