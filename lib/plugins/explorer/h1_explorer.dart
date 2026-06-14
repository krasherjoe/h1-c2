import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'h1_explorer_config.dart';
import 'h1_explorer_item.dart';
import '../../widgets/h1_text_field.dart';
import '../../services/error_reporter.dart';
import '../../services/database_helper.dart';
import '../../services/mm_command_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class H1Explorer<T extends H1ExplorerItem> extends StatefulWidget {
  final H1ExplorerConfig<T> config;
  final bool selectionMode;
  final Widget? appBarTitle;

  const H1Explorer({
    super.key,
    required this.config,
    this.selectionMode = false,
    this.appBarTitle,
  });

  @override
  State<H1Explorer<T>> createState() => _H1ExplorerState<T>();
}

class _H1ExplorerState<T extends H1ExplorerItem> extends State<H1Explorer<T>> {
  final _searchController = TextEditingController();
  List<T> _items = [];
  bool _isLoading = true;
  int? _dbSize;
  int _lastLogCount = -1;
  String _query = '';
  bool _showSearch = false;


  bool _showFilter = false;
  String _statusFilter = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _treeMode = false;
  int _displaySize = 1; // 0=S, 1=M, 2=L
  final Set<String> _expandedFolders = {};
  final _diagnosticKey = GlobalKey();
  List<TreeFolder> _folders = [];
  List<TreeFolder> _breadcrumbs = [];

