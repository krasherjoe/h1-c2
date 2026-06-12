import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';
import '../../../services/database_helper.dart';
import '../../../widgets/h1_text_field.dart';
import '../screens/product_editor_screen.dart';

class PickedItem {
  final String productId;
  final String productName;
  final int unitPrice;
  final String? variantLabel;

  const PickedItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.variantLabel,
  });
}

class VariantPickerSheet extends StatefulWidget {
  final String? customerId;

  const VariantPickerSheet({super.key, this.customerId});

  @override
  State<VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends State<VariantPickerSheet> {
  final _repo = ProductRepository();
  final _searchCtrl = TextEditingController();
  final _expandedParents = <String>{};
  List<Product> _allProducts = [];
  List<Product> _filtered = [];
  Map<String, List<Product>> _variantsByParent = {};
  Map<String, int> _customerPrices = {};
  bool _loading = true;

  List<Product> get _parents => _filtered.where((p) => !p.isVariant).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _repo.searchProducts(''),
      _loadCustomerPrices(),
    ]);
    final products = (results[0] as List).cast<Product>();
    final customerPrices = results[1] as Map<String, int>;

    final prices = <String, int>{};
    for (final p in products) {
      final cp = customerPrices[p.id];
      prices[p.id] = cp ?? p.defaultUnitPrice;
    }
    for (final p in products) {
      if (p.parentId != null && !customerPrices.containsKey(p.id)) {
        final pp = customerPrices[p.parentId];
        if (pp != null) prices[p.id] = pp;
      }
    }

    final variantsByParent = <String, List<Product>>{};
    for (final p in products) {
      if (p.isVariant && p.parentId != null) {
        variantsByParent.putIfAbsent(p.parentId!, () => []).add(p);
      }
    }

    if (mounted) {
      setState(() {
        _allProducts = products;
        _filtered = products;
        _variantsByParent = variantsByParent;
        _customerPrices = prices;
        _loading = false;
      });
    }
  }

  Future<Map<String, int>> _loadCustomerPrices() async {
    final cid = widget.customerId;
    if (cid == null || cid.isEmpty) return {};
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'customer_product_prices',
        where: 'customer_id = ?',
        whereArgs: [cid],
      );
      return {for (final r in rows) (r['product_id'] as String): (r['price'] as int?) ?? 0};
    } catch (_) {
      return {};
    }
  }

  void _search(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      _filtered = query.isEmpty
          ? _allProducts
          : _allProducts.where((p) =>
              p.name.toLowerCase().contains(query) ||
              (p.barcode?.toLowerCase().contains(query) ?? false) ||
              (p.modelNumber?.toLowerCase().contains(query) ?? false)
            ).toList();
    });
  }

  Future<void> _createProduct(String name) async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const ProductEditorScreen()),
    );
    if (product != null && mounted) {
      Navigator.pop(context, PickedItem(
        productId: product.id,
        productName: product.name,
        unitPrice: product.defaultUnitPrice,
      ));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final query = _searchCtrl.text.trim();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 32, height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('商品を追加', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: H1TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: '商品名で検索',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: _search,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_circle, size: 18),
                label: Text(query.isEmpty ? '新規商品登録' : '「$query」を新規登録'),
                onPressed: () => _createProduct(_searchCtrl.text.trim()),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: _loading
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ))
              : _buildList(cs),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme cs) {
    final parents = _parents;
    final variantsByParent = _variantsByParent;
    final items = <Widget>[];

    if (parents.isEmpty && _filtered.where((p) => p.isVariant).isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: cs.onSurfaceVariant),
              const SizedBox(height: 8),
              Text('商品が見つかりません', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    for (final parent in parents) {
      final hasVariants = variantsByParent.containsKey(parent.id);
      final expanded = _expandedParents.contains(parent.id);
      final price = _customerPrices[parent.id] ?? parent.defaultUnitPrice;

      items.add(ListTile(
        dense: true,
        leading: Icon(hasVariants
            ? (expanded ? Icons.expand_more : Icons.chevron_right)
            : Icons.inventory_2, size: 18, color: cs.primary),
        title: Text(parent.name, style: const TextStyle(fontSize: 14)),
        subtitle: Row(
          children: [
            Text('¥$price', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            if (_customerPrices.containsKey(parent.id)) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('顧客別', style: TextStyle(fontSize: 9, color: cs.onTertiaryContainer)),
              ),
            ],
          ],
        ),
        onTap: hasVariants
            ? () => _selectVariant(parent)
            : () => Navigator.pop(context, PickedItem(
                productId: parent.id,
                productName: parent.name,
                unitPrice: price,
              )),
        trailing: hasVariants
            ? IconButton(
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                onPressed: () {
                  setState(() {
                    if (expanded) {
                      _expandedParents.remove(parent.id);
                    } else {
                      _expandedParents.add(parent.id);
                    }
                  });
                },
              )
            : Icon(Icons.add_circle_outline, size: 18, color: cs.primary),
      ));

      if (hasVariants && expanded) {
        for (final variant in variantsByParent[parent.id]!) {
          final vPrice = _customerPrices[variant.id] ?? variant.defaultUnitPrice;
          items.add(Padding(
            padding: const EdgeInsets.only(left: 32),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.subdirectory_arrow_right, size: 16, color: cs.onSurfaceVariant),
              title: Text(variant.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text('¥$vPrice', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              trailing: Icon(Icons.add_circle_outline, size: 18, color: cs.primary),
              onTap: () => Navigator.pop(context, PickedItem(
                productId: variant.id,
                productName: variant.name,
                unitPrice: vPrice,
                variantLabel: _extractVariantLabel(variant.name, parent.name),
              )),
            ),
          ));
        }
      }
    }

    // フィルタ結果がバリアントのみの場合
    if (parents.isEmpty) {
      for (final p in _filtered.where((p) => p.isVariant)) {
        final price = _customerPrices[p.id] ?? p.defaultUnitPrice;
        final parentName = _allProducts
            .where((pp) => pp.id == p.parentId)
            .map((pp) => pp.name)
            .firstOrNull;
        items.add(ListTile(
          dense: true,
          leading: Icon(Icons.subdirectory_arrow_right, size: 18, color: cs.onSurfaceVariant),
          title: Text(p.name, style: const TextStyle(fontSize: 13)),
          subtitle: Text('¥$price', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          trailing: Icon(Icons.add_circle_outline, size: 18, color: cs.primary),
          onTap: () => Navigator.pop(context, PickedItem(
            productId: p.id,
            productName: p.name,
            unitPrice: price,
            variantLabel: parentName != null ? _extractVariantLabel(p.name, parentName) : null,
          )),
        ));
      }
    }

    return ListView(shrinkWrap: true, children: items);
  }

  Future<void> _selectVariant(Product parent) async {
    final groups = await _repo.getOptionGroups(parent.id);
    if (groups.isEmpty) {
      // オプショングループがない場合は親商品として選択
      if (!mounted) return;
      Navigator.pop(context, PickedItem(
        productId: parent.id,
        productName: parent.name,
        unitPrice: _customerPrices[parent.id] ?? parent.defaultUnitPrice,
      ));
      return;
    }

    if (!mounted) return;
    final result = await _showVariantOptionPicker(parent, groups);
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<PickedItem?> _showVariantOptionPicker(
    Product parent,
    List<ProductOptionGroup> groups,
  ) async {
    // groupId -> (valueId, valueName)
    final selections = <String, _OptionSel>{};
    final groupValues = <String, List<ProductOptionValue>>{};

    for (final g in groups) {
      final values = await _repo.getOptionValues(g.id);
      groupValues[g.id] = values;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlgState) {
          final allSelected = selections.values.every((v) => v.valueId != null);
          return AlertDialog(
            title: Text('${parent.name} - オプション選択'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groups.map((g) {
                  final values = groupValues[g.id] ?? [];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: values.map((v) {
                            final selected = selections[g.id]?.valueId == v.id;
                            return ChoiceChip(
                              label: Text('${v.value}${v.priceModifier != 0 ? " (¥${v.priceModifier >= 0 ? "+" : ""}${v.priceModifier})" : ""}'),
                              selected: selected,
                              onSelected: (s) {
                                setDlgState(() {
                                  if (s) {
                                    selections[g.id] = _OptionSel(v.id, v.value);
                                  } else {
                                    selections.remove(g.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: allSelected
                    ? () async {
                        final selectedIds = selections.values
                            .map((s) => s.valueId)
                            .where((v) => v != null)
                            .cast<String>()
                            .toList();
                        final variant = await _resolveVariant(parent.id, selectedIds);
                        if (variant != null) {
                          final label = '(${selections.values.map((s) => s.valueName).join(", ")})';
                          final price = _customerPrices[variant.id] ?? variant.defaultUnitPrice;
                          Navigator.pop(ctx2, {
                            'productId': variant.id,
                            'productName': variant.name,
                            'price': price.toString(),
                            'label': label,
                          });
                        } else {
                          ScaffoldMessenger.of(ctx2).showSnackBar(
                            const SnackBar(content: Text('該当するバリアントが見つかりません')),
                          );
                        }
                      }
                    : null,
                child: const Text('選択'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null) return null;
    return PickedItem(
      productId: result['productId']!,
      productName: result['productName']!,
      unitPrice: int.parse(result['price']!),
      variantLabel: result['label'],
    );
  }

  Future<Product?> _resolveVariant(String parentId, List<String> optionValueIds) async {
    final variants = await _repo.getVariants(parentId);
    for (final v in variants) {
      final vOptions = await _repo.getVariantOptionValues(v.id);
      final vOptionIds = vOptions.map((o) => o.id).toSet();
      if (vOptionIds.length == optionValueIds.length &&
          optionValueIds.every((id) => vOptionIds.contains(id))) {
        return v;
      }
    }
    return null;
  }

  String? _extractVariantLabel(String variantName, String parentName) {
    if (variantName.startsWith(parentName)) {
      final rest = variantName.substring(parentName.length).trim();
      if (rest.startsWith('(') && rest.endsWith(')')) return rest;
      if (rest.isNotEmpty) return '($rest)';
    }
    return null;
  }
}

class _OptionSel {
  final String valueId;
  final String valueName;
  const _OptionSel(this.valueId, this.valueName);
}
