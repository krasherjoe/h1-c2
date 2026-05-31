import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../calculator_keypad.dart';

Future<Map<String, dynamic>?> showPriceAdjustmentDialog(
  BuildContext context, {
  required int subtotal,
  required int itemDiscount,
  required double taxRate,
  required bool includeTax,
  required bool isTaxInclusiveMode,
  String? currentAdjustmentType,
  int? currentAdjustmentUnit,
}) async {
  final manualDiscountController = TextEditingController(
    text: (currentAdjustmentType == 'manual' && currentAdjustmentUnit != null
        ? currentAdjustmentUnit.toString()
        : '0'),
  );
  final calculatedResult = ValueNotifier<Map<String, int>>({});

  void updateCalculation() {
    final discount = int.tryParse(manualDiscountController.text) ?? 0;
    final baseAmount = subtotal - itemDiscount;

    int taxAmt;
    int taxableAmt;
    int adjustedTotal;

    if (isTaxInclusiveMode) {
      final taxInclusiveBase = baseAmount - discount;
      taxAmt = (taxInclusiveBase * taxRate / (1 + taxRate)).round();
      taxableAmt = taxInclusiveBase - taxAmt;
      adjustedTotal = taxInclusiveBase;
    } else {
      taxableAmt = baseAmount - discount;
      taxAmt = includeTax ? (taxableAmt * taxRate).floor() : 0;
      adjustedTotal = taxableAmt + taxAmt;
    }

    calculatedResult.value = {
      'subtotal': subtotal,
      'itemDiscount': itemDiscount,
      'baseAmount': baseAmount,
      'discount': discount,
      'taxableAmount': taxableAmt,
      'tax': taxAmt,
      'total': adjustedTotal,
    };
  }

  updateCalculation();

  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dialogHeight = MediaQuery.of(context).size.height * 0.8;
          return Dialog(
            child: SizedBox(
              width: 360,
              height: dialogHeight,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '値引き額:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: manualDiscountController,
                                  keyboardType: TextInputType.none,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Theme.of(dialogContext).colorScheme.surface,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (_) {
                                    updateCalculation();
                                    setState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 40,
                                height: 40,
                                child: IconButton(
                                  icon: const Icon(Icons.backspace),
                                  onPressed: () {
                                    if (manualDiscountController.text.isNotEmpty) {
                                      manualDiscountController.text =
                                          manualDiscountController.text.substring(
                                        0,
                                        manualDiscountController.text.length - 1,
                                      );
                                      updateCalculation();
                                      setState(() {});
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ValueListenableBuilder<Map<String, int>>(
                            valueListenable: calculatedResult,
                            builder: (context, result, _) {
                              if (result.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final fmt = NumberFormat('#,###');
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                                      : Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('小計:'),
                                        Text(
                                          '￥${fmt.format(result['subtotal'])}',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    if (result['itemDiscount']! > 0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('明細値引き:'),
                                          Text(
                                            '-￥${fmt.format(result['itemDiscount'])}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFFF6F00),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('値引き額:'),
                                        Text(
                                          '-￥${fmt.format(result['discount'])}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Theme.of(context).colorScheme.secondary
                                                : Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (includeTax) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '消費税 (${(taxRate * 100).toInt()}%):',
                                          ),
                                          Text(
                                            '￥${fmt.format(result['tax'])}',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '合計:',
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          '￥${fmt.format(result['total'])}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: dialogHeight * 0.5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InvoiceCalculatorKeypad(
                        controller: manualDiscountController,
                        onUpdate: () {
                          updateCalculation();
                          setState(() {});
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('キャンセル'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext, {
                              'type': null,
                              'unit': null,
                            });
                          },
                          child: Text(
                            'クリア',
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final discount = int.tryParse(manualDiscountController.text);
                            if (discount != null && discount >= 0) {
                              Navigator.pop(dialogContext, {
                                'type': 'manual',
                                'unit': discount,
                              });
                            }
                          },
                          child: const Text('登録'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
