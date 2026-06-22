import 'package:flutter/material.dart';
import '../../../utils/theme_utils.dart' show textColorOn;

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
  final int? priceAdjustmentAmount;
  final String? priceAdjustmentLabel;
  final VoidCallback? onPriceAdjustmentTap;
  final String? paymentStatus;
  final int? receivedAmount;

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
    this.priceAdjustmentAmount,
    this.priceAdjustmentLabel,
    this.onPriceAdjustmentTap,
    this.paymentStatus,
    this.receivedAmount,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasDiscount = discountAmount > 0;
    final hasPriceAdjustment = priceAdjustmentAmount != null && priceAdjustmentAmount! > 0;
    final hasAnyAdjustment = hasDiscount || hasPriceAdjustment;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (showDiscountOnly ? hasAnyAdjustment : true) ...[
            _row(cs, '小計', subtotal, labelColor: cs.onSurfaceVariant),
            if (hasAnyAdjustment) const SizedBox(height: 4),
          ],
          if (hasDiscount)
            _row(cs, '値引き', -discountAmount, labelColor: cs.error),
          if (hasPriceAdjustment)
            GestureDetector(
              onTap: onPriceAdjustmentTap,
              child: _row(cs, priceAdjustmentLabel ?? '端数調整', -priceAdjustmentAmount!, labelColor: cs.error),
            ),
          if (showTaxExcludedIfDifferent
              ? (taxableAmount != subtotal)
              : true) ...[
            if (hasAnyAdjustment) const SizedBox(height: 4),
            _row(cs, '税抜合計', taxableAmount, labelColor: cs.onSurfaceVariant),
          ],
          const SizedBox(height: 4),
          _row(cs, '消費税 (${(taxRate * 100).round()}%)', tax, labelColor: cs.onSurfaceVariant),
          const Divider(height: 16),
          _row(cs, totalLabelIsTaxIncluded ? '合計 (税込)' : '合計', total, totalStyle: true),
          if (paymentStatus != null) ...[
            const SizedBox(height: 8),
            _paymentStatusRow(cs),
          ],
        ],
      ),
    );
  }

  Widget _paymentStatusRow(ColorScheme cs) {
    final (Color badgeColor, String badgeText, String infoText) = switch (paymentStatus) {
      'paid' => (cs.primary, '済', '入金済: ${formatMoney(receivedAmount ?? total)}'),
      'partial' => (cs.tertiary, '一部入金', '入金: ${formatMoney(receivedAmount ?? 0)} / ${formatMoney(total)}'),
      'unpaid' => (cs.error, '未払い', '残高: ${formatMoney(total)}'),
      _ => (cs.error, '', ''),
    };
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(badgeText, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: textColorOn(badgeColor),
          )),
        ),
        const SizedBox(width: 8),
        Text(infoText, style: TextStyle(fontSize: 13, color: cs.onSurface)),
      ],
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
