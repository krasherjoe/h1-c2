import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../../../models/product_category_model.dart';
import '../../../services/product_category_repository.dart';
import '../../../services/database_helper.dart';
import '../../../widgets/h1_text_field.dart';

abstract class CategoryCommand {
  Future<void> execute(Database db);
  Future<void> undo(Database db);
  String get description;
}

class CreateCategoryCommand implements CategoryCommand {
  final ProductCategory category;

  CreateCategoryCommand(this.category);

  @override
  Future<void> execute(Database db) async {
    await db.insert('product_categories', category.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> undo(Database db) async {
    await db.delete('product_categories',
        where: 'id = ?', whereArgs: [category.id]);
  }

  @override
  String get description => '作成';
}

class RenameCategoryCommand implements CategoryCommand {
  final String nodeId;
  final String oldName;
  final String newName;

  RenameCategoryCommand(this.nodeId, this.oldName, this.newName);

  @override
  Future<void> execute(Database db) async {
    await db.update(
      'product_categories',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  Future<void> undo(Database db) async {
    await db.update(
      'product_categories',
      {'name': oldName},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  String get description => '名前変更';
}

class MoveCategoryCommand implements CategoryCommand {
  final String nodeId;
  final String? oldParentId;
  final String? newParentId;

  MoveCategoryCommand(this.nodeId, this.oldParentId, this.newParentId);

  @override
  Future<void> execute(Database db) async {
    await db.update(
      'product_categories',
      {'parent_id': newParentId},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  Future<void> undo(Database db) async {
    await db.update(
      'product_categories',
      {'parent_id': oldParentId},
      where: 'id = ?',
      whereArgs: [nodeId],
    );
  }

  @override
  String get description => '移動';
}

class DeleteCategoryCommand implements CategoryCommand {
  final ProductCategory node;
  final List<ProductCategory> children;

  DeleteCategoryCommand(this.node, this.children);

  @override
  Future<void> execute(Database db) async {
    await db.update(
      'product_categories',
      {'parent_id': node.parentId},
      where: 'parent_id = ?',
      whereArgs: [node.id],
    );
    await db.delete('product_categories',
        where: 'id = ?', whereArgs: [node.id]);
  }

  @override
  Future<void> undo(Database db) async {
    await db.insert('product_categories', node.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    for (final child in children) {
      final restored = child.copyWith(parentId: node.id);
      await db.insert('product_categories', restored.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  @override
  String get description => '削除';
}

class CategoryUndoStack {
  final List<CategoryCommand> _history = [];
  final List<CategoryCommand> _redoStack = [];
  static const maxHistory = 50;

  void push(CategoryCommand cmd) {
    _history.add(cmd);
    if (_history.length > maxHistory) _history.removeAt(0);
    _redoStack.clear();
  }

  Future<void> undo(Database db) async {
    if (_history.isEmpty) return;
    final cmd = _history.removeLast();
    await cmd.undo(db);
    _redoStack.add(cmd);
  }

  Future<void> redo(Database db) async {
    if (_redoStack.isEmpty) return;
    final cmd = _redoStack.removeLast();
    await cmd.execute(db);
    _history.add(cmd);
  }

  bool get canUndo => _history.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
  int get undoCount => _history.length;
  int get redoCount => _redoStack.length;
  String get lastDescription =>
      _history.isNotEmpty ? _history.last.description : '';
}

class CategoryExplorerScreen extends StatefulWidget {
  const CategoryExplorerScreen({super.key});

  @override
  State<CategoryExplorerScreen> createState() => _CategoryExplorerScreenState();
}

class _CategoryExplorerScreenState extends State<CategoryExplorerScreen> {
  final _repo = ProductCategoryRepository();
  final _undoStack = CategoryUndoStack();
  final _scrollController = ScrollController();

  List<ProductCategory> _rootNodes = [];
  final _childrenCache = <String, List<ProductCategory>>{};
  final _expanded = <String>{};
  final _selected = <String>{};
  String? _lastClickedId;
  bool _isLoading = true;
  Map<String, int> _productCounts = {};

  late Database _db;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _db = await DatabaseHelper().database;
    await _loadRoots();
    _productCounts = await _repo.getAllProductCounts();
    setState(() => _isLoading = false);
  }

  Future<void> _loadRoots() async {
    _rootNodes = await _repo.getRoots();
    _childrenCache.clear();
  }

  List<_FlatNode> _buildFlatList() {
    final result = <_FlatNode>[];
    for (final root in _rootNodes) {
      _addToFlatList(root, 0, result);
    }
    return result;
  }

  void _addToFlatList(
      ProductCategory node, int depth, List<_FlatNode> result) {
    result.add(_FlatNode(category: node, depth: depth));
    if (_expanded.contains(node.id)) {
      final children = _childrenCache[node.id];
      if (children != null) {
        for (final child in children) {
          _addToFlatList(child, depth + 1, result);
        }
      }
    }
  }

  Future<void> _toggleExpand(ProductCategory node) async {
    if (_expanded.contains(node.id)) {
      setState(() => _expanded.remove(node.id));
    } else {
      final children = await _repo.getChildren(node.id);
      setState(() {
        _childrenCache[node.id] = children;
        _expanded.add(node.id);
      });
    }
  }

  void _toggleSelect(String id, {bool shift = false, bool ctrl = false}) {
    setState(() {
      if (shift && _lastClickedId != null) {
        final flat = _buildFlatList();
        final idx1 = flat.indexWhere((n) => n.category.id == _lastClickedId);
        final idx2 = flat.indexWhere((n) => n.category.id == id);
        if (idx1 >= 0 && idx2 >= 0) {
          final start = idx1 < idx2 ? idx1 : idx2;
          final end = idx1 < idx2 ? idx2 : idx1;
          for (var i = start; i <= end; i++) {
            _selected.add(flat[i].category.id);
          }
          return;
        }
      }
      if (ctrl) {
        if (_selected.contains(id)) {
          _selected.remove(id);
        } else {
          _selected.add(id);
        }
      } else {
        _selected.clear();
        _selected.add(id);
      }
      _lastClickedId = id;
    });
  }

  Future<void> _onDrop(String targetId, String draggedId) async {
    final maps = await _db.query(
      'product_categories',
      where: 'id = ?',
      whereArgs: [draggedId],
      limit: 1,
    );
    if (maps.isEmpty) return;
    final oldParentId = maps.first['parent_id'] as String?;
    final command = MoveCategoryCommand(draggedId, oldParentId, targetId);
    await command.execute(_db);
    _undoStack.push(command);
    await _reload();
  }

  Future<void> _reload() async {
    await _loadRoots();
    _productCounts = await _repo.getAllProductCounts();
    if (mounted) setState(() {});
  }

  Future<void> _createCategory({String? parentId}) async {
    final name = await _showInputDialog('カテゴリ名', '');
    if (name == null || name.isEmpty) return;
    final cat = ProductCategory(
      id: const Uuid().v4(),
      name: name,
      parentId: parentId,
    );
    await _repo.save(cat);
    _undoStack.push(CreateCategoryCommand(cat));
    await _reload();
    if (parentId != null && mounted) {
      setState(() {
        _expanded.add(parentId);
        _childrenCache.remove(parentId);
      });
    }
  }

  Future<void> _renameCategory(ProductCategory cat) async {
    final name = await _showInputDialog('名前変更', cat.name);
    if (name == null || name.isEmpty || name == cat.name) return;
    final command = RenameCategoryCommand(cat.id, cat.name, name);
    await command.execute(_db);
    _undoStack.push(command);
    await _reload();
  }

  Future<void> _deleteCategory(ProductCategory cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text(
            '「${cat.name}」を削除しますか？\n子カテゴリは1階層上に移動されます。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('削除')),
        ],
      ),
    );
    if (confirm != true) return;
    final children = await _repo.getChildren(cat.id);
    final command = DeleteCategoryCommand(cat, children);
    await command.execute(_db);
    _undoStack.push(command);
    _selected.remove(cat.id);
    await _reload();
  }

  Future<String?> _showInputDialog(
    String title,
    String initial, {
    TextInputType? keyboardType,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: H1TextField(
          controller: controller,
          decoration: const InputDecoration(),
          keyboardType: keyboardType,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('OK')),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _undo() async {
    await _undoStack.undo(_db);
    await _reload();
  }

  Future<void> _redo() async {
    await _undoStack.redo(_db);
    await _reload();
  }

  Future<void> _showContextMenu(
      ProductCategory cat, Offset position) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & MediaQuery.of(context).size,
      ),
      items: [
        const PopupMenuItem(value: 'add', child: Text('新規サブカテゴリ追加')),
        const PopupMenuItem(value: 'rename', child: Text('名前変更')),
        const PopupMenuItem(value: 'delete', child: Text('削除')),
      ],
    );
    if (result == null || !mounted) return;
    switch (result) {
      case 'add':
        await _createCategory(parentId: cat.id);
      case 'rename':
        await _renameCategory(cat);
      case 'delete':
        await _deleteCategory(cat);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('CE:商品カテゴリ'),
        actions: [
          if (_undoStack.canUndo)
            Badge(
              label: Text('${_undoStack.undoCount}'),
              child: IconButton(
                icon: const Icon(Icons.undo),
                tooltip: '元に戻す: ${_undoStack.lastDescription}',
                onPressed: _undo,
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.undo,
                  color: cs.onSurface.withValues(alpha: 0.3)),
              onPressed: null,
            ),
          IconButton(
            icon: Icon(Icons.redo,
                color: _undoStack.canRedo
                    ? null
                    : cs.onSurface.withValues(alpha: 0.3)),
            onPressed: _undoStack.canRedo ? _redo : null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        mini: true,
        tooltip: '新規ルートカテゴリ',
        onPressed: () => _createCategory(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rootNodes.isEmpty
              ? _buildEmptyState(cs)
              : _buildTreeView(cs),
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category,
              size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('カテゴリが空です',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add),
            label: const Text('ルートカテゴリを作成'),
            onPressed: () => _createCategory(),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeView(ColorScheme cs) {
    final flat = _buildFlatList();
    return ListView.builder(
      controller: _scrollController,
      itemCount: flat.length,
      itemBuilder: (ctx, i) {
        final fn = flat[i];
        return _CategoryTreeNodeWidget(
          category: fn.category,
          depth: fn.depth,
          isExpanded: _expanded.contains(fn.category.id),
          isSelected: _selected.contains(fn.category.id),
          productCount: _productCounts[fn.category.id] ?? 0,
          onTap: () => _toggleExpand(fn.category),
          onSelectToggle: () => _toggleSelect(fn.category.id),
          onShiftSelect: () =>
              _toggleSelect(fn.category.id, shift: true),
          onCtrlSelect: () =>
              _toggleSelect(fn.category.id, ctrl: true),
          onLongPress: (pos) => _showContextMenu(fn.category, pos),
          onExpandedToggle: () => _toggleExpand(fn.category),
          onAccept: (draggedId) => _onDrop(fn.category.id, draggedId),
        );
      },
    );
  }
}

class _FlatNode {
  final ProductCategory category;
  final int depth;
  _FlatNode({required this.category, required this.depth});
}

class _CategoryTreeNodeWidget extends StatefulWidget {
  final ProductCategory category;
  final int depth;
  final bool isExpanded;
  final bool isSelected;
  final int productCount;
  final VoidCallback onTap;
  final VoidCallback onSelectToggle;
  final VoidCallback onShiftSelect;
  final VoidCallback onCtrlSelect;
  final void Function(Offset) onLongPress;
  final VoidCallback onExpandedToggle;
  final void Function(String) onAccept;

  const _CategoryTreeNodeWidget({
    required this.category,
    required this.depth,
    required this.isExpanded,
    required this.isSelected,
    required this.productCount,
    required this.onTap,
    required this.onSelectToggle,
    required this.onShiftSelect,
    required this.onCtrlSelect,
    required this.onLongPress,
    required this.onExpandedToggle,
    required this.onAccept,
  });

  @override
  State<_CategoryTreeNodeWidget> createState() =>
      _CategoryTreeNodeWidgetState();
}

class _CategoryTreeNodeWidgetState extends State<_CategoryTreeNodeWidget> {
  bool _isDragHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cat = widget.category;

    final bgColor = widget.isSelected
        ? cs.secondaryContainer.withValues(alpha: 0.3)
        : _isDragHovering
            ? cs.tertiaryContainer.withValues(alpha: 0.3)
            : Colors.transparent;

    final rowContent = Container(
      height: 44,
      color: bgColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onExpandedToggle,
            child: Container(
              width: 32,
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                _expanded
                    ? Icons.expand_more
                    : Icons.chevron_right,
                size: 20,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onSelectToggle,
            child: SizedBox(
              width: 24,
              height: 44,
              child: Icon(
                widget.isSelected
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 18,
                color: widget.isSelected
                    ? cs.primary
                    : cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            _expanded
                ? Icons.folder_open
                : Icons.folder,
            size: 18,
            color: cs.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cat.name,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 13.5, color: cs.onSurface),
            ),
          ),
          if (widget.productCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.productCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final node = Padding(
      padding: EdgeInsets.only(left: 16.0 + widget.depth * 20.0),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: () {
          final renderBox = context.findRenderObject() as RenderBox;
          final pos = renderBox.localToGlobal(Offset.zero);
          widget.onLongPress(pos);
        },
        child: LongPressDraggable<String>(
          data: cat.id,
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(cat.name,
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: rowContent,
          ),
          child: rowContent,
        ),
      ),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (_) {
        setState(() => _isDragHovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _isDragHovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragHovering = false);
        widget.onAccept(details.data);
      },
      builder: (ctx, candidateData, rejectedData) => node,
    );
  }

  bool get _expanded => widget.isExpanded;
}
