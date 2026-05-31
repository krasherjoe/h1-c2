import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/invoice_models.dart';
import '../../models/payment_schedule_model.dart' show PaymentStatus;
import '../../models/document_type_colors.dart' show documentTypeBadgeColor;

class InvoiceHistoryItem extends StatelessWidget {
  final Invoice invoice;
  final bool isUnlocked;
  final NumberFormat amountFormatter;
  final DateFormat dateFormatter;
  final bool showInvoiceNumber;
  final bool isRedInvoice;
  final bool hasLinkedRedInvoice;
  final String? linkedRedInvoiceId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final bool isPickerMode;
  final bool isSelected;

  const InvoiceHistoryItem({
    super.key,
    required this.invoice,
    required this.isUnlocked,
    required this.amountFormatter,
    required this.dateFormatter,
    this.showInvoiceNumber = true,
    this.isRedInvoice = false,
    this.hasLinkedRedInvoice = false,
    this.linkedRedInvoiceId,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.isPickerMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surfaceColor = cs.surface;
    final draftTint = Color.alphaBlend(
      const Color(0xFFFFC107).withValues(alpha: 0.15),
      cs.surface,
    );
    final redTint = Color.alphaBlend(
      cs.error.withValues(alpha: 0.08),
      cs.surface,
    );
    final cancelledTint = Color.alphaBlend(
      cs.error.withValues(alpha: 0.04),
      cs.surface,
    );
    final cardColor = isRedInvoice
        ? redTint
        : hasLinkedRedInvoice
        ? cancelledTint
        : invoice.isDraft
        ? draftTint
        : surfaceColor;
    final cardBorder = isRedInvoice || hasLinkedRedInvoice
        ? BorderSide(
            color: cs.error.withValues(alpha: isRedInvoice ? 0.3 : 0.15),
            width: isRedInvoice ? 1.5 : 1.0,
          )
        : null;
    final iconBg = isUnlocked
        ? documentTypeBadgeColor(invoice.documentType).withValues(alpha: 0.12)
        : cs.surfaceContainerHighest;
    final iconColor = isUnlocked
        ? documentTypeBadgeColor(invoice.documentType)
        : cs.onSurfaceVariant;
    final docLabel = _docTypeLabel(invoice.documentType);
    final docLabelColor = documentTypeBadgeColor(invoice.documentType);

    final hasSubject = invoice.subject?.isNotEmpty ?? false;
    final firstItemDesc = invoice.items.isNotEmpty
        ? invoice.items.first.description
        : '';
    final othersCount = invoice.items.length > 1 ? invoice.items.length - 1 : 0;
    final subjectLine = hasSubject ? invoice.subject! : firstItemDesc;
    final subjectDisplay = hasSubject
        ? subjectLine
        : (othersCount > 0 ? "$subjectLine 他$othersCount件" : subjectLine);
    final customerName = invoice.customerNameForDisplay.endsWith('様')
        ? invoice.customerNameForDisplay
        : '${invoice.customerNameForDisplay} 様';
    final subjectColor = cs.primary;
    final amountColor = cs.onSurface;
    final subjectWeight = invoice.isLocked
        ? FontWeight.normal
        : FontWeight.bold;
    final amountWeight = invoice.isLocked ? FontWeight.normal : FontWeight.bold;
    final dateColor = cs.onSurfaceVariant;

    final card = Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: cardBorder ?? BorderSide.none,
      ),
      elevation: invoice.isDraft ? 1.5 : 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: iconBg,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: Icon(
                            _docTypeIcon(invoice.documentType),
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        if (invoice.isLocked)
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(
                              Icons.link,
                              size: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    docLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: docLabelColor,
                    ),
                  ),
                  if (isRedInvoice)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: cs.error,
                        ),
                      ),
                    )
                  else if (hasLinkedRedInvoice)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '取消済',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          dateFormatter.format(invoice.date),
                          style: TextStyle(fontSize: 12, color: dateColor),
                        ),
                        if (invoice.isDraft)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '下書き',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ),
                        if (invoice.documentType == DocumentType.invoice &&
                            invoice.isReceiptIssued)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .tertiaryContainer
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '領収書発行済',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          ),
                        if (invoice.paymentStatus == PaymentStatus.paid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '入金済',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.green.shade700,
                              ),
                            ),
                          )
                        else if (invoice.paymentStatus == PaymentStatus.partial)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '一部入金',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customerName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: invoice.isLocked
                            ? FontWeight.normal
                            : FontWeight.w700,
                        color: cs.onSurface,
                        decoration: isRedInvoice || hasLinkedRedInvoice
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showInvoiceNumber) ...[
                      const SizedBox(height: 2),
                      Text(
                        invoice.invoiceNumber,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subjectDisplay,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: subjectWeight,
                              color: cs.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "￥${amountFormatter.format(invoice.totalAmount)}",
                          style: TextStyle(
                            fontWeight: amountWeight,
                            fontSize: 13,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (isPickerMode) {
      return Stack(
        children: [
          card,
          if (isSelected)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      );
    }
    return card;
  }

  IconData _docTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.estimation:
        return Icons.request_quote;
      case DocumentType.order:
        return Icons.assignment;
      case DocumentType.delivery:
        return Icons.local_shipping;
      case DocumentType.invoice:
        return Icons.receipt_long;
      case DocumentType.receipt:
        return Icons.task_alt;
    }
  }

  String _docTypeLabel(DocumentType type) {
    switch (type) {
      case DocumentType.estimation:
        return '見積';
      case DocumentType.order:
        return '受注';
      case DocumentType.delivery:
        return '納品';
      case DocumentType.invoice:
        return '請求';
      case DocumentType.receipt:
        return '領収';
    }
  }
}