  bool get _hasActiveFilters =>
      _statusFilter.isNotEmpty || _dateFrom != null || _dateTo != null ||
      widget.config.typeFilter.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _treeMode = widget.config.defaultTreeView;
    _showSearch = widget.config.showSearch;
    _loadDisplaySize();
    widget.config.onListChanged = _loadItems;
    _loadItems();
  }

  Future<void> _loadDisplaySize() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _displaySize = prefs.getInt('explorer_display_size') ?? 1);
  }

  void _cycleDisplaySize() async {
    _displaySize = (_displaySize + 1) % 3;
    setState(() {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('explorer_display_size', _displaySize);
  }

  @override
  void dispose() {
    widget.config.onListChanged = null;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    widget.config.statusFilter = _statusFilter;
    widget.config.dateFrom = _dateFrom;
    widget.config.dateTo = _dateTo;
    setState(() => _isLoading = true);
    try {
      if (_treeMode && widget.config.supportsTreeView) {
        final folders = await widget.config.getSubfolders(widget.config.currentFolderId);
        final items = widget.config.currentFolderId != null
            ? await widget.config.fetchFolderItems(widget.config.currentFolderId!, _query)
            : await widget.config.fetchItems(_query);
        final crumbs = await widget.config.getBreadcrumbs(widget.config.currentFolderId);
        if (!mounted) return;
        setState(() {
          _folders = folders;
          _items = items;
          _breadcrumbs = crumbs;
          _isLoading = false;
        });
      } else {
        final items = await widget.config.fetchItems(_query);
        if (!mounted) return;
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
      _updateDbSize();
    } catch (e, st) {
      ErrorReporter.sendError(message: '[H1Explorer] _loadItems: $e', stackTrace: st);
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _query = value;
    _loadItems();
  }

  void _clearFilters() {
    setState(() {
      widget.config.typeFilter = '';
      _statusFilter = '';
      _dateFrom = null;
      _dateTo = null;
    });
    _loadItems();
  }

  void _openViewer(T item) {
    Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => _H1ExplorerViewerScreen<T>(
          config: widget.config,
          item: item,
        ),
      ),
    ).then((changed) {
      if (changed == true && mounted) _loadItems();
    });
  }

  Future<void> _openEditor(T? item) async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => widget.config.buildEditor(context, item),
      ),
    );
    if (result != null && mounted) _loadItems();
  }

  Future<void> _confirmDelete(T item) async {
    final allowed = await widget.config.canDelete(item);
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この項目は削除できません')),
      );
      return;
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${item.title}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.config.deleteItem(item);
      if (mounted) _loadItems();
    }
  }

  void _onItemTap(T item) {
    if (widget.selectionMode) {
      Navigator.pop(context, item);
    } else {
      _openViewer(item);
    }
  }

  void _navigateToFolder(String? folderId) {
    setState(() {
      widget.config.currentFolderId = folderId;
    });
    _loadItems();
  }

  Map<String, List<T>> _groupItems() {
    final grouped = <String, List<T>>{};
    for (final item in _items) {
      final key = widget.config.groupKey(item) ?? '';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  Future<void> _updateDbSize() async {
    try {
      final db = await DatabaseHelper().database;
      final file = File(db.path);
      _dbSize = await file.length();
      if (_items.length != _lastLogCount) {
        _lastLogCount = _items.length;
      }
      if (mounted) setState(() {});
    } catch (_) {
      _dbSize = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSort = widget.config.sortOptions.isNotEmpty;
    final overflowActions = widget.config.overflowActions;
    return Scaffold(
      appBar: AppBar(
        title: widget.appBarTitle ?? Text(widget.config.explorerTitle),
        centerTitle: true,
        leading: Navigator.of(context).canPop()
            ? const BackButton()
            : null,
        actions: [
          if (hasSort)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: '並び替え',
              initialValue: widget.config.currentSortKey,
              onSelected: (key) {
                widget.config.onSortChanged(key);
                _loadItems();
              },
              itemBuilder: (_) => widget.config.sortOptions
                  .map((o) => PopupMenuItem(
                        value: o.key,
                        child: Text(o.label),
                      ))
                  .toList(),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'メニュー',
            onSelected: (id) {
              switch (id) {
                case '_filter':
                  setState(() => _showFilter = !_showFilter);
                  break;
                case '_tree':
                  setState(() {
                    _treeMode = !_treeMode;
                    if (_treeMode) widget.config.currentFolderId = null;
                  });
                  _loadItems();
                  break;
                case '_diagnostic':
                  _captureDiagnostic();
                  break;
                default:
                  widget.config.onOverflowAction(context, id, onListChanged: _loadItems);
              }
            },
            itemBuilder: (_) {
              final items = <PopupMenuItem<String>>[];
              items.add(PopupMenuItem<String>(
                value: '_filter',
                child: ListTile(
                  leading: Icon(_showFilter ? Icons.filter_list_off : Icons.filter_list),
                  title: Text(_showFilter ? 'フィルター解除' : 'フィルター'),
                  dense: true,
                ),
              ));
              if (widget.config.supportsTreeView) {
                items.add(PopupMenuItem<String>(
                  value: '_tree',
                  child: ListTile(
                    leading: Icon(_treeMode ? Icons.list : Icons.folder_open),
                    title: Text(_treeMode ? 'リスト表示' : 'ツリー表示'),
                    dense: true,
                  ),
                ));
              }
              if (_items.isNotEmpty || _dbSize != null) {
                items.add(PopupMenuItem<String>(
                  value: '_diagnostic',
                  child: ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: const Text('診断'),
                    dense: true,
                  ),
                ));
              }
              for (final a in overflowActions) {
                items.add(PopupMenuItem<String>(
                  value: a.id,
                  child: ListTile(
                    leading: Icon(a.icon),
                    title: Text(a.label),
                    dense: true,
                  ),
                ));
              }
              return items;
            },
          ),
          IconButton(
            icon: Icon(_displaySize == 0 ? Icons.view_list : _displaySize == 1 ? Icons.view_module : Icons.view_day,
                size: 20),
            tooltip: _displaySize == 0 ? 'S表示' : _displaySize == 1 ? 'M表示' : 'L表示',
            onPressed: _cycleDisplaySize,
          ),
        ],
      ),
      body: RepaintBoundary(
        key: _diagnosticKey,
        child: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: H1TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: widget.config.searchHint,
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                    prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                    suffixIcon: IconButton(
                      icon: Icon(_showFilter ? Icons.filter_list_off : Icons.filter_list, size: 20),
                      onPressed: () => setState(() => _showFilter = !_showFilter),
                      tooltip: _showFilter ? 'フィルターを隠す' : 'フィルターを表示',
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                onChanged: _onSearchChanged,
              ),
            ),
          if (_showFilter) _buildFilterBar(),
          if (_hasActiveFilters)
            _buildActiveFilters(),
          if (_treeMode && _breadcrumbs.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: _breadcrumbs.map((b) => Row(
                  children: [
                    if (_breadcrumbs.first != b)
                      Icon(Icons.chevron_right, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ActionChip(
                      avatar: Icon(Icons.folder, size: 14),
                      label: Text(b.name, style: const TextStyle(fontSize: 12)),
                      onPressed: b.id == widget.config.currentFolderId ? null : () => _navigateToFolder(b.id),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                )).toList(),
              ),
            ),
          _buildDbInfo(),
          Expanded(child: _buildBody()),
        ],
      ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Future<void> _captureDiagnostic() async {
    final buf = StringBuffer();
    buf.writeln('📷 **D1診断** (${widget.config.explorerTitle})');
    buf.writeln('items: ${_items.length} | loading: $_isLoading | tree: $_treeMode');
    buf.writeln('DB: ${_dbSize != null ? "${(_dbSize! / 1024).round()}KB" : "--"}');
    try {
      final db = await DatabaseHelper().database;
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
      for (final t in tables) {
        final name = t['name'] as String;
        final cnt = await db.rawQuery('SELECT COUNT(*) as c FROM "$name"');
        buf.writeln('  $name: ${cnt.first['c']}行');
      }
    } catch (_) {}
    ErrorReporter.sendLog(message: buf.toString());

    try {
      final boundary = _diagnosticKey.currentContext?.findRenderObject();
      if (boundary == null) { ErrorReporter.sendLog(message: '📷 screenshot: boundary null'); return; }
      final repBoundary = boundary as RenderRepaintBoundary;
      final image = await repBoundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) { ErrorReporter.sendLog(message: '📷 screenshot: byteData null'); return; }
      final svc = MmCommandService.instance;
      if (svc.pat == null) { ErrorReporter.sendLog(message: '📷 screenshot: PAT null'); return; }
      final err = await svc.uploadFile(byteData.buffer.asUint8List(), 'd1_diagnostic.png');
      if (err != null) ErrorReporter.sendLog(message: '📷 screenshot upload: $err');
    } catch (e) {
      ErrorReporter.sendLog(message: '📷 screenshot error: $e');
    }
  }

  Widget _buildDbInfo() {
    final cs = Theme.of(context).colorScheme;
    final count = _items.length;
    final sizeStr = _dbSize != null ? '${(_dbSize! / 1024).round()}KB' : '--';
    final empty = count == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            empty ? '全0件' : '全$count件',
            style: TextStyle(
              fontSize: 12,
              color: empty ? cs.error : cs.onSurfaceVariant,
              fontWeight: empty ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'DB: $sizeStr',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget? _buildFab() {
    if (widget.selectionMode) return null;
    final actions = widget.config.fabActions(context);
    if (actions != null) {
      return FloatingActionButton(
        heroTag: 'explorer_fab_${widget.config.hashCode}',
        onPressed: () => _showFabMenu(actions),
        child: const Icon(Icons.add),
      );
    }
    return FloatingActionButton(
      heroTag: 'explorer_fab_${widget.config.hashCode}',
      onPressed: () => _openEditor(null),
      child: const Icon(Icons.add),
    );
  }

  void _showFabMenu(
    List<({IconData icon, String label, VoidCallback onTap})> actions,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: actions
              .map((a) => ListTile(
                    leading: Icon(a.icon),
                    title: Text(a.label),
                    onTap: () {
                      Navigator.pop(ctx);
                      Future.microtask(() => a.onTap());
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final cs = Theme.of(context).colorScheme;
    final typeOptions = widget.config.typeFilterOptions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          if (typeOptions.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ToggleButtons(
                isSelected: typeOptions.map((o) => widget.config.typeFilter == o.value).toList(),
                onPressed: (i) {
                  setState(() {
                    widget.config.typeFilter = typeOptions[i].value;
                  });
                  _loadItems();
                },
                borderRadius: BorderRadius.circular(8),
                constraints: const BoxConstraints(minHeight: 32, minWidth: 52),
                textStyle: const TextStyle(fontSize: 11),
                children: typeOptions.map((o) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(o.icon, size: 14),
                      const SizedBox(width: 3),
                      Text(o.label),
                    ],
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ToggleButtons(
              isSelected: [
                _statusFilter == '',
                _statusFilter == 'draft',
                _statusFilter == 'confirmed',
              ],
              onPressed: (i) {
                setState(() {
                  _statusFilter = ['', 'draft', 'confirmed'][i];
                });
                _loadItems();
              },
              borderRadius: BorderRadius.circular(8),
              constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
              textStyle: const TextStyle(fontSize: 12),
              children: const [
                Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('すべて')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('下書き')),
                Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('確定')),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _dateChip(context, cs, '開始日', _dateFrom, (d) => _dateFrom = d),
              const SizedBox(width: 8),
              _dateChip(context, cs, '終了日', _dateTo, (d) => _dateTo = d),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('クリア', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateChip(BuildContext context, ColorScheme cs, String label, DateTime? value, void Function(DateTime?) setter) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            setter(picked);
            _loadItems();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: value != null ? cs.primary : cs.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.date_range, size: 16, color: value != null ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                value != null
                    ? '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}'
                    : label,
                style: TextStyle(fontSize: 12, color: value != null ? cs.primary : cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilters() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (widget.config.typeFilter.isNotEmpty)
              _filterChip(cs, widget.config.typeFilterOptions
                  .where((o) => o.value == widget.config.typeFilter)
                  .map((o) => o.label)
                  .firstOrNull ?? widget.config.typeFilter, () {
                setState(() => widget.config.typeFilter = '');
                _loadItems();
              }),
            if (_statusFilter.isNotEmpty)
              _filterChip(cs, _statusFilter == 'draft' ? '下書き' : '確定', () {
                setState(() => _statusFilter = '');
                _loadItems();
              }),
            if (_dateFrom != null)
              _filterChip(cs, '${_dateFrom!.month}/${_dateFrom!.day}から', () {
                setState(() => _dateFrom = null);
                _loadItems();
              }),
            if (_dateTo != null)
              _filterChip(cs, '${_dateTo!.month}/${_dateTo!.day}まで', () {
                setState(() => _dateTo = null);
                _loadItems();
              }),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(ColorScheme cs, String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InputChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildTreeView() {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        // 左ペイン: フォルダツリー
        Container(
          width: 180,
          color: cs.surfaceContainerLow,
          child: _folders.isEmpty
              ? Center(child: Text('フォルダなし',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _folders.length,
                  itemBuilder: (ctx, i) => _buildFolderTile(_folders[i], cs),
                ),
        ),
        Container(width: 1, color: cs.outlineVariant),
        // 右ペイン: 商品カード
        Expanded(
          child: _items.isEmpty
              ? Center(child: Text(widget.config.emptyMessage,
                  style: TextStyle(color: cs.onSurfaceVariant)))
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: (MediaQuery.of(context).size.width - 200) > 400 ? 3 : 2,
                      childAspectRatio: 1.4,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (ctx, i) => _buildItemCard(_items[i], cs),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFolderTile(TreeFolder folder, ColorScheme cs) {
    return DragTarget<T>(
      onAcceptWithDetails: (details) async {
        await widget.config.moveItemToFolder(details.data, folder.id);
        _loadItems();
      },
      builder: (ctx, candidates, rejected) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? Colors.amber.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          dense: _displaySize == 0,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: Icon(
            _expandedFolders.contains(folder.id) ? Icons.folder_open : Icons.folder,
            color: candidates.isNotEmpty ? Colors.amber : cs.tertiary,
            size: [18.0, 20.0, 22.0][_displaySize],
          ),
          title: Text(folder.name,
              style: TextStyle(fontSize: [13.0, 14.0, 15.0][_displaySize],
                  fontWeight: FontWeight.w500)),
          trailing: Text('${folder.itemCount}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          onTap: () => _navigateToFolder(folder.id),
        ),
      ),
    );
  }

  Widget _buildItemCard(T item, ColorScheme cs) {
    return LongPressDraggable<T>(
      data: item,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 160,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon ?? widget.config.itemIcon, size: 24, color: cs.primary),
                  const SizedBox(height: 6),
                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.25,
        child: _buildItemCardContent(item, cs),
      ),
      child: _buildItemCardContent(item, cs),
    );
  }

  Widget _buildItemCardContent(T item, ColorScheme cs) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => _onItemTap(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon ?? widget.config.itemIcon, size: 24, color: cs.primary),
              const SizedBox(height: 6),
              Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: [12.0, 13.0, 14.0][_displaySize],
                      fontWeight: FontWeight.w500)),
              if (item.badge != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(item.badge!, style: TextStyle(fontSize: 9, color: cs.onPrimaryContainer)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_treeMode && widget.config.supportsTreeView) {
      return _buildTreeView();
    }

    if (_items.isEmpty) {
      return Center(child: Text(widget.config.emptyMessage));
    }

    final hasGrouping = _items.any((i) => widget.config.groupKey(i) != null);
    if (!hasGrouping) {
      return _buildList(_items);
    }

    final grouped = _groupItems();
    final sortedKeys = grouped.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView(
        children: [
          _buildGroupChips(sortedKeys),
          for (final key in sortedKeys) ...[
            if (key.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  key,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ..._buildGroupItems(grouped[key]!),
          ],
        ],
      ),
    );
  }

  Widget _buildGroupChips(List<String> keys) {
    final nonEmpty = keys.where((k) => k.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: nonEmpty
            .map((k) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(k, style: const TextStyle(fontSize: 13)),
                    onPressed: () => _scrollToGroup(k),
                  ),
                ))
            .toList(),
      ),
    );
  }

  final _listKey = GlobalKey();

  void _scrollToGroup(String key) {
    final state = _listKey.currentState;
    if (state != null) {
      Scrollable.ensureVisible(
        state.context,
        alignment: 0.05,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  Widget _buildList(List<T> items) {
    return ListView.builder(
      key: _listKey,
      itemCount: items.length,
      itemBuilder: (context, index) => _buildItemTile(items[index]),
    );
  }

  List<Widget> _buildGroupItems(List<T> items) {
    return items.map((item) => _buildItemTile(item)).toList();
  }

  Widget _buildItemTile(T item) {
    final content = widget.config.buildItemTileContent(context, item);
    final paddingV = [1.0, 2.0, 3.0][_displaySize];
    final textScale = [0.85, 1.0, 1.15][_displaySize];
    return GestureDetector(
      onTap: () => _onItemTap(item),
      onLongPress: widget.selectionMode ? null : () => _confirmDelete(item),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: paddingV),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: content,
        ),
      ),
    );
  }
}

class _H1ExplorerViewerScreen<T extends H1ExplorerItem> extends StatefulWidget {
  final H1ExplorerConfig<T> config;
  final T item;

  const _H1ExplorerViewerScreen({required this.config, required this.item});

  @override
  State<_H1ExplorerViewerScreen<T>> createState() => _H1ExplorerViewerScreenState<T>();
}

class _H1ExplorerViewerScreenState<T extends H1ExplorerItem> extends State<_H1ExplorerViewerScreen<T>> {
  Future<void> _edit() async {
    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => widget.config.buildEditor(context, widget.item),
      ),
    );
    if (!mounted) return;
    if (result != null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(widget.item.title),
        centerTitle: true,
        actions: [
          if (widget.item.canEdit)
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _edit,
          ),
        ],
      ),
      body: widget.config.buildViewer(context, widget.item),
      floatingActionButton: widget.item.canEdit
          ? FloatingActionButton(
              onPressed: _edit,
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }
}
