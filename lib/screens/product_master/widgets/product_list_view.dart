import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../models/product_category_model.dart';
import '../models/product_list_types.dart';
import 'product_card.dart';

class ProductListView extends StatelessWidget {
  final List<Product> filteredProducts;
  final List<ProductCategory> categories;
  final Map<String, List<Product>> variantsByParent;
  final Set<String> expandedCatIds;
  final Set<String> expandedParentIds;
  final bool breadcrumbMode;
  final bool treeMode;
  final String? currentCategoryId;
  final bool selectMode;
  final bool selectionMode;
  final Set<String> selectedIds;

  final ValueChanged<String>? onCategoryTap;
  final void Function(String categoryId, Product product)? onCategoryDrop;
  final VoidCallback? onBreadcrumbTop;
  final ValueChanged<String>? onBreadcrumbCategoryTap;
  final ValueChanged<Product>? onProductTap;
  final ValueChanged<Product>? onProductLongPress;
  final ValueChanged<Product>? onDetailProduct;
  final ValueChanged<Product>? onSelectProduct;
  final VoidCallback? onToggleExpand;

  const ProductListView({
    super.key,
    required this.filteredProducts,
    required this.categories,
    required this.variantsByParent,
    required this.expandedCatIds,
    required this.expandedParentIds,
    this.breadcrumbMode = false,
    this.treeMode = true,
    this.currentCategoryId,
    this.selectMode = false,
    this.selectionMode = false,
    this.selectedIds = const {},
    this.onCategoryTap,
    this.onCategoryDrop,
    this.onBreadcrumbTop,
    this.onBreadcrumbCategoryTap,
    this.onProductTap,
    this.onProductLongPress,
    this.onDetailProduct,
    this.onSelectProduct,
    this.onToggleExpand,
  });

  List<TreeItem> _buildItemList() {
    if (breadcrumbMode && treeMode) {
      return _buildBreadcrumbItems();
    }
    if (!treeMode) {
      final list = <TreeItem>[];
      for (final p in filteredProducts) {
        list.add((type: 'product', id: p.id, product: p, isVariant: false, depth: 0));
        if (expandedParentIds.contains(p.id) && variantsByParent[p.id] != null) {
          for (final v in variantsByParent[p.id]!) {
            list.add((type: 'product', id: v.id, product: v, isVariant: true, depth: 0));
          }
        }
      }
      return list;
    }
    final list = <TreeItem>[];
    final catById = <String, ProductCategory>{};
    for (final c in categories) catById[c.id] = c;
    final children = <String, List<ProductCategory>>{};
    for (final c in categories) {
      final pid = c.parentId ?? 'root';
      children.putIfAbsent(pid, () => []).add(c);
    }
    final rootProducts = filteredProducts.where((p) => p.categoryId == null || p.categoryId!.isEmpty).toList();
    if (rootProducts.isNotEmpty) {
      list.add((type: 'uncategorized', id: '__uncategorized__', product: null, isVariant: false, depth: 0));
      for (final p in rootProducts) {
        list.add((type: 'product', id: p.id, product: p, isVariant: false, depth: 0));
        if (expandedParentIds.contains(p.id) && variantsByParent[p.id] != null) {
          for (final v in variantsByParent[p.id]!) {
            list.add((type: 'product', id: v.id, product: v, isVariant: true, depth: 0));
          }
        }
      }
    }
    _buildCategoryTree('root', catById, children, 0, list);
    return list;
  }

  void _buildCategoryTree(String parentId, Map<String, ProductCategory> catById,
      Map<String, List<ProductCategory>> children, int depth, List<TreeItem> list) {
    for (final cat in children[parentId] ?? []) {
      final expanded = expandedCatIds.contains(cat.id);
      list.add((type: 'category', id: cat.id, product: null, isVariant: false, depth: depth));
      if (expanded) {
        final catProducts = filteredProducts.where((p) => p.categoryId == cat.id).toList();
        for (final p in catProducts) {
          list.add((type: 'product', id: p.id, product: p, isVariant: false, depth: depth + 1));
          if (expandedParentIds.contains(p.id) && variantsByParent[p.id] != null) {
            for (final v in variantsByParent[p.id]!) {
              list.add((type: 'product', id: v.id, product: v, isVariant: true, depth: depth + 1));
            }
          }
        }
        _buildCategoryTree(cat.id, catById, children, depth + 1, list);
      }
    }
  }

  List<TreeItem> _buildBreadcrumbItems() {
    final list = <TreeItem>[];
    final path = <ProductCategory>[];
    var cur = currentCategoryId != null
        ? categories.where((c) => c.id == currentCategoryId).firstOrNull
        : null;
    while (cur != null) {
      path.insert(0, cur);
      cur = cur.parentId != null
          ? categories.where((c) => c.id == cur!.parentId).firstOrNull
          : null;
    }
    list.add((type: 'breadcrumb', id: '__path__', product: null, isVariant: false, depth: 0));
    final childCats = categories.where((c) => c.parentId == currentCategoryId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final cat in childCats) {
      list.add((type: 'category', id: cat.id, product: null, isVariant: false, depth: 0));
    }
    final catProducts = filteredProducts.where((p) {
      if (currentCategoryId == null) return p.categoryId == null || p.categoryId!.isEmpty;
      return p.categoryId == currentCategoryId;
    }).toList();
    for (final p in catProducts) {
      list.add((type: 'product', id: p.id, product: p, isVariant: false, depth: 0));
      if (expandedParentIds.contains(p.id) && variantsByParent[p.id] != null) {
        for (final v in variantsByParent[p.id]!) {
          list.add((type: 'product', id: v.id, product: v, isVariant: true, depth: 0));
        }
      }
    }
    return list;
  }

