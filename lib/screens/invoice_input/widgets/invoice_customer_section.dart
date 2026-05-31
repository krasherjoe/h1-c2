import 'package:flutter/material.dart';
import '../../../models/customer_model.dart';
import '../../../models/invoice_models.dart';
import '../../../models/payment_schedule_model.dart' show PaymentStatus;
import '../../../widgets/customer_rank_badge.dart';

class InvoiceCustomerSection extends StatelessWidget {
  final Customer? selectedCustomer;
  final Invoice? currentInvoice;
  final bool isViewMode;
  final bool isLocked;
  final VoidCallback? onSelectCustomer;

  const InvoiceCustomerSection({
    super.key,
    required this.selectedCustomer,
    required this.currentInvoice,
    required this.isViewMode,
    required this.isLocked,
    this.onSelectCustomer,
  });

  static String _customerNameWithHonorific(Customer customer) {
    final base = customer.formalName;
    final hasHonorific = RegExp(r'(様|御中|殿)$').hasMatch(base);
    return hasHonorific
        ? base
        : "$base ${HonorificCode.toName(customer.title)}";
  }

  BoxDecoration _cardDecoration(BuildContext context, {Color? baseColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    baseColor ??= Theme.of(context).cardColor;
    if (isDark) {
      return BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: 0.10), baseColor),
            baseColor,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.06),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      );
    } else {
      return BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context, baseColor: Theme.of(context).colorScheme.surface),
      child: ListTile(
        leading: Icon(Icons.business, color: Theme.of(context).colorScheme.onSurfaceVariant),
        title: Row(
          children: [
            Flexible(
              child: Text(
                selectedCustomer != null
                    ? _customerNameWithHonorific(selectedCustomer!)
                    : "取引先を選択してください",
                style: TextStyle(
                  color: selectedCustomer == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (selectedCustomer != null && selectedCustomer!.rank != CustomerRank.none)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: CustomerRankBadge(
                  rank: selectedCustomer!.rank,
                  discountRateOverride: selectedCustomer!.rankDiscountRate,
                  compact: true,
                ),
              ),
            if (currentInvoice != null && currentInvoice!.paymentStatus == PaymentStatus.paid)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.check_circle, size: 16, color: Colors.green),
              )
            else if (currentInvoice != null && currentInvoice!.paymentStatus == PaymentStatus.partial)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.adjust, size: 16, color: Colors.orange),
              ),
          ],
        ),
        subtitle: isViewMode
            ? null
            : Text(
                "顧客マスターから選択",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: (isViewMode || isLocked)
            ? null
            : const Icon(Icons.chevron_right),
        onTap: (isViewMode || isLocked)
            ? null
            : onSelectCustomer,
      ),
    );
  }
}
