import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../models/product_model.dart';
import '../../../services/product_repository.dart';

class VariantPickerSheet extends StatefulWidget {
  final Product parent;
  final List<ProductOptionGroup> groups;
  final Map<ProductOptionGroup, List<ProductOptionValue>> allValues;
  final Map<String, ProductOptionValue?> selected;

  const VariantPickerSheet({
    super.key,
    required this.parent,
    required this.groups,
    required this.allValues,
    required this.selected,
  });

  @override
  State<VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends State<VariantPickerSheet> {
  late Map<String, ProductOptionValue?> _sel;
  final _repo = ProductRepository();
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _sel = Map.from(widget.selected);
  }

  int _computePrice() {
    int price = widget.parent.defaultUnitPrice;
    for (final g in widget.groups) {
      final v = _sel[g.id];
      if (v == null) continue;
      if (g.isAbsolute) {
        if (v.priceModifier > 0) price = v.priceModifier;
      } else {
        price += v.priceModifier;
      }
    }
    return price;
  }

  String _buildVariantName() {
    final parts = [widget.parent.name];
    for (final g in widget.groups) {
      final v = _sel[g.id];
      if (v != null) parts.add(v.value);
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext ctx) {
    final cs = Theme.of(ctx).colorScheme;
    final price = _computePrice();
    final vName = _buildVariantName();

    return Padding(
      padding: EdgeInsets.only(
        top: 24,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('${widget.parent.name} の選択', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...widget.groups.map((g) {
            final vals = widget.allValues[g] ?? [];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(g.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _sel[g.id]?.id,
                      isExpanded: true,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      ),
                      items: vals.map((v) => DropdownMenuItem<String>(
                        value: v.id,
                        child: Row(
                          children: [
                            Expanded(child: Text(v.value, style: const TextStyle(fontSize: 14))),
                            Text(g.isAbsolute
                                ? (v.priceModifier > 0 ? '¥${NumberFormat("#,###").format(v.priceModifier)}' : '')
                                : (v.priceModifier >= 0 ? '+¥${NumberFormat("#,###").format(v.priceModifier)}' : '-¥${NumberFormat("#,###").format(v.priceModifier.abs())}'),
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          ],
                        ),
                      )).toList(),
                      onChanged: (id) => setState(() {
                        _sel[g.id] = vals.firstWhere((v) => v.id == id);
                      }),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 24),
          Row(
            children: [
              Text(vName, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              const Spacer(),
              Text('¥${NumberFormat("#,###").format(price)}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.primary)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('この商品を選択'),
              onPressed: () async {
                final existing = await _repo.searchProducts(vName);
                final match = existing.where((p) => p.name == vName);
                Product variant;
                if (match.isNotEmpty) {
                  variant = match.first;
                } else {
                  final vId = _uuid.v4();
                  variant = Product(
                    id: vId,
                    name: vName,
                    parentId: widget.parent.id,
                    defaultUnitPrice: price,
                    wholesalePrice: widget.parent.wholesalePrice,
                    category: widget.parent.category,
                    categoryId: widget.parent.categoryId,
                  );
                  await _repo.saveProduct(variant);
                  final ovIds = _sel.values.where((v) => v != null).map((v) => v!.id).toList();
                  if (ovIds.isNotEmpty) {
                    await _repo.setVariantOptions(vId, ovIds);
                  }
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx, variant);
              },
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        ],
      ),
    );
  }
}
