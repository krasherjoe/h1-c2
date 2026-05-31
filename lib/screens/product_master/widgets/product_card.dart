import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/product_model.dart';

class ProductPreviewCard extends StatelessWidget {
  const ProductPreviewCard({
    super.key,
    required this.name,
    required this.category,
    required this.barcode,
    this.modelNumber,
    this.manufacturer,
    required this.unitPrice,
    this.wholesalePrice,
    required this.stockQuantity,
  });

  final String name;
  final String category;
  final String barcode;
  final String? modelNumber;
  final String? manufacturer;
  final String unitPrice;
  final String? wholesalePrice;
  final String stockQuantity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.inventory_2, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? '商品名未入力' : name,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.isEmpty ? 'カテゴリ: 未分類' : 'カテゴリ: $category',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _ProductInfoChip(
                  label: '単価',
                  value: unitPrice.isEmpty ? '未設定' : '￥$unitPrice',
                ),
                if (wholesalePrice != null && wholesalePrice!.isNotEmpty)
                  _ProductInfoChip(
                    label: '仕入',
                    value: '￥$wholesalePrice',
                  ),
                if (!const ['サポート', 'サービス'].contains(category))
                  _ProductInfoChip(
                    label: '在庫',
                    value: stockQuantity.isEmpty ? '0' : stockQuantity,
                  ),
                _ProductInfoChip(
                  label: 'バーコード',
                  value: barcode.isEmpty ? '未登録' : barcode,
                ),
                if (modelNumber != null && modelNumber!.isNotEmpty)
                  _ProductInfoChip(
                    label: '型番',
                    value: modelNumber!,
                  ),
                if (manufacturer != null && manufacturer!.isNotEmpty)
                  _ProductInfoChip(
                    label: 'メーカー',
                    value: manufacturer!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductInfoChip extends StatelessWidget {
  const _ProductInfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  final bool indent;
  final bool selectMode;
  final bool isSelected;
  final bool hasVariants;
  final bool expanded;
  final bool isTreeMode;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onMenuAction;

  const ProductCard({
    super.key,
    required this.product,
    this.indent = false,
    this.selectMode = false,
    this.isSelected = false,
    this.hasVariants = false,
    this.expanded = false,
    this.isTreeMode = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.only(bottom: 6, left: indent ? 32 : 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: selectMode ? 0 : 1,
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : (p.isHidden
              ? theme.colorScheme.surfaceContainerHighest
              : theme.cardColor),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              if (selectMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
                    size: 22,
                  ),
                ),
              Icon(
                p.isLocked ? Icons.link : (p.isVariant ? Icons.subdirectory_arrow_right : Icons.inventory_2),
                size: 20,
                color: p.isLocked
                    ? theme.colorScheme.error
                    : (p.isVariant
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: indent ? 13 : 14,
                        color: p.isHidden ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                        decoration: p.isHidden ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (indent)
                      Row(children: [
                        if (p.barcode != null && p.barcode!.isNotEmpty)
                          Text(p.barcode!, style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                        if (p.barcode != null && p.barcode!.isNotEmpty && p.wholesalePrice > 0)
                          const SizedBox(width: 8),
                        Text(
                          '仕入 ¥${NumberFormat("#,###").format(p.wholesalePrice)}',
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const Spacer(),
                        Text(
                          '在庫: ${p.stockQuantity?.toString() ?? '管理なし'}',
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ])
                    else
                      Row(children: [
                        Flexible(
                          child: Text(
                            '販売 ¥${NumberFormat('#,###').format(p.defaultUnitPrice)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                          ),
                        ),
                        if (p.wholesalePrice > 0) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '仕入 ¥${NumberFormat('#,###').format(p.wholesalePrice)}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (!p.isNonStockCategory)
                          Text(
                            '在庫: ${p.stockQuantity?.toString() ?? '管理なし'}',
                            style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                          ),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<PopupMenuItem<String>> buildProductMenuItems(Product p, bool hasVariants, bool expanded, bool selectMode, bool selectionMode) {
  final list = <PopupMenuItem<String>>[];
  if (hasVariants) {
    list.add(PopupMenuItem(
      value: 'expand',
      child: ListTile(
        leading: Icon(expanded ? Icons.expand_less : Icons.expand_more),
        title: Text(expanded ? 'バリエーションを閉じる' : 'バリエーションを表示'),
        dense: true,
      ),
    ));
  }
  list.add(const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('編集'), dense: true)));
  if (!p.isVariant) {
    list.add(const PopupMenuItem(value: 'options', child: ListTile(leading: Icon(Icons.tune), title: Text('オプション管理'), dense: true)));
    if (hasVariants) {
      list.add(const PopupMenuItem(value: 'variant', child: ListTile(leading: Icon(Icons.add_box), title: Text('バリエーション追加'), dense: true)));
    }
    list.add(const PopupMenuItem(value: 'customer_price', child: ListTile(leading: Icon(Icons.attach_money), title: Text('顧客別価格'), dense: true)));
  }
  list.add(const PopupMenuItem(value: 'detail', child: ListTile(leading: Icon(Icons.info_outline), title: Text('詳細'), dense: true)));
  if (!selectMode && !selectionMode) {
    list.add(const PopupMenuItem(value: 'select', child: ListTile(leading: Icon(Icons.checklist), title: Text('複数選択モード'), dense: true)));
  }
  list.add(const PopupMenuItem(
    value: 'delete',
    child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('削除', style: TextStyle(color: Colors.red)), dense: true),
  ));
  return list;
}
