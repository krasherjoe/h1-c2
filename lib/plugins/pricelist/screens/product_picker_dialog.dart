import 'package:flutter/material.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';

class PickedProduct {
  final String productId;
  final String name;
  final int price;
  final bool isVariant;
  final String? parentName;

  const PickedProduct({
    required this.productId,
    required this.name,
    required this.price,
    this.isVariant = false,
    this.parentName,
  });
}

class ProductPickerDialog extends StatefulWidget {
  const ProductPickerDialog({super.key});

  @override
  State<ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<ProductPickerDialog> {
  final _repo = ProductRepository();
  final _searchCtl = TextEditingController();

  List<Product> _allProducts = [];
  List<Product> _filtered = [];
  final _expandedParents = <String>{};
  bool _loading = true;

  // 親商品のみのリスト（バリアントは除く）
  List<Product> get _parents =>
      _filtered.where((p) => !p.isVariant).toList();

  // 親ID -> バリアントリスト
  Map<String, List<Product>> get _variantsByParent {
    final map = <String, List<Product>>{};
    for (final p in _filtered) {
      if (p.isVariant && p.parentId != null) {
        map.putIfAbsent(p.parentId!, () => []).add(p);
      }
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await _repo.getAllProducts();
    if (!mounted) return;
    setState(() {
      _allProducts = products;
      _filtered = products;
      _loading = false;
    });
  }

  void _search(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allProducts;
      } else {
        _filtered = _allProducts.where((p) =>
          p.name.toLowerCase().contains(query) ||
          (p.barcode?.toLowerCase().contains(query) ?? false) ||
          (p.category?.toLowerCase().contains(query) ?? false) ||
          (p.modelNumber?.toLowerCase().contains(query) ?? false)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('商品を選択', style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtl,
              decoration: const InputDecoration(
                hintText: '商品名・バーコードで検索',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(child: Text('商品が見つかりません', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 8),
                        children: _buildProductList(),
                      ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProductList() {
    final cs = Theme.of(context).colorScheme;
    final parents = _parents;
    final variantsByParent = _variantsByParent;
    final items = <Widget>[];

    for (final parent in parents) {
      final hasVariants = variantsByParent.containsKey(parent.id);
      final expanded = _expandedParents.contains(parent.id);

      items.add(ListTile(
        dense: true,
        leading: Icon(hasVariants
            ? (expanded ? Icons.expand_more : Icons.chevron_right)
            : Icons.inventory_2, size: 18, color: cs.primary),
        title: Text(parent.name, style: const TextStyle(fontSize: 14)),
        subtitle: Text('¥${_formatPrice(parent.defaultUnitPrice)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        onTap: () => Navigator.pop(context, PickedProduct(
          productId: parent.id,
          name: parent.name,
          price: parent.defaultUnitPrice,
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
            : null,
      ));

      if (hasVariants && expanded) {
        for (final variant in variantsByParent[parent.id]!) {
          items.add(Padding(
            padding: const EdgeInsets.only(left: 32),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.subdirectory_arrow_right, size: 16, color: cs.onSurfaceVariant),
              title: Text(variant.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text('¥${_formatPrice(variant.defaultUnitPrice)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              onTap: () => Navigator.pop(context, PickedProduct(
                productId: variant.id,
                name: variant.name,
                price: variant.defaultUnitPrice,
                isVariant: true,
                parentName: parent.name,
              )),
            ),
          ));
        }
      }
    }

    if (parents.isEmpty) {
      // 検索結果がバリアントのみの場合、全件表示
      for (final p in _filtered) {
        items.add(ListTile(
          dense: true,
          leading: Icon(Icons.subdirectory_arrow_right, size: 18, color: cs.onSurfaceVariant),
          title: Text(p.name, style: const TextStyle(fontSize: 13)),
          subtitle: Text('¥${_formatPrice(p.defaultUnitPrice)}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          onTap: () => Navigator.pop(context, PickedProduct(
            productId: p.id,
            name: p.name,
            price: p.defaultUnitPrice,
            isVariant: true,
          )),
        ));
      }
    }

    return items;
  }

  String _formatPrice(int price) => price.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
