import 'package:flutter/material.dart';

class DocumentItemCard extends StatelessWidget {
  final String productName;
  final String maker;
  final String productCode;
  final String? notes;
  final int unitPrice;
  final double quantity;
  final int? discountAmount;
  final double? discountRate;
  final int subtotal;
  final String Function(int) formatMoney;
  final String Function(double) formatQty;

  final VoidCallback? onTapProductName;
  final VoidCallback? onTapMaker;
  final VoidCallback? onTapNotes;
  final VoidCallback? onTapPrice;
  final VoidCallback? onTapDiscount;
  final VoidCallback? onDelete;

  const DocumentItemCard({
    super.key,
    required this.productName,
    required this.maker,
    required this.productCode,
    this.notes,
    required this.unitPrice,
    required this.quantity,
    this.discountAmount,
    this.discountRate,
    required this.subtotal,
    required this.formatMoney,
    required this.formatQty,
    this.onTapProductName,
    this.onTapMaker,
    this.onTapNotes,
    this.onTapPrice,
    this.onTapDiscount,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDiscount = discountAmount != null || discountRate != null;
    final baseSubtotal = (quantity * unitPrice).round();
    final makerCode = [
      if (maker.isNotEmpty) maker,
      if (productCode.isNotEmpty) productCode,
    ].join(' / ');

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0.5,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 10, onDelete != null ? 4 : 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(
              child: Text(productName.isEmpty ? '(商品名未入力)' : productName,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500,
                  color: productName.isEmpty ? (cs.error) : cs.onSurface,
                  decoration: onTapProductName != null && productName.isNotEmpty
                      ? TextDecoration.underline : null)),
              onTap: onTapProductName,
            ),
            if (makerCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _buildField(
                  child: Text(makerCode, style: TextStyle(fontSize: 11.5,
                    color: cs.onSurfaceVariant,
                    decoration: onTapMaker != null ? TextDecoration.underline : null)),
                  onTap: onTapMaker,
                ),
              ),
            if (notes != null && notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _buildField(
                  child: Text(notes!, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  onTap: onTapNotes,
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildField(
                  child: Text(formatMoney(unitPrice),
                    style: TextStyle(fontSize: 12, color: cs.primary, fontWeight: FontWeight.w600,
                      decoration: onTapPrice != null ? TextDecoration.underline : null)),
                  onTap: onTapPrice,
                ),
                const SizedBox(width: 4),
                if (!hasDiscount)
                  Text('× ${formatQty(quantity)} = ${formatMoney(subtotal)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                else
                  onDelete != null
                      ? Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('× ${formatQty(quantity)} = ${formatMoney(baseSubtotal)}',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough)),
                          Text('値引後: ${formatMoney(subtotal)}',
                            style: TextStyle(fontSize: 12, color: cs.error, fontWeight: FontWeight.w600)),
                        ])
                      : Row(children: [
                          Text('× ${formatQty(quantity)} = ${formatMoney(baseSubtotal)}',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough)),
                          const SizedBox(width: 4),
                          Text(formatMoney(subtotal),
                            style: TextStyle(fontSize: 12, color: cs.error, fontWeight: FontWeight.w600)),
                        ]),
                if (onDelete != null) ...[
                  const Spacer(),
                  if (onTapDiscount != null)
                    IconButton(
                      icon: Icon(Icons.discount, size: 18,
                        color: hasDiscount ? cs.error : cs.onSurfaceVariant),
                      tooltip: '値引設定',
                      onPressed: onTapDiscount,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(formatQty(quantity),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                    onPressed: onDelete,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({required Widget child, VoidCallback? onTap}) {
    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}
