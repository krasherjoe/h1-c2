import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/invoice_models.dart';

class InvoiceHeaderSection extends StatelessWidget {
  final DateTime selectedDate;
  final bool showNewBadge;
  final bool showCopyBadge;
  final bool isViewMode;
  final bool isLocked;
  final DocumentType documentType;
  final bool hasRedInvoice;
  final bool isRedInvoice;
  final VoidCallback? onDateTap;
  final VoidCallback? onCreateReceipt;

  const InvoiceHeaderSection({
    super.key,
    required this.selectedDate,
    this.showNewBadge = false,
    this.showCopyBadge = false,
    required this.isViewMode,
    required this.isLocked,
    required this.documentType,
    this.hasRedInvoice = false,
    this.isRedInvoice = false,
    this.onDateTap,
    this.onCreateReceipt,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy/MM/dd');
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: isViewMode ? null : onDateTap,
          child: Builder(
            builder: (context) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      "伝票日付: ${fmt.format(selectedDate)}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (showNewBadge)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.tertiaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "新規",
                          style: TextStyle(
                            color: cs.onTertiaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (showCopyBadge)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "複写",
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (!isViewMode && !isLocked) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, size: 18, color: cs.primary),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
        if (isLocked && documentType == DocumentType.invoice && !hasRedInvoice && !isRedInvoice) ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onCreateReceipt,
            icon: const Icon(Icons.receipt, size: 16),
            label: const Text('領収証生成'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.secondary,
              foregroundColor: cs.onSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }
}
