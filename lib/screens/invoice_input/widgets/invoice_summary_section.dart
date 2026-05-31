import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InvoiceSummarySection extends StatelessWidget {
  final int subtotal;
  final int itemDiscountAmount;
  final int priceAdjustmentDiscount;
  final int grossProfit;
  final double taxRate;
  final bool isTaxInclusiveMode;
  final bool includeTax;
  final bool isViewMode;
  final bool isLocked;
  final bool summaryIsBlue;
  final NumberFormat format;

  final VoidCallback? onPriceAdjustmentTap;
  final VoidCallback? onTaxRateTap;
  final ValueChanged<bool>? onSummaryThemeChanged;

  const InvoiceSummarySection({
    super.key,
    required this.subtotal,
    required this.itemDiscountAmount,
    required this.priceAdjustmentDiscount,
    required this.grossProfit,
    required this.taxRate,
    required this.isTaxInclusiveMode,
    required this.includeTax,
    required this.isViewMode,
    required this.isLocked,
    required this.summaryIsBlue,
    required this.format,
    this.onPriceAdjustmentTap,
    this.onTaxRateTap,
    this.onSummaryThemeChanged,
  });

  int get _totalDiscountAmount => itemDiscountAmount + priceAdjustmentDiscount;

  int get _tax {
    if (isTaxInclusiveMode) {
      final taxInclusiveSubtotal = subtotal - itemDiscountAmount - priceAdjustmentDiscount;
      return (taxInclusiveSubtotal * taxRate / (1 + taxRate)).round();
    } else {
      final taxableAmount = subtotal - _totalDiscountAmount;
      return includeTax ? (taxableAmount * taxRate).floor() : 0;
    }
  }

  int get _taxableAmount {
    if (isTaxInclusiveMode) {
      final taxInclusiveSubtotal = subtotal - itemDiscountAmount - priceAdjustmentDiscount;
      return taxInclusiveSubtotal - _tax;
    } else {
      return subtotal - _totalDiscountAmount;
    }
  }

  int get _total {
    if (isTaxInclusiveMode) {
      return subtotal - itemDiscountAmount - priceAdjustmentDiscount;
    } else {
      return _taxableAmount + _tax;
    }
  }

  String _formatAmount(int amount) {
    final formatted = format.format(amount);
    return formatted.isEmpty ? "0" : formatted;
  }

  Widget _buildSummaryRow(String label, String value, Color textColor, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int tax = _tax;
    final int taxableAmount = _taxableAmount;
    final int total = _total;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final useBlue = summaryIsBlue;
    final bgColor = useBlue
        ? Theme.of(context).colorScheme.primaryContainer
        : (isDark ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : Theme.of(context).colorScheme.surfaceContainerHighest);
    final borderColor = Colors.transparent;
    final labelColor = useBlue ? Theme.of(context).colorScheme.onPrimaryContainer : textColor;
    final totalColor = useBlue ? Theme.of(context).colorScheme.onPrimary : textColor;
    final dividerColor = useBlue
        ? Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.2)
        : Theme.of(context).dividerTheme.color ?? Theme.of(context).colorScheme.outline;

    return GestureDetector(
      onLongPress: () async {
        if (onSummaryThemeChanged == null) return;
        final selected = await showModalBottomSheet<String>(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.palette, color: Theme.of(context).colorScheme.primary),
                  title: const Text('インディゴ'),
                  onTap: () => Navigator.pop(context, 'blue'),
                ),
                ListTile(
                  leading: Icon(Icons.palette, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  title: const Text('白'),
                  onTap: () => Navigator.pop(context, 'white'),
                ),
              ],
            ),
          ),
        );
        if (selected == null) return;
        onSummaryThemeChanged!(selected == 'blue');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryRow(
              isTaxInclusiveMode ? "税込小計" : "小計",
              "￥${_formatAmount(subtotal)}",
              labelColor,
            ),
            if (itemDiscountAmount > 0 && !isTaxInclusiveMode) ...[
              Divider(color: dividerColor),
              _buildSummaryRow(
                "値引き",
                "-￥${_formatAmount(itemDiscountAmount)}",
                Theme.of(context).colorScheme.error,
              ),
            ],
            if (priceAdjustmentDiscount > 0 || (!isViewMode && !isLocked)) ...[
              Divider(color: dividerColor),
              GestureDetector(
                onTap: isViewMode || isLocked ? null : onPriceAdjustmentTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "価格調整",
                          style: TextStyle(
                            fontSize: 14,
                            color: useBlue ? Theme.of(context).colorScheme.onPrimary : (isDark ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        if (!isViewMode && !isLocked) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.settings,
                            size: 16,
                            color: useBlue
                                ? Theme.of(context).colorScheme.onPrimary
                                : (isDark ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ],
                    ),
                    if (priceAdjustmentDiscount > 0)
                      Text(
                        "-￥${_formatAmount(priceAdjustmentDiscount)}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: useBlue
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : (isDark ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.primary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            Divider(color: dividerColor),
            _buildSummaryRow(
              isTaxInclusiveMode ? "税抜金額（逆算）" : "税抜金額",
              "￥${_formatAmount(taxableAmount)}",
              labelColor,
            ),
            Divider(color: dividerColor),
            GestureDetector(
              onTap: isViewMode || isLocked ? null : onTaxRateTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tax > 0
                            ? (isTaxInclusiveMode
                                ? "消費税 (${(taxRate * 100).toInt()}% 逆算)"
                                : "消費税 (${(taxRate * 100).toInt()}%)")
                            : "消費税 (非課税)",
                        style: TextStyle(
                          fontSize: 14,
                          color: labelColor,
                        ),
                      ),
                      if (!(isViewMode || isLocked)) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit,
                          size: 14,
                          color: labelColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    tax > 0 ? "￥${_formatAmount(tax)}" : "￥0",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: dividerColor),
            _buildSummaryRow(
              tax > 0 ? "合計金額 (税込)" : "合計金額",
              "￥${_formatAmount(total)}",
              totalColor,
              isTotal: true,
            ),
            if (grossProfit != 0) ...[
              const SizedBox(height: 4),
              _buildSummaryRow(
                "参考粗利",
                "￥${_formatAmount(grossProfit)}",
                grossProfit >= 0 ? Colors.green : Colors.red,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
