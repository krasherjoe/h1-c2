import '../../../models/invoice_models.dart';

int calculateGrossProfit(List<InvoiceItem> items, Map<String, int> wholesalePrices) {
  int gp = 0;
  for (final item in items) {
    final wp = item.productId != null ? wholesalePrices[item.productId] : null;
    if (wp != null && wp > 0) {
      gp += (item.unitPrice - wp) * item.quantity;
    }
  }
  return gp;
}

int calculateItemDiscount(List<InvoiceItem> items) {
  return items.fold(0, (sum, item) {
    if (item.discountAmount != null && item.discountAmount! > 0) {
      return sum + item.discountAmount!;
    }
    if (item.discountRate != null && item.discountRate! > 0) {
      final base = item.quantity * item.unitPrice;
      return sum + (base * item.discountRate!).round();
    }
    return sum;
  });
}

int calculatePriceAdjustmentDiscount(
  Invoice? currentInvoice,
  List<InvoiceItem> items,
  bool isTaxInclusiveMode,
  bool includeTax,
  double taxRate,
) {
  final adjustmentType = currentInvoice?.priceAdjustmentType;
  final adjustmentUnit = currentInvoice?.priceAdjustmentUnit;

  if (adjustmentType == null || adjustmentUnit == null) {
    return 0;
  }

  if (adjustmentType == 'manual') {
    return adjustmentUnit;
  }

  final unit = adjustmentUnit;
  final baseAmount = calculateSubTotal(items) - calculateItemDiscount(items);

  int totalBeforeAdjustment;
  if (isTaxInclusiveMode) {
    totalBeforeAdjustment = baseAmount;
  } else {
    final taxAmount = includeTax ? (baseAmount * taxRate).floor() : 0;
    totalBeforeAdjustment = baseAmount + taxAmount;
  }

  int adjustedTotal;
  switch (adjustmentType) {
    case 'round_down':
      adjustedTotal = (totalBeforeAdjustment ~/ unit) * unit;
      break;
    case 'round_up':
      adjustedTotal = ((totalBeforeAdjustment + unit - 1) ~/ unit) * unit;
      break;
    case 'round_nearest':
      adjustedTotal = ((totalBeforeAdjustment + unit ~/ 2) ~/ unit) * unit;
      break;
    default:
      return 0;
  }

  return totalBeforeAdjustment - adjustedTotal;
}

int calculateSubTotal(List<InvoiceItem> items) {
  return items.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));
}
