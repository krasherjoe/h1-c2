import 'package:flutter/material.dart';

class DocumentSummarySection extends StatelessWidget {
  final int subtotal;
  final int discountAmount;
  final int taxableAmount;
  final int tax;
  final int total;
  final double taxRate;
  final String Function(int amount) formatMoney;
  final bool showDiscountOnly;
  final bool totalLabelIsTaxIncluded;
  final bool showTaxExcludedIfDifferent;

  const DocumentSummarySection({
    super.key,
    required this.subtotal,
    required this.discountAmount,
    required this.taxableAmount,
    required this.tax,
    required this.total,
    required this.taxRate,
    required this.formatMoney,
    this.showDiscountOnly = false,
    this.totalLabelIsTaxIncluded = false,
    this.showTaxExcludedIfDifferent = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDiscount = discountAmount > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (showDiscountOnly ? hasDiscount : true) ...[
            _row(cs, '小計', subtotal, labelColor: cs.onSurfaceVariant),
            if (hasDiscount) const SizedBox(height: 4),
          ],
          if (hasDiscount)
            _row(cs, '値引き', -discountAmount, labelColor: cs.error),
          if (showTaxExcludedIfDifferent
              ? (taxableAmount != subtotal)
              : true) ...[
            if (hasDiscount) const SizedBox(height: 4),
            _row(cs, '税抜合計', taxableAmount, labelColor: cs.onSurfaceVariant),
          ],
          const SizedBox(height: 4),
          _row(cs, '消費税 (${(taxRate * 100).round()}%)', tax, labelColor: cs.onSurfaceVariant),
          const Divider(height: 16),
          _row(cs, totalLabelIsTaxIncluded ? '合計 (税込)' : '合計', total, totalStyle: true),
        ],
      ),
    );
  }

  Widget _row(ColorScheme cs, String label, int amount, {bool totalStyle = false, Color? labelColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: totalStyle ? 15 : 13,
            fontWeight: totalStyle ? FontWeight.bold : FontWeight.normal,
            color: labelColor ?? cs.onSurface,
          )),
          Text(formatMoney(amount), style: TextStyle(
            fontSize: totalStyle ? 16 : 13,
            fontWeight: totalStyle ? FontWeight.bold : FontWeight.normal,
            color: totalStyle ? cs.primary : cs.onSurface,
          )),
        ],
      ),
    );
  }
}