  Widget _breadcrumbBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = <ProductCategory>[];
    var cur = currentCategoryId != null
        ? categories.where((c) => c.id == currentCategoryId).firstOrNull
        : null;
    while (cur != null) {
      path.insert(0, cur);
      cur = cur.parentId != null
          ? categories.where((c) => c.id == cur!.parentId).firstOrNull
          : null;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              avatar: const Icon(Icons.home, size: 16),
              label: const Text('TOP', style: TextStyle(fontSize: 12)),
              onPressed: onBreadcrumbTop ?? () {},
              visualDensity: VisualDensity.compact,
            ),
            for (final cat in path) ...[
              const Icon(Icons.chevron_right, size: 16),
              ActionChip(
                avatar: const Icon(Icons.folder, size: 14),
                label: Text(cat.name, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  if (onBreadcrumbCategoryTap != null) onBreadcrumbCategoryTap!(cat.id);
                },
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryHeader(BuildContext context, String name, int count, bool expanded, String catId, {int depth = 0}) {
    final childCount = categories.where((c) => c.parentId == catId).length;
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, bottom: 2),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2),
        color: expanded ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: DragTarget<Product>(
          onAcceptWithDetails: (details) {
            if (onCategoryDrop != null) onCategoryDrop!(catId, details.data);
          },
          builder: (ctx, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return ListTile(
              dense: true,
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(expanded ? Icons.expand_more : Icons.chevron_right, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32),
                    onPressed: () {
                      if (onCategoryTap != null) onCategoryTap!(catId);
                    },
                  ),
                  Icon(
                    Icons.folder,
                    color: isHovering ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.secondary,
                    size: 20,
                  ),
                ],
              ),
              title: Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isHovering ? Theme.of(ctx).colorScheme.primary : null,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (childCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$childCount', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onTertiaryContainer)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$count', style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSecondaryContainer)),
                  ),
                ],
              ),
              onTap: () {
                if (onCategoryTap != null) onCategoryTap!(catId);
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItemList();
    if (filteredProducts.isEmpty && items.isEmpty) {
      return const Center(child: Text('商品が見つかりません'));
    }
    final listView = ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: 80,
        top: breadcrumbMode && treeMode ? 0 : 4,
        left: 12,
        right: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final entry = items[index];
        if (entry.type == 'uncategorized') {
          return _uncategorizedHeader(context);
        }
        if (entry.type == 'category') {
          final cat = categories.where((c) => c.id == entry.id).firstOrNull;
          final expanded = expandedCatIds.contains(entry.id);
          final cntProducts = filteredProducts.where((p) => p.categoryId == entry.id).length;
          return _categoryHeader(
            context,
            cat?.name ?? '不明',
            cntProducts,
            expanded,
            entry.id,
            depth: entry.depth,
          );
        }
        return _buildProductItem(context, entry);
      },
    );
    if (breadcrumbMode && treeMode) {
      return Column(children: [
        _breadcrumbBar(context),
        Expanded(child: listView),
      ]);
    }
    return listView;
  }

  Widget _buildProductItem(BuildContext context, TreeItem entry) {
    final p = entry.product!;
    final leftIndent = entry.depth * 16.0 + (entry.isVariant ? 24.0 : 0.0);
    final hasVariants = variantsByParent[p.id]?.isNotEmpty ?? false;
    final expanded = expandedParentIds.contains(p.id);

    final card = Padding(
      padding: EdgeInsets.only(left: leftIndent, bottom: entry.isVariant ? 4 : 6),
      child: ProductCard(
        product: p,
        indent: entry.isVariant,
        selectMode: selectMode,
        selectionMode: selectionMode,
        isSelected: selectedIds.contains(p.id),
        hasVariants: hasVariants,
        expanded: expanded,
        isTreeMode: treeMode,
        onTap: () {
          if (selectMode) {
            if (onSelectProduct != null) onSelectProduct!(p);
          } else if (selectionMode) {
            if (p.isHidden) return;
            if (onProductTap != null) onProductTap!(p);
          } else {
            if (hasVariants && !entry.isVariant) {
              if (onToggleExpand != null) onToggleExpand!();
            } else {
              if (onDetailProduct != null) onDetailProduct!(p);
            }
          }
        },
        onLongPress: () {
          if (selectMode) return;
          if (selectionMode) {
            if (onProductLongPress != null) onProductLongPress!(p);
          } else {
            if (onSelectProduct != null) onSelectProduct!(p);
          }
        },
      ),
    );

    if (!treeMode || selectMode || selectionMode) {
      return card;
    }
    return LongPressDraggable<Product>(
      data: p,
      delay: const Duration(milliseconds: 400),
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          child: Opacity(
            opacity: 0.92,
            child: ProductCard(
              product: p,
              indent: entry.isVariant,
              selectMode: selectMode,
              selectionMode: selectionMode,
              isSelected: false,
              hasVariants: hasVariants,
              expanded: expanded,
              isTreeMode: treeMode,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }

  Widget _uncategorizedHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: DragTarget<Product>(
          onAcceptWithDetails: (details) {
            if (onCategoryDrop != null) onCategoryDrop!('', details.data);
          },
          builder: (ctx, candidateData, rejectedData) {
            final isHovering = candidateData.isNotEmpty;
            return ListTile(
              dense: true,
              leading: Icon(
                Icons.folder_off,
                color: isHovering ? Theme.of(ctx).colorScheme.primary : Theme.of(ctx).colorScheme.outline,
                size: 20,
              ),
              title: Text(
                '未分類',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isHovering ? Theme.of(ctx).colorScheme.primary : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
