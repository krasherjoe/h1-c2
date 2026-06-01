import 'package:flutter/material.dart';
import 'h1_explorer_item.dart';
import 'h1_explorer_config.dart';

class H1Explorer<T extends H1ExplorerItem> extends StatefulWidget {
  final H1ExplorerConfig<T> config;

  const H1Explorer({super.key, required this.config});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.config.explorerTitle),
        centerTitle: true,
        actions: [
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(null),
        child: const Icon(Icons.add),
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
    return RefreshIndicator(
      onRefresh: _loadItems,
      child: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
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
              onTap: () => _openViewer(item),
              onLongPress: () => _confirmDelete(item),
            ),
          );
        },
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
      body: config.buildEditor(context, item),
    );
  }
}
