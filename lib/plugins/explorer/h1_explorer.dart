import 'package:flutter/material.dart';
import 'h1_explorer_config.dart';
import 'h1_explorer_item.dart';

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
  String _query = '';
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final items = await widget.config.fetchItems(_query);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String value) {
    _query = value;
    _loadItems();
  }

  void _openViewer(T item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _H1ExplorerViewerScreen<T>(
          config: widget.config,
          item: item,
        ),
      ),
    );
  }

  Future<void> _openEditor(T? item) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _H1ExplorerEditorScreen<T>(
          config: widget.config,
          item: item,
        ),
      ),
    );
    if (result == true && mounted) _loadItems();
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

  Map<String, List<T>> _groupItems() {
    final grouped = <String, List<T>>{};
    for (final item in _items) {
      final key = widget.config.groupKey(item) ?? '';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final hasSort = widget.config.sortOptions.isNotEmpty;
    final overflowActions = widget.config.overflowActions;
    return Scaffold(
      appBar: AppBar(
        title: widget.appBarTitle ?? Text(widget.config.explorerTitle),
        centerTitle: true,
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
          if (overflowActions.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'その他',
              onSelected: (id) => widget.config.onOverflowAction(
                context,
                id,
                onListChanged: _loadItems,
              ),
              itemBuilder: (_) => overflowActions
                  .map((a) => PopupMenuItem<String>(
                        value: a.id,
                        child: ListTile(
                          leading: Icon(a.icon),
                          title: Text(a.label),
                          dense: true,
                        ),
                      ))
                  .toList(),
            ),
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () => setState(() => _showSearch = !_showSearch),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.config.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _buildFab(),
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
                      a.onTap();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView.builder(
        key: _listKey,
        itemCount: items.length,
        itemBuilder: (context, index) => _buildItemTile(items[index]),
      ),
    );
  }

  List<Widget> _buildGroupItems(List<T> items) {
    return items.map((item) => _buildItemTile(item)).toList();
  }

  Widget _buildItemTile(T item) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final allowed = await widget.config.canDelete(item);
        if (!allowed) return false;
        if (!context.mounted) return false;
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
        return confirmed == true;
      },
      onDismissed: (_) async {
        await widget.config.deleteItem(item);
        if (mounted) _loadItems();
      },
      child: ListTile(
        leading: Icon(item.icon ?? widget.config.itemIcon),
        title: Text(item.title),
        subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
        trailing: item.badge != null
            ? Chip(
                label: Text(
                  item.badge!,
                  style: const TextStyle(fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
              )
            : null,
        onTap: () => _onItemTap(item),
        onLongPress: widget.selectionMode ? null : () => _confirmDelete(item),
      ),
    );
  }
}

class _H1ExplorerViewerScreen<T extends H1ExplorerItem> extends StatelessWidget {
  final H1ExplorerConfig<T> config;
  final T item;

  const _H1ExplorerViewerScreen({required this.config, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _H1ExplorerEditorScreen<T>(
                  config: config,
                  item: item,
                ),
              ),
            ),
          ),
        ],
      ),
      body: config.buildViewer(context, item),
    );
  }
}

class _H1ExplorerEditorScreen<T extends H1ExplorerItem> extends StatelessWidget {
  final H1ExplorerConfig<T> config;
  final T? item;

  const _H1ExplorerEditorScreen({required this.config, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item == null ? '新規作成' : '編集'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: config.buildEditor(context, item),
    );
  }
}
