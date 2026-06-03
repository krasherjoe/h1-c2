import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';
import '../../../services/database_helper.dart';
import '../../../services/customer_repository.dart';
import '../../../models/customer_model.dart';
import '../../../widgets/h1_text_field.dart';
import '../models/price_entry.dart';
import '../services/price_list_repository.dart';
import '../services/undo_stack.dart';
import '../../../services/sync_service.dart';

class PriceExplorerScreen extends StatefulWidget {
  final String? initialYear;
  final String? initialCustomerName;
  final bool Function(PriceEntry)? onSelect;
  final bool selectionMode;

  const PriceExplorerScreen({
    super.key,
    this.initialYear,
    this.initialCustomerName,
    this.onSelect,
    this.selectionMode = false,
  });

  @override
  State<PriceExplorerScreen> createState() => _PriceExplorerScreenState();
}

class _PriceExplorerScreenState extends State<PriceExplorerScreen> {
  final _repo = PriceListRepository();
  final _undoStack = UndoStack();
  final _scrollController = ScrollController();

  String? _currentYear;
  List<String> _years = [];
  List<PriceEntry> _rootNodes = [];
  final _childrenCache = <String, List<PriceEntry>>{};
  final _expanded = <String>{};
  final _selected = <String>{};
  String? _lastClickedId;
  bool _isLoading = true;
  PriceEntry? _highlightedNode;

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
    _years = await _repo.getYears();
    final year = widget.initialYear ?? (_years.isNotEmpty ? _years.first : DateTime.now().year.toString());
    _currentYear = year;
    await _loadRoots(year);
    if (widget.initialCustomerName != null && widget.initialCustomerName!.isNotEmpty) {
      await _autoExpandToCustomer(widget.initialCustomerName!);
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadRoots(String year) async {
    _rootNodes = await _repo.getRoots(year);
    _childrenCache.clear();
  }

  Future<void> _autoExpandToCustomer(String customerName) async {
    final matches = await _repo.searchByCustomer(_currentYear!, customerName);
    if (matches.isEmpty) return;
    final target = matches.first;
    final path = await _repo.getPath(target.id);
    setState(() {
      for (final node in path) {
        _expanded.add(node.id);
      }
      _highlightedNode = target;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToNode(target.id);
    });
  }

  void _scrollToNode(String id) {
    // find the index in the flattened list
    final flat = _buildFlatList();
    final index = flat.indexWhere((n) => n.entry.id == id);
    if (index >= 0 && _scrollController.hasClients) {
      _scrollController.animateTo(
        index * 48.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  List<_FlatNode> _buildFlatList() {
    final result = <_FlatNode>[];
    for (final root in _rootNodes) {
      _addToFlatList(root, 0, result);
    }
    return result;
  }

  void _addToFlatList(PriceEntry node, int depth, List<_FlatNode> result) {
    result.add(_FlatNode(entry: node, depth: depth));
    if (_expanded.contains(node.id)) {
      final children = _childrenCache[node.id];
      if (children != null) {
        for (final child in children) {
          _addToFlatList(child, depth + 1, result);
        }
      }
    }
  }

  Future<void> _toggleExpand(PriceEntry node) async {
    if (!node.isFolder) return;
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
        final idx1 = flat.indexWhere((n) => n.entry.id == _lastClickedId);
        final idx2 = flat.indexWhere((n) => n.entry.id == id);
        if (idx1 >= 0 && idx2 >= 0) {
          final start = idx1 < idx2 ? idx1 : idx2;
          final end = idx1 < idx2 ? idx2 : idx1;
          for (var i = start; i <= end; i++) {
            _selected.add(flat[i].entry.id);
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

  Future<void> _onDrop(String targetFolderId, String draggedId) async {
    final maps = await _db.query(
      'price_entries',
      where: 'id = ?',
      whereArgs: [draggedId],
      limit: 1,
    );
    if (maps.isEmpty) return;
    final oldParentId = maps.first['parent_id'] as String?;
    final command = MoveNodeCommand(draggedId, oldParentId, targetFolderId);
    await command.execute(_db);
    _undoStack.push(command);
    await _reload();
  }

  Future<void> _reload() async {
    if (_currentYear == null) return;
    await _loadRoots(_currentYear!);
    if (mounted) setState(() {});
  }

  Future<void> _createFolder({String? parentId}) async {
    final name = await _showInputDialog('フォルダ名', '');
    if (name == null || name.isEmpty) return;
    final now = DateTime.now();
    final entry = PriceEntry(
      id: const Uuid().v4(),
      year: _currentYear!,
      parentId: parentId,
      name: name,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.save(entry);
    SyncService.pushChange(
      entityType: 'price_entry',
      entityId: entry.id,
      action: 'create_folder',
      data: entry.toMap(),
    );
    _undoStack.push(CreateNodeCommand(entry));
    await _reload();
    if (parentId != null && mounted) {
      setState(() {
        _expanded.add(parentId);
        _childrenCache.remove(parentId);
      });
    }
  }

  Future<void> _createCustomerFolder({String? parentId}) async {
    final customers = await CustomerRepository().searchCustomers('');
    if (!mounted) return;
    final customer = await showDialog<Customer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('納入先を選択'),
        content: SizedBox(
          width: double.maxFinite,
          child: customers.isEmpty
            ? const Center(child: Text('顧客が登録されていません'))
            : ListView.builder(
                itemCount: customers.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(customers[i].displayName),
                  onTap: () => Navigator.pop(ctx, customers[i]),
                ),
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル'))],
      ),
    );
    if (customer == null) return;
    final now = DateTime.now();
    final entry = PriceEntry(
      id: const Uuid().v4(),
      year: _currentYear!,
      parentId: parentId,
      name: customer.displayName,
      customerId: customer.id,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.save(entry);
    SyncService.pushChange(
      entityType: 'price_entry',
      entityId: entry.id,
      action: 'create_customer_folder',
      data: entry.toMap(),
    );
    await _reload();
    if (parentId != null && mounted) {
      setState(() {
        _expanded.add(parentId);
        _childrenCache.remove(parentId);
      });
    }
  }

  Future<void> _createPriceEntry({String? parentId}) async {
    final name = await _showInputDialog('商品名', '');
    if (name == null || name.isEmpty) return;
    final priceStr = await _showInputDialog('単価', '0', keyboardType: TextInputType.number);
    if (priceStr == null) return;
    final price = int.tryParse(priceStr) ?? 0;
    final now = DateTime.now();
    final entry = PriceEntry(
      id: const Uuid().v4(),
      year: _currentYear!,
      parentId: parentId,
      name: name,
      unitPrice: price,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.save(entry);
    SyncService.pushChange(
      entityType: 'price_entry',
      entityId: entry.id,
      action: 'create',
      data: entry.toMap(),
    );
    _undoStack.push(CreateNodeCommand(entry));
    await _reload();
    if (parentId != null && mounted) {
      setState(() {
        _expanded.add(parentId);
        _childrenCache.remove(parentId);
      });
    }
  }

  Future<void> _renameNode(PriceEntry node) async {
    final name = await _showInputDialog('名前変更', node.name);
    if (name == null || name.isEmpty || name == node.name) return;
    final command = RenameNodeCommand(node.id, node.name, name);
    await command.execute(_db);
    SyncService.pushChange(
      entityType: 'price_entry',
      entityId: node.id,
      action: 'rename',
      data: node.toMap(),
    );
    _undoStack.push(command);
    await _reload();
  }

  Future<void> _editPrice(PriceEntry node) async {
    if (node.isFolder) return;
    final priceStr = await _showInputDialog(
      '価格変更',
      node.unitPrice.toString(),
      keyboardType: TextInputType.number,
    );
    if (priceStr == null) return;
    final newPrice = int.tryParse(priceStr);
    if (newPrice == null || newPrice == node.unitPrice) return;
    final command = EditPriceCommand(node.id, node.unitPrice, newPrice);
    await command.execute(_db);
    SyncService.pushChange(
      entityType: 'price_entry',
      entityId: node.id,
      action: 'edit_price',
      data: node.toMap(),
    );
    _undoStack.push(command);
    await _reload();
  }

  Future<void> _deleteNode(PriceEntry node) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${node.name}」を削除しますか？\n子階層も全て削除されます。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('削除')),
        ],
      ),
    );
    if (confirm != true) return;
    final children = await _getAllDescendants(node.id);
    final command = DeleteNodeCommand(node, children);
    await command.execute(_db);
    SyncService.pushChange(
      entityType: 'price_entry',
      entityId: node.id,
      action: 'delete',
      data: node.toMap(),
    );
    _undoStack.push(command);
    _selected.remove(node.id);
    await _reload();
  }

  Future<List<PriceEntry>> _getAllDescendants(String id) async {
    final result = <PriceEntry>[];
    final children = await _repo.getChildren(id);
    for (final child in children) {
      result.add(child);
      final grand = await _getAllDescendants(child.id);
      result.addAll(grand);
    }
    return result;
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
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

  Future<void> _showContextMenu(PriceEntry node, Offset position) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & MediaQuery.of(context).size,
      ),
      items: [
        const PopupMenuItem(value: 'add_folder', child: Text('新規サブフォルダ追加')),
        const PopupMenuItem(value: 'add_price', child: Text('新規価格追加')),
        const PopupMenuItem(value: 'rename', child: Text('名前変更')),
        if (!node.isFolder) const PopupMenuItem(value: 'edit_price', child: Text('価格変更')),
        const PopupMenuItem(value: 'copy', child: Text('コピー')),
        const PopupMenuItem(value: 'cut', child: Text('切り取り')),
        const PopupMenuItem(value: 'paste', child: Text('貼り付け')),
        const PopupMenuItem(value: 'delete', child: Text('削除')),
      ],
    );
    if (result == null || !mounted) return;
    switch (result) {
      case 'add_folder':
        await _createFolder(parentId: node.id);
      case 'add_price':
        await _createPriceEntry(parentId: node.id);
      case 'rename':
        await _renameNode(node);
      case 'edit_price':
        await _editPrice(node);
      case 'copy':
        await _copyNode(node);
      case 'cut':
        await _cutNode(node);
      case 'paste':
        await _pasteNode(node);
      case 'delete':
        await _deleteNode(node);
    }
  }

  String? _clipboardNodeId;
  bool _clipboardIsCut = false;

  Future<void> _copyNode(PriceEntry node) async {
    _clipboardNodeId = node.id;
    _clipboardIsCut = false;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('コピーしました'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _cutNode(PriceEntry node) async {
    _clipboardNodeId = node.id;
    _clipboardIsCut = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('切り取りました'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _pasteNode(PriceEntry target) async {
    if (_clipboardNodeId == null) return;
    if (_clipboardIsCut) {
      final command = MoveNodeCommand(_clipboardNodeId!, null, target.id);
      await command.execute(_db);
      _undoStack.push(command);
      _clipboardNodeId = null;
    } else {
      final created = await _repo.copySubtree(_clipboardNodeId!, target.id);
      _undoStack.push(CopyNodeCommand(_clipboardNodeId!, target.id, created.map((e) => e.id).toList()));
    }
    await _reload();
    if (mounted) {
      setState(() => _expanded.add(target.id));
    }
  }

  Future<void> _bulkMove() async {
    if (_selected.length < 2) return;
    final targetId = await _showTargetPicker();
    if (targetId == null) return;
    for (final id in _selected.toList()) {
      final command = MoveNodeCommand(id, null, targetId);
      await command.execute(_db);
      _undoStack.push(command);
    }
    _selected.clear();
    await _reload();
  }

  Future<void> _bulkCopy() async {
    if (_selected.length < 2) return;
    final targetId = await _showTargetPicker();
    if (targetId == null) return;
    for (final id in _selected.toList()) {
      final created = await _repo.copySubtree(id, targetId);
      _undoStack.push(CopyNodeCommand(id, targetId, created.map((e) => e.id).toList()));
    }
    _selected.clear();
    await _reload();
  }

  Future<String?> _showTargetPicker() async {
    final flat = _buildFlatList();
    final folders = flat.where((n) => n.entry.isFolder).toList();
    if (folders.isEmpty) return null;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('移動先を選択'),
        children: folders.map((n) {
          final indent = '  ' * n.depth;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, n.entry.id),
            child: Text('$indent${n.entry.name}'),
          );
        }).toList(),
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        surfaceTintColor: cs.surfaceTint,
        scrolledUnderElevation: 1,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PE:価格表', style: TextStyle(color: cs.onPrimary)),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentYear,
                isDense: true,
                dropdownColor: cs.surfaceContainerHigh,
                style: TextStyle(fontSize: 14, color: cs.onPrimary),
                icon: Icon(Icons.arrow_drop_down, color: cs.onPrimary.withValues(alpha: 0.7)),
                onChanged: _years.isEmpty
                    ? null
                    : (v) async {
                        if (v == null) return;
                        setState(() {
                          _currentYear = v;
                          _expanded.clear();
                          _selected.clear();
                          _childrenCache.clear();
                          _highlightedNode = null;
                        });
                        await _loadRoots(v);
                        if (mounted) setState(() {});
                      },
                items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              ),
            ),
            if (_currentYear == null)
              IconButton(
                icon: Icon(Icons.add, size: 18, color: cs.onPrimary.withValues(alpha: 0.7)),
                tooltip: '年度追加',
                onPressed: _addYear,
              ),
          ],
        ),
        actions: [
          if (_undoStack.canUndo)
            Badge(
              label: Text('${_undoStack.undoCount}'),
              child: IconButton(
                icon: Icon(Icons.undo, color: cs.onPrimary),
                tooltip: '元に戻す: ${_undoStack.lastDescription}',
                onPressed: _undo,
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.undo, color: cs.onPrimary.withValues(alpha: 0.3)),
              onPressed: null,
            ),
          IconButton(
            icon: Icon(Icons.redo,
                color: _undoStack.canRedo ? cs.onPrimary : cs.onPrimary.withValues(alpha: 0.3)),
            onPressed: _undoStack.canRedo ? _redo : null,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rootNodes.isEmpty
              ? _buildEmptyState(cs)
              : _buildTreeView(cs),
      bottomNavigationBar: _buildBottomBar(cs),
    );
  }

  Future<void> _addYear() async {
    final year = await _showInputDialog('新しい年度', (_currentYear ?? DateTime.now().year.toString()));
    if (year == null || year.isEmpty) return;
    setState(() {
      _currentYear = year;
      if (!_years.contains(year)) _years.add(year);
      _years.sort((a, b) => b.compareTo(a));
      _rootNodes = [];
      _expanded.clear();
      _selected.clear();
    });
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('価格表が空です', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.create_new_folder),
            label: const Text('ルートフォルダを作成'),
            onPressed: () => _createFolder(),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.add),
            label: const Text('価格を追加'),
            onPressed: () => _createPriceEntry(),
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
        return _TreeNodeWidget(
          entry: fn.entry,
          depth: fn.depth,
          isExpanded: _expanded.contains(fn.entry.id),
          isSelected: _selected.contains(fn.entry.id),
          isHighlighted: _highlightedNode?.id == fn.entry.id,
          isLastChild: false,
                      onTap: () {
            if (!fn.entry.isFolder && widget.selectionMode) {
              widget.onSelect?.call(fn.entry);
              Navigator.pop(context, fn.entry);
            } else {
              _toggleExpand(fn.entry);
            }
          },
          onSelectToggle: () => _toggleSelect(fn.entry.id),
          onShiftSelect: () => _toggleSelect(fn.entry.id, shift: true),
          onCtrlSelect: () => _toggleSelect(fn.entry.id, ctrl: true),
          onLongPress: (pos) => _showContextMenu(fn.entry, pos),
          onExpandedToggle: () => _toggleExpand(fn.entry),
          onAccept: (draggedId) => _onDrop(fn.entry.id, draggedId),
        );
      },
    );
  }

  Widget _buildBottomBar(ColorScheme cs) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              tooltip: '新規フォルダ',
              onPressed: () => _createFolder(),
            ),
            IconButton(
              icon: const Icon(Icons.business),
              tooltip: '納入先フォルダ',
              onPressed: () => _createCustomerFolder(),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '新規商品',
              onPressed: () => _createPriceEntry(),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '削除',
              onPressed: _selected.length == 1
                  ? () async {
                      final flat = _buildFlatList();
                      final node = flat.where((n) => n.entry.id == _selected.first).firstOrNull;
                      if (node != null) await _deleteNode(node.entry);
                    }
                  : null,
            ),
            const Spacer(),
            if (_selected.isNotEmpty)
              Text('${_selected.length}件選択',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            if (_selected.length >= 2) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.drive_file_move, size: 16),
                label: const Text('移動', style: TextStyle(fontSize: 12)),
                onPressed: _bulkMove,
              ),
              TextButton.icon(
                icon: const Icon(Icons.content_copy, size: 16),
                label: const Text('コピー', style: TextStyle(fontSize: 12)),
                onPressed: _bulkCopy,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FlatNode {
  final PriceEntry entry;
  final int depth;
  _FlatNode({required this.entry, required this.depth});
}

class _TreeNodeWidget extends StatefulWidget {
  final PriceEntry entry;
  final int depth;
  final bool isExpanded;
  final bool isSelected;
  final bool isHighlighted;
  final bool isLastChild;
  final VoidCallback onTap;
  final VoidCallback onSelectToggle;
  final VoidCallback onShiftSelect;
  final VoidCallback onCtrlSelect;
  final void Function(Offset) onLongPress;
  final VoidCallback onExpandedToggle;
  final void Function(String) onAccept;

  const _TreeNodeWidget({
    required this.entry,
    required this.depth,
    required this.isExpanded,
    required this.isSelected,
    required this.isHighlighted,
    required this.isLastChild,
    required this.onTap,
    required this.onSelectToggle,
    required this.onShiftSelect,
    required this.onCtrlSelect,
    required this.onLongPress,
    required this.onExpandedToggle,
    required this.onAccept,
  });

  @override
  State<_TreeNodeWidget> createState() => _TreeNodeWidgetState();
}

class _TreeNodeWidgetState extends State<_TreeNodeWidget> {
  bool _isDragHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = widget.entry;

    final bgColor = widget.isHighlighted
        ? cs.primaryContainer.withValues(alpha: 0.4)
        : widget.isSelected
            ? cs.secondaryContainer.withValues(alpha: 0.3)
            : _isDragHovering
                ? cs.tertiaryContainer.withValues(alpha: 0.3)
                : Colors.transparent;

    final node = Padding(
      padding: EdgeInsets.only(left: 16.0 + widget.depth * 20.0),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: () {
          final renderBox = context.findRenderObject() as RenderBox;
          final pos = renderBox.localToGlobal(Offset.zero);
          widget.onLongPress(pos);
        },
        child: Container(
          height: 44,
          color: bgColor,
          child: Row(
            children: [
              if (e.isFolder)
                GestureDetector(
                  onTap: widget.onExpandedToggle,
                  child: Container(
                    width: 32,
                    height: 44,
                    alignment: Alignment.center,
                    child: Icon(
                      widget.isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              else
                const SizedBox(width: 32),
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
                    color: widget.isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                e.isFolder
                    ? (widget.isExpanded ? Icons.folder_open : Icons.folder)
                    : Icons.article_outlined,
                size: 18,
                color: e.isFolder ? cs.tertiary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, color: cs.onSurface),
                ),
              ),
              if (!e.isFolder && e.unitPrice != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    '¥${_formatMoney(e.unitPrice!)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!e.isFolder) return node;

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

  String _formatMoney(int amount) =>
    amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
