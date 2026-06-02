import 'package:flutter/material.dart';
import '../../../models/product_category_model.dart';
import '../../../services/product_category_repository.dart';

class CategoryPickerDialog extends StatefulWidget {
  final String? selectedId;

  const CategoryPickerDialog({super.key, this.selectedId});

  @override
  State<CategoryPickerDialog> createState() => _CategoryPickerDialogState();
}

class _CategoryPickerDialogState extends State<CategoryPickerDialog> {
  final _repo = ProductCategoryRepository();

  List<ProductCategory> _rootNodes = [];
  final _childrenCache = <String, List<ProductCategory>>{};
  final _expanded = <String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _rootNodes = await _repo.getRoots();
    if (widget.selectedId != null) {
      final path = await _repo.getPath(widget.selectedId!);
      for (final cat in path) {
        if (cat.id != widget.selectedId) {
          final children = await _repo.getChildren(cat.id);
          _childrenCache[cat.id] = children;
          _expanded.add(cat.id);
        }
      }
    }
    setState(() => _isLoading = false);
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

  List<_PickerFlatNode> _buildFlatList() {
    final result = <_PickerFlatNode>[];
    for (final root in _rootNodes) {
      _addToFlatList(root, 0, result);
    }
    return result;
  }

  void _addToFlatList(
      ProductCategory node, int depth, List<_PickerFlatNode> result) {
    result.add(_PickerFlatNode(category: node, depth: depth));
    if (_expanded.contains(node.id)) {
      final children = _childrenCache[node.id];
      if (children != null) {
        for (final child in children) {
          _addToFlatList(child, depth + 1, result);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('カテゴリを選択'),
      content: SizedBox(
        width: 320,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.clear, size: 16),
                        label: const Text('カテゴリなし'),
                        onPressed: () =>
                            Navigator.pop(context, '' as Object?),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: _buildFlatList().map((fn) {
                        return InkWell(
                          onTap: () => Navigator.pop(
                              context, fn.category.id),
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: 16.0 + fn.depth * 20.0),
                            child: Container(
                              height: 40,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        _toggleExpand(fn.category),
                                    child: Container(
                                      width: 28,
                                      height: 40,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        _expanded.contains(
                                                fn.category.id)
                                            ? Icons.expand_more
                                            : Icons.chevron_right,
                                        size: 18,
                                        color: cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    _expanded.contains(
                                            fn.category.id)
                                        ? Icons.folder_open
                                        : Icons.folder,
                                    size: 18,
                                    color: cs.tertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    fn.category.name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  if (widget.selectedId ==
                                      fn.category.id)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(left: 8),
                                      child: Icon(Icons.check,
                                          size: 16, color: cs.primary),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ],
    );
  }
}

class _PickerFlatNode {
  final ProductCategory category;
  final int depth;
  _PickerFlatNode({required this.category, required this.depth});
}
